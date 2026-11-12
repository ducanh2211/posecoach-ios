import Testing
@testable import PoseDomain

/// Port từ `KTT/ShotScorerTest.kt` — phép chấm điểm xếp hạng.
///
/// Bài quan trọng nhất: `mucKhongDoDuocBiBoRa` — luật số 4 của dự án, loại lỗi cực khó phát hiện bằng mắt:
/// app vẫn chạy, vẫn ra 5 tấm, chỉ là chọn sai tấm.
struct ShotScorerTest {

    private func m(
        scale: Double? = 0.60,
        centerX: Double? = 0.50,
        elevationDeg: Double? = 0.0,
        yawDeg: Double? = 0.0,
        faceYawDeg: Double? = nil,
        eyesOpen: Double? = nil,
        pitchCue: [PitchSource: Double] = [.legs: 0.0],
        perspectiveIndex: [PerspectiveSource: Double] = [.torsoAnkle: 0.0],
        pose: [PoseGroup: [Double]] = [.spine: [0.0]]
    ) -> PoseMeasurement {
        PoseMeasurement(
            framing: .full,
            scale: scale,
            centerX: centerX,
            tiltDeg: 0.0,
            elevationDeg: elevationDeg,
            yawDeg: yawDeg,
            faceYawDeg: faceYawDeg,
            eyesOpen: eyesOpen,
            anchorHeightMeters: 1.60,
            rollDeg: [:],
            pitchCue: pitchCue,
            perspectiveIndex: perspectiveIndex,
            poseAngles: pose
        )
    }

    /// Hồ sơ ảnh mẫu có ĐỦ 5 mục hình học. Hậu kỳ tắt để bài kiểm chỉ soi phần hình học.
    private func profile(_ m: PoseMeasurement? = nil) -> TemplateProfile {
        TemplateProfile(
            framing: .full,
            measurement: m ?? self.m(),
            active: [.yaw, .scale, .center, .elevation, .pitch, .pose],
            skipped: [:],
            poseGroups: FramingClass.full.poseGroups
        )
    }

    private func scoreOf(_ tpl: PoseMeasurement, _ cand: PoseMeasurement, _ post: PostQuality? = nil) -> ShotScore {
        ShotScorer.score(profile(tpl), cand, .selection, post)
    }

    // MARK: - Chênh lệch góc — bẫy vòng qua ±180°

    /// Đoạn video của dự án chạy qua vùng này: góc nhảy từ −171° sang +176°. Trừ thẳng ra 347°, thực tế chỉ
    /// lệch 13°.
    @Test("chênh góc luôn lấy đường ngắn nhất trên vòng tròn")
    func chenhGocDuongNganNhat() {
        #expect(isClose(ShotScorer.angleDiff(-171.0, 176.0), 13.0, 1e-9))
        #expect(isClose(ShotScorer.angleDiff(176.0, -171.0), 13.0, 1e-9))
        #expect(isClose(ShotScorer.angleDiff(180.0, -180.0), 0.0, 1e-9))
        #expect(isClose(ShotScorer.angleDiff(0.0, 180.0), 180.0, 1e-9))
        #expect(isClose(ShotScorer.angleDiff(5.0, -5.0), 10.0, 1e-9))
    }

    // MARK: - Điểm số

    @Test("khớp hoàn toàn thì được điểm tuyệt đối")
    func khopHoanToan() {
        #expect(isClose(scoreOf(m(), m()).total, 100.0, 1e-9))
    }

    @Test("lệch càng nhiều điểm càng thấp")
    func lechCangNhieu() {
        let tpl = m()
        let gan = scoreOf(tpl, m(yawDeg: 5.0)).total
        let xa = scoreOf(tpl, m(yawDeg: 25.0)).total
        #expect(gan > xa, "Lệch 5° phải hơn điểm lệch 25°")
    }

