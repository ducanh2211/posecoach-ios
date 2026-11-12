import Testing
@testable import PoseDomain

/// Port từ `KTT/MirrorSelfieTest.kt` — TỰ CHỤP QUA GƯƠNG / CAMERA TRƯỚC: lật ở CHỮ, không lật ở phép đo (FOOTGUNS
/// 48, 49, 54, 106).
struct MirrorSelfieTest {

    private let minVis: Float = 0.5

    private func tayTraiGioCao() -> PoseFrame {
        frameOf(
            (Lm.leftShoulder, lm(0.58, 0.35, 0.18, -0.30)),
            (Lm.rightShoulder, lm(0.42, 0.35, -0.18, -0.30)),
            (Lm.leftElbow, lm(0.66, 0.24, 0.34, -0.45)),
            (Lm.rightElbow, lm(0.38, 0.52, -0.22, -0.05)),
            (Lm.leftWrist, lm(0.70, 0.12, 0.42, -0.62)),
            (Lm.rightWrist, lm(0.36, 0.66, -0.24, 0.18)),
            (Lm.leftHip, lm(0.54, 0.62, 0.11, 0.0)),
            (Lm.rightHip, lm(0.46, 0.62, -0.11, 0.0))
        )
    }

    @Test("lật hai lần thì về như cũ")
    func latHaiLan() {
        let a = tayTraiGioCao()
        let b = a.mirrored().mirrored()
        for i in 0..<33 {
            #expect(isClose(b.points[i].x, a.points[i].x, 1e-9))
            #expect(isClose(b.points[i].y, a.points[i].y, 1e-9))
            #expect(abs(b.visibility[i] - a.visibility[i]) <= 1e-6)
        }
    }

    @Test("lật phải HOÁN ĐỔI nhãn trái phải, không chỉ đổi toạ độ")
    func latHoanDoiNhan() {
        let g = tayTraiGioCao().mirrored()
        #expect(g.points[Lm.rightWrist].y < g.points[Lm.leftWrist].y, "Sau khi lật, tay giơ cao phải là tay PHẢI")
        #expect(isClose(g.points[Lm.rightWrist].x, 1.0 - 0.70, 1e-9))
    }

    @Test("lật cũng phải đổi dấu toạ độ THẬT")
    func latDoiDauToaDoThat() {
        let g = tayTraiGioCao().mirrored()
        #expect(isClose(g.world[Lm.rightWrist].x, -0.42, 1e-9))
        #expect(isClose(g.world[Lm.rightWrist].y, -0.62, 1e-9))
    }

    @Test("đo trên đúng khung hình sẽ lưu thì khớp với ảnh mẫu")
    func doTrenKhungSeLuu() {
        let mau = Measurer.measure(tayTraiGioCao(), .half, minVis)
        let khungSeLuu = Measurer.measure(tayTraiGioCao(), .half, minVis)
        let lech = ShotScorer.deviation(mau, khungSeLuu).poseDeg
        #expect((lech ?? 99.0) < 1.0, "Phải khớp, đo được \(String(describing: lech))")
    }

    @Test("lật khung xương trước khi đo sẽ cho ra ảnh NGƯỢC với ảnh mẫu")
    func latTruocKhiDo() {
        let mau = Measurer.measure(tayTraiGioCao(), .half, minVis)
        let daLat = Measurer.measure(tayTraiGioCao().mirrored(), .half, minVis)
        let lech = ShotScorer.deviation(mau, daLat).poseDeg
        #expect((lech ?? 0.0) > 10.0, "Khung đã lật phải KHÁC hẳn ảnh mẫu, đo được \(String(describing: lech))")
    }

    private let band = Band(accept: 5.0, enter: 7.5, unlock: 15.0, actionFloor: 1.0)

    private func cue(
        _ c: Criterion, _ signed: Double,
        tuChup: Bool = false, latGuong: Bool = false, fromDevice: Bool = true,
        hint: PoseHint? = nil, mayNguocChieu: Bool = false, tamTay: Bool = false
    ) throws -> String {
        let s = CriterionStatus(
            criterion: c, state: .failing, deviation: 12.0, signedDelta: signed, band: band,
            poseHint: hint, rollFromDevice: fromDevice, tuChup: tuChup, latGuong: latGuong,
            mayNguocChieu: mayNguocChieu, tamTay: tamTay
        )
        return try #require(CuePresenter().update([s], 0, 0.0)).vi()
    }

    @Test("tự chụp thì BỎ tiền tố bảo mẫu")
    func tuChupBoBaoMau() throws {
        let nguoiKhac = try cue(.yaw, 1.0, tuChup: false)
        let tuChup = try cue(.yaw, 1.0, tuChup: true)
        #expect(nguoiKhac.contains("Bảo mẫu"), "Người khác chụp: \(nguoiKhac)")
        #expect(!tuChup.contains("Bảo mẫu"), "Tự chụp không được có 'Bảo mẫu': \(tuChup)")
    }

