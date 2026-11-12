import Foundation

/// ĐỔI CÂU MÔ TẢ BỐI CẢNH RA NHÃN — khi ảnh/video không nhận ra được, người dùng gõ chữ (09/10/2026). Port từ
/// `KT/scene/SceneVocabulary.kt`. PO chốt: không gọi AI trên mạng, dùng TỪ ĐIỂN trên máy.
///
/// Nhãn đích là đúng bộ nhãn ML Kit mà `SceneMatching` dùng. Tra CẢ tiếng Anh lẫn tiếng Việt cùng lúc, bất kể máy đặt
/// ngôn ngữ nào. Từ ở đây là chữ NGƯỜI DÙNG GÕ VÀO, không phải chữ hiển thị, nên không nằm trong String Catalog.
///
/// Gõ không dấu vẫn hiểu ("quan ca phe"). Gõ CÓ dấu thì phải khớp đúng dấu: "áo" không thành "ao" (FOOTGUNS 107).
public enum SceneVocabulary {

    /// Kết quả hiểu một câu: các nhãn hiểu được (đúng thứ tự gõ) và các từ không hiểu.
    public struct Parsed: Equatable, Sendable {
        public let labels: [String]
        public let unknown: [String]
    }

    /// ⚠️ Mảng chứ không phải Dictionary: thứ tự khai báo quyết định trùng khớp nào thắng (như `mapOf` của Kotlin).
    private static let words: [(String, [String])] = [
        ("Flower", ["flower", "blossom", "bloom", "hoa", "bông hoa", "vườn hoa"]),
        ("Flowerpot", ["flowerpot", "flower pot", "potted plant", "chậu hoa", "chậu cây"]),
        ("Plant", ["plant", "greenery", "foliage", "leaves", "cây xanh", "cây cảnh", "lá cây"]),
        ("Garden", ["garden", "park", "yard", "vườn", "công viên", "sân vườn"]),
        ("Tree", ["tree", "cây", "cây cối", "hàng cây"]),
        ("Forest", ["forest", "woods", "jungle", "rừng", "rừng cây"]),
        ("Beach", ["beach", "seaside", "coast", "shore", "bãi biển", "bờ biển"]),
        ("Sand", ["sand", "cát"]),
        ("Sea", ["sea", "ocean", "biển", "đại dương"]),
        ("Water", ["water", "nước", "mặt nước"]),
        ("Lake", ["lake", "pond", "hồ", "ao"]),
        ("River", ["river", "stream", "sông", "suối"]),
        ("Waterfall", ["waterfall", "thác", "thác nước"]),
        ("Mountain", ["mountain", "hill", "núi", "đồi"]),
        ("Field", ["field", "meadow", "farm", "rice field", "cánh đồng", "đồng lúa", "ruộng"]),
        ("Sky", ["sky", "bầu trời", "trời"]),
        ("Cloud", ["cloud", "mây"]),
        ("Sunset", ["sunset", "sunrise", "golden hour", "hoàng hôn", "bình minh"]),
        ("Snow", ["snow", "tuyết"]),
        ("Rock", ["rock", "stone", "cliff", "đá", "vách đá"]),
        ("Room", [
            "room", "indoors", "indoor", "inside", "bedroom", "living room",
            "phòng", "trong phòng", "trong nhà", "phòng khách", "phòng ngủ",
        ]),
        ("Wall", ["wall", "tường", "bức tường"]),
        ("Window", ["window", "cửa sổ"]),
        ("Door", ["door", "gate", "entrance", "cửa", "cổng", "cửa ra vào"]),
        ("Bench", ["bench", "ghế dài", "ghế đá"]),
        ("Chair", ["chair", "seat", "ghế"]),
        ("Table", ["table", "desk", "bàn"]),
        ("Couch", ["couch", "sofa", "ghế sofa"]),
        ("Loveseat", ["loveseat", "ghế đôi"]),
        ("Shelf", ["shelf", "bookshelf", "kệ", "kệ sách", "giá sách"]),
        ("Curtain", ["curtain", "rèm", "rèm cửa"]),
        ("Kitchen", ["kitchen", "bếp", "nhà bếp"]),
        ("Countertop", ["countertop", "counter", "mặt bàn", "quầy"]),
        ("Building", ["building", "house", "tòa nhà", "toà nhà", "nhà", "cao ốc"]),
        ("Skyscraper", ["skyscraper", "tower", "high rise", "nhà cao tầng", "tòa tháp"]),
        ("Bridge", ["bridge", "cầu"]),
        ("Road", ["road", "đường", "con đường"]),
        ("Street", ["street", "alley", "sidewalk", "đường phố", "phố", "hẻm", "ngõ", "vỉa hè"]),
        ("Temple", ["temple", "pagoda", "church", "shrine", "đền", "chùa", "nhà thờ"]),
        ("Castle", ["castle", "palace", "lâu đài", "cung điện"]),
        ("Museum", ["museum", "gallery", "bảo tàng"]),
        ("Handrail", ["railing", "handrail", "balcony", "lan can", "ban công"]),
        ("Bicycle", ["bicycle", "bike", "xe đạp"]),
        ("Car", ["car", "ô tô", "oto", "xe hơi"]),
        ("Boat", ["boat", "ship", "thuyền", "tàu"]),
        ("Cup", ["cup", "mug", "cốc", "ly", "tách"]),
        ("Coffee", ["coffee", "cafe", "café", "coffee shop", "cà phê", "quán cà phê", "quán cafe"]),
        ("Cappuccino", ["cappuccino", "latte"]),
        ("Umbrella", ["umbrella", "ô dù", "dù", "cây dù"]),
        ("Balloon", ["balloon", "bóng bay"]),
    ]

