import CoreGraphics
import Foundation
import Observation
import os
import PoseDomain

/// ViewModel màn chụp. Port `KT/capture/CaptureViewModel.kt` + phần vòng đời / hiệu ứng của `KT/capture/CaptureScreen.kt`
/// (phân tích ảnh mẫu, camera, cảm biến, nhận diện mặt live, đếm ngược tự động, đồng hồ quay). Phần chấm điểm sau khi
/// chụp: `CaptureViewModel+ChamDiem.swift`.
///
/// Khác Android: ViewModel tạo MỚI mỗi lần vào màn (`CaptureView(template:)`), nên không cần `startFresh()` — trạng thái
/// lần trước không rò được sang lần sau (FOOTGUNS 23, 90, 114 không áp dụng).
@Observable @MainActor final class CaptureViewModel {

    nonisolated static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "CaptureViewModel")

    /// Mức tin cậy tối thiểu để coi một điểm khớp là đo được.
    nonisolated static let minVis: Float = 0.5

    nonisolated static let burstCount = 8
    nonisolated static let burstIntervalMs = 500

    /// Số liệu khuôn mặt cũ hơn mức này thì coi như không có. Nhận diện mặt chạy ~3 lần/giây; vượt mốc nghĩa là máy
    /// đang nghẽn hoặc mẫu đã quay mặt đi — cả hai đều phải bỏ mục đó chứ không dùng số cũ.
    private static let faceToiDaMs: Int64 = 600

    private(set) var state = CaptureUiState()
    /// Phần đổi theo từng khung nhận diện — tách khỏi `state` để không vẽ lại cả màn mỗi khung (xem `CaptureLiveState`).
    private(set) var live = CaptureLiveState()
    private(set) var permission: CameraPermission.Status = CameraPermission.status

    /// Ảnh mẫu đã qua cổng kiểm.
    let template: URL

    /// Số đo ẢNH MẪU và lớp khung hình của nó. ⚠️ Chốt MỘT LẦN rồi dùng cho mọi khung về sau — không suy lại từ camera.
    @ObservationIgnored private(set) var templateProfile: TemplateProfile?
    /// ENGINE HƯỚNG DẪN — tạo một lần khi có hồ sơ, vì nó giữ trạng thái khoá/mở của từng tiêu chí qua nhiều khung.
    @ObservationIgnored private var engine: GuidanceEngine?
    /// Khung xương thô của ẢNH MẪU — câu nhắc chỉnh dáng cần biết khớp nào lệch.
    @ObservationIgnored private var templateFrameForPose: PoseFrame?
    /// Giai đoạn đặt máy của chế độ `datMay`. Tạo khi có hồ sơ ảnh mẫu.
    @ObservationIgnored private var datMayGate: DatMayGate?

    // Hai giá trị từ ngoài vòng đo — chạy ở nhịp riêng, không đồng bộ với nhịp khung hình.
    @ObservationIgnored private var angularSpeedDegPerSec = 0.0
    /// Độ vẹo / độ ngẩng của MÁY theo cảm biến. ⚠️ Độ vẹo chỉ để chọn nhắc ai ở mục nghiêng ngang — không tham gia chấm.
    @ObservationIgnored private var deviceRollDeg: Double?
    @ObservationIgnored private var devicePitchDeg: Double?

    /// Tỉ lệ khung người dùng chọn, ngang/dọc khi cầm dọc. `nil` = chưa biết (chưa dựng giao diện), đo trên toàn khung.
    @ObservationIgnored private(set) var tiLeKhung: Double?
    /// Mức zoom nhỏ nhất máy làm được — đọc một lần khi camera sẵn sàng.
    @ObservationIgnored private var zoomMin: Float = 0.5
    /// Khoảng zoom máy này làm được — thuộc tính phần cứng, đọc một lần khi camera sẵn sàng.
    private(set) var zoomRange: ClosedRange<Float> = 1...1
    /// Góc mở DỌC của ống kính ở mức zoom và tỉ lệ khung hiện tại. `nil` = chưa đọc được → `Measurer.vfovAnhMau`.
    @ObservationIgnored private var vFovDeg: Double?

    /// Số liệu khuôn mặt mới nhất từ đường thời gian thực, kèm mốc thời gian.
    @ObservationIgnored private var liveFace: FaceInfo?
    @ObservationIgnored private var liveFaceAtMs: Int64 = 0

    /// Chế độ camera SAU của ảnh mẫu này — nút xoay camera quay về đây khi rời camera trước. Ảnh mẫu gương thì về chế độ
    /// gương, còn lại về người khác chụp.
    @ObservationIgnored private let cheDoCamSau: ShootMode
    /// Chế độ camera TRƯỚC: ảnh mẫu đặt máy thì về đặt máy, còn lại selfie.
    @ObservationIgnored private let cheDoCamTruoc: ShootMode

    @ObservationIgnored private var detector: PoseDetector?
    private var controller: CaptureController?
    @ObservationIgnored private var tilt: DeviceTilt?
    @ObservationIgnored private var sensorLoop: Task<Void, Never>?
    @ObservationIgnored private var autoLoop: Task<Void, Never>?
    @ObservationIgnored private var recordingTimer: Task<Void, Never>?
    @ObservationIgnored private var analyzeTask: Task<Void, Never>?
    /// Đang chụp dở một loạt (từ lúc bấm tới tấm cuối) — chặn bấm chồng trước khi có tấm đầu.
    @ObservationIgnored private var bursting = false

    /// Bộ điều khiển camera để khung xem trước gắn vào. View CHỈ dùng nó cho `CameraPreviewView`.
    var previewSource: CaptureController? { controller }

    /// Sẵn sàng quay chưa: phải có ảnh mẫu đo được VÀ camera mở được.
    var readyToRecord: Bool { templateProfile != nil && state.cameraReady }

    /// NHÓM CỦA ẢNH MẪU QUYẾT ĐỊNH CHẾ ĐỘ CHỤP — ảnh mẫu selfie gương gần như không tái tạo được ở chế độ người khác chụp.
    /// Hàng nút chọn chế độ đã gỡ (13/09/2026, yêu cầu PO); chỉ còn nút xoay camera trước/sau.
    init(template: URL) {
        self.template = template
        let kind = MediaLibrary.TemplateKind.of(template.lastPathComponent)
        cheDoCamSau = kind == .mirror ? .tuChupGuong : .nguoiKhac
        cheDoCamTruoc = kind == .tripod ? .datMay : .tuChupCamTruoc
        let dau: ShootMode = switch kind {
        case .selfie: .tuChupCamTruoc
        case .mirror: .tuChupGuong
        case .photographer: .nguoiKhac
        case .tripod: .datMay
        }
        onShootModeChanged(dau)
    }

    nonisolated static func nowMs() -> Int64 { Int64(ProcessInfo.processInfo.systemUptime * 1000) }

    // MARK: - Vòng đời

    /// Màn hiện ra: phân tích ảnh mẫu MỘT LẦN, xin quyền / mở camera.
    func onAppear() {
        if analyzeTask == nil { analyzeTask = Task { await analyzeTemplate() } }
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

    /// Rời màn. Thứ tự bắt buộc: tắt camera XONG mới đóng bộ nhận diện — ngược lại sập ở tầng C++ (FOOTGUNS 11).
    func onDisappear() {
        recordingTimer?.cancel()
        recordingTimer = nil
        sensorLoop?.cancel()
        sensorLoop = nil
        autoLoop?.cancel()
        autoLoop = nil
        tilt?.stop()
        tilt = nil
        controller?.stop()
        detector?.close()
        controller = nil
        detector = nil
        state.cameraReady = false
        state.recording = false
    }

    private func startCamera() {
        guard controller == nil else { return }
        let face = LiveFaceTracker { [weak self] info in
            DispatchQueue.main.async { self?.onLiveFace(info) }
        }
        let detector = PoseDetector(
            onResult: { [weak self] frame, stats in
                DispatchQueue.main.async { self?.onLiveFrame(frame, stats) }
            },
            onError: { [weak self] text in
                DispatchQueue.main.async { self?.onCameraError(text) }
            },
            onFrame: { face.offer($0) }
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

        // --- Cảm biến nghiêng + mức zoom: lấy mẫu ~30 lần/giây (cảm biến trả 50-100 lần/giây, zoom chỉ đổi khi
        // người dùng chụm ngón — đọc đúng nhịp từng cái thì tốn hơn nhiều mà không được gì).
        let t = DeviceTilt()
        t.start()
        tilt = t
        sensorLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let r = t.state
                // Hai số này CHỈ để chọn nhắc ai ở mục nghiêng ngang / giai đoạn đặt máy, không tham gia chấm.
                self.onSensorReading(r.angularSpeedDegPerSec,
                                     r.hasData ? r.rollDeg : nil,
                                     r.hasData ? r.cameraPitchDeg : nil)
                if let c = self.controller { self.onZoomChanged(c.zoomRatio) }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    // MARK: - Ảnh mẫu

    private func analyzeTemplate() async {
        let file = template
        let (thumb, frame, face) = await Task.detached { () -> (CGImage?, PoseFrame?, FaceInfo?) in
            let bmp = UprightImage.decode(file)
            // Không nạp được ảnh thì KHÔNG gọi bộ nhận diện — nó trả khung rỗng và người dùng nhận câu "không tìm thấy
            // người", sai nguyên nhân.
            let frame = bmp.flatMap { StillPoseAnalyzer.analyze($0) }
            // Góc mặt của ảnh mẫu — cần cho mục 1 khi ảnh mẫu là chân dung.
            let face = bmp.flatMap { FaceAnalyzer().analyze($0) }
            return (bmp, frame, face)
        }.value
        onTemplateAnalyzed(file.deletingPathExtension().lastPathComponent, thumb, frame, face)
    }

    func onTemplateAnalyzed(_ name: String, _ thumb: CGImage?, _ frame: PoseFrame?, _ face: FaceInfo?) {
        state.templateName = name
        state.templateThumb = thumb
        state.analyzingTemplate = false
        guard let frame, !frame.isEmpty else {
            state.templateError = uiText(frame == nil ? "capture_err_template_model" : "capture_err_template_no_person")
            return
        }
        guard let framing = FramingClass.detect(frame, Self.minVis) else {
            state.templateError = uiText("capture_err_template_framing")
            return
        }
        // ⚠️ HỒ SƠ ẢNH MẪU chốt Ở ĐÂY, một lần duy nhất — quyết định luôn NHỮNG TIÊU CHÍ NÀO được chấm.
        let profile = TemplateProfile.from(
            frame, framing, Self.minVis, face: face,
            gocMayNhan: MediaLibrary.gocMayTheoNhan(name),
            kieuChupTren: MediaLibrary.kieuChupTrenTheoNhan(name)
        )
        templateProfile = profile
        datMayGate = DatMayGate(MediaLibrary.gocMayTheoNhan(name))
        // Engine phải tạo SAU khi có hồ sơ — nó đọc hồ sơ để biết mục nào áp dụng.
        engine = GuidanceEngine(profile)
        templateFrameForPose = frame

        state.templateFraming = framing
        state.criteriaSummary = profile.describe()
        // Ảnh mẫu dọc hay ngang — quyết định việc nhắc xoay máy.
        state.templatePortrait = thumb.map { $0.height >= $0.width }
        state.mocMau = Measurer.mocLuoi(frame, framing, Self.minVis)
        state.templateError = nil
    }

    // MARK: - Camera, cảm biến, zoom báo về

    func onCameraReady(_ liveDetectionActive: Bool) {
        state.cameraReady = true
        state.liveDetectionActive = liveDetectionActive
        // Các mức zoom máy này làm được — đọc MỘT LẦN, không đổi suốt phiên.
        if let c = controller {
            zoomRange = c.zoomRange()
            zoomMin = zoomRange.lowerBound
        }
        capNhatVFov()
    }

    func onCameraError(_ text: UiText) {
        state.cameraError = text
    }

    func onRotationChanged(_ portrait: Bool) {
        state.devicePortrait = portrait
    }

    func onSensorReading(_ angularSpeed: Double, _ rollDeg: Double?, _ pitchDeg: Double?) {
        angularSpeedDegPerSec = angularSpeed
        deviceRollDeg = rollDeg
        devicePitchDeg = pitchDeg
    }

    func onZoomChanged(_ ratio: Float) {
        guard ratio != state.zoomRatio else { return }
        state.zoomRatio = ratio
        capNhatVFov()
    }

    /// Chọn một mức zoom (chip, kéo thước, chụm ngón).
    func setZoom(_ ratio: Float) {
        controller?.setZoom(ratio)
        onZoomChanged(min(max(ratio, zoomRange.lowerBound), zoomRange.upperBound))
    }

    /// Bấm vào cảnh báo zoom → đưa zoom về 1,0x.
    func resetZoom() {
        controller?.resetZoom()
    }

    /// Một tỉ lệ cho bốn chỗ: phép đo, khung quay video, góc mở dọc, ảnh ra (FOOTGUNS 98).
    func onTiLeKhungChanged(_ tiLe: Double) {
        tiLeKhung = tiLe
        controller?.setTiLeKhung(tiLe)
        capNhatVFov()
    }

    private func capNhatVFov() {
        vFovDeg = controller?.verticalFovDeg(tiLeKhung)
    }

    func onLiveFace(_ info: FaceInfo?) {
        liveFace = info
        liveFaceAtMs = Self.nowMs()
    }

    // MARK: - Chế độ

    /// Đổi AI cầm máy. Đặt máy tự chụp: người dùng đứng xa, không bấm được — bật sẵn tự đếm ngược.
    private func onShootModeChanged(_ m: ShootMode) {
        datMayGate?.reset()
        state.mode = m
        if m.datMay { onAutoModeChanged(true) }
    }

    /// Đổi camera trước/sau — phải gắn lại toàn bộ camera, nên báo bộ điều khiển TRƯỚC rồi mới đổi trạng thái.
    func flipCamera() {
        guard !state.recording, state.burstTaken == 0, !bursting else { return }
        let next = state.mode.camTruoc ? cheDoCamSau : cheDoCamTruoc
        controller?.setShootMode(next)
        onShootModeChanged(next)
    }

    /// Đổi giữa chụp liên tục và quay video.
    func onModeChanged(burst: Bool) {
        guard burst != state.burstMode, !state.recording, !bursting else { return }
        controller?.setMode(burst ? .burst : .video)
        state.burstMode = burst
        state.burstTaken = 0
    }

    /// Bật / tắt tự động: đủ giống thì đếm ngược rồi bấm quay hộ. ⚠️ KHÔNG khoá nút chụp tay — PO chốt không bao giờ
    /// chặn việc chụp.
    func onAutoModeChanged(_ on: Bool) {
        state.autoMode = on
        state.countdown = nil
        autoLoop?.cancel()
        autoLoop = on ? Task { [weak self] in await self?.runAutoCountdown() } : nil
    }

    /// TỰ ĐỘNG: vòng lặp tự đọc trạng thái mới nhất mỗi 100 ms và **chịu được những cú tụt ngắn** — tay người luôn rung.
    /// ⚠️ Chỉ khoá theo `autoMode`, không khoá theo `readyToPose` (điểm dao động quanh ngưỡng → không bao giờ đếm xong).
    private func runAutoCountdown() async {
        var dem = AutoCountdown()
        while !Task.isCancelled {
            let s = state
            // Đang quay / chụp / xử lý thì không đếm — nếu không nó bấm chồng lên nhau. Chỉ đếm khi toàn bộ quy trình
            // đã xong (`readyToCapture`); mục không hội tụ được engine đánh dấu bỏ qua trước khi cờ này bật.
            let busy = s.recording || s.burstTaken > 0 || s.processing
            switch dem.tick(Self.nowMs(), ready: s.readyToCapture, busy: busy) {
            case .cho:
                if s.countdown != nil { state.countdown = nil }
            case let .dem(con):
                datNeuKhac(\.countdown, con)
            case .chup:
                state.countdown = nil
                shoot()
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Nhận diện thời gian thực

    /// Một khung hình vừa nhận diện xong.
    private func onLiveFrame(_ rawFrame: PoseFrame, _ stats: PoseDetector.InferenceStats) {
        let minVisibility = Self.minVis
        let mode = state.mode
        // ⚠️ CAMERA TRƯỚC: khung bộ nhận diện nhận là ảnh THÔ (chưa lật), còn khung xem trước đã lật và ảnh ghi ra cũng
        // lật. Lật ở đây một lần là đúng cả hai chỗ: phép đo chạy trên đúng bức ảnh sẽ lưu, khung xương vẽ đè cũng khớp.
        // Soi gương thì KHÔNG lật — camera sau chụp thẳng, khung thô đã chính là bức ảnh sẽ lưu.
        let khungLat = mode.camTruoc ? rawFrame.mirrored() : rawFrame
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
        let detected = !frame.isEmpty && frame.visibility.contains { $0 >= minVisibility }
        let profile = templateProfile
        let now = Self.nowMs()

        // ⚠️ CẦM MÁY SAI thì mọi phép đo phía sau đều mất nghĩa — xét TRƯỚC các tiêu chí.
        let prepCamMay = CameraPrep.warningFor(state.devicePortrait, state.templatePortrait, state.zoomRatio)
        // ĐẶT MÁY TỰ CHỤP: giai đoạn đặt máy nói TRƯỚC mọi hướng dẫn về chỗ đứng (chặn cả tự chụp, như mọi cảnh báo cầm
        // máy). Đặt xong mà chưa thấy người thì mời ra đứng vào khung.
        var prep = prepCamMay
        if prep == nil, mode.datMay, let gate = datMayGate, let profile {
            prep = gate.update(
                deviceRollDeg,
                devicePitchDeg.map { -$0 }, // camera TRƯỚC nhìn ngược camera sau
                now,
                GuidanceConfig.bandFor(.roll, profile.framing, profile.measurement.scale, nil)!,
                GuidanceConfig.bandFor(.pitch, profile.framing, profile.measurement.scale, .gocMay)
            ) ?? (detected ? nil : uiText("tripod_step_into_frame"))
        }

        // ⚠️ ĐÚNG `Measurer.measure` mà ảnh mẫu đã đi qua, với ĐÚNG lớp khung hình của ảnh mẫu — bất biến số 1: hướng dẫn
        // realtime và chấm điểm sau khi quay đọc từ cùng một phép đo.
        var live: PoseMeasurement?
        if detected, let profile {
            let vFov = vFovDeg ?? Measurer.vfovAnhMau
            let face = liveFace.flatMap { f -> FaceInfo? in
                guard now - liveFaceAtMs < Self.faceToiDaMs else { return nil }
                // ⚠️ CAMERA TRƯỚC: khung xương đã lật ở trên, nhưng ML Kit chạy trên ảnh THÔ nên góc mặt CHƯA lật. Lật
                // ngang thì góc quay trái/phải đổi dấu.
                return mode.camTruoc ? FaceInfo(yawDeg: f.yawDeg.map { -$0 }, eyesOpen: f.eyesOpen) : f
            }
            let doAnh = Measurer.measure(frame, profile.framing, minVisibility, face: face, vFovDeg: vFov)
            // ⚠️ GÓC MÁY PHÍA CAMERA LẤY TỪ CẢM BIẾN — độ thật, cùng thang với NHÃN góc của ảnh mẫu. KHÔNG suy từ khung
            // xương: con số đó lẫn dáng đứng và loại ống kính (FOOTGUNS 91). Camera trước nhìn NGƯỢC hướng camera sau,
            // nên dấu góc đảo lại.
            if let camBien = devicePitchDeg.map({ mode.camTruoc ? -$0 : $0 }) {
                live = doAnh.gocMayTuCamBien(camBien, vFov)
            } else {
                live = doAnh.boGocMayTuAnh()
            }
        }

        let result = engine?.update(
            live, Int64(Date().timeIntervalSince1970 * 1000), angularSpeedDegPerSec,
            prepWarning: prep,
            zoomRatio: state.zoomRatio,
            deviceRollDeg: deviceRollDeg,
            devicePitchDeg: devicePitchDeg,
            mode: mode,
            templateFrame: templateFrameForPose,
            liveFrame: detected ? frame : nil,
            minVis: minVisibility,
            allowSkip: state.autoMode,
            vFovDeg: vFovDeg,
            zoomMin: zoomMin
        )

        // ⚠️ Phần đổi theo từng khung ghi vào `live` MỘT lần. Phần thuộc `state` chỉ ghi khi giá trị ĐỔI: ghi đè đúng giá
        // trị cũ cũng làm SwiftUI vẽ lại mọi view đọc `state` — cả màn hình, 20-30 lần/giây.
        var l = CaptureLiveState()
        l.pose = frame
        l.visiblePoints = frame.visibility.filter { $0 >= minVisibility }.count
        l.bodyYawDeg = detected ? frame.bodyYawDeg(minVisibility) : nil
        // Chỉ hiện để theo dõi. KHÔNG dùng làm mốc đo — mốc đo luôn là lớp khung hình của ảnh mẫu.
        l.liveFraming = detected ? FramingClass.detect(frame, minVisibility) : nil
        l.inferenceMs = stats.inferenceTimeMs
        l.frameWidth = rongCat
        l.frameHeight = caoCat
        l.criteria = result?.statuses ?? []
        l.matchPercent = result?.matchPercent
        // Cùng lớp khung hình của ẢNH MẪU — live không tự chọn mốc.
        l.mocLive = (detected && profile != nil) ? Measurer.mocLuoi(frame, profile!.framing, minVisibility) : nil
        l.stableForMs = result?.stableForMs ?? 0
        #if DEBUG
        l.debugGocMay = Self.debugGocMay(devicePitchDeg.map { mode.camTruoc ? -$0 : $0 })
        l.debugDo = Self.debugDo(profile?.measurement, live, vFovDeg)
        l.debugChiTiet = Self.debugChiTiet(
            inW: rong, inH: cao, cropW: rongCat, cropH: caoCat, zoom: state.zoomRatio,
            visible: l.visiblePoints, ms: stats.inferenceTimeMs, deviceRoll: deviceRollDeg,
            t: profile?.measurement, l: live, statuses: l.criteria
        )
        #endif
        self.live = l

        datNeuKhac(\.personDetected, detected)
        datNeuKhac(\.cue, result?.cue)
        datNeuKhac(\.cueForModel, result?.cueForModel == true)
        datNeuKhac(\.prepWarning, prep)
        datNeuKhac(\.readyToCapture, result?.readyToCapture ?? false)
        datNeuKhac(\.readyToPose, result?.readyToPose == true)
        datNeuKhac(\.almost, result?.almost == true)
        datNeuKhac(\.denBoCuc, result?.denBoCuc == true)
    }

    /// Ghi một trường của `state` CHỈ KHI giá trị đổi — xem chú thích cuối `onLiveFrame`.
    private func datNeuKhac<T: Equatable>(_ truong: WritableKeyPath<CaptureUiState, T>, _ giaTri: T) {
        if state[keyPath: truong] != giaTri { state[keyPath: truong] = giaTri }
    }

    // MARK: - Chụp / quay

    /// Nút chụp (đồng hồ tự động cũng gọi đúng hàm này): chụp một loạt, hoặc bắt đầu / dừng quay.
    func shoot() {
        guard let c = controller else { return }
        if state.burstMode {
            guard !bursting else { return }
            let dir = ShotStore.burstDir()
            // Xoá loạt cũ trước khi chụp loạt mới, nếu không ảnh của hai lần chụp lẫn vào nhau.
            try? FileManager.default.removeItem(at: dir)
            bursting = true
            c.captureBurst(
                dir: dir, count: Self.burstCount, intervalMs: Self.burstIntervalMs,
                onProgress: { [weak self] n in self?.state.burstTaken = n },
                onDone: { [weak self] files in
                    self?.bursting = false
                    self?.processBurst(files)
                }
            )
        } else if state.recording {
            c.stopRecording()
        } else {
            let target = ShotStore.recordingsDir()
                .appendingPathComponent("rec-\(Int64(Date().timeIntervalSince1970 * 1000)).mp4")
            c.startRecording(outputFile: target) { [weak self] done in self?.onRecordingStopped(done) }
            onRecordingStarted()
        }
    }

    /// Bấm nút chụp tay: huỷ lần đếm đang chạy rồi chụp.
    func shootManually() {
        state.countdown = nil
        shoot()
    }

    private func onRecordingStarted() {
        state.recording = true
        state.recordedMs = 0
        let startedAt = Self.nowMs()
        // Đồng hồ quay + tự dừng ở 30 giây.
        recordingTimer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.state.recording else { return }
                let elapsed = Self.nowMs() - startedAt
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
        if let video {
            processRecording(video)
        } else {
            onProcessingFailed(uiText("process_err_record"))
        }
    }

    // MARK: - Chấm điểm báo về

    func onProcessing(_ progress: Float, _ note: UiText) {
        state.processing = true
        state.processProgress = min(max(progress, 0), 1)
        state.processNote = note
    }

    /// Khác Android: đặt lại `burstTaken` — Kotlin giữ nguyên nên chấm loạt ảnh hỏng thì nút chụp (`burstTaken == 0`)
    /// khoá luôn tới khi rời màn (đã báo người dùng).
    func onProcessingFailed(_ message: UiText) {
        state.processing = false
        state.processProgress = 0
        state.burstTaken = 0
        state.cameraError = message
    }

    func onFinished(_ sessionDir: URL) {
        state.processing = false
        state.processProgress = 1
        state.finishedSession = sessionDir
    }

    /// Màn hình đã chuyển sang màn kết quả — xoá để không nhảy lại (FOOTGUNS 114).
    func onFinishedHandled() {
        state.finishedSession = nil
    }
}
