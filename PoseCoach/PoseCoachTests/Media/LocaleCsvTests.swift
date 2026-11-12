import Foundation
import Testing
@testable import PoseCoach

/// ⚠️ KHOÁ LẠI LỖI ĐÃ GẶP TRÊN MÁY THẬT — 06/09/2026, máy cài tiếng Việt. Port `KTT/LocaleCsvTest.kt`.
///
/// Định dạng số theo ngôn ngữ máy → tiếng Việt dùng dấu PHẨY thập phân. Bảng kê ảnh (`ShotStore`) là CSV ngăn bằng dấu
/// phẩy, nên một giá trị thành HAI cột và mọi cột sau trượt một ô. Không lộ trên máy mặc định tiếng Anh.
struct LocaleCsvTests {

    @Test func dinhDangTheoNgonNguMayLamVoCsv() {
        let vi = String(format: "%.3f", locale: Locale(identifier: "vi_VN"), 0.899)
        #expect(vi == "0,899", "Tiếng Việt dùng dấu phẩy — đây là gốc của lỗi")
        // Dòng đúng phải có 4 cột: id, thời điểm, điểm, đáng tin.
        let hong = "id,10,\(vi),true".components(separatedBy: ",")
        #expect(hong.count == 5, "Một giá trị thành HAI cột nên dòng thừa ra một ô, mọi cột sau trượt đi")
        #expect(hong[2] == "0", "Cột điểm bị cắt làm đôi")
        #expect(hong[3] == "899", "Nửa sau bị đọc nhầm thành cột kế tiếp")
    }

    @Test func posixGiuDauChamNenCsvConNguyen() {
        for loc in ["vi_VN", "de_DE", "fr_FR", "en_US"] {
            // `ShotStore.num` không phụ thuộc ngôn ngữ máy — vòng lặp giữ như bản Kotlin.
            let s = ShotStore.num(0.899)
            #expect(s == "0.899", "Máy cài \(loc) vẫn phải ra dấu chấm")
            #expect(s.components(separatedBy: ",").count == 1, "Đúng 1 cột")
        }
    }

    @Test func docLaiRaDungGiaTri() throws {
        let ghi = ShotStore.num(0.899)
        #expect(abs(try #require(Double(ghi)) - 0.899) < 1e-9)
    }
}
