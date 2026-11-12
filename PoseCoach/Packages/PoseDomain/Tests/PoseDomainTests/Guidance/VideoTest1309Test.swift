import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/VideoTest1309Test.kt` — những gì video test 13/09/2026 lộ ra: nhãn góc máy trong tên file, mốc cỡ
/// mẫu dự phòng bằng khung mặt (FOOTGUNS 84), câu "nâng máy + chúc máy" gộp một động tác (FOOTGUNS 73).
struct VideoTest1309Test {

    private let minVis: Float = 0.5

    @Test("nhãn góc đọc đúng ba mức")
    func nhanGocBaMuc() throws {
        #expect(isClose(try #require(MediaLibrary.gocMayTheoNhan("selfie-tren-tai-nghe-nhin-nghieng")), -35.0, 1e-9))
        #expect(isClose(try #require(MediaLibrary.gocMayTheoNhan("selfie-ngang-keo-co-ao")), 0.0, 1e-9))
        #expect(isClose(try #require(MediaLibrary.gocMayTheoNhan("selfie-duoi-nen-troi-xanh")), 25.0, 1e-9))
        #expect(isClose(try #require(MediaLibrary.gocMayTheoNhan("tren-kinh-ram")), -35.0, 1e-9))
    }

    @Test("không có nhãn thì trả nil, không đoán")
    func khongNhanTraNil() {
        #expect(MediaLibrary.gocMayTheoNhan("nam-nen-trang-tay-tui") == nil)
        #expect(MediaLibrary.gocMayTheoNhan("selfie-keo-co-ao") == nil)
        #expect(MediaLibrary.gocMayTheoNhan("mirror-phong-thay-do") == nil)
    }

    @Test("tên hiển thị bỏ cả tiền tố nhóm lẫn nhãn góc")
    func tenHienThi() {
        let t = MediaLibrary.Template(URL(fileURLWithPath: "selfie-tren-tai-nghe-nhin-nghieng.jpg"))
        #expect(t.displayName == "tai nghe nhin nghieng")
        #expect(t.kind == .selfie)
    }

    @Test("nhãn góc giúp ảnh chân dung có mục góc máy")
    func nhanGocChanDung() throws {
        let chanDung = frameOf(
            (Lm.nose, lm(0.50, 0.40)),
            (Lm.leftEye, lm(0.56, 0.34)),
            (Lm.rightEye, lm(0.44, 0.34)),
            (Lm.leftShoulder, lm(0.78, 0.80, 0.18, -0.45)),
            (Lm.rightShoulder, lm(0.22, 0.80, -0.18, -0.45))
        )
        #expect(!TemplateProfile.from(chanDung, .chest, minVis).active.contains(.pitch))
        let coNhan = TemplateProfile.from(chanDung, .chest, minVis, gocMayNhan: -35.0)
        #expect(coNhan.active.contains(.pitch), "Có nhãn thì phải chấm được mục ngửa/chúc")
        #expect(isClose(try #require(coNhan.measurement.pitchCue[.gocMay]), -35.0, 1e-9))
    }

    @Test("ảnh mẫu mất mốc chính thì so cỡ mẫu bằng khung mặt")
    func matMocChinhDungKhungMat() throws {
        var tpl = Measurer.measure(frameOf(), .full, minVis)
        tpl.scale = nil
        tpl.faceScale = 0.20
        var live = Measurer.measure(frameOf(), .full, minVis)
        live.scale = 0.60
        live.faceScale = 0.10
        let d = try #require(ShotScorer.deviation(tpl, live).scaleRatio, "Mốc chính hỏng thì phải lùi về khung mặt")
        #expect(isClose(d, 0.5, 1e-9))
    }

    @Test("ảnh mẫu có mốc chính thì KHÔNG lùi về khung mặt dù khung hình thiếu")
    func coMocChinhKhongLui() {
        var tpl = Measurer.measure(frameOf(), .full, minVis)
        tpl.scale = 0.70
        tpl.faceScale = 0.20
        var live = Measurer.measure(frameOf(), .full, minVis)
        live.scale = nil
        live.faceScale = 0.20
        #expect(ShotScorer.deviation(tpl, live).scaleRatio == nil)
    }

    @Test("chụp từ trên cao thân co rút thì bỏ đường trục thân")
    func thanCoRutBoTrucThan() {
        let coRut = frameOf(
            (Lm.leftShoulder, lm(0.70, 0.40)),
            (Lm.rightShoulder, lm(0.30, 0.40)),
            (Lm.leftHip, lm(0.58, 0.55)),
            (Lm.rightHip, lm(0.40, 0.55))
        )
        let m = Measurer.measure(coRut, .full, minVis)
        #expect(m.rollDeg[.spine] == nil, "Thân co rút thì trục thân vô nghĩa")
        #expect(m.rollDeg[.shoulders] != nil, "Đường vai vẫn phải còn")
    }

    @Test("người đứng bình thường vẫn giữ đường trục thân")
    func dungBinhThuongGiuTrucThan() {
        let binhThuong = frameOf(
            (Lm.leftShoulder, lm(0.58, 0.25)),
            (Lm.rightShoulder, lm(0.42, 0.25)),
            (Lm.leftHip, lm(0.55, 0.55)),
            (Lm.rightHip, lm(0.45, 0.55))
        )
        #expect(Measurer.measure(binhThuong, .full, minVis).rollDeg[.spine] != nil)
    }

    private let band = Band(accept: 10.0, enter: 15.0, unlock: 30.0, actionFloor: 3.0)

    private func cau(_ st: CriterionStatus) throws -> String {
        try #require(CuePresenter().update([st], 0, 0.0)).vi()
    }

    private func st(
        _ c: Criterion, _ dev: Double, _ signed: Double?, _ b: Band,
        kemChuc: Bool = false, gocMau: Double? = nil, tuChup: Bool = false, hint: PoseHint? = nil
    ) -> CriterionStatus {
        CriterionStatus(
            criterion: c, state: .failing, deviation: dev, signedDelta: signed, band: b,
            poseHint: hint, kemChuc: kemChuc, gocMauKhongCoCaoThap: gocMau, tuChup: tuChup
        )
    }

    @Test("gộp cao và chúc thành MỘT động tác")
    func gopCaoVaChuc() throws {
        let nang = try cau(st(.elevation, 20.0, 20.0, band, kemChuc: true))
        #expect(nang.contains("Nâng máy") && nang.contains("chúc xuống"), "\(nang)")
        let ha = try cau(st(.elevation, 20.0, -20.0, band, kemChuc: true))
        #expect(ha.contains("Hạ máy") && ha.contains("hất lên"), "\(ha)")
    }

    @Test("chỉ lệch độ cao thì bảo giữ nguyên góc")
    func chiLechDoCao() throws {
        let t = try cau(st(.elevation, 20.0, 20.0, band))
        #expect(t.contains("giữ nguyên góc"), "\(t)")
        #expect(!t.contains("chúc"), "\(t)")
    }

    @Test("tự chụp thì câu dáng KHÔNG còn chữ Bảo mẫu")
    func tuChupKhongBaoMau() throws {
        let t = try cau(st(.pose, 40.0, nil, Band(accept: 15.0, enter: 22.5, unlock: 45.0, actionFloor: 12.0),
                           tuChup: true, hint: PoseHint(.armBend, .left)))
        #expect(!t.contains("Bảo mẫu"), "Selfie mà vẫn bảo mẫu: \(t)")
        #expect(t.hasPrefix("Gập tay"), "\(t)")
    }

    private let bandGoc = Band(accept: 12.0, enter: 18.0, unlock: 36.0, actionFloor: 3.0)

    @Test("ảnh mẫu chúc gắt không có mục cao/thấp thì vẫn bảo NÂNG MÁY")
    func chucGatBaoNangMay() throws {
        let t = try cau(st(.pitch, 20.0, 20.0, bandGoc, gocMau: -53.0))
        #expect(t.contains("Nâng máy") && t.contains("chúc xuống"), "\(t)")
    }

    @Test("ảnh mẫu ngửa gắt không có mục cao/thấp thì bảo HẠ MÁY")
    func nguaGatBaoHaMay() throws {
        let t = try cau(st(.pitch, 20.0, -20.0, bandGoc, gocMau: 40.0))
        #expect(t.contains("Hạ máy") && t.contains("hất lên"), "\(t)")
    }

    @Test("ảnh mẫu góc nhẹ thì chỉ nói chúc hoặc hất, không bắt đổi độ cao")
    func gocNhe() throws {
        let t = try cau(st(.pitch, 15.0, 15.0, bandGoc, gocMau: -8.0))
        #expect(!t.contains("Nâng máy"), "\(t)")
        #expect(t.contains("Chúc máy"), "\(t)")
    }

    @Test("chúc quá tay so với ảnh mẫu góc gắt thì chỉ bảo hất lại, không bảo hạ máy")
    func chucQuaTay() throws {
        let t = try cau(st(.pitch, 22.0, -22.0, bandGoc, gocMau: -53.0))
        #expect(!t.contains("Hạ máy"), "\(t)")
        #expect(t.contains("Hất máy"), "\(t)")
    }
}
