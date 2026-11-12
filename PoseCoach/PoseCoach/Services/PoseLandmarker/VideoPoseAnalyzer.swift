import CoreGraphics
import Foundation
import MediaPipeTasksVision
import os
import PoseDomain

/// Nhận diện khung xương trên chuỗi khung hình VIDEO. Port từ `KT/pose/VideoPoseAnalyzer.kt`.
///
/// Khác ảnh tĩnh ở điểm quyết định: **có BÁM (tracking)** — dò người một lần rồi bám qua các khung sau. Vì vậy phải
/// đưa khung **tuần tự, không tua** (FOOTGUNS 18).
///
/// Chạy ĐỒNG BỘ: gọi xong có kết quả ngay. Phải gọi từ luồng nền.
nonisolated final class VideoPoseAnalyzer {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "VideoPoseAnalyzer")

    private var landmarker: PoseLandmarker?

    /// Mốc thời gian khung hình trước, để ép tăng nghiêm ngặt.
    private var lastTimestamp: Int64 = -1

    init(
        modelAsset: String = PoseDetector.modelFull,
        delegate: Delegate = .CPU,
        minPoseDetectionConfidence: Float = 0.5,
        minTrackingConfidence: Float = 0.5
    ) {
        // Tạo phải đi qua khoá dùng chung (FOOTGUNS 17).
        do {
            landmarker = try MediaPipeGuard.serialized {
                let options = PoseLandmarkerOptions()
                options.baseOptions.modelAssetPath = try PoseDetector.modelPath(modelAsset)
                options.baseOptions.delegate = delegate
                options.runningMode = .video
                options.numPoses = 1
                options.minPoseDetectionConfidence = minPoseDetectionConfidence
                options.minTrackingConfidence = minTrackingConfidence
                return try PoseLandmarker(options: options)
            }
        } catch {
            Self.log.error("Không nạp được model cho chế độ video: \(error.localizedDescription, privacy: .public)")
            landmarker = nil
        }
    }

    var isReady: Bool { landmarker != nil }

    /// Phân tích một khung hình đã dựng đúng chiều.
    ///
    /// `timestampMs` phải **tăng nghiêm ngặt**, nếu không MediaPipe báo lỗi. Hàm tự ép điều đó, nhưng bên gọi vẫn nên
    /// truyền mốc thật của video để cơ chế bám chạy đúng nhịp.
    ///
    /// - Returns: `PoseFrame` rỗng (giữ mốc thời gian) khi không thấy người; `nil` khi không nạp được model hoặc lỗi.
    func analyze(_ image: CGImage, _ timestampMs: Int64) -> PoseFrame? {
        guard let lm = landmarker else { return nil }
        let ts = timestampMs > lastTimestamp ? timestampMs : lastTimestamp + 1
        lastTimestamp = ts
        do {
            let result = try lm.detect(videoFrame: MPImage.rgba(image), timestampInMilliseconds: Int(ts))
            return PoseFrame.firstPose(of: result, ts)
        } catch {
            Self.log.error("Lỗi khi phân tích khung hình video: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func close() {
        MediaPipeGuard.serialized { landmarker = nil }
    }
}
