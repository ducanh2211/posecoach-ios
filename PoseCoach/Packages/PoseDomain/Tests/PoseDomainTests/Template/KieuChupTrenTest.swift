import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/KieuChupTrenTest.kt` — KIỂU CHỤP TỪ TRÊN CAO (19/09/2026): nhãn thứ hai sau `tren` (`gan` / `xa`)
/// chỉ đổi câu nhắc khoảng cách/zoom.
struct KieuChupTrenTest {

    private let minVis: Float = 0.5

    @Test("đọc đúng nhãn thứ hai sau tren, nhãn rong cũ thành gần")
    func docNhanThuHai() {
        #expect(MediaLibrary.kieuChupTrenTheoNhan("tren-gan-kinh-ram-tai-nghe") == .gan)
        #expect(MediaLibrary.kieuChupTrenTheoNhan("tren-rong-kinh-ram-tai-nghe") == .gan)
        #expect(MediaLibrary.kieuChupTrenTheoNhan("tren-xa-toc-hong-ben-be-boi") == .xaZoom)
        #expect(MediaLibrary.kieuChupTrenTheoNhan("tren-kinh-ram") == nil)
        #expect(MediaLibrary.kieuChupTrenTheoNhan("ngang-xa-ho") == nil)
    }

    @Test("tên hiển thị bỏ cả hai nhãn")
    func tenHienThiBoHaiNhan() {
        func ten(_ f: String) -> String { MediaLibrary.Template(URL(fileURLWithPath: f)).displayName }
        #expect(ten("tren-gan-kinh-ram-tai-nghe.jpg") == "kinh ram tai nghe")
        #expect(ten("tren-kinh-ram.jpg") == "kinh ram")
        #expect(ten("ngang-nam-nen-trang.jpg") == "nam nen trang")
    }

    @Test("gán nhãn ảnh nhập và đổi ý gán lại")
    func ganNhanVaDoiY() {
        let f = "\(MediaLibrary.tienToNhap)123.jpg"
        let lan1 = MediaLibrary.ganNhan(f, .photographer, .tren, .gan)
        #expect(lan1 == "tren-gan-toi-chon-123.jpg")
        let lan2 = MediaLibrary.ganNhan(lan1, .photographer, .ngang, .gan)
        #expect(lan2 == "ngang-toi-chon-123.jpg", "Góc ngang thì không ghi kiểu chụp trên cao")
    }

    private func nguoi() -> PoseFrame {
        func p(_ u: Double, _ v: Double, _ y: Double, _ x3: Double) -> (P2, Float, P3) { (P2(u, v), 0.99, P3(x3, y, 0.0)) }
        return frameOf(
            (Lm.nose, p(0.50, 0.10, -0.60, 0.0)),
            (Lm.leftEye, p(0.52, 0.09, -0.62, 0.03)), (Lm.rightEye, p(0.48, 0.09, -0.62, -0.03)),
            (Lm.leftShoulder, p(0.58, 0.22, -0.45, 0.18)), (Lm.rightShoulder, p(0.42, 0.22, -0.45, -0.18)),
            (Lm.leftHip, p(0.55, 0.52, 0.0, 0.11)), (Lm.rightHip, p(0.45, 0.52, 0.0, -0.11)),
            (Lm.leftKnee, p(0.55, 0.72, 0.42, 0.11)), (Lm.rightKnee, p(0.45, 0.72, 0.42, -0.11)),
            (Lm.leftAnkle, p(0.55, 0.92, 0.85, 0.11)), (Lm.rightAnkle, p(0.45, 0.92, 0.85, -0.11))
        )
    }

    private func chay(
        _ kieu: KieuChupTren?, zoom: Float, heSoCo: Double,
        mode: ShootMode = .nguoiKhac, zoomMin: Float = 0.5
    ) throws -> GuidanceResult {
        let f = nguoi()
        let g = MediaLibrary.GocMayNhan.tren.doNghieng
        let profile = TemplateProfile.from(
            f, try #require(FramingClass.detect(f, minVis)), minVis, gocMayNhan: g, kieuChupTren: kieu
        )
        let engine = GuidanceEngine(profile)
        let m0 = Measurer.measure(f, profile.framing, minVis)
        var live = m0
        live.scale = (m0.scale ?? 0.5) * heSoCo
        live.tiltDeg = g
        live.pitchCue[.gocMay] = g
        live.elevationDeg = Measurer.gocNhin(g, m0.elevationAnchorY, 65.0)
        var t: Int64 = 0
        var r = engine.update(live, t, 0.0, zoomRatio: zoom, mode: mode, zoomMin: zoomMin)
        for _ in 0..<100 {
            t += 100
            r = engine.update(live, t, 0.0, zoomRatio: zoom, mode: mode, zoomMin: zoomMin)
        }
        return r
    }

    @Test("đứng gần mà đang zoom vào quá 1x thì bảo đưa zoom về")
    func dungGanZoomQua() throws {
        let r = try chay(.gan, zoom: 2, heSoCo: 1.0)
        #expect(r.cue?.vi() == "Đưa zoom về 1x hoặc nhỏ hơn đến khi tích sáng")
    }

    @Test("đứng gần người nhỏ thì tiến sát, gợi ý cả 1x lẫn kiểu mắt cá")
    func dungGanNguoiNho() throws {
        let c = try #require(try chay(.gan, zoom: 1, heSoCo: 0.6).cue).vi()
        #expect(c.hasPrefix("Tiến sát vào") && c.contains("0.5–0.7x"), "\(c)")
    }

    @Test("đứng gần ở 0.5x cũng được, không bắt đổi zoom")
    func dungGan05x() throws {
        let r = try chay(.gan, zoom: 0.5, heSoCo: 1.0)
        let c = r.cue?.vi() ?? ""
        #expect(!c.contains("zoom về"), "\(c)")
        let scale = try #require(r.statuses.first { $0.criterion == .scale })
        #expect(!scale.zoomSai)
    }

    @Test("đứng gần người to quá thì bảo nâng máy cao hơn, không bảo lùi")
    func dungGanNguoiTo() throws {
        let r = try chay(.gan, zoom: 1, heSoCo: 1.6)
        #expect(r.cue?.vi() == "Nâng máy cao hơn nữa, vẫn chúc xuống, đến khi thấy cả người")
    }

    @Test("máy không có ống góc rộng thì không gợi ý mắt cá")
    func khongGocRong() throws {
        let c = try #require(try chay(.gan, zoom: 1, heSoCo: 0.6, zoomMin: 1).cue).vi()
        #expect(c.hasSuffix("giữ zoom 1x"), "\(c)")
    }

    @Test("từ xa mà đang đứng gần thì bảo lùi ra rồi zoom")
    func tuXaMaDungGan() throws {
        let c = try #require(try chay(.xaZoom, zoom: 1, heSoCo: 1.6).cue).vi()
        #expect(c.hasPrefix("Lùi ra xa thêm") && c.hasSuffix("rồi zoom vào"), "\(c)")
    }

    @Test("không có nhãn, mẫu chúc gắt, người to quá thì cũng bảo nâng máy")
    func khongNhanChucGat() throws {
        let r = try chay(nil, zoom: 1, heSoCo: 1.6)
        #expect(r.cue?.vi() == "Nâng máy cao hơn nữa, vẫn chúc xuống, đến khi thấy cả người")
        let scale = try #require(r.statuses.first { $0.criterion == .scale })
        #expect(scale.zoomToiDa == nil)
    }

    @Test("selfie không bị nhãn này tác động")
    func selfieKhongTacDong() throws {
        let c = try chay(.gan, zoom: 2, heSoCo: 1.0, mode: .tuChupCamTruoc).cue?.vi() ?? ""
        #expect(!c.contains("zoom về"), "\(c)")
    }
}
