import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/RollCriterionTest.kt` — MỤC 8 NGHIÊNG NGANG.
///
/// Ảnh mẫu là ảnh tĩnh, không có cảm biến — lấy cảm biến cho khung camera rồi trừ cho số suy từ ảnh mẫu là phá
/// bất biến số 1. Cảm biến chỉ dùng để chọn NHẮC AI. Bài `mauNgaNguoiGiongAnhMau` đỏ ngay nếu ai đó đổi phép
/// chấm sang dùng cảm biến.
struct RollCriterionTest {

    private let minVis: Float = 0.5

    private func lm(_ u: Double, _ v: Double, _ wx: Double, _ wy: Double, _ wz: Double) -> (P2, Float, P3) {
        (P2(u, v), 0.99, P3(wx, wy, wz))
    }

    private func frameOf(_ e: (Int, (P2, Float, P3))...) -> PoseFrame {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        var wld = Array(repeating: P3(0, 0, 0), count: 33)
        for (i, t) in e { pts[i] = t.0; vis[i] = t.1; wld[i] = t.2 }
        return PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
    }

    /// Người đứng, xoay nghiêng `tiltDeg` độ quanh tâm khung. Dương = nghiêng sang phải.
    private func nguoi(_ tiltDeg: Double) -> PoseFrame {
        let r = toRadians(tiltDeg)
        func rot(_ x: Double, _ y: Double) -> (Double, Double) {
            let dx = x - 0.5, dy = y - 0.5
            return (0.5 + (dx * cos(r) - dy * sin(r)), 0.5 + (dx * sin(r) + dy * cos(r)))
        }
        func p(_ x: Double, _ y: Double, _ wx: Double, _ wy: Double) -> (P2, Float, P3) {
            let (u, v) = rot(x, y)
            return lm(u, v, wx, wy, 0.0)
        }
        // ⚠️ MẪU QUAY MẶT VÀO MÁY: vai TRÁI của họ nằm bên PHẢI ảnh (MediaPipe đặt tên theo GIẢI PHẪU).
        return frameOf(
            (Lm.leftShoulder, p(0.58, 0.30, 0.18, -0.30)),
            (Lm.rightShoulder, p(0.42, 0.30, -0.18, -0.30)),
            (Lm.leftHip, p(0.54, 0.58, 0.11, 0.0)),
            (Lm.rightHip, p(0.46, 0.58, -0.11, 0.0)),
            (Lm.leftKnee, p(0.54, 0.76, 0.11, 0.42)),
            (Lm.rightKnee, p(0.46, 0.76, -0.11, 0.42)),
            (Lm.leftAnkle, p(0.54, 0.93, 0.11, 0.85)),
            (Lm.rightAnkle, p(0.46, 0.93, -0.11, 0.85))
        )
    }

    private func roll(_ f: PoseFrame, _ src: RollSource) -> Double? {
        Measurer.measure(f, .full, minVis).rollDeg[src]
    }

    // MARK: - Phép đo

    @Test("người đứng thẳng thì góc nghiêng bằng không")
    func dungThangBangKhong() throws {
        #expect(isClose(try #require(roll(nguoi(0.0), .spine)), 0.0, 0.5))
        #expect(isClose(try #require(roll(nguoi(0.0), .shoulders)), 0.0, 0.5))
    }

    @Test("nghiêng 15 độ thì đo ra 15 độ")
    func nghieng15() throws {
        #expect(isClose(try #require(roll(nguoi(15.0), .spine)), 15.0, 1.0))
        #expect(isClose(try #require(roll(nguoi(-20.0), .spine)), -20.0, 1.0))
    }

    @Test("hai đường đo cho ra kết quả gần bằng nhau")
    func haiDuongGanBang() throws {
        for t in [-25.0, -10.0, 0.0, 10.0, 25.0] {
            let a = try #require(roll(nguoi(t), .spine))
            let b = try #require(roll(nguoi(t), .shoulders))
            #expect(abs(a - b) < 3.0, "nghiêng \(t)°: trục thân \(a)° so với đường vai \(b)°")
        }
    }

    /// ⚠️ Lỗi đã xảy ra thật: đường vai ra ~178° cho người đứng thẳng vì `leftShoulder` nằm bên PHẢI ảnh.
    @Test("người quay mặt vào máy thì đường vai KHÔNG được ra 180 độ")
    func duongVaiKhong180() throws {
        let v = try #require(roll(nguoi(0.0), .shoulders))
        #expect(abs(v) < 5.0, "Người đứng thẳng phải cho ~0°, nhận được \(v)°")
    }

    @Test("mẫu quay nghiêng người thì BỎ đường đo bằng vai")
    func quayNghiengBoVai() {
        // Hai vai chồng lên nhau trên ảnh: sai vài điểm ảnh là góc nhảy hàng chục độ.
        let quayNghieng = frameOf(
            (Lm.leftShoulder, lm(0.500, 0.30, -0.18, -0.30, 0.0)),
            (Lm.rightShoulder, lm(0.505, 0.30, 0.18, -0.30, 0.0)),
            (Lm.leftHip, lm(0.500, 0.58, -0.11, 0.0, 0.0)),
            (Lm.rightHip, lm(0.505, 0.58, 0.11, 0.0, 0.0))
        )
        let m = Measurer.measure(quayNghieng, .full, minVis)
        #expect(m.rollDeg[.shoulders] == nil)
        // Trục thân vẫn dài nên vẫn đo được — đó là lý do nó là đường ưu tiên.
        #expect(m.rollDeg[.spine] != nil)
    }

    // MARK: - ⚠️ Ca vỡ nếu ai đó chuyển sang chấm bằng cảm biến

    @Test("mẫu ngả người giống hệt ảnh mẫu thì phải ĐẠT")
    func mauNgaNguoiGiongAnhMau() throws {
        let tpl = Measurer.measure(nguoi(15.0), .full, minVis)
        let live = Measurer.measure(nguoi(15.0), .full, minVis)
        let dev = try #require(ShotScorer.deviation(tpl, live).rollDeg, "Phải đo được, không được trả nil")
        #expect(dev < 1.0, "Hai bên giống hệt nhau thì lệch phải ~0, đo được \(dev)")
    }

    @Test("ảnh mẫu thẳng mà khung hình nghiêng thì báo lệch đúng số")
    func anhMauThangKhungNghieng() throws {
        let tpl = Measurer.measure(nguoi(0.0), .full, minVis)
        let live = Measurer.measure(nguoi(12.0), .full, minVis)
        #expect(isClose(try #require(ShotScorer.deviation(tpl, live).rollDeg), 12.0, 1.5))
    }

    @Test("chỉ so khi hai bên cùng đường đo")
    func chiSoCungDuong() {
        var tpl = Measurer.measure(nguoi(0.0), .full, minVis)
        tpl.rollDeg = [.spine: 0.0]
        var live = Measurer.measure(nguoi(0.0), .full, minVis)
        live.rollDeg = [.shoulders: 0.0]
        #expect(ShotScorer.deviation(tpl, live).rollDeg == nil)
    }

    // MARK: - Cảm biến chọn NHẮC AI

    private let band = Band(accept: 5.0, enter: 7.5, unlock: 15.0, actionFloor: 2.0)

    private func cue(_ signed: Double, fromDevice: Bool) -> String? {
        let s = CriterionStatus(
            criterion: .roll, state: .failing, deviation: 12.0, signedDelta: signed, band: band,
            rollFromDevice: fromDevice
        )
        return CuePresenter().update([s], 0, 0.0)?.vi()
    }

    @Test("máy đang vẹo thì nhắc NGƯỜI CẦM MÁY")
    func mayVeoNhacNguoiCamMay() throws {
        let t = try #require(cue(12.0, fromDevice: true))
        #expect(t.contains("máy"), "Phải nói về máy, nhận được: \(t)")
        #expect(!t.contains("mẫu"), "Không được đổ cho mẫu, nhận được: \(t)")
    }

    /// ⚠️ ĐỔI CHỦ Ý 14/09/2026: nhãn "Máy nghiêng" mà câu lại bảo mẫu — người dùng không biết làm gì.
    @Test("dù máy đang thẳng vẫn nói về MÁY, không đổ cho mẫu")
    func mayThangVanNoiVeMay() throws {
        let t = try #require(cue(12.0, fromDevice: false))
        #expect(t.contains("máy"), "Phải nói về máy, nhận được: \(t)")
        #expect(!t.contains("mẫu"), "Không được đổ cho mẫu, nhận được: \(t)")
    }

    @Test("hai chiều nghiêng cho ra hai câu khác nhau")
    func haiChieuHaiCau() {
        #expect(cue(12.0, fromDevice: true) != cue(-12.0, fromDevice: true))
        #expect(cue(12.0, fromDevice: false) != cue(-12.0, fromDevice: false))
    }
}