    /// LUẬT SỐ 4: đại lượng không đo được thì bỏ ra và chia lại trọng số, KHÔNG trừ điểm.
    @Test("mục không đo được bị bỏ ra chứ không bị trừ điểm")
    func mucKhongDoDuocBiBoRa() {
        let thieuMoc = scoreOf(m(), m(elevationDeg: nil))
        #expect(isClose(thieuMoc.total, 100.0, 1e-9))
        #expect(thieuMoc.perCriterion["cao_thap"] == nil, "Mục không đo được không được có mặt")
    }

    @Test("mất mốc thì tổng trọng số dùng phải giảm")
    func matMocTrongSoGiam() {
        let tpl = m()
        let du = scoreOf(tpl, m())
        let thieu = scoreOf(tpl, m(elevationDeg: nil, yawDeg: nil))
        #expect(thieu.weightUsed < du.weightUsed)
    }

    @Test("đo ít mục quá thì bị đánh dấu là thiếu căn cứ")
    func doItMucThieuCanCu() {
        let tpl = m()
        let duMuc = scoreOf(tpl, m())
        let thieuMuc = scoreOf(tpl, m(centerX: nil, elevationDeg: nil, yawDeg: nil, pitchCue: [:], pose: [:]))
        #expect(duMuc.trustworthy)
        #expect(!thieuMuc.trustworthy, "Chỉ đo được 1 mục thì không đủ căn cứ tin")
    }

    @Test("không đo được gì cả thì điểm bằng không")
    func khongDoDuocGi() {
        let trong = m(scale: nil, centerX: nil, elevationDeg: nil, yawDeg: nil, pitchCue: [:], pose: [:])
        let s = scoreOf(m(), trong)
        #expect(isClose(s.total, 0.0, 1e-9))
        #expect(isClose(s.weightUsed, 0.0, 1e-9))
    }

    // MARK: - Độ lệch từng mục

    /// Xa/gần tính theo TỈ LỆ TƯƠNG ĐỐI: 0,05 trên mốc ~0,15 là 33%, trên mốc ~0,85 chỉ 6%.
    @Test("chênh xa/gần tính theo tỉ lệ tương đối")
    func chenhXaGanTiLe() throws {
        let d = ShotScorer.deviation(m(scale: 0.80), m(scale: 0.60))
        #expect(isClose(try #require(d.scaleRatio), 0.25, 1e-9))

        let dNho = ShotScorer.deviation(m(scale: 0.20), m(scale: 0.15))
        #expect(isClose(try #require(dNho.scaleRatio), 0.25, 1e-9))
    }

    @Test("một bên không đo được thì độ lệch là không xác định")
    func motBenKhongDoDuoc() {
        #expect(ShotScorer.deviation(m(centerX: nil), m(centerX: 0.5)).centerX == nil)
    }

    /// Ghép "tới đâu hay tới đó" khi số khớp hai bên khác nhau sẽ so nhầm khớp — ra số vô nghĩa mà trông hợp lệ.
    @Test("nhóm khớp lệch số lượng thì bỏ qua chứ không ghép bừa")
    func nhomKhopLechSoLuong() {
        let tpl = m(pose: [.arms: [10.0, 20.0, 30.0, 40.0]])
        let cand = m(pose: [.arms: [10.0, 20.0]])
        #expect(ShotScorer.deviation(tpl, cand).poseDeg == nil)
    }

    @Test("chênh dáng lấy trung bình các khớp so được")
    func chenhDangTrungBinh() throws {
        let tpl = m(pose: [.arms: [0.0, 0.0]])
        let cand = m(pose: [.arms: [10.0, 30.0]])
        #expect(isClose(try #require(ShotScorer.deviation(tpl, cand).poseDeg), 20.0, 1e-9))
    }

    // MARK: - Hồ sơ ảnh mẫu quyết định mục nào được chấm

