import CoreGraphics
import PoseDomain

/// Trạng thái màn xem lại — bước cuối của chuỗi lõi. Port `KT/result/ResultUiState.kt`.
///
///     ảnh mẫu → hướng dẫn → quay → **chọn 5 ảnh khớp nhất** → giữ 1
///
/// Khác Kotlin: bỏ `templateName` / `templateThumb` — Kotlin nạp nhưng `ResultScreen` không hiện ở đâu.
struct ResultUiState {
    var loading = true

    /// Tối đa 5 khung, tốt nhất đứng đầu.
    var shots: [ResultShot] = []

    /// Ảnh đang được xem to. Mặc định là tấm đứng đầu.
    var selectedId: Int64?

    /// Ảnh đã TÍCH để "Lưu ảnh đã chọn".
    var checked: Set<Int64> = []

    /// Đang lưu/xoá — khoá các nút để không bấm chồng.
    var busy = false

    /// Bấm quay lại khi chưa lưu hay xoá — hiện hộp thoại hỏi có lưu không.
    var hoiKhiThoat = false

    /// Đang hỏi lại trước khi xoá hết.
    var xacNhanXoa = false

    /// Đã xong — màn hình đóng và chuyển tới đây. `nil` = còn ở lại.
    var exitTo: ResultExit?

    var message: UiText?

    var selected: ResultShot? {
        shots.first { $0.candidate.id == selectedId } ?? shots.first
    }

    var isEmpty: Bool { !loading && shots.isEmpty }

    /// Những mục mà **KHÔNG khung nào trong cả lần quay đạt nổi** — xem `FailedCriterion.failedCriteria` (FOOTGUNS 24).
    var failedCriteria: [FailedCriterion] {
        FailedCriterion.failedCriteria(shots.map(\.candidate))
    }
}

nonisolated struct ResultShot {
    let candidate: ShotCandidate
    let bitmap: CGImage?

    /// Điểm hiện cho người dùng: số nguyên 0-100.
    ///
    /// ⚠️ `"%.0f".format(x)` của Java làm tròn **nửa lên** (48,5 → "49"); `String(format: "%.0f")` của C làm tròn **nửa về
    /// số chẵn** (→ "48"). Điểm đọc lại từ bảng kê 3 chữ số thập phân nên ,500 gặp được. Điểm luôn ≥ 0 → `rounded()`.
    var scoreText: String { String(Int(candidate.score.rounded())) }
}

/// Rời màn kết quả đi đâu (17/10/2026, PO chốt).
enum ResultExit {
    /// Đã lưu → sang Thư viện xem ngay cặp ảnh mẫu / ảnh chụp.
    case library
    /// Đã xoá để chụp lại → về camera, giữ nguyên ảnh mẫu.
    case camera
    /// Thoát bằng nút quay lại (đã lưu hoặc bỏ) → về màn Ảnh mẫu.
    case templates
}

enum ResultAction {
    /// Xem to một ảnh.
    case select(Int64)
    /// Tích / bỏ tích một ảnh để lưu riêng.
    case toggleCheck(Int64)
    /// Lưu MỌI ảnh (kèm ảnh mẫu, xếp theo điểm) → Thư viện.
    case saveAll
    /// Chỉ lưu ảnh đã tích → Thư viện.
    case saveChecked
    /// Hỏi lại trước khi xoá hết.
    case askDiscard
    case cancelDiscard
    /// Xoá hết ảnh lần chụp này → về camera chụp lại.
    case discard
    /// Nút quay lại khi chưa lưu hay xoá.
    case back
    case dismissBack
    /// Hộp thoại quay lại: lưu tất cả rồi về màn Ảnh mẫu.
    case backSave
    /// Hộp thoại quay lại: không lưu — xoá rồi về màn Ảnh mẫu.
    case backDiscard
}
