// Port từ `KT/guidance/DatMayGate.kt`.

/// GIAI ĐOẠN 1 CỦA CHẾ ĐỘ ĐẶT MÁY TỰ CHỤP — đặt máy cho đúng TRƯỚC khi người dùng ra đứng vào khung (17/10/2026,
/// PO duyệt, FOOTGUNS 113).
///
/// Chỉ kiểm những thứ CẢM BIẾN đo được: máy thẳng, và góc ngửa/chúc theo nhãn góc của ảnh mẫu. Đạt và giữ yên
/// `giuYenMs` thì KHOÁ — từ đó hướng dẫn chuyển sang chỗ đứng của người. Máy bị chạm/đổ thì mở khoá.
///
/// Ngưỡng lấy NGUYÊN từ `GuidanceConfig` của hai mục tương ứng — không đặt số mới.
public final class DatMayGate {

    /// Đạt rồi phải giữ yên ngần này mới khoá — tránh khoá lúc tay còn đang buông máy.
    public static let giuYenMs: Int64 = 1_000

    /// Góc ngửa/chúc của ảnh mẫu theo nhãn, độ. `nil` = ảnh không có nhãn góc → chỉ kiểm thẳng.
    private let gocMau: Double?

    /// Đã đặt máy xong và đang khoá.
    public private(set) var daDat = false

    private var datTuMs: Int64?

    public init(_ gocMau: Double?) {
        self.gocMau = gocMau
    }

    /// - Parameters:
    ///   - roll: độ vẹo máy theo cảm biến, độ (dương = xoay theo chiều kim đồng hồ).
    ///   - pitch: góc ngửa/chúc của TRỤC CAMERA đang dùng, độ (dương = ngửa lên).
    /// - Returns: câu cần hiện, `nil` = không có gì cần nói ở giai đoạn này.
    @discardableResult
    public func update(_ roll: Double?, _ pitch: Double?, _ nowMs: Int64, _ rollBand: Band, _ pitchBand: Band?) -> UiText? {
        // Không có cảm biến: không đo được thì không chặn (quy tắc số 4).
        guard let roll, let pitch else { daDat = true; return nil }
        // Máy gần nằm ngang mặt đất thì độ vẹo là nhiễu — coi như thẳng (như mục ROLL).
        let lechVeo = abs(pitch) < GuidanceEngine.deviceRollTrustPitchDeg ? roll : 0.0
        let lechNgua: Double? = if let gocMau, pitchBand != nil { pitch - gocMau } else { nil }

        if daDat {
            var bung = abs(lechVeo) > rollBand.unlock
            if let lechNgua, let pitchBand, abs(lechNgua) > pitchBand.unlock { bung = true }
            if !bung { return nil }
            daDat = false
            datTuMs = nil
        }

        let veoDat = abs(lechVeo) <= rollBand.accept
        let nguaDat: Bool = if let lechNgua, let pitchBand { abs(lechNgua) <= pitchBand.accept } else { true }
        if veoDat && nguaDat {
            let tu = datTuMs ?? nowMs
            datTuMs = tu
            if nowMs - tu >= DatMayGate.giuYenMs { daDat = true; return nil }
            return uiText("tripod_hold_still")
        }
        datTuMs = nil
        if !veoDat { return uiText(lechVeo > 0 ? "tripod_roll_ccw" : "tripod_roll_cw") }
        if let lechNgua, lechNgua > 0 { return uiText("tripod_tilt_down") }
        return uiText("tripod_tilt_up")
    }

    public func reset() {
        daDat = false
        datTuMs = nil
    }
}
