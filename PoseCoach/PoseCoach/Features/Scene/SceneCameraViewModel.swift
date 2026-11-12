import Foundation

/// Trạng thái + thao tác của camera bối cảnh. Port phần `remember { … }` / `LaunchedEffect` của
/// `KT/scene/SceneCameraScreen.kt` (Kotlin không có ViewModel riêng). Hằng số giữ đúng chỗ Android đặt (D8).
@Observable @MainActor final class SceneCameraViewModel {

    /// Nên chụp bao nhiêu tấm để nhận ra một NƠI: trái – giữa – phải. Một tấm hay bỏ sót cả nửa bối cảnh; ML Kit gắn nhãn
    /// từng tấm riêng nên thêm góc là thêm yếu tố nhận ra được. Chụp cùng MỘT đồ vật thì một tấm là đủ — nên đây là mức
    /// GỢI Ý, không chặn: bấm "Xong" được từ tấm đầu tiên.
    static let goiYSoTam = 3

    /// Quay nhanh hơn mức này thì khung hình nhoè, ML Kit không nhận ra gì. ⚠️ Số PHỎNG ĐOÁN, chưa đo trên máy thật.
    static let quayNhanhDegPerSec = 35.0

    /// Chưa đủ chừng này thì chưa cho dừng — video quá ngắn chỉ ra 1-2 khung.
    static let quayToiThieuMs: Int64 = 2_000

    let camera = SceneCamera()

    private(set) var permission: CameraPermission.Status = CameraPermission.status
    private(set) var ready = false
    private(set) var failed = false
    var videoMode = false
    private(set) var recording = false
    private(set) var elapsed: Int64 = 0
    private(set) var zoom: Float = 1
    private(set) var zoomStops: [Float] = [1]
    private(set) var tooFast = false
    private(set) var busy = false
    private(set) var photos: [URL] = []
    private(set) var videoAvailable = true

    /// Ảnh/video vừa chụp/quay (file tạm của app) → màn đề xuất.
    @ObservationIgnored private let onDone: ([URL]) -> Void
    @ObservationIgnored private let tilt = DeviceTilt()
    @ObservationIgnored private var recordStart = Date()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var started = false

    init(onDone: @escaping ([URL]) -> Void) {
        self.onDone = onDone
    }

    // MARK: - Vòng đời

    func onAppear() {
        // Tốc độ di máy lúc quay — đọc con quay hồi chuyển.
        tilt.start()
        permission = CameraPermission.status
        switch permission {
        case .granted: startCamera()
        case .notDetermined: Task { await requestPermission() }
        case .denied: break
        }
    }

    func requestPermission() async {
        let ok = await CameraPermission.request()
        permission = ok ? .granted : .denied
        if ok { startCamera() }
    }

    func onDisappear() {
        loop?.cancel()
        loop = nil
        tilt.stop()
        camera.stop()
        started = false
    }

    private func startCamera() {
        if started { return }
        started = true
        camera.start(
            onReady: { [weak self] in
                guard let self else { return }
                ready = true
                videoAvailable = camera.videoAvailable
                zoomStops = camera.zoomStops()
            },
            onError: { [weak self] in self?.failed = true }
        )
    }

    // MARK: - Thao tác

    /// Bỏ ra, xoá những tấm vừa chụp.
    func huy() {
        if camera.isRecording { camera.stopRecording() }
        photos.forEach { try? FileManager.default.removeItem(at: $0) }
        photos = []
    }

    func setZoom(_ z: Float) {
        camera.setZoom(z)
        zoom = z
    }

    func flip() {
        camera.flip { [weak self] in
            guard let self else { return }
            videoAvailable = camera.videoAvailable
            zoomStops = camera.zoomStops()
        }
        zoom = 1
    }

    /// Đã chụp ít nhất một tấm: "Xong" để đi đề xuất.
    func done() { onDone(photos) }

    func shutter() {
        if !ready || busy { return }
        if videoMode {
            if recording {
                if elapsed >= Self.quayToiThieuMs { camera.stopRecording() }
                return
            }
            let ok = camera.startRecording(SceneRepository.newCaptureFile("mov")) { [weak self] done in
                guard let self else { return }
                recording = false
                // Quay xong là đi đề xuất luôn, kèm những tấm đã chụp trước đó (nếu có).
                if let done { onDone(photos + [done]) }
            }
            if ok {
                recording = true
                recordStart = Date()
                elapsed = 0
                startLoop()
            }
        } else {
            busy = true
            camera.takePhoto(SceneRepository.newCaptureFile("jpg")) { [weak self] done in
                guard let self else { return }
                busy = false
                if let done { photos.append(done) }
            }
        }
    }

    /// Lúc quay: làm mượt tốc độ di máy để chữ không nhấp nháy; tự dừng trước mốc tối đa.
    private func startLoop() {
        loop?.cancel()
        loop = Task {
            var muot = 0.0
            while recording && !Task.isCancelled {
                muot = muot * 0.7 + tilt.state.angularSpeedDegPerSec * 0.3
                tooFast = muot > Self.quayNhanhDegPerSec
                elapsed = Int64(Date().timeIntervalSince(recordStart) * 1000)
                if elapsed >= SceneRepository.maxVideoMs - 500 { camera.stopRecording() }
                try? await Task.sleep(for: .milliseconds(150))
            }
            tooFast = false
        }
    }
}
