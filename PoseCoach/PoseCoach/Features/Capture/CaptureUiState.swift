import CoreGraphics
import Foundation
import PoseDomain

/// Trạng thái màn chụp. Port `KT/capture/CaptureUiState.kt`.
///
/// Khác Android: `debugDo`, `debugGocMay` (code `⚠️ TẠM`, D7) chỉ có ở bản Debug, kèm `debugChiTiet` riêng iOS —
/// xem `CaptureViewModel+Debug`.
struct CaptureUiState {

    #if DEBUG
    var debugGocMay: String?
    var debugDo: String?
    var debugChiTiet: String?
    #endif

    /// Độ giống ảnh mẫu ngay lúc này, 0..100. `nil` = chưa đo được.
    var matchPercent: Int?
    /// Đã đủ giống để chuẩn bị tạo dáng và bấm quay.
    var readyToPose = false
    /// Các mục đang làm dở đều đã lệch ít — mới được nói "gần đúng".
    var almost = false

    /// Mốc đặt người của ẢNH MẪU trên lưới — tính một lần khi phân tích ảnh mẫu.
    var mocMau: MocLuoi?
    /// Mốc đặt người của khung camera hiện tại.
    var mocLive: MocLuoi?
    /// Đã xong các bước góc máy — tới lượt hiện mốc trên lưới (FOOTGUNS 110).
    var denBoCuc = false

    /// Người dùng bật chế độ tự động đếm ngược rồi quay.
    var autoMode = false
    /// Giây còn lại của đồng hồ đếm ngược. `nil` = chưa đếm.
    var countdown: Int?

    /// Chế độ chụp: AI cầm máy, camera nào, ảnh có lật không.
    var mode: ShootMode = .nguoiKhac

    // --- Ảnh mẫu ---
    var templateName = ""
    var templateThumb: CGImage?
    var templateFraming: FramingClass?
    var templateError: UiText?
    var analyzingTemplate = true
    /// Ảnh mẫu này sẽ được chấm theo những tiêu chí nào, và bỏ qua gì vì sao.
    var criteriaSummary: [UiText] = []
    /// TRẠNG THÁI SỐNG của từng tiêu chí — nguồn duy nhất để vẽ danh sách dấu tích.
    var criteria: [CriterionStatus] = []
    /// Ảnh mẫu dọc hay ngang. `nil` = chưa biết.
    var templatePortrait: Bool?

    // --- Camera ---
    var cameraReady = false
    var cameraError: UiText?
    /// Máy yếu có thể không chạy nổi nhận diện trong lúc quay — phải báo, không im lặng.
    var liveDetectionActive = true

    // --- Nhận diện thời gian thực ---
    var pose: PoseFrame = .empty
    var personDetected = false
    var visiblePoints = 0
    var bodyYawDeg: Double?
    var liveFraming: FramingClass?
    var inferenceMs: Int64 = 0
    /// Cỡ khung đã cắt theo tỉ lệ khung — khung xương vẽ theo cỡ này.
    var frameWidth = 0
    var frameHeight = 0

    // --- Engine hướng dẫn ---
    /// Câu nhắc đang hiện. Mỗi lúc đúng MỘT câu. `nil` = không nhắc gì.
    var cue: UiText?
    /// Cảnh báo về CÁCH CẦM MÁY (xoay ngang, đang zoom) — làm mọi phép đo phía sau mất nghĩa.
    var prepWarning: UiText?
    /// Câu đang hiện là câu để ĐỌC TO CHO MẪU NGHE.
    var cueForModel = false
    /// Đủ điều kiện để bấm quay chưa.
    var readyToCapture = false
    /// Đã giữ ổn định được bao lâu, mili giây.
    var stableForMs: Int64 = 0
    var devicePortrait = true
    /// Mức zoom hiện tại. 1,0 = tiêu cự gốc.
    var zoomRatio: Float = 1

    // --- Quay / chụp liên tục ---
    /// Mặc định CHỤP LIÊN TỤC (PO 08/10/2026): ảnh đủ độ phân giải cảm biến, nét hơn khung cắt từ video.
    var burstMode = true
    /// Số ảnh đã chụp xong trong loạt hiện tại.
    var burstTaken = 0
    var recording = false
    var recordedMs: Int64 = 0

    // --- Chấm điểm sau khi quay ---
    var processing = false
    var processProgress: Float = 0
    var processNote: UiText = .raw("")

    /// Đã chốt xong danh sách ảnh — chuyển sang màn xem lại.
    var finishedSession: URL?

    /// Quay đủ lâu để có gì mà chọn chưa.
    var canStop: Bool { recordedMs >= Self.minRecordMs }

    /// Ngắn hơn mức này thì gần như không có khung nào khác nhau để chọn.
    static let minRecordMs: Int64 = 3_000
    /// Tự dừng ở mốc này. Tài liệu sản phẩm chốt 15-30 giây.
    static let maxRecordMs: Int64 = 30_000
}
