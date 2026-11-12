import AVFoundation
import CoreMedia
import os

/// Ghi video từ chính luồng khung hình của camera ra file `.mp4` — phần iOS thay cho `Recorder` của CameraX.
///
/// iOS không có sẵn "quay + phân tích cùng một luồng": `AVCaptureMovieFileOutput` không chạy chung được với
/// `AVCaptureVideoDataOutput` trên mọi máy. Nên lấy khung từ luồng phân tích và tự ghi bằng `AVAssetWriter`.
///
/// Khung camera đến ở chiều GỐC của cảm biến (không xoay, không lật — xem `CaptureController`). Hướng cầm máy lúc BẮT ĐẦU
/// quay và việc lật gương được ghi thành `preferredTransform` của rãnh hình, như CameraX chốt `targetRotation` lúc bắt đầu
/// ghi. Video thô chỉ dùng nội bộ để cắt khung rồi xoá, nên nơi đọc (`VideoFrameSource`, 3c) phải áp transform này.
///
/// Mọi hàm gọi trên CÙNG một hàng đợi (hàng đợi khung hình của camera).
nonisolated final class VideoRecorder: @unchecked Sendable {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "VideoRecorder")

    let outputFile: URL
    private let writer: AVAssetWriter
    private let settings: [String: Any]?
    private let rotationAngle: CGFloat
    private let mirrored: Bool
    private var input: AVAssetWriterInput?
    private var droppedFrames = 0

    /// - Parameters:
    ///   - settings: cấu hình nén (lấy từ `AVCaptureVideoDataOutput.recommendedVideoSettings`).
    ///   - rotationAngle: độ, theo chiều kim đồng hồ — cùng quy ước `AVCaptureConnection.videoRotationAngle`.
    ///   - mirrored: lật ngang hình ghi ra (camera trước, PO chốt 06/09/2026).
    init(outputFile: URL, settings: [String: Any]?, rotationAngle: CGFloat, mirrored: Bool) throws {
        try? FileManager.default.removeItem(at: outputFile)
        self.outputFile = outputFile
        self.writer = try AVAssetWriter(outputURL: outputFile, fileType: .mp4)
        self.settings = settings
        self.rotationAngle = rotationAngle
        self.mirrored = mirrored
    }

    /// Ghi một khung. Khung đầu tiên mở phiên ghi (biết cỡ khung mới tính được transform).
    func append(_ sampleBuffer: CMSampleBuffer) {
        if writer.status == .unknown {
            guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
            let dims = CMVideoFormatDescriptionGetDimensions(format)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            input.transform = Self.transform(width: CGFloat(dims.width), height: CGFloat(dims.height),
                                             rotationAngle: rotationAngle, mirrored: mirrored)
            guard writer.canAdd(input) else {
                Self.log.error("AVAssetWriter không nhận rãnh hình")
                return
            }
            writer.add(input)
            self.input = input
            guard writer.startWriting() else {
                Self.log.error("Không bắt đầu ghi được: \(self.writer.error?.localizedDescription ?? "", privacy: .public)")
                return
            }
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
        guard writer.status == .writing, let input else { return }
        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        } else {
            // Bộ nén chưa kịp — bỏ khung, không xếp hàng (giữ luồng camera không nghẽn).
            droppedFrames += 1
        }
    }

    /// Đóng file. `done(nil)` = thành công; có lỗi thì bên gọi xoá file và báo người dùng.
    func finish(_ done: @escaping (Error?) -> Void) {
        if droppedFrames > 0 {
            Self.log.notice("Bỏ \(self.droppedFrames) khung khi ghi vì bộ nén chưa kịp")
        }
        switch writer.status {
        case .writing:
            input?.markAsFinished()
            writer.finishWriting { [self] in
                done(writer.status == .completed ? nil : (writer.error ?? AVError(.unknown)))
            }
        case .unknown:
            // Chưa nhận được khung nào — như `ERROR_NO_VALID_DATA` của CameraX.
            writer.cancelWriting()
            done(AVError(.noDataCaptured))
        default:
            let error = writer.error ?? AVError(.unknown)
            writer.cancelWriting()
            done(error)
        }
    }

    /// Xoay (và lật) khung gốc về đúng chiều xem, dời về gốc toạ độ.
    static func transform(width: CGFloat, height: CGFloat, rotationAngle: CGFloat, mirrored: Bool) -> CGAffineTransform {
        var t = CGAffineTransform(rotationAngle: rotationAngle * .pi / 180)
        // Lật SAU khi xoay — lật theo chiều ngang của hình đã dựng đứng. Lật trước khi xoay thì cầm dọc thành lật dọc.
        if mirrored { t = t.concatenating(CGAffineTransform(scaleX: -1, y: 1)) }
        let box = CGRect(x: 0, y: 0, width: width, height: height).applying(t)
        return t.concatenating(CGAffineTransform(translationX: -box.minX, y: -box.minY))
    }
}
