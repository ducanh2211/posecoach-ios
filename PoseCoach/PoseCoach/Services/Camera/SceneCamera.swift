import AVFoundation
import os
import UIKit

/// CAMERA CHỤP BỐI CẢNH — chỉ để ghi lại nơi chụp cho bước đề xuất ảnh mẫu (09/10/2026). Port `KT/scene/SceneCamera.kt`.
///
/// ⚠️ Cố ý TÁCH khỏi `CaptureController` (màn chụp có hướng dẫn): ở đây không nhận diện người, không đo, không cần chất
/// lượng cao. Gộp chung thì mọi chỉnh sửa camera đề xuất đều có nguy cơ làm hỏng màn chụp chính — phần PO đã chốt là ổn
/// định. Chỉ dùng chung cách chọn ống kính / zoom (`CaptureController.pickDevice`, `zoomBase`, `applyZoom`).
///
/// Ba chức năng: xem trước + chụp ảnh + quay video. Ảnh/video chỉ cần đủ cho ML Kit gắn nhãn (~640 px) nên quay HD là
/// thừa. Máy không gắn nổi cả ba thì bỏ quay video và báo qua `videoAvailable` — không im lặng.
///
/// Khác Android: `AVCaptureMovieFileOutput` (không gắn micro → quay không tiếng, khỏi xin quyền micro). Gọi từ luồng
/// chính; callback trả về luồng chính.
nonisolated final class SceneCamera: NSObject, @unchecked Sendable {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "SceneCamera")

    /// Phiên camera. View gắn vào lớp xem trước qua `CameraPreviewView(camera:)`.
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "SceneCamera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()

    private let lock = NSLock()
    private var _device: AVCaptureDevice?
    private var _zoomBase: CGFloat = 1

    // Chỉ dùng trên luồng chính.
    private(set) var front = false
    private(set) var videoAvailable = true
    private var inFlightPhoto: Saver?
    private var onRecordingDone: ((URL?) -> Void)?
    private var recordingActive = false

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Mở / dừng

    func start(onReady: @escaping () -> Void, onError: @escaping () -> Void) {
        let front = self.front
        sessionQueue.async { [self] in
            let ok = bind(front: front)
            if ok { session.startRunning() }
            let video = ok && session.outputs.contains(movieOutput)
            DispatchQueue.main.async { [self] in
                videoAvailable = video
                if ok { onReady() } else { onError() }
            }
        }
    }

    /// Gắn camera + xem trước + chụp + quay. Chạy trên `sessionQueue`. `false` = không mở được camera.
    private func bind(front: Bool) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        locked { _device = nil }

        guard let device = CaptureController.pickDevice(front: front) else {
            Self.log.error("Không có camera bối cảnh")
            return false
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw AVError(.deviceNotConnected) }
            session.addInput(input)
        } catch {
            Self.log.error("Không mở được camera bối cảnh: \(error.localizedDescription, privacy: .public)")
            return false
        }
        // Đủ cho ML Kit; như `Quality.HD` + lùi về SD của Android.
        session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .medium

        guard session.canAddOutput(photoOutput) else {
            Self.log.error("Không gắn được bộ chụp ảnh bối cảnh")
            return false
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .speed
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        } else {
            Self.log.warning("Máy không gắn được cả chụp lẫn quay, bỏ quay video")
        }

        let base = CaptureController.zoomBase(device)
        CaptureController.applyZoom(device, base)
        locked {
            _device = device
            _zoomBase = base
        }
        return true
    }

    /// Đổi camera trước/sau. Không đổi được lúc đang quay. Không gắn được thì quay về camera cũ.
    func flip(onDone: @escaping () -> Void = {}) {
        if recordingActive { return }
        front.toggle()
        let next = front
        sessionQueue.async { [self] in
            let okMoi = bind(front: next)
            if !okMoi { _ = bind(front: !next) }
            let video = session.outputs.contains(movieOutput)
            DispatchQueue.main.async { [self] in
                if !okMoi { front = !next }
                videoAvailable = video
                onDone()
            }
        }
    }

    func stop() {
        stopRecording()
        sessionQueue.sync {
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            session.commitConfiguration()
            locked { _device = nil }
        }
    }

    // MARK: - Zoom

    var zoomRatio: Float {
        let (device, base) = locked { (_device, _zoomBase) }
        guard let device else { return 1 }
        return Float(device.videoZoomFactor / base)
    }

    /// Các mức zoom máy này làm được: 0.5x khi có ống góc rộng, 1x, 2x... tới mức tối đa.
    func zoomStops() -> [Float] {
        let (device, base) = locked { (_device, _zoomBase) }
        guard let device else { return [1] }
        var stops: [Float] = []
        if Float(device.minAvailableVideoZoomFactor / base) <= 0.6 { stops.append(0.5) }
        stops.append(1)
        for z: Float in [2, 5] where z <= Float(device.maxAvailableVideoZoomFactor / base) { stops.append(z) }
        return stops
    }

    func setZoom(_ ratio: Float) {
        sessionQueue.async { [self] in
            let (device, base) = locked { (_device, _zoomBase) }
            guard let device else { return }
            CaptureController.applyZoom(device, CGFloat(ratio) * base)
        }
    }

    // MARK: - Chụp / quay

    /// Góc xoay theo hướng GIAO DIỆN lúc bấm — ảnh lưu đúng chiều cầm máy (như `targetRotation = display.rotation`).
    /// Cùng quy ước với `CameraPreviewView`.
    private static func captureAngle() -> CGFloat {
        let o = MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.effectiveGeometry.interfaceOrientation
        }
        switch o {
        case .landscapeRight: return 0
        case .landscapeLeft: return 180
        case .portraitUpsideDown: return 270
        default: return 90
        }
    }

    private static func setAngle(_ connection: AVCaptureConnection?, _ angle: CGFloat) {
        guard let connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    /// Chụp một tấm vào `file`. `onDone(nil)` = hỏng (file dở đã xoá).
    func takePhoto(_ file: URL, onDone: @escaping (URL?) -> Void) {
        guard locked({ _device }) != nil, session.outputs.contains(photoOutput), inFlightPhoto == nil else {
            return onDone(nil)
        }
        Self.setAngle(photoOutput.connection(with: .video), Self.captureAngle())
        let saver = Saver(file: file) { [weak self] ok in
            DispatchQueue.main.async {
                self?.inFlightPhoto = nil
                if !ok { try? FileManager.default.removeItem(at: file) }
                onDone(ok ? file : nil)
            }
        }
        inFlightPhoto = saver
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.photoQualityPrioritization = .speed
        photoOutput.capturePhoto(with: settings, delegate: saver)
    }

    var isRecording: Bool { recordingActive }

    /// Quay KHÔNG tiếng — chỉ cần hình để nhận diện. `false` = không bắt đầu được.
    func startRecording(_ file: URL, onDone: @escaping (URL?) -> Void) -> Bool {
        guard videoAvailable, !recordingActive, session.outputs.contains(movieOutput) else { return false }
        Self.setAngle(movieOutput.connection(with: .video), Self.captureAngle())
        recordingActive = true
        onRecordingDone = onDone
        movieOutput.startRecording(to: file, recordingDelegate: self)
        return true
    }

    func stopRecording() {
        if movieOutput.isRecording { movieOutput.stopRecording() }
    }

    /// Ghi ảnh chụp ra file. Giữ tham chiếu tới khi xong — bộ chụp chỉ giữ delegate yếu.
    private final class Saver: NSObject, AVCapturePhotoCaptureDelegate {
        private let file: URL
        private let done: (Bool) -> Void

        init(file: URL, done: @escaping (Bool) -> Void) {
            self.file = file
            self.done = done
        }

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error {
                SceneCamera.log.warning("Chụp bối cảnh hỏng: \(error.localizedDescription, privacy: .public)")
                return done(false)
            }
            guard let data = photo.fileDataRepresentation() else { return done(false) }
            do {
                try data.write(to: file)
                done(true)
            } catch {
                SceneCamera.log.warning("Không ghi được ảnh bối cảnh: \(error.localizedDescription, privacy: .public)")
                done(false)
            }
        }
    }
}

extension SceneCamera: AVCaptureFileOutputRecordingDelegate {

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection],
        error: Error?
    ) {
        // Lỗi có cờ "đã ghi xong" (vd. dừng vì đầy giới hạn) thì file vẫn dùng được.
        let finished = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
        let ok = error == nil || finished == true
        if !ok {
            Self.log.warning("Quay bối cảnh hỏng: \(error?.localizedDescription ?? "", privacy: .public)")
            try? FileManager.default.removeItem(at: outputFileURL)
        }
        DispatchQueue.main.async { [self] in
            recordingActive = false
            let done = onRecordingDone
            onRecordingDone = nil
            done?(ok ? outputFileURL : nil)
        }
    }
}
