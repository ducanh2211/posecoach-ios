import AVFoundation
import CoreMotion
import os
import PoseDomain
import UIKit

/// CAMERA THẬT cho màn chụp — xem trước, nhận diện thời gian thực, CHỤP LIÊN TỤC và QUAY VIDEO.
/// Port từ `KT/camera/CaptureController.kt`.
///
/// Vì sao quay video thật thay vì lưu khung đã nhận diện: khung đưa vào bộ nhận diện chỉ ~640 px (cố ý, cho nhanh). Lưu
/// chúng làm ảnh cuối thì ảnh xấu — và tự trả lời sai câu hỏi lớn nhất của dự án (*"khung cắt từ video có đẹp bằng ảnh
/// chụp thường không"*). Quay 1080p rồi cắt khung mới đúng thiết kế đã chốt.
///
/// Đây là bộ điều khiển camera DUY NHẤT của app.
///
/// Khác Android (cách tự nhiên của AVFoundation, hành vi giữ nguyên):
/// - **Một luồng khung hình nuôi cả nhận diện lẫn quay video** (`VideoRecorder`), không có `VideoCapture` riêng. Luồng
///   này giữ NGUYÊN chiều cảm biến (góc 0°, không lật) suốt phiên — đổi chiều giữa lúc quay thì cỡ khung đổi và file hỏng.
///   Hướng cầm máy được áp ở ba nơi: nhận diện tự xoay khung (`orientationForAnalysis`), video ghi transform lúc bắt đầu
///   quay, ảnh chụp đặt góc trên kết nối của bộ chụp ngay trước mỗi tấm (FOOTGUNS 10, 95).
/// - Khung xem trước: View tự gắn `session` vào `AVCaptureVideoPreviewLayer`. Lớp xem trước của iOS tự lật camera trước
///   và KHÔNG tự zoom bằng cử chỉ — không cần `lamMoiKhungXem` (FOOTGUNS 109 là lỗi riêng của `PreviewView`).
/// - Callback luôn chạy trên luồng chính, như `ContextCompat.getMainExecutor` của Kotlin.
///
/// `@unchecked Sendable`: trạng thái chéo luồng nằm sau `lock`; phần còn lại ghi rõ chỉ dùng trên một hàng đợi.
nonisolated final class CaptureController: NSObject, @unchecked Sendable {

    /// HAI CÁCH BẮT ẢNH, người dùng chọn. Không thay thế nhau:
    ///
    /// | | `video` | `burst` |
    /// |---|---|---|
    /// | Bắt được gì | mọi khoảnh khắc trong 15-30 giây | 8 khoảnh khắc quanh lúc bấm |
    /// | Chất lượng mỗi ảnh | khung cắt từ video (thấp hơn) | **ảnh chụp thật, full độ phân giải** |
    /// | Hợp với | mẫu đang cử động, cười nói tự nhiên | mẫu đã vào dáng, chỉ chờ đúng lúc |
    /// | Rác sinh ra | 60-100 MB video thô | vài MB ảnh |
    enum Mode { case video, burst }

    /// Hướng cầm máy. Tên giữ như Kotlin: `landscapeLeft` = đỉnh máy quay sang TRÁI (`Surface.ROTATION_90`,
    /// `UIDeviceOrientation.landscapeLeft`).
    enum DeviceRotation: CaseIterable {
        case portrait, landscapeLeft, portraitUpsideDown, landscapeRight

        var isPortrait: Bool { self == .portrait || self == .portraitUpsideDown }

        /// Góc xoay khung cảm biến về đúng chiều, độ theo chiều kim đồng hồ — quy ước `videoRotationAngle` của
        /// AVFoundation. Thay cho `surfaceRotation` của Kotlin.
        var videoRotationAngle: CGFloat {
            switch self {
            case .portrait: 90
            case .landscapeLeft: 0
            case .portraitUpsideDown: 270
            case .landscapeRight: 180
            }
        }
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "CaptureController")

    /// Tỉ lệ ngang/dọc của cảm biến 4:3 khi cầm dọc.
    private static let tiLe43Doc = 3.0 / 4.0

    /// Cạnh dài khung đưa vào nhận diện — tương đương độ phân giải mặc định 640×480 của `ImageAnalysis`.
    private static let analysisLongSide = 640

    /// Hướng mới phải giữ được bấy nhiêu mili-giây mới được đổi (FOOTGUNS 69).
    ///
    /// ⚠️ Hướng suy từ gia tốc kế, tức từ thành phần trọng lực nằm trong mặt phẳng màn hình. Chúc máy xuống thì thành
    /// phần đó co gần bằng 0, góc suy ra chỉ còn là nhiễu — nhảy sang ngang rồi về dọc liên tục. Mà app này BẢO người ta
    /// chúc máy xuống (mục 3 và 4). Lật nhầm là toàn bộ khung xương xoay 90° mà không có gì báo lỗi (FOOTGUNS 10).
    private static let giuHuongMs: Int64 = 400

    private let detector: PoseDetector
    private let onRotationChanged: (DeviceRotation) -> Void
    /// Camera đã mở xong. Tham số cho biết nhận diện thời gian thực có chạy không.
    private let onReady: (_ liveDetectionActive: Bool) -> Void
    /// Báo ra ngoài khi có sự cố — không được im lặng (luật số 7 của dự án).
    private let onError: (UiText) -> Void

    /// Phiên camera. View gắn vào `AVCaptureVideoPreviewLayer.session` để xem trước.
    let session = AVCaptureSession()

    /// Mọi thao tác cấu hình phiên chạy tuần tự ở đây (`startRunning` chặn luồng, không được gọi trên luồng chính).
    private let sessionQueue = DispatchQueue(label: "CaptureController.session")
    /// Khung hình camera tới ở đây; ghi video chạy luôn trên hàng đợi này.
    private let videoQueue = DispatchQueue(label: "CaptureController.video")
    /// Nhận diện chạy ở hàng đợi riêng để không chặn việc ghi video.
    private let analysisQueue = DispatchQueue(label: "CaptureController.analysis")

    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let motion = CMMotionManager.shared
    private let motionQueue = OperationQueue.main

    /// Khoá cho trạng thái đọc chéo luồng (luồng chính ↔ hàng đợi camera).
    private let lock = NSLock()
    private var _device: AVCaptureDevice?
    /// Hệ số `videoZoomFactor` ứng với zoom 1x (ống chính). Máy nhiều ống kính: `videoZoomFactor` 1 = ống góc rộng 0,5x.
    private var _zoomBase: CGFloat = 1
    private var _currentRotation: DeviceRotation = .portrait
    private var _liveDetectionActive = false
    private var _analysisBusy = false
    private var _activeFront = false
    private var _photoActive = false
    private var _videoActive = false
    private var _recordingActive = false
    private var _started = false

    // Chỉ dùng trên `videoQueue`.
    private var recorder: VideoRecorder?
    private var onRecordingFinished: ((URL?) -> Void)?

    // Chỉ dùng trên luồng chính.
    private var huongChoDoi: DeviceRotation?
    private var huongChoTuTimeMs: Int64 = 0
    private var lastOrientationDeg = -1
    private var inFlightPhoto: PhotoSaver?
    private var runtimeErrorObserver: NSObjectProtocol?

    /// Cách bắt ảnh đang dùng. Đổi bằng `setMode` — việc đó cấu hình lại phiên.
    private(set) var mode: Mode = .video

    /// Camera trước hay sau, và ảnh ghi ra có lật không.
    ///
    /// ⚠️ LẬT ẢNH GHI RA LÀ QUYẾT ĐỊNH SẢN PHẨM: PO chốt 06/09/2026 **lưu ảnh đã lật** khi dùng camera trước — người dùng
    /// nhìn màn hình thế nào thì muốn ảnh ra thế đó.
    private(set) var shootMode: ShootMode = .nguoiKhac

    /// Video quay khung 16:9 hay 4:3. Khung chọn hẹp hơn 3:4 (9:16, Full) thì quay 16:9 để không mất độ phân giải; còn
    /// lại quay 4:3 để đủ phần hai bên.
    private var video169 = false

    init(
        detector: PoseDetector,
        onRotationChanged: @escaping (DeviceRotation) -> Void,
        onReady: @escaping (_ liveDetectionActive: Bool) -> Void,
        onError: @escaping (UiText) -> Void
    ) {
        self.detector = detector
        self.onRotationChanged = onRotationChanged
        self.onReady = onReady
        self.onError = onError
        super.init()
    }

    // MARK: - Chế độ

    /// Đổi camera trước/sau. Phải gọi TRƯỚC `start()` khi mở màn (FOOTGUNS 104).
    func setShootMode(_ next: ShootMode) {
        if next == shootMode { return }
        let doiCamera = next.camTruoc != shootMode.camTruoc
        shootMode = next
        if !doiCamera { return }
        reconfigureIfStarted()
    }

    /// Người dùng đổi tỉ lệ khung. Chỉ cấu hình lại khi phải đổi khung quay video.
    func setTiLeKhung(_ tiLeDoc: Double) {
        let next = tiLeDoc < Self.tiLe43Doc - 0.02
        if next == video169 { return }
        video169 = next
        // Chụp liên tục luôn dùng khung ảnh 4:3 của cảm biến — tỉ lệ video không ảnh hưởng.
        if mode == .video { reconfigureIfStarted() }
    }

    /// Đổi cách bắt ảnh. Phải cấu hình lại vì hai chế độ dùng hai bộ ra khác nhau.
    func setMode(_ next: Mode) {
        if next == mode { return }
        mode = next
        reconfigureIfStarted()
    }

    /// Nhận diện thời gian thực có chạy được không.
    var liveDetectionActive: Bool { locked { _liveDetectionActive } }

    // MARK: - Zoom

    /// Mức zoom hiện tại. 1,0 = không zoom (đúng tiêu cự gốc của ống kính chính).
    ///
    /// ⚠️ Zoom là một đường lách qua tiêu chí: app đo "xa/gần" bằng kích thước mẫu trong khung, zoom vào làm mục đó ĐẠT
    /// dù người vẫn đứng nguyên chỗ cũ. Nên phải theo dõi và cảnh báo.
    var zoomRatio: Float {
        let (device, base) = locked { (_device, _zoomBase) }
        guard let device else { return 1 }
        return Float(device.videoZoomFactor / base)
    }

    /// Đưa zoom về đúng tiêu cự gốc. Gọi khi người dùng bấm nút sửa cảnh báo zoom.
    func resetZoom() { setZoom(1) }

    /// Đặt mức zoom. Tự kẹp vào khoảng máy này làm được.
    func setZoom(_ ratio: Float) {
        sessionQueue.async { [self] in
            let (device, base) = locked { (_device, _zoomBase) }
            guard let device else { return }
            Self.applyZoom(device, CGFloat(ratio) * base)
        }
    }

    /// CÁC MỨC ZOOM MÁY NÀY LÀM ĐƯỢC, để dựng nút bấm. Không viết cứng 1x/2x/3x.
    func zoomStops() -> [Float] {
        let range = zoomRange()
        guard locked({ _device }) != nil else { return [1] }
        var stops: [Float] = []
        if range.lowerBound <= 0.6 { stops.append(0.5) }
        stops.append(1)
        for z: Float in [2, 3, 5, 10] where z <= range.upperBound { stops.append(z) }
        return stops
    }

    /// KHOẢNG ZOOM LIÊN TỤC máy này làm được — dùng cho thao tác kéo thả. Chưa có camera thì `1...1`.
    func zoomRange() -> ClosedRange<Float> {
        let (device, base) = locked { (_device, _zoomBase) }
        guard let device else { return 1...1 }
        return Float(device.minAvailableVideoZoomFactor / base)...Float(device.maxAvailableVideoZoomFactor / base)
    }

    /// GÓC MỞ DỌC CỦA ỐNG KÍNH ở mức zoom hiện tại, tính bằng ĐỘ. Mục 3 (máy cao/thấp) cần con số này:
    ///
    ///     elevation = độ_nghiêng_máy + (0,5 − y_mốc) × vFOV
    ///
    /// Khác Android: Android tính từ cỡ cảm biến + tiêu cự; iOS có sẵn `videoFieldOfView` — góc mở theo cạnh DÀI của khung
    /// (chiều ngang cảm biến), đúng cạnh "dọc trên màn hình" khi chụp dọc. Góc đó ứng với `videoZoomFactor` = 1 của thiết
    /// bị, nên chia cho chính `videoZoomFactor` (không phải `zoomRatio`).
    ///
    /// ⚠️ Tỉ lệ khung người dùng chọn: tầng đo đọc `y` trong khung ĐÃ CẮT, nên vFOV phải là của khung đã cắt. Khung rộng
    /// hơn khung camera (1:1) thì cắt trên dưới — vFOV hẹp lại; khung hẹp hơn (9:16) thì cắt hai bên — giữ nguyên. Khác
    /// Android: so với tỉ lệ khung đang PHÂN TÍCH (16:9 khi quay video khung hẹp), vì iOS phân tích chính khung quay.
    ///
    /// `nil` khi chưa có camera hoặc máy không khai báo — tầng đo lùi về `VFOV_ANH_MAU`.
    func verticalFovDeg(_ tiLeKhung: Double?) -> Double? {
        guard let device = locked({ _device }) else { return nil }
        let format = device.activeFormat
        let fov = Double(format.videoFieldOfView)
        guard fov > 0 else { return nil }
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let canhDoc = Double(max(dims.width, dims.height))
        let canhNgang = Double(min(dims.width, dims.height))
        guard canhDoc > 0 else { return nil }

        var nuaTan = tan(fov * .pi / 180 / 2.0)
        nuaTan /= max(Double(device.videoZoomFactor), 0.01)
        let tiLeCamBien = canhNgang / canhDoc
        if let tiLeKhung, tiLeKhung > tiLeCamBien {
            nuaTan *= tiLeCamBien / tiLeKhung
        }
        return 2.0 * atan(nuaTan) * 180 / .pi
    }

    // MARK: - Mở / dừng

    func start() {
        locked { _started = true }
        // Hướng ban đầu theo giao diện hiện tại — như `readDisplayRotation()` của Kotlin.
        let initial = MainActor.assumeIsolated { Self.readDisplayRotation() }
        locked { _currentRotation = initial }

        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main
        ) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
            Self.log.error("Camera lỗi khi đang chạy: \(error?.localizedDescription ?? "", privacy: .public)")
            self?.onError(uiText("camera_err_open", .string(error?.localizedDescription ?? "")))
        }

        let cfg = currentConfig()
        sessionQueue.async { [self] in
            let ok = configure(cfg)
            if ok {
                if cfg.mode == .burst { thuNhoKhungVideoKhiChup() }
                session.startRunning()
            }
            let live = liveDetectionActive
            DispatchQueue.main.async { [self] in
                if ok { onReady(live) }
            }
        }

        startOrientationUpdates()
        // Báo hướng ban đầu NGAY — trình nghe chỉ báo khi hướng ĐỔI (lỗi 16/09/2026: cầm dọc mà bị nhắc "xoay máy về
        // dọc" suốt).
        onRotationChanged(initial)
    }

    /// Dừng camera. Gọi từ luồng chính.
    ///
    /// ⚠️ THỨ TỰ BẮT BUỘC, và phải CHỜ luồng phân tích dừng hẳn. Bên gọi sẽ đóng bộ nhận diện ngay sau hàm này; còn một
    /// khung đang dở thì nó gọi vào vùng nhớ vừa giải phóng và sập ở tầng C++ — không thông báo gì (FOOTGUNS 11).
    func stop() {
        motion.stopAccelerometerUpdates()
        if let runtimeErrorObserver { NotificationCenter.default.removeObserver(runtimeErrorObserver) }
        runtimeErrorObserver = nil
        stopRecording()
        locked {
            _started = false
            _liveDetectionActive = false
        }
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        sessionQueue.sync {
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            session.commitConfiguration()
            locked {
                _device = nil
                _photoActive = false
                _videoActive = false
            }
        }
        // Chờ khung đang dở trên hai hàng đợi chạy xong.
        videoQueue.sync {}
        analysisQueue.sync {}
    }

    private func reconfigureIfStarted() {
        guard locked({ _started }) else { return }
        let cfg = currentConfig()
        sessionQueue.async { [self] in
            guard configure(cfg) else { return }
            if cfg.mode == .burst { thuNhoKhungVideoKhiChup() }
            if !session.isRunning { session.startRunning() }
        }
    }

    /// Ảnh chụp cấu hình đọc trên luồng chính, đưa sang `sessionQueue`. ⚠️ Không để `sessionQueue` gọi ngược
    /// `DispatchQueue.main.sync`: `stop()` trên luồng chính đang chờ `sessionQueue` → hai bên chờ nhau mãi.
    private struct Config {
        let mode: Mode
        let shootMode: ShootMode
        let video169: Bool
    }

    private func currentConfig() -> Config {
        Config(mode: mode, shootMode: shootMode, video169: video169)
    }

    // MARK: - Cấu hình phiên (tương đương `bindAll`)

    /// Gắn camera + bộ ra theo chế độ hiện tại. Chạy trên `sessionQueue`. `false` = không mở được camera (đã báo lỗi).
    ///
    /// Không dựng lại phiên khi xoay máy (FOOTGUNS 12) — chỉ gọi khi đổi chế độ, đổi camera, đổi tỉ lệ khung video.
    private func configure(_ cfg: Config) -> Bool {
        let mode = cfg.mode, video169 = cfg.video169
        let front = cfg.shootMode.camTruoc

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        locked {
            _device = nil
            _photoActive = false
            _videoActive = false
            _liveDetectionActive = false
        }

        guard let device = Self.pickDevice(front: front) else {
            fail(uiText("camera_err_open", .string("no camera")))
            return false
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw AVError(.deviceNotConnected) }
            session.addInput(input)
        } catch {
            Self.log.error("Không mở được camera: \(error.localizedDescription, privacy: .public)")
            fail(uiText("camera_err_open", .string(error.localizedDescription)))
            return false
        }

        if mode == .burst {
            // Ảnh chụp ưu tiên CHẤT LƯỢNG (PO 08/10/2026) — preset `.photo` cho độ phân giải ảnh cao nhất.
            session.sessionPreset = .photo
        } else {
            session.sessionPreset = .inputPriority
            Self.selectVideoFormat(device, video169: video169)
        }

        // Luồng khung hình: nuôi nhận diện, và ghi video ở chế độ `video`.
        // YUV — định dạng GỐC của cảm biến: phần cứng khỏi đổi cả khung lớn sang BGRA 30 lần/giây, bộ nén video nhận
        // thẳng. Khung đưa vào nhận diện vẫn là BGRA: `UprightPixelBuffer` đổi lúc xoay, ở cỡ đã thu nhỏ (như CameraX
        // đổi YUV → RGBA cho `ImageAnalysis`).
        let yuv = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let pixelFormat = videoOutput.availableVideoPixelFormatTypes.contains(yuv) ? yuv : kCVPixelFormatType_32BGRA
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat]
        // Bận thì VỨT khung mới, không xếp hàng — hướng dẫn trễ 1 giây tệ hơn hướng dẫn thưa (`KEEP_ONLY_LATEST`).
        videoOutput.alwaysDiscardsLateVideoFrames = true
        let videoOk = session.canAddOutput(videoOutput)
        if videoOk {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if let c = videoOutput.connection(with: .video) {
                // Giữ chiều GỐC của cảm biến, không lật — xem chú thích đầu lớp.
                if c.isVideoRotationAngleSupported(0) { c.videoRotationAngle = 0 }
                if c.isVideoMirroringSupported {
                    c.automaticallyAdjustsVideoMirroring = false
                    c.isVideoMirrored = false
                }
                if c.isVideoStabilizationSupported { c.preferredVideoStabilizationMode = .off }
            }
        }

        var photoOk = false
        if mode == .burst, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            if let maxDims = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                photoOutput.maxPhotoDimensions = maxDims
            }
            photoOk = true
        }

        let base = Self.zoomBase(device)
        Self.applyZoom(device, base)
        locked {
            _device = device
            _zoomBase = base
            _activeFront = front
            _photoActive = photoOk
            _videoActive = mode == .video && videoOk
            _liveDetectionActive = videoOk
        }

        if mode == .video && !videoOk {
            // Không có luồng khung hình thì không quay được — báo như lỗi mở camera.
            fail(uiText("camera_err_open", .string("video output")))
            return false
        }
        if !videoOk {
            // Như đường lui của Kotlin: vẫn xem trước + chụp, nói rõ cho người dùng biết.
            Self.log.warning("Không gắn được luồng khung hình, bỏ phần nhận diện")
            fail(uiText("camera_err_no_live_detection"))
        }
        if mode == .burst && !photoOk {
            fail(uiText("camera_err_burst"))
        }
        return true
    }

    private func fail(_ text: UiText) {
        DispatchQueue.main.async { [self] in onError(text) }
    }

    /// Camera sau: ưu tiên thiết bị NHIỀU ỐNG (có ống góc rộng 0,5x, tự chuyển sang ống tele) — tương đương camera
    /// logic mặc định của CameraX. Camera trước: ống góc rộng.
    static func pickDevice(front: Bool) -> AVCaptureDevice? {
        if front {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera,
        ]
        for t in types {
            if let d = AVCaptureDevice.default(t, for: .video, position: .back) { return d }
        }
        return nil
    }

    /// `videoZoomFactor` ứng với 1x. Thiết bị có ống góc rộng (triple, dual-wide): mốc chuyển sang ống chính.
    static func zoomBase(_ device: AVCaptureDevice) -> CGFloat {
        guard device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera,
              let first = device.virtualDeviceSwitchOverVideoZoomFactors.first
        else { return 1 }
        return CGFloat(truncating: first)
    }

    static func applyZoom(_ device: AVCaptureDevice, _ factor: CGFloat) {
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        } catch {
            log.warning("Không đặt được zoom: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Cạnh dài tối đa của khung VIDEO khi chụp liên tục — đủ nét cho khung xem trước, nhỏ hơn nhiều khung ảnh 12 MP.
    private static let burstVideoLongSideMax: Int32 = 1920

    /// CHỤP LIÊN TỤC: preset `.photo` chọn định dạng mà khung VIDEO cũng to như ảnh (máy đời mới 4032×3024) — luồng khung
    /// hình chuyển 30 khung cỡ đó mỗi giây chỉ để thu về 640 px cho nhận diện, máy nóng nhanh (Android nhận sẵn 640×480).
    /// Đổi sang định dạng khung video nhỏ hơn nhưng GIỐNG HỆT định dạng của preset ở mọi thứ ảnh hưởng tới kết quả:
    /// - cùng góc mở (`videoFieldOfView`) — mục 3 đọc thẳng số này (`verticalFovDeg`)
    /// - cùng tỉ lệ khung — phép cắt theo tỉ lệ khung và khung đưa vào nhận diện không đổi
    /// - chụp được đúng cỡ ảnh đang chụp, cùng mức chất lượng, cùng định dạng điểm ảnh, cùng không gian màu
    ///
    /// Không có định dạng nào thoả HẾT thì giữ nguyên preset `.photo`. Chạy trên `sessionQueue`, SAU khi `configure` đã
    /// áp preset (định dạng của preset là mốc so).
    private func thuNhoKhungVideoKhiChup() {
        guard let device = locked({ _device }), locked({ _photoActive }) else { return }
        let goc = device.activeFormat
        let dimsGoc = CMVideoFormatDescriptionGetDimensions(goc.formatDescription)
        guard max(dimsGoc.width, dimsGoc.height) > Self.burstVideoLongSideMax,
              let anh = goc.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height })
        else { return }
        let tiLeGoc = Double(dimsGoc.width) / Double(dimsGoc.height)
        let loaiDiemAnh = CMFormatDescriptionGetMediaSubType(goc.formatDescription)
        let fps30 = CMTime(value: 1, timescale: 30)

        let hop = device.formats.filter { f in
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            return max(d.width, d.height) <= Self.burstVideoLongSideMax
                && abs(Double(d.width) / Double(d.height) - tiLeGoc) < 0.01
                && abs(f.videoFieldOfView - goc.videoFieldOfView) < 0.01
                && CMFormatDescriptionGetMediaSubType(f.formatDescription) == loaiDiemAnh
                && f.supportedMaxPhotoDimensions.contains { $0.width == anh.width && $0.height == anh.height }
                && (!goc.isHighPhotoQualitySupported || f.isHighPhotoQualitySupported)
                && f.supportedColorSpaces.contains(device.activeColorSpace)
                && f.videoSupportedFrameRateRanges.contains { $0.minFrameDuration <= fps30 && fps30 <= $0.maxFrameDuration }
        }
        // Khung lớn nhất trong số hợp lệ — khung xem trước nét nhất.
        guard let chon = hop.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        }) else {
            Self.log.info("Chụp liên tục: không có định dạng nhỏ hơn tương đương \(dimsGoc.width)×\(dimsGoc.height) (vFOV \(goc.videoFieldOfView), ảnh \(anh.width)×\(anh.height)) — giữ preset .photo")
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        do {
            try device.lockForConfiguration()
            device.activeFormat = chon
            device.unlockForConfiguration()
        } catch {
            Self.log.warning("Chụp liên tục: không đổi được định dạng, giữ preset .photo: \(error.localizedDescription, privacy: .public)")
            return
        }
        photoOutput.maxPhotoDimensions = anh
        // Đổi định dạng có thể đặt lại zoom — đưa về đúng 1x như `configure`.
        Self.applyZoom(device, locked { _zoomBase })
        let d = CMVideoFormatDescriptionGetDimensions(chon.formatDescription)
        Self.log.info("Chụp liên tục: khung video \(dimsGoc.width)×\(dimsGoc.height) → \(d.width)×\(d.height), vFOV \(chon.videoFieldOfView), ảnh \(anh.width)×\(anh.height)")
    }

    /// Chọn khung quay: ưu tiên Full HD, không có thì tụt xuống HD chứ không bỏ cuộc — quay được ở chất lượng thấp vẫn hơn
    /// không quay được (`Quality.FHD` + `lowerQualityOrHigherThan(HD)`). Sai tỉ lệ thì lấy tỉ lệ kia.
    private static func selectVideoFormat(_ device: AVCaptureDevice, video169: Bool) {
        let w169: [(Int32, Int32)] = [(1920, 1080), (1280, 720)]
        let w43: [(Int32, Int32)] = [(1440, 1080), (960, 720)]
        let wanted = video169 ? w169 + w43 : w43 + w169
        let fps30 = CMTime(value: 1, timescale: 30)
        for (w, h) in wanted {
            let match = device.formats.first { f in
                let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
                return d.width == w && d.height == h
                    && f.videoSupportedFrameRateRanges.contains { $0.minFrameDuration <= fps30 && fps30 <= $0.maxFrameDuration }
            }
            guard let match else { continue }
            do {
                try device.lockForConfiguration()
                device.activeFormat = match
                device.activeVideoMinFrameDuration = fps30
                device.activeVideoMaxFrameDuration = fps30
                device.unlockForConfiguration()
            } catch {
                log.warning("Không đặt được khung quay: \(error.localizedDescription, privacy: .public)")
            }
            return
        }
        log.warning("Không có khung Full HD/HD, giữ khung mặc định")
    }

    // MARK: - Hướng cầm máy

    /// Hướng giao diện lúc mở camera. `UIInterfaceOrientation` NGƯỢC tên với hướng máy khi nằm ngang.
    @MainActor
    private static func readDisplayRotation() -> DeviceRotation {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .landscapeRight: return .landscapeLeft
        case .landscapeLeft: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }

    private func startOrientationUpdates() {
        guard motion.isAccelerometerAvailable else { return }
        lastOrientationDeg = -1
        // `OrientationEventListener` mặc định nhận số ở `SENSOR_DELAY_NORMAL` (200 ms).
        motion.accelerometerUpdateInterval = 0.2
        motion.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            self.onAcceleration(Float(a.x), Float(a.y), Float(a.z))
        }
    }

    /// Công thức của `OrientationEventListener` (AOSP), giữ nguyên: Android đảo dấu gia tốc kế để ra vector trọng lực
    /// hướng xuống; gia tốc kế iOS đã sẵn chiều đó (máy nằm ngửa đọc `(0, 0, -1)`) nên dùng thẳng.
    private func onAcceleration(_ x: Float, _ y: Float, _ z: Float) {
        let magnitude = x * x + y * y
        var orientation = -1 // ORIENTATION_UNKNOWN
        // Máy gần nằm phẳng thì không xác định được hướng.
        if magnitude * 4 >= z * z {
            let oneEightyOverPi: Float = 57.29577957855
            let angle = atan2f(-y, x) * oneEightyOverPi
            orientation = 90 - Int((angle + 0.5).rounded(.down)) // Math.round(float)
            while orientation >= 360 { orientation -= 360 }
            while orientation < 0 { orientation += 360 }
        }
        // Listener chỉ được gọi khi số độ ĐỔI.
        if orientation == lastOrientationDeg { return }
        lastOrientationDeg = orientation
        onOrientationChanged(orientation)
    }

    private func onOrientationChanged(_ orientation: Int) {
        if orientation == -1 { return }
        let next: DeviceRotation
        switch orientation {
        case 45..<135: next = .landscapeRight
        case 135..<225: next = .portraitUpsideDown
        case 225..<315: next = .landscapeLeft
        default: next = .portrait
        }
        if next == locked({ _currentRotation }) {
            huongChoDoi = nil
            return
        }
        // Hướng mới: bắt đầu đếm giờ, chưa đổi ngay.
        let now = Int64(ProcessInfo.processInfo.systemUptime * 1000)
        if next != huongChoDoi {
            huongChoDoi = next
            huongChoTuTimeMs = now
            return
        }
        if now - huongChoTuTimeMs < Self.giuHuongMs { return }
        huongChoDoi = nil
        // Nhận diện đọc hướng này ở khung kế tiếp; video và ảnh đọc lúc bắt đầu quay / lúc bấm chụp (FOOTGUNS 10, 95).
        locked { _currentRotation = next }
        onRotationChanged(next)
    }

    /// Hướng của khung cảm biến (góc 0°, không lật) so với chiều dựng đứng — để `PoseDetector` tự xoay.
    ///
    /// KHÔNG lật camera trước: như `ImageAnalysis` của CameraX, khung phân tích là hình THẬT; tầng trên tự lật khung
    /// xương khi cần (`CaptureViewModel`: `if (mode.camTruoc) rawFrame.mirrored()`).
    static func orientationForAnalysis(_ rotation: DeviceRotation) -> UIImage.Orientation {
        switch rotation {
        case .portrait: .right
        case .landscapeLeft: .up
        case .portraitUpsideDown: .left
        case .landscapeRight: .down
        }
    }

    // MARK: - Chụp liên tục

    /// Chụp một loạt `count` ảnh, cách nhau `intervalMs`. Gọi từ luồng chính.
    ///
    /// ⚠️ Chụp NỐI TIẾP chứ không bắn cùng lúc: bắn chồng thì máy tự huỷ bớt, số ảnh nhận về ít hơn số đã hứa mà không có
    /// lỗi nào báo ra.
    ///
    /// - Parameters:
    ///   - onProgress: số ảnh đã chụp xong, để vẽ thanh tiến trình.
    ///   - onDone: danh sách file thật sự chụp được — có thể ít hơn `count`.
    func captureBurst(
        dir: URL,
        count: Int,
        intervalMs: Int,
        onProgress: @escaping (Int) -> Void,
        onDone: @escaping ([URL]) -> Void
    ) {
        guard locked({ _photoActive }) else {
            onError(uiText("camera_err_burst"))
            onDone([])
            return
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var taken: [URL] = []

        func shoot(_ index: Int) {
            if index >= count {
                onDone(taken)
                return
            }
            let file = dir.appendingPathComponent(String(format: "burst-%02d.jpg", index))
            capturePhoto(to: file) { ok in
                if ok {
                    taken.append(file)
                    onProgress(taken.count)
                }
                // Hỏng một tấm thì bỏ qua tấm đó, KHÔNG bỏ cả loạt.
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(intervalMs)) { shoot(index + 1) }
            }
        }
        shoot(0)
    }

    /// Chụp một tấm. `done` chạy trên luồng chính.
    private func capturePhoto(to file: URL, _ done: @escaping (Bool) -> Void) {
        let rotation = locked { _currentRotation }
        let mirror = shootMode.latGuong && shootMode.camTruoc
        let saver = PhotoSaver(file: file) { [weak self] ok in
            DispatchQueue.main.async {
                self?.inFlightPhoto = nil
                done(ok)
            }
        }
        inFlightPhoto = saver
        sessionQueue.async { [self] in
            // Gọi `capturePhoto` khi bộ chụp không có kết nối đang chạy là ném ngoại lệ ObjC — sập app.
            guard locked({ _photoActive }), let c = photoOutput.connection(with: .video), c.isActive, c.isEnabled else {
                saver.finish(false)
                return
            }
            // ⚠️ Đặt hướng NGAY TRƯỚC mỗi tấm — thiếu là ảnh ra nằm ngang (FOOTGUNS 95).
            if c.isVideoRotationAngleSupported(rotation.videoRotationAngle) {
                c.videoRotationAngle = rotation.videoRotationAngle
            }
            // Ảnh ra phải khớp khung xem trước (PO 06/09/2026).
            if c.isVideoMirroringSupported {
                c.automaticallyAdjustsVideoMirroring = false
                c.isVideoMirrored = mirror
            }
            let settings: AVCapturePhotoSettings
            if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = .quality
            photoOutput.capturePhoto(with: settings, delegate: saver)
        }
    }

    // MARK: - Quay video

    var isRecording: Bool { locked { _recordingActive } }

    /// Bắt đầu quay vào `outputFile`. KHÔNG thu tiếng — sản phẩm không dùng tới, mà xin quyền micro sẽ làm người dùng
    /// nghi ngờ vô cớ ở một app chụp ảnh.
    ///
    /// - Parameter onFinished: gọi trên luồng chính khi quay xong. `nil` nghĩa là quay hỏng (đã báo lỗi, đã xoá file).
    func startRecording(outputFile: URL, onFinished: @escaping (URL?) -> Void) {
        guard locked({ _videoActive }) else {
            onError(uiText("camera_err_not_ready"))
            onFinished(nil)
            return
        }
        let alreadyRecording = locked { () -> Bool in
            if _recordingActive { return true }
            _recordingActive = true
            return false
        }
        if alreadyRecording { return }

        let rotation = locked { _currentRotation }
        let mirror = shootMode.latGuong && shootMode.camTruoc
        videoQueue.async { [self] in
            let settings = videoOutput.recommendedVideoSettings(forVideoCodecType: .h264, assetWriterOutputFileType: .mp4)
            do {
                recorder = try VideoRecorder(outputFile: outputFile, settings: settings,
                                             rotationAngle: rotation.videoRotationAngle, mirrored: mirror)
                onRecordingFinished = onFinished
            } catch {
                finishRecording(outputFile, error, onFinished)
            }
        }
    }

    /// Dừng quay. Kết quả trả về qua `onFinished` đã truyền lúc bắt đầu.
    func stopRecording() {
        videoQueue.async { [self] in
            guard let r = recorder, let onFinished = onRecordingFinished else { return }
            recorder = nil
            onRecordingFinished = nil
            r.finish { [self] error in finishRecording(r.outputFile, error, onFinished) }
        }
    }

    private func finishRecording(_ file: URL, _ error: Error?, _ onFinished: @escaping (URL?) -> Void) {
        locked { _recordingActive = false }
        DispatchQueue.main.async { [self] in
            if let error {
                let code = (error as NSError).code
                Self.log.error("Quay hỏng, mã lỗi \(code): \(error.localizedDescription, privacy: .public)")
                onError(uiText("camera_err_record", .int(code)))
                try? FileManager.default.removeItem(at: file)
                onFinished(nil)
            } else {
                onFinished(file)
            }
        }
    }

    // MARK: - Khoá

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

