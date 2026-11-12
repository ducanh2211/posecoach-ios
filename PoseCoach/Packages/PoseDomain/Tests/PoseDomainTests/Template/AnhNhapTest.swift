import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/AnhNhapTest.kt` — GÁN KIỂU CHỤP VÀ GÓC MÁY cho ảnh tự nhập bằng TÊN FILE.
///
/// ⚠️ iOS tách đôi `MediaLibrary.ganNhan`: phần TÍNH TÊN MỚI ở `PoseDomain` (kiểm ở đây), phần ĐỔI TÊN FILE trên
/// đĩa ở `Services/Media` (Phase 3). Hai ý của bản Kotlin — *file mới tồn tại*, *file cũ biến mất, không để lại
/// bản trùng* — kiểm ở Phase 3 cùng phần đổi tên.
struct AnhNhapTest {

    private let anhMoiNhap = "\(MediaLibrary.tienToNhap)1757800000000.jpg"

    private func khongDuoi(_ ten: String) -> String { (ten as NSString).deletingPathExtension }

    @Test("nhận diện đúng ảnh tự nhập")
    func nhanDienAnhTuNhap() {
        #expect(MediaLibrary.laAnhNhap(URL(fileURLWithPath: anhMoiNhap)))
        #expect(!MediaLibrary.laAnhNhap(URL(fileURLWithPath: "selfie-tren-tai-nghe.jpg")))
    }

    @Test("gán selfie từ trên cao thì file mang cả tiền tố lẫn nhãn")
    func ganSelfieTuTren() throws {
        let ten = MediaLibrary.ganNhan(anhMoiNhap, .selfie, .tren)
        #expect(ten == "selfie-tren-toi-chon-1757800000000.jpg")
        #expect(MediaLibrary.TemplateKind.of(ten) == .selfie)
        #expect(isClose(try #require(MediaLibrary.gocMayTheoNhan(khongDuoi(ten))), -35.0, 1e-9))
        #expect(MediaLibrary.Template(URL(fileURLWithPath: ten)).displayName == "toi chon 1757800000000")
    }

    @Test("ảnh toàn thân tự đo được góc thì chỉ gán kiểu, không gán góc")
    func chiGanKieu() {
        let ten = MediaLibrary.ganNhan(anhMoiNhap, .photographer, nil)
        #expect(ten == "toi-chon-1757800000000.jpg")
        #expect(MediaLibrary.gocMayTheoNhan(khongDuoi(ten)) == nil)
    }

    @Test("đổi ý gán lại thì LỘT nhãn cũ, không chồng nhãn")
    func ganLaiLotNhanCu() throws {
        let lan1 = MediaLibrary.ganNhan(anhMoiNhap, .selfie, .tren)
        let lan2 = MediaLibrary.ganNhan(lan1, .mirror, .duoi)
        #expect(lan2 == "mirror-duoi-toi-chon-1757800000000.jpg")
        #expect(MediaLibrary.TemplateKind.of(lan2) == .mirror)
        #expect(isClose(try #require(MediaLibrary.gocMayTheoNhan(khongDuoi(lan2))), 25.0, 1e-9))
    }

    @Test("gán lại y hệt thì không đổi gì")
    func ganLaiYHet() {
        let lan1 = MediaLibrary.ganNhan(anhMoiNhap, .selfie, .ngang)
        let lan2 = MediaLibrary.ganNhan(lan1, .selfie, .ngang)
        #expect(lan1 == lan2)
    }
}
