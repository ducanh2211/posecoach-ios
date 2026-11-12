import AVFoundation

/// Quyền dùng camera — bọc `AVCaptureDevice.authorizationStatus` để tầng giao diện không import AVFoundation.
nonisolated enum CameraPermission {

    enum Status {
        /// Chưa hỏi lần nào — bấm nút thì hệ thống hiện hộp thoại xin quyền.
        case notDetermined
        case granted
        /// Đã từ chối (hoặc bị giới hạn) — hệ thống không hỏi lại nữa, phải mở Cài đặt.
        case denied
    }

    static var status: Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// Hỏi quyền. Trả `true` nếu được cấp.
    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