// MARK: - Khung hình camera

nonisolated extension CaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Ghi trước, phân tích sau: ghi phải nhận MỌI khung, phân tích thì bận được phép bỏ.
        recorder?.append(sampleBuffer)

        let rotation: DeviceRotation? = locked {
            guard _liveDetectionActive, !_analysisBusy else { return nil }
            _analysisBusy = true
            return _currentRotation
        }
        guard let rotation else { return }
        let orientation = Self.orientationForAnalysis(rotation)
        analysisQueue.async { [self] in
            detector.detect(sampleBuffer, orientation: orientation, maxLongSide: Self.analysisLongSide)
            locked { _analysisBusy = false }
        }
    }
}

// MARK: - Lưu một tấm ảnh

/// Nhận ảnh từ `AVCapturePhotoOutput` và ghi ra file. Phải được giữ sống tới khi chụp xong (bộ chụp chỉ giữ tham chiếu yếu).
private nonisolated final class PhotoSaver: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "CaptureController")

    private let file: URL
    private var done: ((Bool) -> Void)?

    init(file: URL, done: @escaping (Bool) -> Void) {
        self.file = file
        self.done = done
    }

    func finish(_ ok: Bool) {
        done?(ok)
        done = nil
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Self.log.warning("Chụp hỏng một tấm: \(error.localizedDescription, privacy: .public)")
            finish(false)
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            Self.log.warning("Chụp hỏng một tấm: không có dữ liệu ảnh")
            finish(false)
            return
        }
        do {
            try data.write(to: file, options: .atomic)
            finish(true)
        } catch {
            Self.log.warning("Không ghi được ảnh: \(error.localizedDescription, privacy: .public)")
            finish(false)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // Lỗi trước khi có ảnh (không gọi `didFinishProcessingPhoto`) — vẫn phải trả kết quả để loạt chụp đi tiếp.
        if done != nil { finish(false) }
    }
}
