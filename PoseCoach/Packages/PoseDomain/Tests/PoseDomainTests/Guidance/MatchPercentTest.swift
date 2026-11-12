import Testing
@testable import PoseDomain

/// Port từ `KTT/MatchPercentTest.kt` — ĐỘ GIỐNG ẢNH MẪU realtime phải lấy từ ĐÚNG hàm chấm điểm (`ShotScorer.score`)
/// và đủ cao khi khung hình giống ảnh mẫu (FOOTGUNS 53).
struct MatchPercentTest {

    private let minVis: Float = 0.5

    private func nguoi(_ dx: Double = 0.0) -> PoseFrame {
        frameOf(
            (Lm.nose, lm(0.50 + dx, 0.10, 0.0, -0.60)),
            (Lm.leftEye, lm(0.53 + dx, 0.09, 0.03, -0.62)),
            (Lm.rightEye, lm(0.47 + dx, 0.09, -0.03, -0.62)),
            (Lm.leftEar, lm(0.55 + dx, 0.10, 0.07, -0.61)),
            (Lm.rightEar, lm(0.45 + dx, 0.10, -0.07, -0.61)),
            (Lm.leftShoulder, lm(0.58 + dx, 0.22, 0.18, -0.45)),
            (Lm.rightShoulder, lm(0.42 + dx, 0.22, -0.18, -0.45)),
            (Lm.leftElbow, lm(0.61 + dx, 0.36, 0.22, -0.22)),
            (Lm.rightElbow, lm(0.39 + dx, 0.36, -0.22, -0.22)),
            (Lm.leftWrist, lm(0.62 + dx, 0.48, 0.24, -0.02)),
            (Lm.rightWrist, lm(0.38 + dx, 0.48, -0.24, -0.02)),
            (Lm.leftHip, lm(0.55 + dx, 0.52, 0.11, 0.0)),
            (Lm.rightHip, lm(0.45 + dx, 0.52, -0.11, 0.0)),
            (Lm.leftKnee, lm(0.55 + dx, 0.72, 0.11, 0.42)),
            (Lm.rightKnee, lm(0.45 + dx, 0.72, -0.11, 0.42)),
            (Lm.leftAnkle, lm(0.55 + dx, 0.92, 0.11, 0.85)),
            (Lm.rightAnkle, lm(0.45 + dx, 0.92, -0.11, 0.85))
        )
    }

    private func match(_ tpl: PoseFrame, _ live: PoseFrame) throws -> Int? {
        let profile = TemplateProfile.from(tpl, try #require(FramingClass.detect(tpl, minVis)), minVis)
        let engine = GuidanceEngine(profile)
        let m = Measurer.measure(live, profile.framing, minVis)
        return chayEngine(engine, m, den: 2_000).matchPercent
    }

    @Test("đang không đo được vẫn cho chụp khi bố cục đã đạt")
    func dangKhongDoDuocVanChoChup() throws {
        let frame = nguoi()
        let framing = try #require(FramingClass.detect(frame, minVis))
        var profile = TemplateProfile.from(frame, framing, minVis)
        profile.active = [.center, .pose]
        var live = Measurer.measure(frame, framing, minVis)
        live.poseAngles = [:]
        let result = chayEngine(GuidanceEngine(profile), live, den: 1_500)
        #expect(result.statuses.contains { $0.criterion == .center && $0.state == .passing })
        #expect(result.statuses.contains { $0.criterion == .pose && $0.state != .passing })
        #expect(result.readyToCapture, "Dáng không được chặn việc chụp")
        #expect(!result.statuses.contains { $0.skipped })
    }

    @Test("lệch tâm rất xa sau khi đã đạt phải mở lại bước bố cục")
    func lechTamXaMoLai() throws {
        let frame = nguoi()
        let framing = try #require(FramingClass.detect(frame, minVis))
        var profile = TemplateProfile.from(frame, framing, minVis)
        profile.active = [.center]
        let engine = GuidanceEngine(profile)
        let matching = Measurer.measure(frame, framing, minVis)
        let moved = Measurer.measure(nguoi(0.25), framing, minVis)
        var result = chayEngine(engine, matching, den: 1_500)
        #expect(result.readyToCapture)
        result = chayEngine(engine, moved, tu: 1_600, den: 2_500)
        #expect(!result.readyToCapture, "Lệch xa không được giữ dấu đạt cũ")
        #expect(result.statuses.count == 1 && result.statuses[0].state == .failing)
        #expect(!result.statuses[0].pending)
    }

    @Test("khung hình GIỐNG HỆT ảnh mẫu thì phải gần 100")
    func giongHetGan100() throws {
        let p = try #require(try match(nguoi(), nguoi()), "Phải tính được điểm")
        #expect(p >= 95, "Giống hệt nhau mà chỉ được \(p) điểm thì ngưỡng 85 không bao giờ với tới")
    }

    @Test("lệch nhẹ vẫn phải trên mốc hiển thị tốt")
    func lechNheTrenMoc() throws {
        let p = try #require(try match(nguoi(), nguoi(0.02)))
        #expect(p >= GuidanceEngine.readyPercent, "Lệch nhẹ mà tụt xuống \(p) thì mốc hiển thị không còn hợp lý")
    }

    @Test("lệch càng nhiều thì điểm càng thấp")
    func lechCangNhieu() throws {
        let it = try #require(try match(nguoi(), nguoi(0.02)))
        let nhieu = try #require(try match(nguoi(), nguoi(0.25)))
        #expect(nhieu < it, "Lệch ít \(it), lệch nhiều \(nhieu) — phải giảm")
    }
}