    /// ⚠️ Bài quan trọng nhất của phần hồ sơ. Mục không thuộc hồ sơ thì BỎ QUA dù khung hình đo được.
    @Test("mục không thuộc hồ sơ thì không chấm dù khung hình đo được")
    func mucKhongThuocHoSo() {
        let chiCoHuong = TemplateProfile(
            framing: .head,
            measurement: m(),
            active: [.yaw],
            skipped: [:],
            poseGroups: []
        )
        let s = ShotScorer.score(chiCoHuong, m(scale: 0.10), .selection)

        // "huong" có mặt để hiển thị, nhưng là HỆ SỐ NHÂN — lệch nặng xa/gần vẫn 100 điểm.
        #expect(Set(s.perCriterion.keys) == ["huong"])
        #expect(isClose(s.total, 100.0, 1e-9))
    }

    /// Hậu kỳ KHÔNG đưa vào hướng dẫn realtime — bảo người dùng "cho nét hơn" là vô nghĩa.
    @Test("mục hậu kỳ chỉ chấm khi chọn ảnh, không chấm khi hướng dẫn")
    func mucHauKyChiKhiChonAnh() {
        let p = TemplateProfile(
            framing: .full,
            measurement: m(),
            active: [.yaw, .sharpness, .crop],
            skipped: [:],
            poseGroups: []
        )
        let post = PostQuality(sharpness: 0.2, crop: 0.0)

        let huongDan = ShotScorer.score(p, m(), .guidance, post)
        let chonAnh = ShotScorer.score(p, m(), .selection, post)

        #expect(Set(huongDan.perCriterion.keys) == ["huong"])
        #expect(Set(chonAnh.perCriterion.keys) == ["huong", "do_net", "cat_cut"])
        #expect(chonAnh.total < huongDan.total, "Hậu kỳ kém phải kéo điểm xuống ở bước chọn ảnh")
    }

    @Test("cắt ngang khớp làm giảm điểm ở bước chọn ảnh")
    func catNgangKhop() {
        let p = profile()
        let khongCat = ShotScorer.score(p, m(), .selection, PostQuality(sharpness: 1.0, crop: 1.0))
        // Hồ sơ mặc định không bật CROP nên phải bật riêng để so.
        var coCrop = p
        coCrop.active.insert(.crop)
        let coCat = ShotScorer.score(coCrop, m(), .selection, PostQuality(sharpness: 1.0, crop: 0.0))
        #expect(coCat.total < khongCat.total)
    }

    // MARK: - Trọng số đổi theo lớp khung hình

    @Test("ảnh chân dung coi trọng xa/gần hơn ảnh toàn thân")
    func chanDungCoiTrongXaGan() {
        let toanThan = Criterion.scale.weightFor(.full)
        let chanDung = Criterion.scale.weightFor(.chest)
        #expect(chanDung > toanThan, "Chân dung phải nặng hơn: \(chanDung) vs \(toanThan)")
    }

    @Test("ảnh toàn thân coi trọng hướng mẫu hơn ảnh chân dung")
    func toanThanCoiTrongHuong() {
        #expect(Criterion.yaw.weightFor(.full) > Criterion.yaw.weightFor(.head))
    }

    @Test("tổng trọng số hình học không đổi giữa các lớp khung hình")
    func tongTrongSoHinhHoc() {
        let hinhHoc: [Criterion] = [.yaw, .scale, .center, .elevation, .pitch]
        for f in FramingClass.allCases {
            let tong = hinhHoc.reduce(0.0) { $0 + $1.weightFor(f) }
            #expect(isClose(tong, Criterion.geometryTotal, 1e-9), "Lớp \(f) cộng ra \(tong)")
        }
    }

    @Test("lệch ngửa/chúc làm giảm điểm")
    func lechNguaChuc() {
        let tpl = m()
        let khop = scoreOf(tpl, m(pitchCue: [.legs: 0.0])).total
        let lech = scoreOf(tpl, m(pitchCue: [.legs: 0.30])).total
        #expect(lech < khop, "Lệch phối cảnh phải mất điểm: \(lech) vs \(khop)")
    }

