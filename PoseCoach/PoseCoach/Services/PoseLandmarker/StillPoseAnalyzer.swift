import CoreGraphics
import Foundation
import MediaPipeTasksVision
import os
import PoseDomain

/// Nhận diện khung xương trên MỘT ẢNH TĨNH (chế độ IMAGE). Port từ `KT/pose/StillPoseAnalyzer.kt`.
///
/// ⚠️ Đây chính là đường sản phẩm dùng để **phân tích ảnh mẫu** — bước đầu của toàn bộ chuỗi:
///
///     ảnh mẫu → UprightImage → StillPoseAnalyzer → PoseFrame → quy ra số → so với camera live
///
/// Ba chế độ chạy của MediaPipe ánh xạ 1-1 với ba chỗ gọi: IMAGE → ảnh mẫu (file này) · VIDEO → chấm khung sau khi
/// quay (`VideoPoseAnalyzer`) · LIVE_STREAM → camera (`PoseDetector`). Cả ba ra `PoseFrame` qua cùng `PoseFrame.from`.
///
/// ⚠️ **DÙNG LẠI một bộ nhận diện**, không tạo mới mỗi lần gọi (FOOTGUNS 17).
nonisolated enum StillPoseAnalyzer {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "StillPoseAnalyzer")

    private static let lock = NSRecursiveLock()
    private static var landmarker: PoseLandmarker?
    private static var loadedModel: String?

    /// Phân tích một ảnh ĐÃ DỰNG ĐÚNG CHIỀU (lấy từ `UprightImage`).
    ///
    /// - Returns: `nil` nếu không nạp được model hoặc MediaPipe báo lỗi. `PoseFrame.empty` nếu model chạy được nhưng
    ///   **không thấy người nào** — hai tình huống khác nhau, bên gọi phải phân biệt để báo đúng nguyên nhân (quy tắc
    ///   "không thất bại im lặng").
    ///
    /// Chạy ĐỒNG BỘ, phải gọi từ luồng nền.
    static func analyze(_ image: CGImage, modelAsset: String = PoseDetector.modelFull) -> PoseFrame? {
        lock.lock()
        defer { lock.unlock() }
        guard let lm = ensureLandmarker(modelAsset) else { return nil }
        do {
            let result = try lm.detect(image: MPImage.rgba(image))
            return PoseFrame.firstPose(of: result, 0)
        } catch {
            log.error("Không phân tích được ảnh: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Tạo bộ nhận diện nếu chưa có, hoặc nếu đổi sang model khác.
    private static func ensureLandmarker(_ modelAsset: String) -> PoseLandmarker? {
        if let landmarker, loadedModel == modelAsset { return landmarker }
        do {
            return try MediaPipeGuard.serialized {
                landmarker = nil
                let options = PoseLandmarkerOptions()
                options.baseOptions.modelAssetPath = try PoseDetector.modelPath(modelAsset)
                // Ảnh tĩnh chạy một lần, không cần nhanh — CPU cho chắc.
                options.baseOptions.delegate = .CPU
                options.runningMode = .image
                options.numPoses = 1
                let created = try PoseLandmarker(options: options)
                landmarker = created
                loadedModel = modelAsset
                return created
            }
        } catch {
            log.error("Không nạp được model cho chế độ ảnh tĩnh: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Giải phóng. Gọi khi app đóng hẳn; bình thường cứ giữ để dùng lại.
    static func release() {
        lock.lock()
        defer { lock.unlock() }
        MediaPipeGuard.serialized {
            landmarker = nil
            loadedModel = nil
        }
    }
}
