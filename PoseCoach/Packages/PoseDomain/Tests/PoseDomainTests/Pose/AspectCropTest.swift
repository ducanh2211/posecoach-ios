import Testing
@testable import PoseDomain

/// Port từ `KTT/AspectCropTest.kt`.
///
/// ⚠️ KHUNG CAMERA PHẢI THEO TỈ LỆ ẢNH MẪU — PO chốt từ đầu dự án.
/// Toạ độ khớp là tỉ lệ so với khung chứa nó: cùng một người đứng cùng một chỗ, chụp bằng khung 4:3
/// và 9:16 ra hai bộ số khác nhau. Không đưa về chung một tỉ lệ thì mục lệch trái/phải và máy cao/thấp
/// đang so hai thứ không so được.
struct AspectCropTest {

    private func lm(_ u: Double, _ v: Double) -> (P2, Float, P3) { (P2(u, v), 0.99, P3(0, 0, 0)) }

    private func frameOf(_ e: (Int, (P2, Float, P3))...) -> PoseFrame {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        var wld = Array(repeating: P3(0, 0, 0), count: 33)
        for (i, t) in e { pts[i] = t.0; vis[i] = t.1; wld[i] = t.2 }
        return PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
    }

    private let frame43 = 4.0 / 3.0     // khung cảm biến
    private let ratio916 = 9.0 / 16.0   // ảnh mẫu dọc
    private let ratio11 = 1.0           // ảnh mẫu vuông

    @Test("cùng tỉ lệ thì không đổi gì")
    func cungTiLeThiKhongDoiGi() {
        let f = frameOf((Lm.nose, lm(0.30, 0.40)))
        let c = f.croppedToAspect(frame43, frame43)
        #expect(isClose(c.points[Lm.nose].x, 0.30, 1e-9))
        #expect(isClose(c.points[Lm.nose].y, 0.40, 1e-9))
    }

    @Test("ảnh mẫu DỌC hơn thì cắt hai bên, trục dọc giữ nguyên")
    func anhMauDocHonThiCatHaiBen() {
        // 9:16 hẹp hơn 4:3 → phần giữ lại rộng (9/16)/(4/3) = 0,4219 bề ngang.
        let f = frameOf((Lm.nose, lm(0.50, 0.40)))
        let c = f.croppedToAspect(ratio916, frame43)
        #expect(isClose(c.points[Lm.nose].x, 0.50, 1e-9), "Điểm ở giữa vẫn ở giữa")
        #expect(isClose(c.points[Lm.nose].y, 0.40, 1e-9), "Trục dọc không đụng tới")
    }

    @Test("điểm ngoài phần cắt bị LOẠI, đúng như khi nằm ngoài khung ảnh")
    func diemNgoaiPhanCatBiLoai() {
        // x = 0,10 nằm ngoài dải giữ lại của khung 9:16 (khoảng 0,289..0,711).
        let f = frameOf((Lm.nose, lm(0.10, 0.40)), (Lm.leftEye, lm(0.50, 0.40)))
        let c = f.croppedToAspect(ratio916, frame43)
        #expect(c.at(Lm.nose, 0.5) == nil, "Điểm ngoài khung phải bị loại")
        #expect(c.at(Lm.leftEye, 0.5) != nil, "Điểm trong khung vẫn còn")
    }

    @Test("ảnh mẫu VUÔNG thì mép khung dịch vào đúng chỗ")
    func anhMauVuongThiMepKhungDichVao() {
        // 1:1 hẹp hơn 4:3 → giữ lại 0,75 bề ngang, mép trái ở 0,125.
        let f = frameOf((Lm.nose, lm(0.125, 0.50)))
        let c = f.croppedToAspect(ratio11, frame43)
        #expect(isClose(c.points[Lm.nose].x, 0.0, 1e-9), "Mép trái của phần cắt phải thành 0")
    }

    @Test("ảnh mẫu NGANG hơn thì cắt trên dưới")
    func anhMauNgangHonThiCatTrenDuoi() {
        let f = frameOf((Lm.nose, lm(0.40, 0.50)))
        let c = f.croppedToAspect(16.0 / 9.0, frame43)
        #expect(isClose(c.points[Lm.nose].x, 0.40, 1e-9), "Trục ngang không đụng tới")
        #expect(isClose(c.points[Lm.nose].y, 0.50, 1e-9), "Điểm giữa vẫn ở giữa")
    }

    /// Ảnh mẫu 9:16 đọc trên khung cảm biến 4:3: phần giữ lại chỉ rộng 42% bề ngang khung. Người đứng ở
    /// `x = 0,62` của khung cảm biến thật ra đang ở `x = 0,78` của khung sẽ chụp — lệch 0,16, gấp hơn ba lần
    /// ngưỡng đạt của mục lệch trái/phải (0,05). Không cắt thì mục đó không bao giờ khớp được.
    @Test("không cắt thì lệch gấp ba lần ngưỡng đạt")
    func khongCatThiLechGapBaLanNguongDat() {
        let f = frameOf((Lm.nose, lm(0.62, 0.50)))
        let c = f.croppedToAspect(ratio916, frame43)
        let lech = abs(c.points[Lm.nose].x - f.points[Lm.nose].x)
        #expect(isClose(lech, 0.164, 0.01), "Lệch phải khoảng 0,16")
        #expect(lech > 0.05 * 3, "Phải vượt xa ngưỡng đạt 0,05, đo được \(lech)")
    }
}
