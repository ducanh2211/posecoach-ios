import MediaPipeTasksVision
import PoseDomain

nonisolated extension PoseFrame {

    /// ĐÂY LÀ CHỖ DUY NHẤT trong toàn app đọc kiểu dữ liệu landmark của MediaPipe. Port từ `PoseFrame.from` trong
    /// `KT/pose/PoseGeometry.kt`. Mọi thay đổi về hệ toạ độ chỉ sửa ở đây.
    static func from(
        _ landmarks: [NormalizedLandmark],
        _ worldLandmarks: [Landmark],
        _ timestampMs: Int64
    ) -> PoseFrame {
        PoseFrame(
            // KHÔNG lật y (FOOTGUNS 3). MediaPipe đã là gốc trên-trái, y hướng xuống — đúng quy ước đã chốt. Vision
            // của iOS thì ngược lại (gốc dưới-trái), chép `1.0 - y` của code Vision cũ sang là sai.
            points: landmarks.map { P2(Double($0.x), Double($0.y)) },
            // visibility có thể vắng mặt — vắng thì coi như không tin được.
            visibility: landmarks.map { $0.visibility?.floatValue ?? 0 },
            world: worldLandmarks.map { P3(Double($0.x), Double($0.y), Double($0.z)) },
            timestampMs: timestampMs
        )
    }

    /// `PoseFrame.EMPTY.copy(timestampMs = …)` của Kotlin: không thấy người, nhưng vẫn giữ mốc thời gian.
    static func empty(at timestampMs: Int64) -> PoseFrame {
        PoseFrame(points: [], visibility: [], world: [], timestampMs: timestampMs)
    }

    /// Người đầu tiên trong kết quả (`numPoses = 1`), hoặc khung rỗng nếu không thấy ai.
    static func firstPose(of result: PoseLandmarkerResult, _ timestampMs: Int64) -> PoseFrame {
        guard let first = result.landmarks.first else { return empty(at: timestampMs) }
        return from(first, result.worldLandmarks.first ?? [], timestampMs)
    }
}
