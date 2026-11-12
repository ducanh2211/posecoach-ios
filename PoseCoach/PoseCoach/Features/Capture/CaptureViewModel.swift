import Foundation
import Observation
import os
import PoseDomain

/// ViewModel màn chụp. Port `KT/capture/CaptureViewModel.kt` + phần vòng đời camera của `CaptureScreen.kt` —
/// **mới phần camera** (kéo sớm để kiểm 3b trên iPhone): xem trước, khung xương, chụp liên tục, quay video, đổi camera.
/// Ảnh mẫu, hướng dẫn, cảm biến nghiêng, zoom, chấm điểm sau khi chụp thêm ở bước 4c.
@Observable @MainActor final class CaptureViewModel {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "CaptureViewModel")

    /// Ngưỡng hiện điểm — dưới mức này coi như không thấy khớp.
    static let minVis: Float = 0.5

    static let burstCount = 8
    static let burstIntervalMs = 500

    private(set) var state = CaptureUiState()
    private(set) var permission: CameraPermission.Status = CameraPermission.status

    /// Đang chụp dở một loạt — khoá nút chụp tới khi xong.
    private(set) var bursting = false

    @ObservationIgnored private var detector: PoseDetector?
    private var controller: CaptureController?
    @ObservationIgnored private var recordingTimer: Task<Void, Never>?

    /// Tỉ lệ ngang/dọc khi cầm dọc của khung người dùng chọn. `nil` = chưa biết (chưa dựng giao diện).
    @ObservationIgnored private(set) var tiLeKhung: Double?

    /// Bộ điều khiển camera để khung xem trước gắn vào. View CHỈ dùng nó cho `CameraPreviewView`.
    var previewSource: CaptureController? { controller }

    /// Ảnh mẫu đã qua cổng kiểm.
    let template: URL
    /// Chế độ camera SAU của ảnh mẫu này — nút xoay camera quay về đây khi rời camera trước. Ảnh mẫu gương thì về chế độ
    /// gương, còn lại về người khác chụp.
    @ObservationIgnored private let cheDoCamSau: ShootMode
    /// Chế độ camera TRƯỚC: ảnh mẫu đặt máy thì về đặt máy, còn lại selfie.
    @ObservationIgnored private let cheDoCamTruoc: ShootMode

    /// NHÓM CỦA ẢNH MẪU QUYẾT ĐỊNH CHẾ ĐỘ CHỤP — không có hàng nút chọn chế độ (gỡ 13/09/2026, yêu cầu PO), chỉ còn nút
    /// xoay camera trước/sau.
    init(template: URL) {
        self.template = template
        let kind = MediaLibrary.TemplateKind.of(template.lastPathComponent)
        cheDoCamSau = kind == .mirror ? .tuChupGuong : .nguoiKhac
        cheDoCamTruoc = kind == .tripod ? .datMay : .tuChupCamTruoc
        state.mode = switch kind {
        case .selfie: .tuChupCamTruoc
        case .mirror: .tuChupGuong
        case .photographer: .nguoiKhac
        case .tripod: .datMay
        }
    }

    // MARK: - Quyền + vòng đời camera

    /// Màn hiện ra. Có quyền thì mở camera ngay.
    func onAppear() {
        permission = CameraPermission.status
        if permission == .granted { startCamera() }
    }

    func requestPermission() async {
        let ok = await CameraPermission.request()
        permission = ok ? .granted : .denied
        if ok { startCamera() }
    }

    /// Rời màn. Thứ tự bắt buộc: tắt camera XONG mới đóng bộ nhận diện — ngược lại sập ở tầng C++ (FOOTGUNS 11).
    func onDisappear() {
        recordingTimer?.cancel()
        recordingTimer = nil
        controller?.stop()
        detector?.close()
        controller = nil
        detector = nil
        state.cameraReady = false
        state.recording = false
    }

    private func startCamera() {
        guard controller == nil else { return }
        let detector = PoseDetector(
            onResult: { [weak self] frame, stats in
                DispatchQueue.main.async { self?.onLiveFrame(frame, stats) }
            },
            onError: { [weak self] text in
                DispatchQueue.main.async { self?.onCameraError(text) }
            }
        )
        detector.setup()
        let c = CaptureController(
            detector: detector,
            onRotationChanged: { [weak self] r in self?.onRotationChanged(r.isPortrait) },
            onReady: { [weak self] live in self?.onCameraReady(live) },
            onError: { [weak self] text in self?.onCameraError(text) }
        )
        // ⚠️ BÁO CHẾ ĐỘ TRƯỚC KHI BẬT (FOOTGUNS 104) — không thì luôn mở camera sau + quay video.
        c.setShootMode(state.mode)
        c.setMode(state.burstMode ? .burst : .video)
        if let tiLeKhung { c.setTiLeKhung(tiLeKhung) }
        c.start()
        self.detector = detector
        controller = c
    }

    // MARK: - Camera báo về

    func onCameraReady(_ liveDetectionActive: Bool) {
        state.cameraReady = true
        state.liveDetectionActive = liveDetectionActive
    }

    func onCameraError(_ text: UiText) {
        state.cameraError = text
    }

    func dismissError() {
        state.cameraError = nil
    }

    func onRotationChanged(_ portrait: Bool) {
        state.devicePortrait = portrait
    }

    /// Một khung hình vừa nhận diện xong.
    private func onLiveFrame(_ rawFrame: PoseFrame, _ stats: PoseDetector.InferenceStats) {
        // ⚠️ CAMERA TRƯỚC: khung bộ nhận diện nhận là ảnh THÔ (chưa lật), còn khung xem trước đã lật và ảnh ghi ra cũng
        // lật. Lật ở đây một lần là đúng cả hai chỗ: phép đo chạy trên đúng bức ảnh sẽ lưu, khung xương vẽ đè cũng khớp.
        // Soi gương thì KHÔNG lật — camera sau chụp thẳng, khung thô đã chính là bức ảnh sẽ lưu.
        let khungLat = state.mode.camTruoc ? rawFrame.mirrored() : rawFrame
        // Cắt về tỉ lệ khung người dùng chọn — đúng vùng họ đang thấy trên màn hình và đúng vùng ảnh ra.
        let rong = stats.inputWidth
        let cao = stats.inputHeight
        let tl = (rong > 0 && cao > 0) ? tiLeKhung.map { TiLeKhung.theoHuong($0, rong, cao) } : nil
        let frame = tl.map { khungLat.croppedToAspect($0, Double(rong) / Double(cao)) } ?? khungLat
        let (rongCat, caoCat): (Int, Int)
        if let tl {
            if tl < Double(rong) / Double(cao) {
                (rongCat, caoCat) = (Int(Double(cao) * tl), cao)
            } else {
                (rongCat, caoCat) = (rong, Int(Double(rong) / tl))
            }
        } else {
            (rongCat, caoCat) = (rong, cao)
        }
        state.pose = frame
        state.personDetected = !frame.isEmpty && frame.visibility.contains { $0 >= Self.minVis }
        state.inferenceMs = stats.inferenceTimeMs
        state.frameWidth = rongCat
        state.frameHeight = caoCat
    }

    // MARK: - Thao tác

    /// Tỉ lệ khung đổi (dựng giao diện, xoay màn hình). Một tỉ lệ cho bốn chỗ: phép đo, khung quay video, góc mở dọc,
    /// ảnh ra (FOOTGUNS 98).
    func onTiLeKhungChanged(_ tiLe: Double) {
        tiLeKhung = tiLe
        controller?.setTiLeKhung(tiLe)
    }

    /// Chụp liên tục hay quay video.
    func onModeChanged(burst: Bool) {
        guard burst != state.burstMode, !state.recording, !bursting else { return }
        controller?.setMode(burst ? .burst : .video)
        state.burstMode = burst
        state.burstTaken = 0
    }

    /// Đổi camera trước/sau. Báo bộ điều khiển TRƯỚC rồi mới đổi trạng thái.
    func flipCamera() {
        guard !state.recording, !bursting else { return }
        let next = state.mode.camTruoc ? cheDoCamSau : cheDoCamTruoc
        controller?.setShootMode(next)
        state.mode = next
        state.pose = .empty
    }

    /// Nút chụp: chụp một loạt, hoặc bắt đầu / dừng quay.
    func shoot() {
        guard let c = controller, state.cameraReady else { return }
        if state.burstMode {
            guard !bursting else { return }
            let dir = ShotStore.burstDir()
            // Xoá loạt cũ trước khi chụp loạt mới, nếu không ảnh của hai lần chụp lẫn vào nhau.
            try? FileManager.default.removeItem(at: dir)
            bursting = true
            state.burstTaken = 0
            c.captureBurst(
                dir: dir, count: Self.burstCount, intervalMs: Self.burstIntervalMs,
                onProgress: { [weak self] n in self?.state.burstTaken = n },
                onDone: { [weak self] files in self?.onBurstDone(files) }
            )
        } else if state.recording {
            guard state.canStop else { return }
            c.stopRecording()
        } else {
            let dir = ShotStore.recordingsDir()
            let target = dir.appendingPathComponent("rec-\(Int64(Date().timeIntervalSince1970 * 1000)).mp4")
            c.startRecording(outputFile: target) { [weak self] done in self?.onRecordingStopped(done) }
            onRecordingStarted()
        }
    }

    private func onBurstDone(_ files: [URL]) {
        bursting = false
        // Bước 4c: chuyển loạt ảnh sang chấm điểm (`processBurst` → `ShotSession`). Tới đó ảnh nằm ở `Caches/burst/`.
        Self.log.info("Chụp liên tục xong: \(files.count) ảnh")
    }

    private func onRecordingStarted() {
        state.recording = true
        state.recordedMs = 0
        let startedAt = ProcessInfo.processInfo.systemUptime
        recordingTimer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.state.recording else { return }
                let elapsed = Int64((ProcessInfo.processInfo.systemUptime - startedAt) * 1000)
                self.state.recordedMs = elapsed
                if elapsed >= CaptureUiState.maxRecordMs {
                    self.controller?.stopRecording()
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func onRecordingStopped(_ video: URL?) {
        state.recording = false
        recordingTimer?.cancel()
        recordingTimer = nil
        // Bước 4c: chấm điểm video (`processRecording` → `ShotSession`) rồi XOÁ video thô. Tới đó video nằm ở
        // `Caches/recordings/`.
        if let video { Self.log.info("Quay xong: \(video.lastPathComponent, privacy: .public)") }
    }
}
