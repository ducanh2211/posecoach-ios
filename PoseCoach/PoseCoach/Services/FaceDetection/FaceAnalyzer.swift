import CoreGraphics
import MLKitFaceDetection
import MLKitVision
import os
import PoseDomain
import UIKit

/// Bọc ML Kit Face Detection. Port từ `KT/face/FaceAnalyzer.kt` (phần dữ liệu `FaceInfo` ở `PoseDomain`).
///
/// Phục vụ hai mục:
///  - **Mục 1 (hướng mẫu)** với ảnh chân dung — góc mặt chính xác hơn góc thân (~3-5° so với ~8-10°)
///  - **Hậu kỳ: mắt nhắm** — ảnh mẫu chớp mắt là ảnh hỏng
///
/// ⚠️ Chạy ĐỒNG BỘ (`results(in:)`) — chỉ gọi từ luồng nền. ML Kit iOS chặn khi gọi trên luồng chính.
/// Mọi lệnh chạy xếp hàng qua `MLKitLock` — chạy chồng nhau thì sập.
///
/// Khác Android: không có hàm chờ có hạn giờ (`Tasks.await(…, 3 s)`) — `results(in:)` đồng bộ sẵn; không có `close()`
/// (ML Kit iOS tự giải phóng khi bỏ tham chiếu).
nonisolated final class FaceAnalyzer: @unchecked Sendable {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "FaceAnalyzer")

    private let detector: FaceDetector = {
        let options = FaceDetectorOptions()
        // FAST đủ dùng: chỉ cần góc quay đầu và xác suất mắt mở.
        //
        // ⚠️ Từng đổi sang ACCURATE (12/09/2026) để lấy góc ngửa/chúc của mặt cho ảnh selfie. ĐÃ ĐO VÀ BỎ: người chụp
        // selfie luôn NHÌN VÀO MÁY, nên góc giữa mặt và ống kính gần như bằng 0 dù máy ở đâu (FOOTGUNS 82).
        options.performanceMode = .fast
        options.classificationMode = .all
        options.landmarkMode = .none
        options.contourMode = .none
        // Mặt nhỏ hơn 15% bề ngang ảnh thì bỏ qua: người qua đường trong nền, không phải mẫu.
        options.minFaceSize = 0.15
        return FaceDetector.faceDetector(options: options)
    }()

    /// Phân tích một ảnh đã dựng đúng chiều. `nil` khi không thấy mặt nào hoặc lỗi.
    ///
    /// Nhiều mặt thì lấy **mặt to nhất** — mẫu đứng gần máy nhất (cùng quy ước `numPoses = 1`).
    func analyze(_ image: CGImage) -> FaceInfo? {
        let vision = VisionImage(image: UIImage(cgImage: image))
        vision.orientation = .up
        do {
            let faces = try MLKitLock.lock.withLock { try detector.results(in: vision) }
            guard let face = faces.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
                return nil
            }
            // ML Kit báo "không có" thì là KHÔNG ĐO ĐƯỢC (mặt nghiêng quá), không phải "mắt nhắm" — giữ `nil` để tầng
            // trên bỏ mục này ra, không trừ điểm oan.
            let l: Double? = face.hasLeftEyeOpenProbability ? Double(face.leftEyeOpenProbability) : nil
            let r: Double? = face.hasRightEyeOpenProbability ? Double(face.rightEyeOpenProbability) : nil
            let eyesOpen: Double?
            if let l, let r {
                // Lấy NHỎ HƠN: nhắm một mắt cũng là ảnh hỏng.
                eyesOpen = min(l, r)
            } else {
                eyesOpen = l ?? r
            }
            return FaceInfo(
                yawDeg: face.hasHeadEulerAngleY ? Double(face.headEulerAngleY) : nil,
                eyesOpen: eyesOpen
            )
        } catch {
            Self.log.warning("Không phân tích được khuôn mặt: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
