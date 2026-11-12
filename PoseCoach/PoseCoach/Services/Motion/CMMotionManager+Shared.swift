import CoreMotion

nonisolated extension CMMotionManager {
    /// Bộ quản lý cảm biến DUY NHẤT của app — Apple khuyên mỗi app chỉ tạo một (nhiều bản làm chậm tốc độ nhận số liệu).
    ///
    /// Hai bên dùng hai luồng số liệu khác nhau nên không giẫm nhau: `DeviceTilt` dùng `deviceMotion`,
    /// `CaptureController` dùng `accelerometer` (hướng cầm máy, như `OrientationEventListener` của Android).
    static let shared = CMMotionManager()
}
