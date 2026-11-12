import Testing
@testable import PoseDomain

/// Port từ `KTT/CamMayThangTest.kt` — CẦM MÁY THẲNG đo bằng CẢM BIẾN (11/10/2026, PO chốt, FOOTGUNS 112).
///
/// Ảnh mẫu người đứng nghiêng không được làm app bảo "xoay máy" mãi — chỉ đòi máy thẳng.
struct CamMayThangTest {

    private let minVis: Float = 0.5

    private func nguoiNga() -> PoseFrame {
        func p(_ u: Double, _ v: Double, _ y: Double, _ x3: Double) -> (P2, Float, P3) { (P2(u, v), 0.99, P3(x3, y, 0.0)) }
        return frameOf(
            (Lm.nose, p(0.62, 0.12, -0.60, 0.0)),
            (Lm.leftEye, p(0.64, 0.11, -0.62, 0.03)), (Lm.rightEye, p(0.60, 0.11, -0.62, -0.03)),
            (Lm.leftShoulder, p(0.70, 0.30, -0.45, 0.18)), (Lm.rightShoulder, p(0.46, 0.22, -0.45, -0.18)),
            (Lm.leftHip, p(0.58, 0.60, 0.0, 0.11)), (Lm.rightHip, p(0.46, 0.58, 0.0, -0.11))
        )
    }

    private func profile() throws -> TemplateProfile {
        let f = nguoiNga()
        return TemplateProfile.from(f, try #require(FramingClass.detect(f, minVis)), minVis)
    }

    private func chay(_ roll: Double?, pitch: Double? = 0.0) throws -> GuidanceResult {
        let p = try profile()
        let engine = GuidanceEngine(p)
        var live = Measurer.measure(nguoiNga(), p.framing, minVis)
        live.rollDeg = [:]
        var r: GuidanceResult?
        for i in 0...60 { r = engine.update(live, Int64(i) * 100, 0.0, deviceRollDeg: roll, devicePitchDeg: pitch) }
        return try #require(r)
    }

    private func roll(_ r: GuidanceResult) throws -> CriterionStatus {
        try #require(r.statuses.first { $0.criterion == .roll })
    }

    @Test("luôn áp dụng, không cần mốc từ ảnh mẫu")
    func luonApDung() throws {
        #expect(try profile().activeFor(.guidance).contains(.roll))
    }

    @Test("máy thẳng thì đạt dù người mẫu đứng nghiêng")
    func mayThangThiDat() throws {
        #expect(try roll(chay(1.0)).state == .passing)
    }

    @Test("máy xoay theo chiều kim đồng hồ thì bảo xoay ngược lại")
    func mayXoayCungChieu() throws {
        #expect(try chay(15.0).cue?.vi() == "Xoay máy ngược chiều kim đồng hồ đến khi tích sáng")
    }

    @Test("máy gần nằm ngang thì không chặn")
    func mayGanNamNgang() throws {
        #expect(try roll(chay(40.0, pitch: -80.0)).state == .passing)
    }
}
