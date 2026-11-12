import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/DoanKieuTrenTest.kt` — đoán kiểu chụp từ trên cao bằng góc mở (GeoCalib)
/// + đầu so với chân (MediaPipe).
struct DoanKieuTrenTest {

    @Test("góc mở rất rộng là góc rộng 0.5x, tức đứng gần")
    func gocMoRatRong() {
        #expect(DoanKieuTren.doan(90.0, nil) == .gan)
    }

    @Test("đầu to hơn chân hẳn là đứng gần")
    func dauToHonChan() {
        #expect(DoanKieuTren.doan(42.0, 0.55) == .gan)
    }

    @Test("đầu gần bằng chân là từ xa rồi zoom")
    func dauGanBangChan() {
        #expect(DoanKieuTren.doan(36.0, 0.05) == .xaZoom)
    }

    @Test("vùng giữa hoặc thiếu dữ liệu thì hỏi, không đoán bừa")
    func vungGiuaThiHoi() {
        #expect(DoanKieuTren.doan(42.0, 0.40) == nil)
        #expect(DoanKieuTren.doan(42.0, nil) == nil)
        #expect(DoanKieuTren.doan(nil, nil) == nil)
    }

    @Test("tỉ lệ tai/chân chia đúng cho cỡ ngoài đời")
    func tiLeTaiChan() throws {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        var wld = Array(repeating: P3(0, 0, 0), count: 33)
        func dat(_ i: Int, _ x: Double, _ y: Double, _ wx: Double) { pts[i] = P2(x, y); vis[i] = 0.99; wld[i] = P3(wx, 0, 0) }
        // Tai cách nhau 0,15 m, trên ảnh 0,20 bề ngang; cổ chân cách nhau 0,15 m, trên ảnh 0,10.
        dat(Lm.leftEar, 0.60, 0.2, 0.075); dat(Lm.rightEar, 0.40, 0.2, -0.075)
        dat(Lm.leftAnkle, 0.55, 0.9, 0.075); dat(Lm.rightAnkle, 0.45, 0.9, -0.075)
        let f = PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
        let r = try #require(DoanKieuTren.tiLeTaiChan(f, 1000, 1000))
        #expect(isClose(r, log(2.0), 1e-9))
    }
}
