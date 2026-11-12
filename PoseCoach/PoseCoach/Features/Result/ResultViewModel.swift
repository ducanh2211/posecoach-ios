import CoreGraphics
import Foundation
import PoseDomain

/// Port `KT/result/ResultViewModel.kt`.
///
/// Khác Kotlin: ViewModel tạo mới mỗi lần vào màn (`RootView` dựng `ResultView` theo phiên), nên không cần `loadedDir`
/// để phân biệt "dựng lại giao diện" với "lần quay mới" — trạng thái cũ không thể sót lại. Vẫn xoá `exitTo` sau khi dùng
/// (FOOTGUNS 114).
@Observable @MainActor final class ResultViewModel {

    private(set) var state = ResultUiState()

    @ObservationIgnored private let store: ShotStore
    @ObservationIgnored private let templateFile: URL
    /// Album sẽ ghi khi lưu. Ảnh giữ lại đi thẳng vào THƯ VIỆN — chỗ duy nhất chứa ảnh kết quả, xem lại bất cứ lúc nào
    /// ở tab "Thư viện".
    @ObservationIgnored private let keepDir: URL
    @ObservationIgnored private var loadStarted = false

    init(sessionDir: URL, templateFile: URL) {
        store = ShotStore.openSession(sessionDir)
        self.templateFile = templateFile
        keepDir = ResultLibrary.dir().appendingPathComponent("buoi-\(Int64(Date().timeIntervalSince1970 * 1000))")
    }

    /// Nạp kết quả từ ĐĨA, không nhận từ màn trước.
    ///
    /// Cố ý như vậy: màn camera và màn này là hai màn riêng, ViewModel của màn trước đã bị huỷ khi rời đi. Đọc lại từ
    /// đĩa thì màn này tự đứng được.
    func load() async {
        if loadStarted { return }
        loadStarted = true
        let s = store
        let shots = await Task.detached {
            s.readIndex().map { c in ResultShot(candidate: c, bitmap: Self.decodeSampled(s.file(c.id), 1280)) }
        }.value
        state.loading = false
        state.shots = shots
        state.selectedId = shots.first?.candidate.id
    }

    /// Màn hình đã chuyển đi theo `ResultUiState.exitTo` — xoá để không dùng lại.
    func onExitHandled() { state.exitTo = nil }

    func onAction(_ action: ResultAction) {
        switch action {
        case let .select(id): state.selectedId = id
        case let .toggleCheck(id):
            if state.checked.contains(id) { state.checked.remove(id) } else { state.checked.insert(id) }
        case .saveAll: save(state.shots, .library)
        case .saveChecked: save(state.shots.filter { state.checked.contains($0.candidate.id) }, .library)
        case .askDiscard: state.xacNhanXoa = true
        case .cancelDiscard: state.xacNhanXoa = false
        case .discard: discard(.camera)
        // Không có ảnh nào thì chẳng có gì để hỏi — dọn rồi thoát luôn.
        case .back:
            if state.shots.isEmpty { discard(.templates) } else { state.hoiKhiThoat = true }
        case .dismissBack: state.hoiKhiThoat = false
        case .backSave: save(state.shots, .templates)
        case .backDiscard: discard(.templates)
        }
    }

    /// Lưu `shots` vào thư viện KÈM ẢNH MẪU, giống mẫu nhất đứng đầu (17/10/2026), rồi xoá phiên tạm.
    ///
    /// Chép RA NGOÀI trước, chép xong mới xoá phiên — làm ngược lại thì chép hỏng là người dùng mất trắng cả lần chụp.
    private func save(_ shots: [ResultShot], _ exit: ResultExit) {
        if shots.isEmpty || state.busy { return }
        state.busy = true
        state.hoiKhiThoat = false
        let s = store, dir = keepDir, mau = templateFile
        Task {
            let ok = await Task.detached {
                // `sortedByDescending` của Kotlin là sắp xếp ổn định; giữ thứ tự cũ khi bằng điểm.
                let anh = shots.enumerated()
                    .sorted { a, b in
                        a.element.candidate.score > b.element.candidate.score
                            || (a.element.candidate.score == b.element.candidate.score && a.offset < b.offset)
                    }
                    .map { (s.file($0.element.candidate.id), Self.roundToInt($0.element.candidate.score)) }
                    .filter { FileManager.default.fileExists(atPath: $0.0.path) }
                return !anh.isEmpty && ResultLibrary.ghiAlbum(dir, mau, anh)
            }.value
            if !ok {
                state.busy = false
                state.message = uiText("result_save_all_failed")
                return
            }
            await Task.detached { s.deleteSession() }.value
            state.busy = false
            state.exitTo = exit
            state.message = nil
        }
    }

    /// Xoá hết ảnh của lần chụp này (không lưu gì).
    private func discard(_ exit: ResultExit) {
        state.busy = true
        state.hoiKhiThoat = false
        state.xacNhanXoa = false
        let s = store
        Task {
            await Task.detached { s.deleteSession() }.value
            state.busy = false
            state.exitTo = exit
        }
    }

    /// Như `roundToInt()` của Kotlin: nửa lên +∞.
    private nonisolated static func roundToInt(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

    /// Đọc ảnh đã thu nhỏ sẵn. Ảnh gốc là hàng chục triệu điểm ảnh; mở 5 tấm cùng lúc ở kích thước gốc là chắc chắn hết
    /// bộ nhớ. ⚠️ Qua `UprightImage`, không đọc file ảnh cách khác.
    private nonisolated static func decodeSampled(_ file: URL, _ maxWidth: Int) -> CGImage? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return UprightImage.decode(file, shortSide: maxWidth)
    }
}