    /// Từ đệm — bỏ qua, không báo là "không hiểu". Viết KHÔNG DẤU.
    private static let stop: Set<String> = [
        // tiếng Anh
        "a", "an", "the", "with", "and", "or", "at", "in", "on", "of", "near", "by", "next", "to",
        "some", "my", "for", "place", "spot", "photo", "picture", "shot", "i", "want", "there",
        "is", "are", "beside", "under", "front", "big", "small", "nice", "beautiful", "view",
        "background", "old", "new", "white", "black",
        // tiếng Việt
        "co", "o", "va", "gan", "canh", "mot", "nhung", "cac", "cho", "tai", "trong", "ben",
        "tren", "duoi", "chup", "anh", "toi", "muon", "noi", "khu", "rat", "dep", "cai", "la",
        "voi", "nhieu", "it", "quan", "truoc", "sau", "nen", "to", "nho", "lon", "trang", "den",
        "hoac", "hay", "kieu", "ngoai",
    ]

    /// Cụm dài nhất có trong từ điển, tính theo số từ.
    private static let maxWords = 3

    /// `associateBy` của Kotlin: trùng khoá thì mục SAU thắng.
    private static let byExact: [String: String] = {
        var out: [String: String] = [:]
        for (label, ws) in words { for w in ws { out[norm(w)] = label } }
        return out
    }()

    /// `groupBy` rồi lấy `first()`: trùng khoá thì mục TRƯỚC thắng.
    private static let byPlain: [String: String] = {
        var out: [String: String] = [:]
        for (label, ws) in words {
            for w in ws {
                let p = plain(norm(w))
                if out[p] == nil { out[p] = label }
            }
        }
        return out
    }()

    private static let tokenRegex = try! NSRegularExpression(pattern: #"[\p{L}\p{N}]+"#)
    private static let markRegex = try! NSRegularExpression(pattern: #"\p{Mn}+"#)

    public static func parse(_ text: String) -> Parsed {
        let s = norm(text)
        let tokens = tokenRegex.matches(in: s, range: NSRange(s.startIndex..., in: s)).map {
            String(s[Range($0.range, in: s)!])
        }
        var labels: [String] = []
        var unknown: [String] = []
        var i = 0
        while i < tokens.count {
            var hit: (String, Int)?
            // Cụm dài trước: "bãi biển" là bãi biển, không phải "biển" thừa chữ "bãi".
            for n in stride(from: min(maxWords, tokens.count - i), through: 1, by: -1) {
                if let label = lookup(Array(tokens[i..<(i + n)])) { hit = (label, n); break }
            }
            if let hit {
                if !labels.contains(hit.0) { labels.append(hit.0) }
                i += hit.1
            } else {
                if !stop.contains(plain(tokens[i])) { unknown.append(tokens[i]) }
                i += 1
            }
        }
        return Parsed(labels: labels, unknown: unknown)
    }

    private static func lookup(_ words: [String]) -> String? {
        for cand in variants(words) {
            if let l = byExact[cand] { return l }
            // Gõ không dấu thì so không dấu. Gõ có dấu mà sai dấu thì KHÔNG khớp.
            if cand.unicodeScalars.elementsEqual(plain(cand).unicodeScalars), let l = byPlain[cand] { return l }
        }
        return nil
    }

    /// Cụm như gõ, rồi cụm bỏ số nhiều tiếng Anh ở từ cuối. Thử cả "-s" lẫn "-es": "trees" → "tree",
    /// "benches" → "bench".
    private static func variants(_ words: [String]) -> [String] {
        let head = words.dropLast()
        let last = words.last!
        // `length` của Kotlin đếm đơn vị UTF-16.
        let len = last.utf16.count
        var out = [words.joined(separator: " ")]
        if len > 3 && last.hasSuffix("s") && !last.hasSuffix("ss") {
            out.append((head + [String(last.dropLast(1))]).joined(separator: " "))
        }
        if len > 4 && last.hasSuffix("es") {
            out.append((head + [String(last.dropLast(2))]).joined(separator: " "))
        }
        return out
    }

    private static func norm(_ s: String) -> String { s.lowercased().precomposedStringWithCanonicalMapping }

    /// Bỏ dấu tiếng Việt (và mọi dấu Latin khác): "cà phê" → "ca phe".
    private static func plain(_ s: String) -> String {
        let d = s.decomposedStringWithCanonicalMapping
        let bo = markRegex.stringByReplacingMatches(in: d, range: NSRange(d.startIndex..., in: d), withTemplate: "")
        return bo.replacingOccurrences(of: "đ", with: "d")
    }
}
