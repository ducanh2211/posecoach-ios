import Foundation
import PoseDomain
import Testing
@testable import PoseCoach

/// Phase 5 — luồng đề xuất ảnh mẫu theo bối cảnh: gắn nhãn ảnh bằng ML Kit, lưu nhãn thư viện ảnh mẫu
/// (`scene-tags-v1.json`, FOOTGUNS 107.4), gõ chữ đi chung hàm xếp hạng, rời luồng thì xoá file tạm (FOOTGUNS 107.1).
@Suite(.serialized) @MainActor
struct SceneFlowTests {

    private final class Ghi: @unchecked Sendable {
        private let lock = NSLock()
        private var _ds: [UiText] = []
        var ds: [UiText] { lock.withLock { _ds } }
        func them(_ t: UiText) { lock.withLock { _ds.append(t) } }
    }

    private func anhCaiSan(_ ten: String) throws -> URL {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return try #require(e.compactMap { $0 as? URL }.first { $0.lastPathComponent == ten }, "thiếu ảnh mẫu \(ten)")
    }

    private func laMa(_ t: UiText, _ key: String) -> Bool {
        if case let .res(k, _) = t { return k == key }
        return false
    }

    @Test func gocAnhRaMotKhungCoNhan() async throws {
        let f = try anhCaiSan("ngang-di-bo-ben-ho.jpg")
        let ghi = Ghi()
        let frames = try await SceneRepository().framesOf(f, video: false) { ghi.them($0) }
        #expect(frames.count == 1 && frames[0].timeMs == 0)
        #expect(ghi.ds.contains { laMa($0, "scene_progress_labeling") })
        // Ảnh đi bộ bên hồ ngoài trời: ML Kit phải nhận ra ít nhất một yếu tố bối cảnh có trong bộ nhãn.
        #expect(!frames[0].tags.isEmpty, "không nhận ra yếu tố bối cảnh nào")
    }

    @Test func fileKhongPhaiAnhThiBaoLoiCoCau() async throws {
        let f = FileManager.default.temporaryDirectory.appendingPathComponent("hong-\(UUID().uuidString).jpg")
        try Data("khong phai anh".utf8).write(to: f)
        defer { try? FileManager.default.removeItem(at: f) }
        do {
            _ = try await SceneRepository().framesOf(f, video: false) { _ in }
            Issue.record("phải ném lỗi")
        } catch let e as SceneError {
            #expect(e.text == uiText("scene_err_type"))
        }
        let v = FileManager.default.temporaryDirectory.appendingPathComponent("hong-\(UUID().uuidString).mov")
        try Data("khong phai video".utf8).write(to: v)
        defer { try? FileManager.default.removeItem(at: v) }
        do {
            _ = try await SceneRepository().framesOf(v, video: true) { _ in }
            Issue.record("phải ném lỗi")
        } catch let e as SceneError {
            #expect(e.text == uiText("scene_err_duration"))
        }
    }

    /// Lần đầu gắn nhãn cả thư viện và GHI tệp lưu; lần sau đọc lại, không chạy ML Kit cho ảnh không đổi.
    @Test func nhanThuVienDuocLuuLai() async throws {
        await Task.detached { MediaLibrary.seedBuiltInTemplates() }.value
        let repo = SceneRepository()
        let (lan1, hong1) = try await repo.library { _ in }
        #expect(!lan1.isEmpty && hong1 == 0)
        let cache = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scene-tags-v1.json")
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: cache)) as? [String: Any])
        #expect(json.count == lan1.count)

        let ghi = Ghi()
        let (lan2, _) = try await repo.library { ghi.them($0) }
        #expect(lan2 == lan1)
        #expect(!ghi.ds.contains { laMa($0, "scene_progress_templates") }, "ảnh không đổi thì không gắn nhãn lại")
    }

    /// Chỉ gõ chữ (không ảnh): câu gõ là MỘT khung, ra yếu tố + xếp ảnh mẫu; từ không hiểu được báo ra.
    @Test func goChuDiChungHamXepHang() async throws {
        await Task.detached { MediaLibrary.seedBuiltInTemplates() }.value
        let vm = SceneViewModel()
        vm.searchText("  bãi biển xyzzy  ")
        #expect(vm.state.query == "bãi biển xyzzy" && vm.state.analyzing)
        for _ in 0..<600 where vm.state.analyzing { try await Task.sleep(for: .milliseconds(50)) }
        #expect(vm.state.analyzed && !vm.state.analyzing && vm.state.error == nil)
        #expect(vm.state.tags.map(\.id).contains("Beach"))
        #expect(vm.state.selected == Set(vm.state.tags.map(\.id)))
        #expect(vm.state.unknownWords == ["xyzzy"])
        #expect(vm.state.templateCount > 0)

        // Bỏ chọn một yếu tố: xếp lại ngay, không phân tích lại.
        vm.toggleTag("Beach")
        #expect(!vm.state.selected.contains("Beach") && !vm.state.analyzing)
        vm.toggleTag("Beach")
        #expect(vm.state.selected.contains("Beach"))

        // Xoá chữ → không còn đầu vào → về trạng thái chưa tìm.
        vm.searchText("")
        #expect(!vm.state.analyzed && vm.state.tags.isEmpty && vm.state.matches.isEmpty)
    }

    @Test func roiLuongXoaFileTam() throws {
        let f = SceneRepository.newCaptureFile("jpg")
        try Data([1, 2, 3]).write(to: f)
        let vm = SceneViewModel()
        vm.addMedia([f], captured: true)
        #expect(vm.state.inputs.count == 1 && !vm.state.inputs[0].video)
        vm.clear()
        #expect(vm.state.inputs.isEmpty && !vm.state.analyzing)
        #expect(!FileManager.default.fileExists(atPath: f.path), "rời luồng phải xoá ảnh/video tạm")
        #expect(SceneRepository.isVideo(URL(fileURLWithPath: "/a/b.mov")) && SceneRepository.isVideo(URL(fileURLWithPath: "/a/b.mp4")))
    }
}
