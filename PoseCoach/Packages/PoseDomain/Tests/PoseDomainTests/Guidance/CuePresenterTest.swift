import Testing
@testable import PoseDomain

/// Port từ `KTT/CuePresenterTest.kt` — luật hiển thị lời nhắc: mỗi lúc một câu, câu đã hiện ở lại đủ lâu, và
/// đóng băng khi lắc mạnh.
struct CuePresenterTest {

    private let band = Band(accept: 10.0, enter: 15.0, unlock: 30.0, actionFloor: 1.0)

    private func status(_ c: Criterion, dev: Double = 40.0, signed: Double = 1.0) -> CriterionStatus {
        CriterionStatus(criterion: c, state: .failing, deviation: dev, signedDelta: signed, band: band)
    }

    /// Thứ tự khai báo trong enum — tương đương `ordinal` của Kotlin.
    private func ordinal(_ c: Criterion) -> Int { Criterion.allCases.firstIndex(of: c)! }

    @Test("không có gì lệch thì không nhắc gì")
    func khongCoGiLech() {
        #expect(CuePresenter().update([], 0, 0.0) == nil)
    }

    @Test("mỗi lúc chỉ một câu")
    func moiLucMotCau() throws {
        let p = CuePresenter()
        let text = try #require(p.update([status(.scale), status(.center)], 0, 0.0))
        // Câu trả về là MỘT câu — luật "mỗi lúc một câu" bảo đảm ngay ở kiểu dữ liệu.
        #expect(!text.vi().isEmpty)
    }

    @Test("câu đã hiện phải ở lại đủ lâu, không bị mục ưu tiên thấp chen")
    func cauDaHienOLai() {
        let p = CuePresenter()
        let first = p.update([status(.scale)], 0, 0.0)
        let second = p.update([status(.scale), status(.pose)], 200, 0.0)
        #expect(first == second)
    }

    /// ⚠️ ĐỔI HÀNH VI 06/09/2026: chen ngang ngay thành máy sinh nhấp nháy trên máy thật.
    @Test("mục ưu tiên cao hơn KHÔNG được chen ngang trước thời hạn")
    func khongChenNgang() throws {
        let p = CuePresenter()
        let first = p.update([status(.pose)], 0, 0.0)
        let second = p.update([status(.yaw), status(.pose)], 100, 0.0)
        #expect(first == second, "Chưa hết thời gian giữ thì phải giữ nguyên câu cũ")

        let third = try #require(p.update([status(.yaw), status(.pose)], GuidanceTiming.cueMinDisplayMs + 100, 0.0))
        #expect(third.vi().contains("xoay người"), "Hết thời hạn thì đổi sang mục ưu tiên cao hơn")
    }

    @Test("hết thời gian giữ thì mới được nhường cho mục ưu tiên thấp hơn")
    func hetThoiGianGiu() throws {
        let p = CuePresenter()
        p.update([status(.scale)], 0, 0.0)
        let next = try #require(p.update([status(.pose)], GuidanceTiming.cueMinDisplayMs + 1, 0.0))
        #expect(next.vi().contains("dáng"))
    }

    @Test("lắc mạnh thì đóng băng câu đang hiện")
    func lacManhDongBang() {
        let p = CuePresenter()
        let first = p.update([status(.scale)], 0, 0.0)
        let frozen = p.update([status(.yaw)], 100, GuidanceTiming.freezeCueAngularSpeedDegPerSec + 10.0)
        #expect(first == frozen)
    }

    /// ⚠️ ĐỔI CHỦ Ý 12/09/2026: dấu đã đo trên ảnh mẫu thật — góc dương = mẫu quay về phía TRÁI của họ.
    @Test("câu về hướng mẫu PHẢI nói rõ chiều xoay")
    func huongMauNoiRoChieu() throws {
        let phai = try #require(CuePresenter().update([status(.yaw, dev: 60.0, signed: 60.0)], 0, 0.0)).vi()
        #expect(phai.contains("phải"), "signed dương thì phải bảo xoay sang PHẢI, nhận: \(phai)")

        let trai = try #require(CuePresenter().update([status(.yaw, dev: 60.0, signed: -60.0)], 0, 0.0)).vi()
        #expect(trai.contains("trái"), "signed âm thì phải bảo xoay sang TRÁI, nhận: \(trai)")
    }

