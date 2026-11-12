import Foundation
import PhotosUI
import PoseDomain
import SwiftUI

/// ĐIỀU PHỐI LUỒNG ĐỀ XUẤT: gom đầu vào → phân tích phần MỚI → gộp nhãn → xếp ảnh mẫu. Port `KT/scene/SceneViewModel.kt`.
///
/// Câu gõ đóng vai MỘT khung hình như ảnh, nên mọi đầu vào đi qua đúng một hàm xếp hạng `SceneMatching.rank`, kể cả
/// phần "khớp một phần, thiếu gì".
///
/// Khác Kotlin: MVI → MVVM, mỗi `SceneAction` thành một hàm. ViewModel tạo mới mỗi lần mở luồng nên không cần
/// `Clear` lúc MỞ (FOOTGUNS 107.1); vẫn gọi `clear()` lúc RỜI để xoá ảnh/video tạm. Thêm `addPicked`: chép mục chọn từ
/// Photo Picker ra file tạm trước khi đưa vào `addMedia`.
@Observable @MainActor final class SceneViewModel {

    private(set) var state = SceneUiState()

    @ObservationIgnored private let repository = SceneRepository()
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var nextId: Int64 = 1
    /// Khung hình đã phân tích của từng đầu vào — thêm ảnh mới không phải phân tích lại ảnh cũ.
    @ObservationIgnored private var framesById: [Int64: [SceneFrame]] = [:]
    /// Yếu tố người dùng đã bỏ chọn — giữ qua các lần đề xuất lại.
    @ObservationIgnored private var deselected: Set<String> = []
    @ObservationIgnored private var templates: [SceneTemplate] = []
    /// Lỗi lúc chép mục chọn từ thư viện máy — đưa vào lần đề xuất kế tiếp như lỗi của một đầu vào hỏng.
    @ObservationIgnored private var loiNhap: UiText?

    /// Thêm ảnh/video. `captured` = app tự chụp bằng camera bối cảnh.
    func addMedia(_ files: [URL], captured: Bool) {
        if files.isEmpty { return }
        let added = files.map { f -> SceneInput in
            defer { nextId += 1 }
            return SceneInput(id: nextId, file: f, video: SceneRepository.isVideo(f), captured: captured)
        }
        state.inputs += added
        suggest()
    }

    /// Mục chọn từ thư viện của máy: chép ra file tạm rồi thêm như `addMedia(…, captured: false)`.
    func addPicked(_ items: [PhotosPickerItem]) {
        if items.isEmpty { return }
        Task {
            var files: [URL] = []
            for item in items {
                if let f = await SceneRepository.copyPicked(item) { files.append(f) }
            }
            if files.count < items.count { loiNhap = uiText("scene_err_type") }
            if files.isEmpty {
                state.error = loiNhap
                loiNhap = nil
                return
            }
            addMedia(files, captured: false)
        }
    }

    func removeInput(_ id: Int64) {
        framesById[id] = nil
        state.inputs.removeAll { $0.id == id }
        suggest()
    }

    /// Tìm lại với câu mô tả mới (rỗng = bỏ câu mô tả).
    func searchText(_ text: String) {
        state.query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        suggest()
    }

    func toggleTag(_ id: String) {
        if deselected.remove(id) == nil { deselected.insert(id) }
        let selected = Set(state.tags.map(\.id)).subtracting(deselected)
        state.selected = selected
        state.matches = SceneMatching.rank(frames(state), templates, selected)
    }

    func cancel() {
        work?.cancel()
        state.analyzing = false
        state.progress = nil
    }

    /// Rời luồng: dừng phân tích, xoá ảnh/video tạm, về trạng thái trống.
    func clear() {
        work?.cancel()
        framesById.removeAll()
        deselected.removeAll()
        templates = []
        state = SceneUiState()
        SceneRepository.clearCaptures()
    }

    /// Mọi khung hình: của các ảnh/video còn trong danh sách, cộng câu gõ.
    private func frames(_ s: SceneUiState) -> [SceneFrame] {
        let media = s.inputs.flatMap { framesById[$0.id] ?? [] }
        let typed = SceneVocabulary.parse(s.query).labels.compactMap { SceneMatching.typedTag($0) }
        return typed.isEmpty ? media : media + [SceneFrame(-1, typed)]
    }

    private func suggest() {
        let previous = work
        previous?.cancel()
        if !state.hasInput {
            state.analyzing = false
            state.progress = nil
            state.analyzed = false
            state.tags = []
            state.matches = []
            return
        }
        state.analyzing = true
        state.error = nil
        state.progress = nil
        var loi = loiNhap
        loiNhap = nil
        let repository = self.repository
        work = Task {
            await previous?.value
            let report: @Sendable (UiText) async -> Void = { [weak self] message in
                await MainActor.run {
                    guard let self, !Task.isCancelled else { return }
                    self.state.progress = message
                }
            }
            // Từng đầu vào mới. Một ảnh hỏng thì bỏ ảnh đó, báo lỗi, các ảnh khác vẫn chạy.
            for input in state.inputs where framesById[input.id] == nil {
                do {
                    framesById[input.id] = try await repository.framesOf(input.file, video: input.video, progress: report)
                } catch is CancellationError {
                    return
                } catch {
                    if Task.isCancelled { return }
                    loi = Self.loiCua(error)
                    state.inputs.removeAll { $0.id == input.id }
                }
            }
            do {
                let (lib, unreadable) = try await repository.library(progress: report)
                templates = lib
                if Task.isCancelled { return }
                let all = frames(state)
                let tags = SceneMatching.tags(all)
                let selected = Set(tags.map(\.id)).subtracting(deselected)
                state.analyzing = false
                state.progress = nil
                state.error = loi
                state.analyzed = true
                state.tags = tags
                state.selected = selected
                state.matches = SceneMatching.rank(all, lib, selected)
                state.unknownWords = SceneVocabulary.parse(state.query).unknown
                state.templateCount = lib.count
                state.unreadableTemplates = unreadable
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                state.analyzing = false
                state.progress = nil
                state.error = uiText("scene_err_analyze", .text(Self.chiTiet(error)))
            }
        }
    }

    private static func loiCua(_ error: Error) -> UiText {
        (error as? SceneError)?.text ?? uiText("scene_err_analyze", .text(chiTiet(error)))
    }

    private static func chiTiet(_ error: Error) -> UiText {
        let m = error.localizedDescription
        return m.isEmpty ? uiText("scene_err_try_other") : .raw(m)
    }
}