    @Test("gương KHÔNG đổi câu về MÁY")
    func guongKhongDoiCauMay() throws {
        for c: Criterion in [.center, .roll] {
            #expect(try cue(c, 1.0, latGuong: false) == cue(c, 1.0, latGuong: true), "Mục \(c) là câu về MÁY")
        }
    }

    @Test("gương ĐỔI CHỮ trái phải trong câu nhắc DÁNG")
    func guongDoiChuDang() throws {
        let hint = PoseHint(.armRaise, .left)
        #expect(try cue(.pose, 1.0, latGuong: false, hint: hint) == "Bảo mẫu giơ tay trái cao hơn")
        #expect(try cue(.pose, 1.0, latGuong: true, hint: hint) == "Bảo mẫu giơ tay phải cao hơn")
    }

    @Test("đổi chữ phải đổi CẢ HAI BÊN, không chỉ một chiều")
    func doiChuCaHaiBen() throws {
        #expect(try cue(.pose, 1.0, latGuong: true, hint: PoseHint(.armLower, .right)) == "Bảo mẫu hạ tay trái xuống")
        let khongBen = PoseHint(.lean)
        #expect(try cue(.pose, 1.0, latGuong: false, hint: khongBen) == cue(.pose, 1.0, latGuong: true, hint: khongBen))
    }

    @Test("gương ĐỔI CHIỀU xoay người của mục hướng mẫu")
    func guongDoiChieuXoay() throws {
        #expect(try cue(.yaw, 30.0, latGuong: false).contains("phải"))
        #expect(try cue(.yaw, 30.0, latGuong: true).contains("trái"))
    }

    @Test("gương KHÔNG đổi các câu theo trục dọc")
    func guongKhongDoiTrucDoc() throws {
        for c: Criterion in [.elevation, .pitch] {
            #expect(try cue(c, 1.0, latGuong: false) == cue(c, 1.0, latGuong: true), "Mục \(c) không được đổi theo gương")
        }
    }

    @Test("chế độ gương bật cả hai cờ")
    func cheDoGuongBatHaiCo() {
        #expect(ShootMode.tuChupGuong.tuChup)
        #expect(ShootMode.tuChupGuong.latGuong)
        #expect(!ShootMode.nguoiKhac.tuChup)
        #expect(!ShootMode.nguoiKhac.latGuong)
    }

    @Test("câu lệch trái phải GIỐNG NHAU ở cả ba chế độ")
    func cauLechTraiPhaiGiongNhau() throws {
        let thuong = try cue(.center, 1.0)
        #expect(try cue(.center, 1.0, latGuong: true) == thuong, "Soi gương phải giống camera thường")
        #expect(try cue(.center, 1.0, latGuong: true, mayNguocChieu: true) == thuong, "Camera trước: hai lần đảo triệt tiêu")
    }

    @Test("câu xoay máy KHÔNG đảo theo camera vì đo bằng cảm biến")
    func cauXoayMayKhongDao() throws {
        #expect(try cue(.roll, 1.0) == cue(.roll, 1.0, latGuong: true, mayNguocChieu: true))
    }

    @Test("tầm tay thì không nói bước chân")
    func tamTayKhongNoiBuoc() throws {
        let xa = try cue(.perspective, 1.0, tamTay: true)
        let gan = try cue(.perspective, -1.0, tamTay: true)
        #expect(!xa.contains("bước") && !xa.contains("Lùi lại"), "Không được nói bước: \(xa)")
        #expect(xa.contains("Duỗi tay"), "Phải nói duỗi tay: \(xa)")
        #expect(gan.contains("Co tay"), "Phải nói co tay: \(gan)")
    }

    @Test("ba chế độ bật đúng các cờ")
    func baCheDoBatDungCo() {
        let k = ShootMode.nguoiKhac
        #expect(!k.tuChup && !k.latGuong && !k.mayNguocChieu && !k.tamTay && !k.camTruoc)
        let g = ShootMode.tuChupGuong
        #expect(g.tuChup && g.latGuong)
        #expect(!g.mayNguocChieu, "Gương KHÔNG đảo chiều dịch máy")
        #expect(!g.tamTay, "Gương không bị chặn ở tầm tay")
        #expect(!g.camTruoc, "Gương dùng camera SAU")
        let c = ShootMode.tuChupCamTruoc
        #expect(c.tuChup && c.latGuong && c.mayNguocChieu && c.tamTay && c.camTruoc)
    }
}
