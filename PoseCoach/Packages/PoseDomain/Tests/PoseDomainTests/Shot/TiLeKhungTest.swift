import Testing
@testable import PoseDomain

/// Port từ `KTT/TiLeKhungTest.kt` — tỉ lệ khung người dùng chọn (19/09/2026).
struct TiLeKhungTest {

    @Test("bốn tỉ lệ tiêu chuẩn và Full lấy theo màn hình")
    func bonTiLeTieuChuanVaFull() {
        #expect(isClose(TiLeKhung.baBon.tiLe(0.46), 0.75, 1e-9))
        #expect(isClose(TiLeKhung.chinMuoiSau.tiLe(0.46), 9.0 / 16.0, 1e-9))
        #expect(isClose(TiLeKhung.vuong.tiLe(0.46), 1.0, 1e-9))
        #expect(isClose(TiLeKhung.full.tiLe(0.46), 0.46, 1e-9))
    }

    @Test("bấm nút đi vòng qua đủ bốn mức rồi quay lại")
    func bamNutDiVong() {
        var t = TiLeKhung.baBon
        var da = [t]
        for _ in 0..<4 { t = t.tiep(); da.append(t) }
        #expect(da.map(\.nhan) == ["3:4", "9:16", "1:1", "Full", "3:4"])
    }

    @Test("cầm máy ngang thì lật tỉ lệ")
    func camMayNgangThiLatTiLe() {
        #expect(isClose(TiLeKhung.theoHuong(0.75, 480, 640), 0.75, 1e-9))
        #expect(isClose(TiLeKhung.theoHuong(0.75, 640, 480), 1 / 0.75, 1e-9))
    }

    @Test("khung 9:16 cắt hai bên, người đứng giữa vẫn ở giữa, người lệch bị đẩy ra mép")
    func khung916CatHaiBen() {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        pts[Lm.nose] = P2(0.5, 0.3); vis[Lm.nose] = 0.99
        pts[Lm.leftShoulder] = P2(0.2, 0.4); vis[Lm.leftShoulder] = 0.99
        let f = PoseFrame(points: pts, visibility: vis, world: Array(repeating: P3(0, 0, 0), count: 33), timestampMs: 0)
        let c = f.croppedToAspect(9.0 / 16.0, 3.0 / 4.0)
        #expect(isClose(c.points[Lm.nose].x, 0.5, 1e-9))
        #expect(isClose(c.points[Lm.nose].y, 0.3, 1e-9))
        // Khung 9:16 hẹp bằng 3/4 khung 3:4: điểm ở 0,2 ra (0,2 − 0,125) / 0,75 = 0,1.
        #expect(isClose(c.points[Lm.leftShoulder].x, 0.1, 1e-9))
    }
}
