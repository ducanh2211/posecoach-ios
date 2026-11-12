import Testing
@testable import PoseDomain

/// Port từ `KTT/DatMayTest.kt` — chế độ ĐẶT MÁY TỰ CHỤP (17/10/2026): ảnh mẫu `tripod-`, hai giai đoạn, câu nói
/// bước chân.
struct DatMayTest {

    private let veo = Band(accept: 6.0, enter: 9.0, unlock: 18.0, actionFloor: 2.0)
    private let ngua = Band(accept: 6.0, enter: 9.0, unlock: 18.0, actionFloor: 2.0)

    @Test("ảnh mẫu tripod bật chế độ đặt máy bằng camera trước")
    func anhMauTripod() throws {
        #expect(MediaLibrary.TemplateKind.of("tripod-ngang-ao-trang.jpg") == .tripod)
        #expect(isClose(try #require(MediaLibrary.gocMayTheoNhan("tripod-ngang-ao-trang")), 0.0, 1e-9))
        #expect(ShootMode.datMay.camTruoc && ShootMode.datMay.datMay && ShootMode.datMay.tuChup)
        #expect(!ShootMode.datMay.tamTay, "Đặt máy không chỉnh khoảng cách bằng tay")
    }

    @Test("đặt máy nghiêng thì nhắc xoay, thẳng và giữ yên thì khoá")
    func datMayNghieng() {
        let g = DatMayGate(0.0)
        #expect(g.update(12.0, 0.0, 0, veo, ngua)?.vi() == "Đặt máy: xoay nhẹ ngược chiều kim đồng hồ cho thẳng")
        #expect(g.update(1.0, 0.0, 100, veo, ngua)?.vi() == "Giữ yên máy…")
        #expect(g.update(1.0, 0.0, 1_200, veo, ngua) == nil)
        #expect(g.daDat)
    }

    @Test("góc ngửa/chúc theo nhãn ảnh mẫu")
    func gocNguaChucTheoNhan() {
        let g = DatMayGate(25.0)    // ảnh mẫu chụp từ dưới lên
        #expect(g.update(0.0, 0.0, 0, veo, ngua)?.vi() == "Đặt máy: ngửa máy lên thêm một chút")
        let h = DatMayGate(-35.0)   // ảnh mẫu chụp từ trên cao
        #expect(h.update(0.0, 0.0, 0, veo, ngua)?.vi() == "Đặt máy: chúc máy xuống thêm một chút")
    }

    @Test("máy bị chạm lệch quá mức thì quay lại đặt máy")
    func mayBiCham() {
        let g = DatMayGate(0.0)
        g.update(0.0, 0.0, 0, veo, ngua)
        g.update(0.0, 0.0, 1_100, veo, ngua)
        #expect(g.daDat)
        #expect(g.update(8.0, 0.0, 1_200, veo, ngua) == nil, "Rung nhẹ không mở khoá")
        #expect(g.daDat)
        #expect(g.update(-25.0, 0.0, 1_300, veo, ngua)?.vi() == "Đặt máy: xoay nhẹ theo chiều kim đồng hồ cho thẳng")
        #expect(!g.daDat)
    }

    @Test("không có cảm biến thì không chặn")
    func khongCoCamBien() {
        let g = DatMayGate(0.0)
        #expect(g.update(nil, nil, 0, veo, ngua) == nil)
        #expect(g.daDat)
    }

    private func cau(_ c: Criterion, _ signed: Double, kemChuc: Bool = false) -> String {
        cueTextFor(
            CriterionStatus(
                criterion: c, state: .failing, deviation: 1.0, signedDelta: signed, band: veo,
                kemChuc: kemChuc, tuChup: true, datMay: true
            )
        ).vi()
    }

    @Test("chỗ đứng nói bước chân theo chiều màn hình")
    func choDungNoiBuocChan() {
        #expect(cau(.center, 0.1) == "Bước sang trái một chút")
        #expect(cau(.center, -0.1) == "Bước sang phải một chút")
        #expect(cau(.scale, 0.3).hasPrefix("Lùi lại"))
        #expect(cau(.scale, -0.3).hasPrefix("Tiến"))
        #expect(cau(.elevation, 5.0, kemChuc: true) == "Đặt máy cao hơn rồi chúc xuống")
    }
}
