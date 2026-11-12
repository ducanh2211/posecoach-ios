/// Số liệu khuôn mặt lấy từ ML Kit. Port từ `data class FaceInfo` trong `KT/face/FaceAnalyzer.kt`
/// (phần gọi ML Kit nằm ở `Services/FaceDetection`, Phase 3c).
///
/// Mọi trường có thể `nil` — không thấy mặt là chuyện bình thường (mẫu quay lưng), không phải lỗi.
public struct FaceInfo: Equatable, Sendable {
    /// Góc mặt quay trái/phải, ĐỘ. 0 = nhìn thẳng vào máy.
    ///
    /// Chính xác hơn hẳn góc thân với ảnh chân dung (~3-5° so với ~8-10°) vì mặt có nhiều mốc rõ ràng hơn
    /// cặp vai. Đó là lý do `FramingClass.yawSource` chỉ định chest/head dùng nguồn này.
    public let yawDeg: Double?

    /// Mắt có mở không, 0..1. Lấy **giá trị NHỎ HƠN** của hai mắt.
    ///
    /// Lấy nhỏ hơn là cố ý: nhắm một mắt cũng là ảnh hỏng. Lấy trung bình sẽ cho qua những tấm nháy một bên.
    public let eyesOpen: Double?

    public init(yawDeg: Double?, eyesOpen: Double?) {
        self.yawDeg = yawDeg
        self.eyesOpen = eyesOpen
    }
}