    // MARK: - Hướng mẫu là HỆ SỐ CHẶN, không phải một mục cộng trung bình

    /// ⚠️ QUYẾT ĐỊNH SẢN PHẨM: mẫu quay sai hướng thì tấm ảnh đã sai rồi. Trước đây vẫn được 49/100.
    @Test("sai hướng hoàn toàn thì điểm phải rất thấp dù mọi thứ khác chuẩn")
    func saiHuongHoanToan() {
        let s = scoreOf(m(yawDeg: 180.0), m(yawDeg: 0.0))
        #expect(s.total < 20.0, "Sai hướng mà vẫn \(s.total) điểm là quá cao")
    }

    @Test("đúng hướng thì không bị phạt gì")
    func dungHuong() {
        let dung = scoreOf(m(yawDeg: 180.0), m(yawDeg: 180.0))
        #expect(isClose(dung.directionFactor, 1.0, 1e-9))
        #expect(isClose(dung.total, 100.0, 1e-9))
    }

    /// Vẫn phải xếp hạng được giữa các khung CÙNG sai hướng, nếu không app giữ bừa 5 tấm.
    @Test("các khung cùng sai hướng vẫn xếp hạng được với nhau")
    func cungSaiHuongVanXepHang() {
        let tpl = m(yawDeg: 180.0)
        let gan = scoreOf(tpl, m(centerX: 0.50, yawDeg: 0.0)).total
        let xa = scoreOf(tpl, m(centerX: 0.75, yawDeg: 0.0)).total
        #expect(gan > xa, "Cả hai cùng sai hướng nhưng vẫn phải phân biệt được")
        #expect(xa > 0.0)
    }

    /// Không đo được hướng KHÁC với sai hướng — luật số 4.
    @Test("không đo được hướng thì không bị phạt")
    func khongDoDuocHuong() {
        let s = scoreOf(m(yawDeg: nil), m(yawDeg: 0.0))
        #expect(isClose(s.directionFactor, 1.0, 1e-9))
    }

    // MARK: - ⚠️ Điểm số phải ăn khớp với dấu tích (12/09/2026)

    /// Video test thật: 7/7 tích xanh cho 73%, khung khác 4/6 tích lại cho 84%. `accept` và `reference` là hai
    /// thang rời nhau (FOOTGUNS 67).
    @Test("mọi mục đạt sát ngưỡng thì điểm vẫn phải từ 90 trở lên")
    func satNguongVanTu90() throws {
        let tpl = m()
        let accepts: [Criterion: Double] = [.scale: 0.10, .center: 0.05, .elevation: 6.0, .pose: 15.0]
        let satNguong = m(
            scale: try #require(tpl.scale) * 1.10,
            centerX: try #require(tpl.centerX) + 0.05,
            elevationDeg: try #require(tpl.elevationDeg) + 6.0,
            pose: [.spine: [15.0]]
        )
        let s = ShotScorer.score(profile(tpl), satNguong, .selection, acceptOf: { accepts[$0] })
        #expect(s.total >= 90.0, "Mọi mục vừa chạm ngưỡng đạt mà chỉ được \(s.total)")
    }

    @Test("trong vùng đạt vẫn còn phân biệt được khung nào đẹp hơn")
    func trongVungDatVanPhanBiet() throws {
        let tpl = m()
        let cx = try #require(tpl.centerX)
        let accepts: [Criterion: Double] = [.center: 0.05]
        func diem(_ lech: Double) -> Double {
            ShotScorer.score(profile(tpl), m(centerX: cx + lech), .selection, acceptOf: { accepts[$0] }).total
        }
        #expect(diem(0.0) > diem(0.049), "khớp hẳn phải hơn đạt sát ngưỡng")
    }
}
