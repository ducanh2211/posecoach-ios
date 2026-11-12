import Foundation
import PoseDomain
import Testing
@testable import PoseCoach

/// `UiText.resolved` đổi đúng mã câu + tham số ra chữ qua String Catalog.
struct UiTextResolveTests {

    private func bundle(_ lang: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: lang, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test func thamSoSoVaChuoi() throws {
        let en = try bundle("en")
        #expect(uiText("camera_err_record", .int(-11805)).resolved(en) == "Recording failed (code -11805). You can try again.")
        #expect(uiText("camera_err_open", .string("busy")).resolved(en) == "Couldn't open the camera: busy")
        #expect(uiText("capture_burst_taken", .int(3), .int(8)).resolved(en) == "● shot 3/8")
    }

    @Test func soNhieu() throws {
        let en = try bundle("en")
        #expect(UiText.plural("steps_n", count: 1, [.int(1)]).resolved(en) == "1 step")
        #expect(UiText.plural("steps_n", count: 3, [.int(3)]).resolved(en) == "3 steps")
    }

    @Test func longCauVaGhepCau() throws {
        let en = try bundle("en")
        let inner = UiText.plural("photos_n", count: 2, [.int(2)])
        #expect(uiText("camera_err_open", .text(inner)).resolved(en) == "Couldn't open the camera: 2 photos")
        #expect(UiText.join([.raw("a"), .raw("b")], separator: " · ").resolved(en) == "a · b")
    }

    @Test func soThucTheoNgonNgu() throws {
        // Như Java: số thực theo dấu thập phân của ngôn ngữ máy (tiếng Việt `1,5`), số nguyên không nhóm hàng nghìn.
        let s = uiText("result_shot_header", .double(1.5), .string("80")).resolved(try bundle("en"))
        let sep = Locale.current.decimalSeparator ?? "."
        #expect(s == "At 1\(sep)5s  ·  80/100 match")
    }

    @Test func tiengViet() throws {
        let vi = try bundle("vi")
        let s = UiText.plural("steps_n", count: 2, [.int(2)]).resolved(vi)
        #expect(s.contains("2") && s != "steps_n")
    }
}
