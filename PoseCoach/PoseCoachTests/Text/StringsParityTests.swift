import Foundation
import Testing

/// MỌI NGÔN NGỮ PHẢI ĐỦ CÂU VÀ KHỚP THAM SỐ. Port `KTT/StringsParityTest.kt`.
///
/// Thiếu câu ở một ngôn ngữ thì iOS lặng lẽ hiện key (hoặc câu tiếng Anh) giữa màn tiếng Việt. Lệch tham số (bản Anh có
/// `%1$lld`, bản dịch quên hoặc đổi thành `%1$@`) thì `String(format:)` đọc sai kiểu — có thể **sập lúc chạy** đúng ở câu
/// đó, build vẫn qua. Bài này bắt cả hai.
///
/// Kiểm bản ĐÃ BIÊN DỊCH trong bundle (`.strings` + `.stringsdict`). Thêm ngôn ngữ mới thì bài này tự kiểm luôn.
struct StringsParityTests {

    /// Một tham số định dạng: `%1$lld`, `%@`, `%.1f`… (`%%` là dấu phần trăm, không phải tham số).
    private static let arg = try! NSRegularExpression(pattern: #"%(\d+\$)?[-#+ 0,(]*\d*(\.\d+)?(lld|ld|d|@|f)"#)

    /// key → danh sách văn bản (một chuỗi, hoặc mọi dạng số nhiều của một chuỗi số nhiều).
    private func read(_ lang: String) throws -> [String: [String]] {
        var out: [String: [String]] = [:]
        let strings = try #require(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang))
        for (k, v) in try #require(NSDictionary(contentsOfFile: strings) as? [String: String]) { out[k] = [v] }
        if let plurals = Bundle.main.path(forResource: "Localizable", ofType: "stringsdict", inDirectory: nil, forLocalization: lang),
           let dict = NSDictionary(contentsOfFile: plurals) as? [String: Any] {
            for (k, v) in dict { out[k] = texts(v) }
        }
        return out
    }

    /// Mọi văn bản lá của một mục `.stringsdict`, trừ khoá cấu hình (`%#@biến@`, kiểu tham số).
    private func texts(_ node: Any) -> [String] {
        guard let d = node as? [String: Any] else { return [] }
        var out: [String] = []
        for (k, v) in d.sorted(by: { $0.key < $1.key }) {
            if k == "NSStringLocalizedFormatKey" || k == "NSStringFormatSpecTypeKey" || k == "NSStringFormatValueTypeKey" { continue }
            if let s = v as? String { out.append(s) } else { out += texts(v) }
        }
        return out
    }

    private func args(_ texts: [String]) -> Set<[String]> {
        Set(texts.map { t in
            let s = t.replacingOccurrences(of: "%%", with: "")
            return Self.arg.matches(in: s, range: NSRange(s.startIndex..., in: s))
                .map { String(s[Range($0.range, in: s)!]) }
                .sorted()
        })
    }

    @Test func moiNgonNguDuCauVaKhopThamSoVoiBanTiengAnh() throws {
        let langs = Bundle.main.localizations.filter { $0 != "Base" && $0 != "en" }
        #expect(langs.contains("vi"), "Phải có ít nhất bản tiếng Việt")
        let en = try read("en")
        for lang in langs {
            let tr = try read(lang)
            #expect(Set(en.keys) == Set(tr.keys),
                    "\(lang): thiếu \(Set(en.keys).subtracting(tr.keys).sorted()), thừa \(Set(tr.keys).subtracting(en.keys).sorted())")
            for (name, texts) in en {
                guard let t = tr[name] else { continue }
                #expect(args(texts) == args(t), "\(lang)/\(name): tham số lệch — en \(args(texts)), \(lang) \(args(t))")
            }
        }
    }

    @Test func boTachThamSoNhanDungKieu() {
        #expect(args(["%1$lld%% match · %2$lld/%3$lld"]) == [["%1$lld", "%2$lld", "%3$lld"]])
        #expect(args(["At %1$.1fs · %2$@/100"]) == [["%1$.1f", "%2$@"]])
        #expect(args(["100%% xong"]) == [[]])
    }
}