    @Test("ngược hẳn hướng thì bảo quay hẳn người lại, không nói trái phải")
    func nguocHanHuong() throws {
        let text = try #require(CuePresenter().update([status(.yaw, dev: 150.0, signed: 150.0)], 0, 0.0)).vi()
        #expect(text.contains("quay hẳn người lại"), "nhận: \(text)")
    }

    @Test("mục khung hình nói về ZOOM khi chỗ đứng đã đúng")
    func khungHinhNoiZoom() throws {
        let quaTo = try #require(CuePresenter().update([status(.scale, dev: 0.4, signed: 0.4)], 0, 0.0)).vi()
        #expect(quaTo.contains("Zoom ra"))
        let quaNho = try #require(CuePresenter().update([status(.scale, dev: 0.4, signed: -0.4)], 0, 0.0)).vi()
        #expect(quaNho.contains("Zoom vào"))
    }

    @Test("ảnh chân dung thì mục khung hình quay về nói ĐI BỘ")
    func chanDungNoiDiBo() throws {
        var s = status(.scale, dev: 0.4, signed: 0.4)
        s.walkInsteadOfZoom = true
        let text = try #require(CuePresenter().update([s], 0, 0.0)).vi()
        #expect(text.contains("Lùi lại"))
    }

    @Test("mục chỗ đứng nói ra SỐ BƯỚC")
    func choDungNoiSoBuoc() throws {
        var s = status(.perspective, dev: 0.3, signed: 0.3)
        s.moveMeters = 1.2
        let text = try #require(CuePresenter().update([s], 0, 0.0)).vi()
        // 1,2m / 0,6m mỗi bước = 2 bước
        #expect(text.contains("Lùi lại"))
        #expect(text.contains("2 bước"))
    }

    @Test("không ước lượng được khoảng cách thì nói một chút")
    func khongUocLuongDuoc() throws {
        let text = try #require(CuePresenter().update([status(.perspective, dev: 0.3, signed: 0.3)], 0, 0.0)).vi()
        #expect(text.contains("một chút"))
    }

    // MARK: - Thứ tự hướng dẫn

    @Test("thứ tự kiểm đúng theo tài liệu")
    func thuTuKiem() {
        // 1 hướng mẫu → 2 xa/gần → 3 cao/thấp → 4 ngửa/chúc → 5 trái/phải → 6 dáng
        let thuTu: [Criterion] = [.yaw, .perspective, .scale, .elevation, .pitch, .center, .pose]
        for i in 1..<thuTu.count {
            #expect(ordinal(thuTu[i - 1]) < ordinal(thuTu[i]), "\(thuTu[i - 1]) phải đứng trước \(thuTu[i])")
        }
    }

    /// ⚠️ ĐỔI CHỦ Ý 12/09/2026: hướng chưa đúng mà kiểm tay chân thì so nhầm tay trái với tay phải.
    @Test("hướng mẫu đứng đầu, dáng đứng cuối")
    func huongDauDangCuoi() {
        #expect(ordinal(.yaw) == 0)
        #expect(ordinal(.pose) > ordinal(.center))
    }

    @Test("máy nghiêng xuống cuối để không cướp lời")
    func mayNghiengXuongCuoi() {
        for c: Criterion in [.yaw, .scale, .elevation, .pitch, .center, .pose] {
            #expect(ordinal(c) < ordinal(.roll), "\(c) phải đứng trước ROLL")
        }
    }

    @Test("đúng hai mục nào là việc của mẫu")
    func haiMucCuaMau() {
        #expect(Criterion.yaw.forModel)
        #expect(Criterion.pose.forModel)
        #expect(!Criterion.perspective.forModel)
        #expect(!Criterion.scale.forModel)
        #expect(!Criterion.center.forModel)
        #expect(!Criterion.elevation.forModel)
        #expect(!Criterion.pitch.forModel)
    }

    @Test("hai mục của mẫu vẫn giữ nhãn hiển thị riêng")
    func nhanHienThi() {
        #expect(viString(Criterion.yaw.displayLabelRes) == "Hướng mẫu")
        #expect(viString(Criterion.pose.displayLabelRes) == "Dáng tay chân")
        // Còn hai mục về chỗ đứng thì gộp làm một dòng.
        #expect(Criterion.scale.displayLabelRes == Criterion.perspective.displayLabelRes)
    }
}
