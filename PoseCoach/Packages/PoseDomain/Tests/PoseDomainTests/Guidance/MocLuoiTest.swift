import Testing
@testable import PoseDomain

/// Port từ `KTT/MocLuoiTest.kt` — MỐC LƯỚI: mốc trên/dưới để đặt người vào khung, và chỉ hiện khi xong bước góc
/// máy (PO 11/10/2026).
struct MocLuoiTest {

    private let minVis: Float = 0.5

    private func nguoi() -> PoseFrame {
        func p(_ u: Double, _ v: Double, _ y: Double, _ x3: Double) -> (P2, Float, P3) { (P2(u, v), 0.99, P3(x3, y, 0.0)) }
        return frameOf(
            (Lm.nose, p(0.50, 0.10, -0.60, 0.0)),
            (Lm.leftEye, p(0.52, 0.09, -0.62, 0.03)), (Lm.rightEye, p(0.48, 0.09, -0.62, -0.03)),
            (Lm.leftEar, p(0.54, 0.10, -0.60, 0.06)), (Lm.rightEar, p(0.46, 0.10, -0.60, -0.06)),
            (Lm.leftShoulder, p(0.58, 0.22, -0.45, 0.18)), (Lm.rightShoulder, p(0.42, 0.22, -0.45, -0.18)),
            (Lm.leftHip, p(0.55, 0.52, 0.0, 0.11)), (Lm.rightHip, p(0.45, 0.52, 0.0, -0.11)),
            (Lm.leftKnee, p(0.55, 0.72, 0.42, 0.11)), (Lm.rightKnee, p(0.45, 0.72, 0.42, -0.11)),
            (Lm.leftAnkle, p(0.55, 0.92, 0.85, 0.11)), (Lm.rightAnkle, p(0.45, 0.92, 0.85, -0.11))
        )
    }

    @Test("ảnh toàn thân lấy đầu và cổ chân")
    func toanThanDauVaCoChan() throws {
        let m = Measurer.mocLuoi(nguoi(), .full, minVis)
        #expect(m.loaiTren == .dau)
        #expect(m.loaiDuoi == .chan)
        #expect(isClose(try #require(m.trenY), 0.10, 1e-9))
        #expect(isClose(try #require(m.duoiY), 0.92, 1e-9))
        #expect(isClose(try #require(m.giuaX), 0.5, 0.02))
    }

    @Test("ảnh chân dung lấy mắt và vai")
    func chanDungMatVaVai() throws {
        let m = Measurer.mocLuoi(nguoi(), .head, minVis)
        #expect(m.loaiTren == .mat)
        #expect(m.loaiDuoi == .vai)
        #expect(isClose(try #require(m.duoiY), 0.22, 1e-9))
    }

    @Test("mốc chỉ bật khi xong các bước góc máy")
    func mocChiBatKhiXongGocMay() throws {
        let f = nguoi()
        let profile = TemplateProfile.from(f, try #require(FramingClass.detect(f, minVis)), minVis)
        let dung = Measurer.measure(f, profile.framing, minVis)
        let engine = GuidanceEngine(profile)
        var sai = dung
        sai.scale = (dung.scale ?? 0.5) * 1.5
        var r: GuidanceResult?
        for i in 0...20 { r = engine.update(sai, Int64(i) * 100, 0.0) }
        #expect(try #require(r).denBoCuc == false)
        for i in 21...60 { r = engine.update(dung, Int64(i) * 100, 0.0) }
        #expect(try #require(r).denBoCuc)
    }
}
