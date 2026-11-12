import Testing
@testable import PoseDomain

/// Port từ `KTT/DuoiSanDatTest.kt` — hai bản sửa từ video test 10/10/2026:
/// - lệch nhỏ hơn mức chỉnh được thì cho qua, không để app im mãi (video-test-3 1:54-2:02);
/// - ảnh mẫu đo cỡ bằng mặt mà khung thiếu thân thì mục khung hình phải lệch (video 1, 9:34).
struct DuoiSanDatTest {

    // Giống mục máy nghiêng: đạt 6°, sàn chỉnh được 2°.
    private let band = Band(accept: 6.0, enter: 9.0, unlock: 18.0, actionFloor: 2.0)

    private func chay(_ gate: CriterionGate, _ lech: Double, _ tuMs: Int64, _ denMs: Int64) -> GateState {
        var s = GateState.unmeasured
        var t = tuMs
        while t <= denMs { s = gate.update(lech, band, t); t += 100 }
        return s
    }

    @Test("lệch nhỏ hơn sàn chỉnh được thì giữ đủ lâu là đạt")
    func lechDuoiSanGiuDuLau() {
        let gate = CriterionGate(.roll)
        // 7° — quá ngưỡng đạt 1°, nhỏ hơn sàn 2°: trước đây đứng im mãi.
        #expect(chay(gate, 7.0, 0, 1_000) != .passing)
        #expect(chay(gate, 7.0, 1_100, GuidanceTiming.stallTimeoutMs + 500) == .passing)
        #expect(gate.locked)
    }

    @Test("lệch quá sàn thì vẫn phải sửa, không cho qua")
    func lechQuaSan() {
        let gate = CriterionGate(.roll)
        // 8,5° — phần phải sửa 2,5° ≥ sàn: vẫn là việc của người dùng.
        #expect(chay(gate, 8.5, 0, 10_000) == .failing)
    }

    @Test("đã khoá thì trôi dưới sàn không làm rung tích")
    func daKhoaTroiDuoiSan() {
        let gate = CriterionGate(.roll)
        _ = chay(gate, 3.0, 0, 2_000)
        #expect(gate.locked)
        #expect(chay(gate, 7.9, 2_100, 20_000) == .passing)
    }

    private func nguoi() -> PoseFrame {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        let wld = Array(repeating: P3(0, 0, 0), count: 33)
        func p(_ i: Int, _ u: Double, _ v: Double) { pts[i] = P2(u, v); vis[i] = 0.99 }
        p(Lm.nose, 0.50, 0.10); p(Lm.leftEye, 0.52, 0.09); p(Lm.rightEye, 0.48, 0.09)
        p(Lm.leftShoulder, 0.58, 0.22); p(Lm.rightShoulder, 0.42, 0.22)
        p(Lm.leftHip, 0.55, 0.52); p(Lm.rightHip, 0.45, 0.52)
        p(Lm.leftKnee, 0.55, 0.72); p(Lm.rightKnee, 0.45, 0.72)
        p(Lm.leftAnkle, 0.55, 0.92); p(Lm.rightAnkle, 0.45, 0.92)
        return PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
    }

    @Test("mẫu chỉ đo được mặt mà khung thiếu thân thì mục khung hình lệch hẳn")
    func mauDoBangMatKhungThieuThan() throws {
        let f = nguoi()
        let dung = Measurer.measure(f, try #require(FramingClass.detect(f, 0.5)), 0.5)
        #expect(dung.tamThan == 3)
        // Ảnh mẫu thấy tới chân nhưng cỡ đo bằng mặt; khung camera chỉ thấy tới vai.
        var mau = dung
        mau.scale = nil
        mau.faceScale = 0.10
        var live = mau
        live.tamThan = 0
        #expect(ShotScorer.thieuThan(mau, live))
        #expect((ShotScorer.deviation(mau, live).scaleRatio ?? 0.0) >= 1.0)
        var liveDuThan = live
        liveDuThan.tamThan = 3
        #expect(!ShotScorer.thieuThan(mau, liveDuThan))
    }
}
