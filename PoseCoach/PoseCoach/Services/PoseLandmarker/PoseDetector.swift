import CoreMedia
import Foundation
import MediaPipeTasksVision
import os
import PoseDomain
import UIKit

/// Lớp bọc quanh MediaPipe Pose Landmarker cho CAMERA THỜI GIAN THỰC (LIVE_STREAM). Port từ `KT/pose/PoseDetector.kt`.
///
/// Mọi thứ đặc thù MediaPipe dừng lại ở file này; tầng trên chỉ nhận `PoseFrame` đã chuẩn hoá.
///
/// Khác Android:
/// - Đầu vào là `CMSampleBuffer` + **hướng thật** của khung. File này tự xoay điểm ảnh về chiều dựng đứng
///   (`UprightPixelBuffer`) như Android tự xoay bitmap, rồi đưa vào MediaPipe với `.up` — tham số `orientation` của
///   MediaPipe 1.0.0 iOS cho kết quả sai (FOOTGUNS 5: sai hướng là hoán trục X/Y, không lỗi nào báo ra; bản iOS cũ đóng
///   cứng `.right`).
/// - Không có `onFrameBitmap`: nhận diện mặt (ML Kit) nhận thẳng cùng `CMSampleBuffer` + hướng từ tầng camera, không
///   phải giải mã lại ảnh.
/// - `onError` trả `UiText` (mã câu), View mới đổi ra chữ.
nonisolated final class PoseDetector: NSObject, PoseLandmarkerLiveStreamDelegate {

    struct Config {
        var modelAsset: String = PoseDetector.modelFull
        /// CPU hay GPU. GPU KHÔNG phải lúc nào cũng nhanh hơn — đo trên máy thật rồi mới chọn, đừng mặc định GPU.
        var delegate: Delegate = .CPU
        var minPoseDetectionConfidence: Float = 0.5
        var minPosePresenceConfidence: Float = 0.5
        var minTrackingConfidence: Float = 0.5
        /// Số người tối đa.
        var numPoses: Int = 1
    }

    /// Số liệu hiệu năng của một lần nhận diện.
    struct InferenceStats {
        let inferenceTimeMs: Int64
        /// Cỡ khung SAU khi xoay về chiều dựng đứng (như bitmap đã xoay của Android).
        let inputWidth: Int
        let inputHeight: Int
        let orientation: UIImage.Orientation
    }

    static let modelLite = "pose_landmarker_lite.task"
    static let modelFull = "pose_landmarker_full.task"
    static let modelHeavy = "pose_landmarker_heavy.task"

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "PoseDetector")

    /// Đường dẫn file model trong bundle. Không có thì ném lỗi để nơi gọi báo người dùng.
    static func modelPath(_ asset: String) throws -> String {
        let name = (asset as NSString).deletingPathExtension
        let ext = (asset as NSString).pathExtension
        guard let path = Bundle.main.path(forResource: name, ofType: ext) else {
            throw NSError(domain: "PoseDetector", code: 1, userInfo: [NSLocalizedDescriptionKey: "missing \(asset)"])
        }
        return path
    }

    private let config: Config
    /// Gọi mỗi khi có kết quả. Chạy trên hàng đợi riêng của MediaPipe, KHÔNG phải luồng giao diện.
    private let onResult: (PoseFrame, InferenceStats) -> Void
    private let onError: (UiText) -> Void
    /// Khung đã dựng đứng vừa đưa vào nhận diện (như `onFrameBitmap` của Kotlin) — cho đường nhận diện mặt thời gian
    /// thực. Gọi trên luồng camera. ⚠️ Bộ đệm lấy từ pool, khung sau ghi đè lên — muốn giữ lại thì phải CHÉP ngay.
    private let onFrame: ((CVPixelBuffer) -> Void)?

    private var landmarker: PoseLandmarker?

    /// Khoá bảo vệ `landmarker` (FOOTGUNS 11): luồng camera gọi `detect`, luồng giao diện gọi `close`. Đóng đúng lúc
    /// một khung đang được gửi đi thì MediaPipe gọi vào vùng nhớ vừa giải phóng và sập ở tầng C++.
    private let lock = NSRecursiveLock()

    /// Khoá riêng cho số liệu thống kê. ⚠️ Callback kết quả KHÔNG được xin `lock`: `close()` thả bộ nhận diện trong lúc
    /// giữ `lock`, nếu MediaPipe chờ callback dở dang chạy xong thì hai bên chờ nhau mãi. Kotlin cũng không khoá ở
    /// `handleResult`.
    private let statsLock = NSLock()

    /// Thời điểm gửi khung đi, để tính thời gian nhận diện khi kết quả quay về.
    private var sentAtMs: Int64 = 0
    /// Đã gửi một khung và CHƯA có kết quả. Nằm sau `statsLock` (callback ghi, luồng camera đọc).
    private var dangChoKetQua = false

    /// Chờ kết quả quá mức này thì thôi chờ, gửi khung mới — phòng trường hợp MediaPipe bỏ khung mà không gọi callback,
    /// nhận diện sẽ đứng hẳn. Không phải ngưỡng hướng dẫn: chỉ là chốt an toàn, bình thường kết quả về sau vài chục ms.
    private static let choKetQuaToiDaMs: Int64 = 1_000
    /// LIVE_STREAM đòi mốc thời gian TĂNG NGHIÊM NGẶT; hai khung cùng một ms làm MediaPipe báo lỗi.
    private var lastSentTimestamp: Int64 = 0

    /// Chỉ luồng camera dùng (trong `detect`).
    private let xoay = UprightPixelBuffer()

    private var lastInputWidth = 0
    private var lastInputHeight = 0
    private var lastOrientation: UIImage.Orientation = .up

    init(
        config: Config = Config(),
        onResult: @escaping (PoseFrame, InferenceStats) -> Void,
        onError: @escaping (UiText) -> Void,
        onFrame: ((CVPixelBuffer) -> Void)? = nil
    ) {
        self.config = config
        self.onResult = onResult
        self.onError = onError
        self.onFrame = onFrame
    }

    var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return landmarker != nil
    }

    func setup() {
        close()
        do {
            let options = PoseLandmarkerOptions()
            options.baseOptions.modelAssetPath = try Self.modelPath(config.modelAsset)
            options.baseOptions.delegate = config.delegate
            options.minPoseDetectionConfidence = config.minPoseDetectionConfidence
            options.minPosePresenceConfidence = config.minPosePresenceConfidence
            options.minTrackingConfidence = config.minTrackingConfidence
            options.numPoses = config.numPoses
            // LIVE_STREAM: kết quả trả về BẤT ĐỒNG BỘ qua delegate. Không được chờ kết quả trong luồng camera.
            options.runningMode = .liveStream
            options.poseLandmarkerLiveStreamDelegate = self

            // Tạo phải đi qua khoá dùng chung (FOOTGUNS 17).
            let created = try MediaPipeGuard.serialized { try PoseLandmarker(options: options) }
            lock.lock()
            landmarker = created
            lastSentTimestamp = 0
            lock.unlock()
            statsLock.withLock { dangChoKetQua = false }
        } catch {
            Self.log.error("Không khởi tạo được bộ nhận diện: \(error.localizedDescription, privacy: .public)")
            onError(uiText("detector_err_load", .string(error.localizedDescription)))
        }
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        MediaPipeGuard.serialized { landmarker = nil }
    }

    /// Đưa một khung hình từ camera vào nhận diện. Gọi từ luồng phân tích của camera; trả về NGAY, kết quả tới sau
    /// qua `onResult`.
    ///
    /// - Parameter orientation: hướng hiển thị của khung (theo hướng cầm máy + camera trước/sau) — tầng camera tính.
    /// - Parameter maxLongSide: thu nhỏ khung về cạnh dài này trước khi nhận diện (`nil` = giữ cỡ). Xem
    ///   `UprightPixelBuffer.upright`.
    func detect(_ sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, maxLongSide: Int? = nil) {
        // Kiểm nhanh trước khi làm việc nặng.
        if !isReady { return }
        // Khung trước chưa có kết quả thì bỏ khung này NGAY, trước bước xoay / thu nhỏ. Nhịp nhận diện KHÔNG đổi:
        // LIVE_STREAM vốn tự vứt khung tới lúc đang bận (FlowLimiter) — chỉ là trước đây vứt SAU khi đã tốn công dựng ảnh.
        let dangCho = statsLock.withLock {
            dangChoKetQua && Self.uptimeMs() - sentAtMs < Self.choKetQuaToiDaMs
        }
        if dangCho { return }

        let image: MPImage
        do {
            guard let raw = CMSampleBufferGetImageBuffer(sampleBuffer),
                  let upright = xoay.upright(raw, orientation, maxLongSide: maxLongSide)
            else {
                Self.log.error("Không đọc được khung hình camera")
                return
            }
            image = try MPImage(pixelBuffer: upright, orientation: .up)
            onFrame?(upright)
        } catch {
            Self.log.error("Không đọc được khung hình camera: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Toàn bộ phần chạm vào MediaPipe nằm trong khoá. `detectAsync` trả về ngay nên giữ khoá không nghẽn camera.
        lock.lock()
        defer { lock.unlock() }
        guard let lm = landmarker else { return }

        // Ép mốc thời gian tăng nghiêm ngặt.
        let now = Self.uptimeMs()
        let ts = now > lastSentTimestamp ? now : lastSentTimestamp + 1
        lastSentTimestamp = ts

        statsLock.lock()
        lastInputWidth = Int(image.width)
        lastInputHeight = Int(image.height)
        lastOrientation = orientation
        sentAtMs = ts
        dangChoKetQua = true
        statsLock.unlock()

        do {
            try lm.detectAsync(image: image, timestampInMilliseconds: Int(ts))
        } catch {
            Self.log.error("detectAsync lỗi: \(error.localizedDescription, privacy: .public)")
            statsLock.withLock { dangChoKetQua = false }
        }
    }

    // MARK: - PoseLandmarkerLiveStreamDelegate

    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        // Có kết quả (kể cả lỗi) — khung kế tiếp được gửi.
        statsLock.withLock { dangChoKetQua = false }
        // Như `setErrorListener` của Kotlin: lời lỗi gốc của thư viện, không có thì câu "lỗi không rõ".
        if let error {
            let msg = error.localizedDescription
            onError(msg.isEmpty ? uiText("detector_err_unknown") : .raw(msg))
            return
        }
        guard let result else {
            onError(uiText("detector_err_unknown"))
            return
        }
        statsLock.lock()
        let stats = InferenceStats(
            inferenceTimeMs: Self.uptimeMs() - sentAtMs,
            inputWidth: lastInputWidth, inputHeight: lastInputHeight, orientation: lastOrientation
        )
        statsLock.unlock()
        // numPoses = 1 nên chỉ có một người. Bật nhiều người thì đây là chỗ cắm logic khoá chủ thể.
        onResult(PoseFrame.firstPose(of: result, Int64(timestampInMilliseconds)), stats)
    }

    /// Đồng hồ đơn điệu, ms — tương đương `SystemClock.uptimeMillis()`.
    private static func uptimeMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }
}
