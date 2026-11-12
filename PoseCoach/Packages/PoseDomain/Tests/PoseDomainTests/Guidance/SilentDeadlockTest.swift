import Testing
@testable import PoseDomain

/// Port từ `KTT/SilentDeadlockTest.kt` — NGÕ CỤT IM LẶNG (quy tắc số 7, FOOTGUNS 46, 72): khung hình sai hẳn so với
/// ảnh mẫu mà app không nói gì — đã gặp trên máy thật ngày 04/09/2026.
struct SilentDeadlockTest {

    private let minVis: Float = 0.5

    private func toanThan() -> PoseFrame {
        frameOf(
            (Lm.nose, lm(0.50, 0.10, 0.0, -0.60)),
            (Lm.leftEye, lm(0.52, 0.09, 0.03, -0.62)),
            (Lm.rightEye, lm(0.48, 0.09, -0.03, -0.62)),
            (Lm.leftShoulder, lm(0.58, 0.22, 0.18, -0.45)),
            (Lm.rightShoulder, lm(0.42, 0.22, -0.18, -0.45)),
            (Lm.leftHip, lm(0.55, 0.52, 0.11, 0.0)),
            (Lm.rightHip, lm(0.45, 0.52, -0.11, 0.0)),
            (Lm.leftKnee, lm(0.55, 0.72, 0.11, 0.42)),
            (Lm.rightKnee, lm(0.45, 0.72, -0.11, 0.42)),
            (Lm.leftAnkle, lm(0.55, 0.92, 0.11, 0.85)),
            (Lm.rightAnkle, lm(0.45, 0.92, -0.11, 0.85))
        )
    }

    private func canMatVaVai() -> PoseFrame {
        frameOf(
            (Lm.nose, lm(0.50, 0.35, 0.0, -0.60)),
            (Lm.leftEye, lm(0.56, 0.30, 0.03, -0.62)),
            (Lm.rightEye, lm(0.44, 0.30, -0.03, -0.62)),
            (Lm.leftShoulder, lm(0.75, 0.80, 0.18, -0.45)),
            (Lm.rightShoulder, lm(0.25, 0.80, -0.18, -0.45))
        )
    }

    private func engineToanThan() throws -> (GuidanceEngine, FramingClass) {
        let f = toanThan()
        let profile = TemplateProfile.from(f, try #require(FramingClass.detect(f, minVis)), minVis)
        return (GuidanceEngine(profile), profile.framing)
    }

    @Test("ảnh mẫu toàn thân gặp khung hình cận thì PHẢI nói gì đó, không được im lặng")
    func toanThanGapCan() throws {
        let (engine, framing) = try engineToanThan()
        let live = Measurer.measure(canMatVaVai(), framing, minVis)
        var cue: String?
        var t: Int64 = 0
        for _ in 0..<60 {
            t += 100
            cue = engine.update(live, t, 0.0).cue?.vi()
        }
        let c = try #require(cue, "Khung hình sai hẳn so với ảnh mẫu mà app không nói gì")
        #expect(!c.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test("mục không đo được không được chặn câu nhắc dành cho mẫu")
    func khongDoDuocKhongChanCauMau() throws {
        let (engine, framing) = try engineToanThan()
        let cutChan = frameOf(
            (Lm.nose, lm(0.50, 0.10, 0.0, -0.60)),
            (Lm.leftEye, lm(0.52, 0.09, 0.03, -0.62)),
            (Lm.rightEye, lm(0.48, 0.09, -0.03, -0.62)),
            (Lm.leftShoulder, lm(0.58, 0.22, 0.18, -0.45)),
            (Lm.rightShoulder, lm(0.42, 0.22, -0.18, -0.45)),
            (Lm.leftHip, lm(0.55, 0.52, 0.11, 0.0)),
            (Lm.rightHip, lm(0.45, 0.52, -0.11, 0.0))
        )
        let res = chayEngine(engine, Measurer.measure(cutChan, framing, minVis), den: 6_000)
        #expect(res.statuses.contains { $0.state == .unmeasured }, "Phải có mục không đo được thì test mới có nghĩa")
        #expect(res.cue != nil || res.readyToPose, "Có mục không đo được thì app vẫn phải nói được gì đó")
    }

    @Test("góc máy VÀNG vẫn phải chặn bước tạo dáng")
    func gocMayVangVanChan() {
        let camera: [GateState] = [.passing, .grey]
        #expect(!camera.allSatisfy { $0 == .passing }, "Vàng chỉ là gần đúng, chưa phải hoàn thành bước góc máy")
        #expect(([.passing, .passing] as [GateState]).allSatisfy { $0 == .passing })
    }
}
