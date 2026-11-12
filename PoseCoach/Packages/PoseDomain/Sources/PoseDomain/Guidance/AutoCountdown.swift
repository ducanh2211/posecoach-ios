/// ĐẾM NGƯỢC TỰ BẤM của chế độ tự động. Port từ vòng lặp `LaunchedEffect(state.autoMode)` trong
/// `KT/capture/CaptureScreen.kt` — tách khỏi UI vào `PoseDomain` để test chạy đúng code thật (bản Kotlin test
/// một bản chép). Màn chụp gọi `tick` mỗi 100ms.
public struct AutoCountdown: Sendable {

    /// Số giây đếm ngược trước khi tự bấm quay.
    public static let autoCountdownSec = 3

    /// Phải đủ giống LIÊN TỤC ngần này mới bắt đầu đếm. ⚠️ Không có mốc này thì một khung hình tình cờ đạt là
    /// đồng hồ chạy — cầm máy trên tay thì điểm dao động liên tục.
    public static let autoStableMs: Int64 = 800

    /// Tụt khỏi mức đủ giống LÂU HƠN ngần này mới huỷ lần đếm. ⚠️ Không có khoảng ân hạn này thì đồng hồ gần
    /// như không bao giờ chạy hết: tay người luôn rung.
    public static let autoCancelGraceMs: Int64 = 500

    public enum Buoc: Equatable, Sendable {
        /// Không đếm (Kotlin: `onCountdown(null)` hoặc chưa giữ đủ lâu).
        case cho
        /// Đang đếm, còn ngần này giây.
        case dem(Int)
        /// Hết giờ — bấm quay.
        case chup
    }

    private let countdownSec: Int
    private let stableMs: Int64
    private let graceMs: Int64

    /// Bắt đầu chuỗi đủ giống liên tục.
    private var readySince: Int64?
    /// Lần gần nhất còn đủ giống.
    private var lastReadyMs: Int64 = 0

    public init(
        countdownSec: Int = AutoCountdown.autoCountdownSec,
        stableMs: Int64 = AutoCountdown.autoStableMs,
        graceMs: Int64 = AutoCountdown.autoCancelGraceMs
    ) {
        self.countdownSec = countdownSec
        self.stableMs = stableMs
        self.graceMs = graceMs
    }

    /// - Parameters:
    ///   - ready: `readyToCapture` của engine.
    ///   - busy: đang quay / chụp / xử lý — không đếm, nếu không nó bấm chồng lên nhau.
    public mutating func tick(_ nowMs: Int64, ready: Bool, busy: Bool) -> Buoc {
        if ready && !busy { lastReadyMs = nowMs }

        if busy {
            readySince = nil
            return .cho
        }
        // Tụt quá lâu thì mới huỷ. Tụt chớp nhoáng thì bỏ qua.
        if nowMs - lastReadyMs > graceMs {
            readySince = nil
            return .cho
        }
        if readySince == nil { readySince = nowMs }
        let held = nowMs - readySince!
        guard held >= stableMs else { return .cho }
        let con = countdownSec - Int((held - stableMs) / 1000)
        if con <= 0 {
            readySince = nil
            return .chup
        }
        return .dem(con)
    }

    public mutating func reset() {
        readySince = nil
        lastReadyMs = 0
    }
}
