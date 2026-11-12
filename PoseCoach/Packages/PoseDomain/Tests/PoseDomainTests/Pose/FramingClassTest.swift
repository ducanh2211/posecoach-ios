import Testing
@testable import PoseDomain

/// Test RIÊNG của iOS (Kotlin không có test tương ứng) — plan Bước 1a yêu cầu.
/// Kỳ vọng tính tay theo `FramingClass.detect` của Kotlin.
struct FramingClassTest {

    private func frame(_ e: [(Int, Double, Double, Float)]) -> PoseFrame {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        for (i, x, y, v) in e { pts[i] = P2(x, y); vis[i] = v }
        return PoseFrame(points: pts, visibility: vis, world: [], timestampMs: 0)
    }

    private let thanTren: [(Int, Double, Double, Float)] = [
        (Lm.nose, 0.5, 0.10, 0.99),
        (Lm.leftShoulder, 0.6, 0.30, 0.99), (Lm.rightShoulder, 0.4, 0.30, 0.99),
        (Lm.leftHip, 0.55, 0.60, 0.99), (Lm.rightHip, 0.45, 0.60, 0.99),
    ]

    /// MediaPipe vẫn trả điểm NGOÀI khung bằng ngoại suy, đôi khi với độ tin cậy cao.
    /// `at` loại theo toạ độ nên cổ chân y = 1,05 coi như không thấy → không thành full.
    @Test("cổ chân ngoại suy ra ngoài khung (y > 1) dù tin cậy cao thì không tính là thấy")
    func coChanNgoaiSuyKhongTinh() {
        let f = frame(thanTren + [(Lm.leftAnkle, 0.55, 1.05, 0.99), (Lm.rightAnkle, 0.45, 1.05, 0.99)])
        #expect(FramingClass.detect(f, 0.5) == .half)
    }

    /// FOOTGUNS 42: người NGỒI thấy rõ bàn chân nhưng thân chỉ tới 65% chiều cao ảnh.
    @Test("người ngồi thấy rõ cổ chân, đáy chỉ 0,65 vẫn là FULL")
    func nguoiNgoiVanLaFull() {
        let f = frame(thanTren + [(Lm.leftAnkle, 0.55, 0.65, 0.99), (Lm.rightAnkle, 0.45, 0.65, 0.99)])
        #expect(FramingClass.detect(f, 0.5) == .full)
    }

    /// FOOTGUNS 14: ảnh nửa người, điểm thấp nhất là hông ở 0,90 — lọt dải "toàn thân" của bản iOS cũ.
    @Test("nửa người đáy 0,90 không thấy gối/cổ chân là HALF, không phải FULL")
    func nuaNguoiDay090LaHalf() {
        let f = frame([
            (Lm.nose, 0.5, 0.30, 0.99),
            (Lm.leftShoulder, 0.6, 0.55, 0.99), (Lm.rightShoulder, 0.4, 0.55, 0.99),
            (Lm.leftHip, 0.55, 0.90, 0.99), (Lm.rightHip, 0.45, 0.90, 0.99),
        ])
        #expect(FramingClass.detect(f, 0.5) == .half)
    }
}
