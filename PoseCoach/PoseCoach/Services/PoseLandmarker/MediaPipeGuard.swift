import Foundation

/// Khoá dùng chung cho việc TẠO và HUỶ bộ nhận diện MediaPipe. Port từ `KT/pose/MediaPipeGuard.kt`.
///
/// ⚠️ BẮT BUỘC (FOOTGUNS 17). Tạo bộ nhận diện là dựng cả đồ thị xử lý ở tầng C++ và ánh xạ file model vào bộ nhớ;
/// làm đồng thời từ nhiều luồng thì sập ở tầng C++ — không có lỗi Swift nào, app chỉ tắt.
///
/// Trên iOS, "huỷ" = thả tham chiếu cuối cùng tới `PoseLandmarker` (không có `close()`), nên việc gán `nil` phải nằm
/// TRONG khoá này.
///
/// Khoá này **chỉ bọc lúc tạo và huỷ**, không bọc lúc chạy nhận diện — bọc cả lúc chạy thì camera phải đợi ảnh mẫu
/// phân tích xong. Khoá đệ quy như `synchronized` của Kotlin.
nonisolated enum MediaPipeGuard {
    private static let lock = NSRecursiveLock()

    static func serialized<T>(_ block: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }
}
