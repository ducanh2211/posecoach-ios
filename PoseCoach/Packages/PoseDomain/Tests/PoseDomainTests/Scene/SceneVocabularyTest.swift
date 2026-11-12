import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/SceneVocabularyTest.kt` — gõ chữ mô tả bối cảnh → nhãn, và ảnh mẫu khớp một phần (09/10/2026).
struct SceneVocabularyTest {

    private func labels(_ t: String) -> [String] { SceneVocabulary.parse(t).labels }

    @Test("hiểu tiếng Việt có dấu")
    func tiengVietCoDau() {
        #expect(labels("quán cà phê có cửa sổ") == ["Coffee", "Window"])
    }

    @Test("gõ không dấu vẫn hiểu")
    func khongDau() {
        #expect(labels("quan ca phe co cua so") == ["Coffee", "Window"])
    }

    @Test("hiểu tiếng Anh, kể cả số nhiều")
    func tiengAnhSoNhieu() {
        #expect(labels("beach with chairs") == ["Beach", "Chair"])
        #expect(labels("trees and benches") == ["Tree", "Bench"])
    }

    @Test("cụm dài thắng cụm ngắn")
    func cumDaiThang() {
        // "bãi biển" là bãi biển, không phải "biển" kèm chữ "bãi" thừa.
        #expect(labels("bãi biển") == ["Beach"])
        // "cửa sổ" không bị đọc thành "cửa" (cửa ra vào).
        #expect(labels("cửa sổ") == ["Window"])
    }

    @Test("gõ có dấu mà sai dấu thì KHÔNG khớp")
    func saiDau() {
        // "áo" (cái áo) không được hiểu thành "ao" (cái ao).
        let p = SceneVocabulary.parse("áo")
        #expect(p.labels.isEmpty)
        #expect(p.unknown == ["áo"])
    }

    @Test("từ không hiểu thì báo ra, từ đệm thì bỏ qua")
    func tuKhongHieu() {
        let p = SceneVocabulary.parse("rooftop gần biển")
        #expect(p.labels == ["Sea"])
        #expect(p.unknown == ["rooftop"])
    }

    /// Từ điển trỏ tới một nhãn mà `SceneMatching` không biết thì chữ gõ hiểu được mà tìm không ra gì — lỗi im lặng.
    @Test("mọi nhãn trong từ điển đều là nhãn mà bộ tìm kiếm hỗ trợ")
    func moiNhanDuocHoTro() {
        let ws = ["hoa", "chậu hoa", "cây xanh", "vườn", "rừng", "cát", "hồ", "sông", "thác", "núi",
                  "cánh đồng", "trời", "mây", "hoàng hôn", "tuyết", "đá", "phòng", "tường", "cửa", "ghế dài",
                  "ghế", "bàn", "sofa", "ghế đôi", "kệ", "rèm", "bếp", "quầy", "nhà", "nhà cao tầng", "cầu",
                  "đường", "phố", "chùa", "lâu đài", "bảo tàng", "lan can", "xe đạp", "ô tô", "thuyền", "cốc",
                  "latte", "dù", "bóng bay"]
        for w in ws {
            let l = labels(w)
            #expect(l.count == 1, "\(w)")
            if let only = l.first { #expect(SceneMatching.typedTag(only) != nil, "\(w)") }
        }
    }

    // MARK: - Khớp một phần — PO chốt: vẫn hiện, ghi rõ thiếu gì.

    private func tag(_ id: String) -> SceneTag { SceneMatching.tag(id, 0.9)! }

    @Test("ảnh mẫu khớp một phần vẫn hiện và ghi rõ thiếu gì")
    func khopMotPhan() throws {
        let tim = [SceneMatching.typedTag("Sea"), SceneMatching.typedTag("Bench")].compactMap { $0 }
        let frames = [SceneFrame(0, tim)]
        let chiCoBien = SceneTemplate(URL(fileURLWithPath: "bien"), "bien", [tag("Sea")])
        let duCa = SceneTemplate(URL(fileURLWithPath: "bien-ghe"), "bien ghe", [tag("Sea"), tag("Bench")])
        let ra = SceneMatching.rank(frames, [chiCoBien, duCa], ["Sea", "Bench"])

        try #require(ra.count == 2)
        #expect(ra[0].template.file.lastPathComponent == "bien-ghe", "Khớp đủ phải đứng trước")
        #expect(ra[0].missing.isEmpty)
        #expect(ra[1].template.file.lastPathComponent == "bien")
        #expect(ra[1].missing.map(\.id) == ["Bench"])
    }
}
