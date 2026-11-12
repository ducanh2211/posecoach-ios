// Port từ `KT/guidance/DistanceEstimator.kt`.

import Foundation

/// ƯỚC LƯỢNG KHOẢNG CÁCH TỪ MÁY TỚI MẪU, MÉT — chỉ để nói ra **số bước chân**.
///
///     d = C × zoom × H_thật / tỉ_lệ_trong_khung
///
/// Đã kiểm trên 13 ảnh thật: sai số trung bình 16%, lớn nhất 39%. ⚠️ Chỉ được dùng để ĐẾM BƯỚC, KHÔNG hiện số
/// mét cho người dùng — hiện mét là hứa một độ chính xác mà phép đo không có.
public enum DistanceEstimator {

    /// Hằng số ống kính, hiệu chuẩn từ 13 ảnh thật (0,678, lệch chuẩn 0,116).
    private static let lensConstant = 0.678

    /// Bước chân khi NHÍCH CHỖ ĐỨNG, mét — vừa cầm máy vừa nhìn màn hình thì bước rụt lại.
    private static let stepMeters = 0.6

    /// KHOẢNG CÁCH TỐI THIỂU theo lớp ảnh, mét. ⚠️ Quyết định sản phẩm, không phải số đo (04/09/2026): lùi ra
    /// một khoảng rồi zoom lên.
    public static func minStandoffMeters(_ framing: FramingClass) -> Double {
        switch framing {
        case .head, .chest: 1.5
        case .half: 2.0
        case .knee: 2.5
        case .full: 3.0
        }
    }

    /// Hệ số ống kính `C = 1 / (2·tan(vFOV₁ₓ/2))` tính từ GÓC MỞ THẬT của máy (19/09/2026).
    ///
    /// - Parameter vFovDeg: góc mở dọc ĐANG DÙNG (đã tính zoom và tỉ lệ khung), độ.
    /// - Returns: `nil` khi số vô lý — lúc đó lùi về `lensConstant`.
    public static func heSoOngKinh(_ vFovDeg: Double?, _ zoomRatio: Float) -> Double? {
        guard let v = vFovDeg else { return nil }
        if v < 10.0 || v > 130.0 { return nil }
        let tanNua1x = tan(toRadians(v) / 2.0) * Double(zoomRatio)
        return tanNua1x <= 1e-6 ? nil : 1.0 / (2.0 * tanNua1x)
    }

    /// Khoảng cách hiện tại, mét. `nil` khi thiếu dữ kiện.
    ///
    /// - Parameters:
    ///   - scaleInFrame: chiều cao mốc đo, theo tỉ lệ chiều cao khung hình.
    ///   - realHeightMeters: chiều cao THẬT của chính mốc đó, từ `worldLandmarks`.
    ///   - zoomRatio: mức zoom hiện tại (1,0 = không zoom).
    ///   - heSo: từ `heSoOngKinh`. `nil` = dùng `lensConstant`.
    public static func estimate(
        _ scaleInFrame: Double?,
        _ realHeightMeters: Double?,
        _ zoomRatio: Float,
        heSo: Double? = nil
    ) -> Double? {
        guard let s = scaleInFrame, let h = realHeightMeters else { return nil }
        // Mốc quá nhỏ trong khung hoặc chiều cao thật vô lý → phép chia nổ tung.
        if s < 0.02 || h < 0.05 || h > 3.0 { return nil }
        return (heSo ?? lensConstant) * Double(zoomRatio) * h / s
    }

    /// Đổi quãng đường cần đi thành SỐ BƯỚC, dạng chữ (vd. "2 bước").
    ///
    /// Dưới 0,4m thì không nói số: sai số của phép đo lớn hơn con số định nói.
    public static func stepsPhrase(_ meters: Double) -> UiText {
        let steps = meters / stepMeters
        if meters < 0.4 { return uiText("steps_a_little") }
        if steps < 1.5 { return .plural("steps_n", count: 1, [.int(1)]) }
        if steps < 2.5 { return .plural("steps_n", count: 2, [.int(2)]) }
        if steps < 3.5 { return .plural("steps_n", count: 3, [.int(3)]) }
        return uiText("steps_a_lot")
    }
}
