import PoseDomain

/// PHẦN TRẠNG THÁI MÀN CHỤP ĐỔI THEO TỪNG KHUNG nhận diện (~20-30 lần/giây). Riêng iOS — Kotlin để chung trong
/// `CaptureUiState`.
///
/// Vì sao tách: `@Observable` theo dõi theo TỪNG THUỘC TÍNH của ViewModel, mà `state` là một thuộc tính — để các trường
/// này trong đó thì mỗi khung SwiftUI vẽ lại mọi view đọc `state`, tức cả màn hình (máy nóng nhanh). Tách ra thì chỉ
/// những view đọc `live` (khung xương, mốc lưới, tiêu chí, số debug) vẽ lại.
struct CaptureLiveState {

    var pose: PoseFrame = .empty
    var visiblePoints = 0
    var bodyYawDeg: Double?
    var liveFraming: FramingClass?
    var inferenceMs: Int64 = 0
    /// Cỡ khung đã cắt theo tỉ lệ khung — khung xương vẽ theo cỡ này.
    var frameWidth = 0
    var frameHeight = 0

    /// Mốc đặt người của khung camera hiện tại.
    var mocLive: MocLuoi?

    /// Độ giống ảnh mẫu ngay lúc này, 0..100. `nil` = chưa đo được.
    var matchPercent: Int?
    /// TRẠNG THÁI SỐNG của từng tiêu chí — nguồn duy nhất để vẽ danh sách dấu tích.
    var criteria: [CriterionStatus] = []
    /// Đã giữ ổn định được bao lâu, mili giây.
    var stableForMs: Int64 = 0

    #if DEBUG
    // Xem `CaptureViewModel+Debug`.
    var debugGocMay: String?
    var debugDo: String?
    var debugChiTiet: String?
    #endif
}
