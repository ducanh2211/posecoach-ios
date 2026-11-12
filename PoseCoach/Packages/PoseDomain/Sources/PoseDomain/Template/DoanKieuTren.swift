import Foundation

/// ĐOÁN KIỂU CHỤP TỪ TRÊN CAO (đứng gần / từ xa rồi zoom) — ghép hai nguồn (08/10/2026).
/// Port từ `KT/template/DoanKieuTren.kt`.
///
/// | Nguồn | Đo gì | Vì sao tách được gần/xa |
/// |---|---|---|
/// | GeoCalib (nền ảnh) | Góc mở ống kính | Góc rộng 0.5x cho góc mở rất rộng; zoom từ xa làm nó hẹp |
/// | MediaPipe (người) | Đầu to hơn chân bao nhiêu | Đứng gần thì đầu gần máy hơn chân nhiều nên to hẳn |
///
/// ⚠️ Các mốc chọn trên chính 17 ảnh đo — số "đúng" là lạc quan, phải kiểm thêm ảnh mới.
/// Chỉ dùng để CHỌN SẴN trong bảng nhập ảnh; người dùng vẫn xác nhận.
public enum DoanKieuTren {

    /// Góc mở từ mức này: chắc chắn góc rộng → đứng gần. Máy chụp thường 1x khoảng 60–75°.
    public static let vfovRong = 75.0
    public static let taiChanGan = 0.45
    public static let taiChanXa = 0.35

    /// `nil` = không đủ chắc, hỏi người dùng.
    public static func doan(_ vfovDeg: Double?, _ taiChan: Double?) -> KieuChupTren? {
        if let vfovDeg, vfovDeg >= vfovRong { return .gan }
        if let taiChan, taiChan >= taiChanGan { return .gan }
        if let taiChan, taiChan <= taiChanXa { return .xaZoom }
        return nil
    }

    /// log( (bề ngang tai trên ảnh / ngoài đời) ÷ (bề ngang cổ chân trên ảnh / ngoài đời) ).
    ///
    /// Chia cho cỡ ngoài đời (toạ độ 3D của MediaPipe) để khử khác biệt cơ thể: chỉ còn lại phần do khoảng
    /// cách tới máy. `nil` khi không thấy rõ cả hai tai và hai cổ chân.
    ///
    /// - Parameters:
    ///   - rong: bề ngang ảnh (điểm ảnh) — toạ độ của khung xương là tỉ lệ 0..1.
    ///   - cao: bề cao ảnh (điểm ảnh).
    public static func tiLeTaiChan(_ f: PoseFrame, _ rong: Int, _ cao: Int, _ v: Float = 0.5) -> Double? {
        func phongDai(_ a: Int, _ b: Int) -> Double? {
            guard let pa = f.at(a, v), let pb = f.at(b, v),
                  let wa = f.world(a, v), let wb = f.world(b, v) else { return nil }
            let anh = hypot((pa.x - pb.x) * Double(rong), (pa.y - pb.y) * Double(cao))
            let dx = wa.x - wb.x; let dy = wa.y - wb.y; let dz = wa.z - wb.z
            let that = (dx * dx + dy * dy + dz * dz).squareRoot()
            return that > 1e-3 && anh > 1 ? anh / that : nil
        }
        guard let tai = phongDai(Lm.leftEar, Lm.rightEar),
              let chan = phongDai(Lm.leftAnkle, Lm.rightAnkle) else { return nil }
        return log(tai / chan)
    }
}
