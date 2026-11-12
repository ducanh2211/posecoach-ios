import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/GocMayTest.kt` — MỤC 3 GÓC MÁY CAO/THẤP đo bằng ĐỘ (12/09/2026).
///
/// Chỉ số cũ (`y` của mốc trên khung) nhạy với khoảng cách hơn cả với độ cao máy — tỉ lệ tín hiệu trên nhiễu
/// dưới 1, nên "làm theo mãi mà không bao giờ đạt". File này khoá lại tính chất làm nên khác biệt đó.
struct GocMayTest {

    private let minVis: Float = 0.5

    private func frameOf(_ e: (Int, (P2, Float, P3))...) -> PoseFrame {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        var wld = Array(repeating: P3(0, 0, 0), count: 33)
        for (i, t) in e { pts[i] = t.0; vis[i] = t.1; wld[i] = t.2 }
        return PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
    }

    /// Người đứng thẳng, máy nhìn từ góc nâng `gocDeg`. Âm = máy ở trên chúc xuống. `coTrongKhung` và
    /// `dayKhung` điều khiển cỡ mẫu và vị trí trên ảnh — hai thứ phép đo mới PHẢI bỏ qua.
    private func nguoi(_ gocDeg: Double, coTrongKhung: Double = 0.5, dayKhung: Double = 0.5) -> PoseFrame {
        // Máy ở TRÊN nhìn xuống thì đầu gần ống kính hơn hông. Dấu xoay ngược với góc để dựng đúng chiều đó.
        let r = -gocDeg * (Double.pi / 180.0)   // Math.toRadians
        func than(_ yGoc: Double, _ zGoc: Double = 0.0) -> P3 {
            P3(0.0, yGoc * cos(r) - zGoc * sin(r), yGoc * sin(r) + zGoc * cos(r))
        }
        func diem(_ u: Double, _ vNoiSuy: Double, _ w: P3, _ x3: Double) -> (P2, Float, P3) {
            (P2(u, dayKhung + (vNoiSuy - 0.5) * coTrongKhung), 0.99, P3(x3, w.y, w.z))
        }
        let vaiY = -0.45, hongY = 0.0
        return frameOf(
            (Lm.leftShoulder, diem(0.58, 0.22, than(vaiY), 0.18)),
            (Lm.rightShoulder, diem(0.42, 0.22, than(vaiY), -0.18)),
            (Lm.leftHip, diem(0.55, 0.52, than(hongY), 0.11)),
            (Lm.rightHip, diem(0.45, 0.52, than(hongY), -0.11)),
            (Lm.leftKnee, diem(0.55, 0.72, than(0.42), 0.11)),
            (Lm.rightKnee, diem(0.45, 0.72, than(0.42), -0.11)),
            (Lm.leftAnkle, diem(0.55, 0.92, than(0.85), 0.11)),
            (Lm.rightAnkle, diem(0.45, 0.92, than(0.85), -0.11))
        )
    }

    /// Mục 4 — độ nghiêng trục ống kính. KHÔNG được đổi theo bố cục.
    private func goc(_ f: PoseFrame) -> Double? { Measurer.measure(f, .full, minVis).tiltDeg }

    /// Mục 3 — góc nhìn tới mốc. CÓ đổi theo bố cục, đó là chủ ý.
    private func nhin(_ f: PoseFrame) -> Double? { Measurer.measure(f, .full, minVis).elevationDeg }

    /// Ảnh chân dung: chỉ mũi + hai vai.
    private func chanDung() -> PoseFrame {
        frameOf(
            (Lm.nose, (P2(0.50, 0.35), 0.99, P3(0.0, -0.60, 0.0))),
            (Lm.leftShoulder, (P2(0.75, 0.80), 0.99, P3(0.18, -0.45, 0.0))),
            (Lm.rightShoulder, (P2(0.25, 0.80), 0.99, P3(-0.18, -0.45, 0.0)))
        )
    }

    // MARK: - Phép đo

    @Test("máy ngang tầm thì góc bằng không")
    func mayNgangTam() throws {
        // Khung xương giả lập là hình học lý tưởng; app đổi số thô ra góc máy thật (xem HieuChinhGocAnhTest).
        #expect(isClose(try #require(goc(nguoi(0.0))), Measurer.hieuChinhGocAnh(0.0), 0.5))
    }

    @Test("máy trên cao chúc xuống ra số ÂM")
    func mayTrenCaoAm() throws {
        let v = try #require(goc(nguoi(-30.0)))
        #expect(v < -20.0, "Máy ở trên phải ra số âm, đo được \(v)")
    }

    @Test("máy dưới thấp ngửa lên ra số DƯƠNG")
    func mayDuoiThapDuong() throws {
        let v = try #require(goc(nguoi(25.0)))
        #expect(v > 15.0, "Máy ở dưới phải ra số dương, đo được \(v)")
    }

    @Test("đo đúng số đo, không chỉ đúng dấu")
    func doDungSoDo() throws {
        for g in [-50.0, -30.0, -15.0, 0.0, 15.0, 40.0] {
            #expect(isClose(try #require(goc(nguoi(g))), Measurer.hieuChinhGocAnh(g), 1.0), "góc \(g)°")
        }
    }

    // MARK: - ⚠️ Ca vỡ của bản cũ

    /// Cùng góc máy, mẫu to nhỏ / cao thấp khác nhau trong khung — "người dùng bước tới một bước".
    @Test("đổi KHOẢNG CÁCH và VỊ TRÍ TRONG KHUNG thì ĐỘ NGHIÊNG KHÔNG được đổi")
    func doiKhoangCachViTriKhongDoi() throws {
        let chuan = try #require(goc(nguoi(-25.0, coTrongKhung: 0.5, dayKhung: 0.5)))
        let laiGan = try #require(goc(nguoi(-25.0, coTrongKhung: 0.9, dayKhung: 0.5)))
        let luiXa = try #require(goc(nguoi(-25.0, coTrongKhung: 0.25, dayKhung: 0.5)))
        let lechLen = try #require(goc(nguoi(-25.0, coTrongKhung: 0.5, dayKhung: 0.3)))
        let lechXuong = try #require(goc(nguoi(-25.0, coTrongKhung: 0.5, dayKhung: 0.8)))

        for (ten, v) in [("lại gần", laiGan), ("lùi xa", luiXa), ("mẫu lệch lên", lechLen), ("mẫu lệch xuống", lechXuong)] {
            #expect(isClose(v, chuan, 0.5), "\(ten) mà góc máy đổi — đúng lỗi của phép đo cũ")
        }
    }

    @Test("ảnh mẫu bị CẮT CÚP thì ĐỘ NGHIÊNG vẫn không đổi")
    func catCupKhongDoi() throws {
        // Ảnh mẫu tải từ mạng gần như luôn đã bị cắt (12/09/2026: 0/13 ảnh còn EXIF máy ảnh).
        let goc1 = try #require(goc(nguoi(-40.0, coTrongKhung: 0.4, dayKhung: 0.5)))
        let goc2 = try #require(goc(nguoi(-40.0, coTrongKhung: 0.95, dayKhung: 0.35)))
        #expect(isClose(goc2, goc1, 0.5))
    }

    // MARK: - Không đo được thì bỏ ra, không đoán (quy tắc số 4)

    @Test("không thấy hông thì trả về nil")
    func khongThayHongNil() {
        // Trục cổ→đầu đã đo và loại: tương quan với trục thân chỉ 0,287, độ lệch chuẩn 23,9°.
        #expect(Measurer.measure(chanDung(), .chest, minVis).tiltDeg == nil)
    }

    @Test("hông nằm NGOÀI khung thì cũng trả về nil")
    func hongNgoaiKhungNil() {
        // MediaPipe bịa điểm ngoài khung với độ tin cậy rất cao (0,74-0,83). Lọc visibility chưa đủ.
        let hongNgoaiKhung = frameOf(
            (Lm.leftShoulder, (P2(0.58, 0.30), 0.99, P3(0.18, -0.45, 0.0))),
            (Lm.rightShoulder, (P2(0.42, 0.30), 0.99, P3(-0.18, -0.45, 0.0))),
            (Lm.leftHip, (P2(0.55, 1.09), 0.99, P3(0.11, 0.0, 0.0))),
            (Lm.rightHip, (P2(0.45, 1.12), 0.99, P3(-0.11, 0.0, 0.0)))
        )
        #expect(Measurer.measure(hongNgoaiKhung, .full, minVis).tiltDeg == nil)
    }

    // MARK: - Nối vào phép chấm điểm

    @Test("giống ảnh mẫu thì lệch bằng không")
    func giongAnhMauLechKhong() throws {
        let tpl = Measurer.measure(nguoi(-35.0), .full, minVis)
        // Cùng góc máy nhưng đứng xa hơn hẳn và lệch khung — vẫn phải ĐẠT.
        let live = Measurer.measure(nguoi(-35.0, coTrongKhung: 0.3, dayKhung: 0.65), .full, minVis)
        let d = ShotScorer.deviation(tpl, live)
        #expect(d.pitchSource == .gocMay)
        let lech = try #require(d.pitchCue)
        #expect(lech < 1.0, "Cùng độ nghiêng thì lệch phải ~0, đo được \(lech)")
    }

    @Test("sai góc máy thì báo đúng số độ lệch")
    func saiGocMayDungSoDo() throws {
        let tpl = Measurer.measure(nguoi(-40.0), .full, minVis)
        let live = Measurer.measure(nguoi(-10.0), .full, minVis)
        let d = ShotScorer.deviation(tpl, live)
        #expect(d.pitchSource == .gocMay)
        let lech = Measurer.hieuChinhGocAnh(-10.0) - Measurer.hieuChinhGocAnh(-40.0)
        #expect(isClose(try #require(d.pitchCue), lech, 1.5))
    }

    @Test("một bên không đo được thì bỏ mục này, không trừ điểm")
    func motBenKhongDoDuocBoMuc() {
        let tpl = Measurer.measure(nguoi(-40.0), .full, minVis)
        let khongThayHong = frameOf(
            (Lm.leftShoulder, (P2(0.58, 0.30), 0.99, P3(0.18, -0.45, 0.0))),
            (Lm.rightShoulder, (P2(0.42, 0.30), 0.99, P3(-0.18, -0.45, 0.0)))
        )
        let live = Measurer.measure(khongThayHong, .full, minVis)
        #expect(ShotScorer.deviation(tpl, live).pitchCue == nil)
    }

    // MARK: - MỤC 3 — GÓC NHÌN. Đại lượng KHÁC mục 4, có phụ thuộc bố cục.

    @Test("góc nhìn bằng độ nghiêng khi mốc nằm GIỮA khung")
    func gocNhinBangDoNghiengKhiGiua() throws {
        // elevation = tilt + (0,5 − y) × vFOV. Mốc của FULL là giữa hông, ở đây nằm hơi dưới giữa khung.
        let m = Measurer.measure(nguoi(-20.0, coTrongKhung: 0.5, dayKhung: 0.5), .full, minVis)
        #expect(isClose(try #require(m.elevationDeg), try #require(m.tiltDeg), 12.0))
    }

    @Test("HAI ĐẠI LƯỢNG ĐỘC LẬP — cùng độ nghiêng nhưng khác góc nhìn")
    func haiDaiLuongDocLap() throws {
        // Giữ mốc trong vùng tin được (|0,5 − y| <= 0,15), ngoài đó mục 3 tự bỏ.
        let a = nguoi(-20.0, dayKhung: 0.38)
        let b = nguoi(-20.0, dayKhung: 0.62)
        #expect(isClose(try #require(goc(b)), try #require(goc(a)), 0.5), "Độ nghiêng phải giống nhau")
        #expect(
            abs(try #require(nhin(a)) - (try #require(nhin(b)))) > 10.0,
            "Góc nhìn phải KHÁC nhau — mẫu cao thấp khác nhau trong khung nghĩa là máy ở độ cao khác nhau"
        )
    }

    @Test("mẫu nằm THẤP trong khung thì góc nhìn NGẢ lên")
    func mauThapTrongKhung() throws {
        // Mẫu tụt xuống dưới khung = tia từ máy tới mẫu chúc xuống nhiều hơn = máy đang cao hơn.
        let cao = try #require(nhin(nguoi(0.0, dayKhung: 0.38)))
        let thap = try #require(nhin(nguoi(0.0, dayKhung: 0.62)))
        #expect(cao > thap, "mẫu cao trong khung: \(cao), mẫu thấp: \(thap)")
    }

    @Test("không thấy hông thì không có cả hai")
    func khongThayHongKhongCoCaHai() {
        let m = Measurer.measure(chanDung(), .chest, minVis)
        #expect(m.tiltDeg == nil)
        #expect(m.elevationDeg == nil)
    }

    // MARK: - Mốc xa tâm khung: phần ĐOÁN lấn át phần ĐO

    /// `(0,5 − y) × vFOV` tỉ lệ thẳng với khoảng cách mốc tới giữa khung; vFOV ảnh mẫu là số đoán (±20°).
    @Test("mốc quá xa tâm khung thì BỎ mục 3, không đưa ra số bịa")
    func mocXaTamBoMuc3() {
        #expect(nhin(nguoi(0.0, dayKhung: 0.20)) == nil)
        #expect(nhin(nguoi(0.0, dayKhung: 0.82)) == nil)
    }

    @Test("mốc gần tâm thì vẫn đo bình thường")
    func mocGanTamVanDo() {
        #expect(nhin(nguoi(0.0, dayKhung: 0.45)) != nil)
        #expect(nhin(nguoi(0.0, dayKhung: 0.58)) != nil)
    }

    @Test("bỏ mục 3 KHÔNG kéo theo mục 4")
    func boMuc3KhongKeoMuc4() {
        let f = nguoi(-25.0, dayKhung: 0.20)
        #expect(nhin(f) == nil)
        #expect(goc(f) != nil)
    }
}
