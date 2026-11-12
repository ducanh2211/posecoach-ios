import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/TestStrings.kt` — ĐỔI `UiText` RA CHỮ TRONG BÀI KIỂM THỬ, không cần chạy app.
///
/// Tầng hướng dẫn trả "mã câu" chứ không trả chữ. Test chạy trên Mac không có bundle của app, nên đọc thẳng
/// `PoseCoach/Resources/Localizable.xcstrings` — đúng tệp chữ app dùng (Android đọc `strings.xml`).
///
/// ⚠️ QUY TẮC GHÉP THAM SỐ — bộ đổi chữ của app (Phase 4a) PHẢI theo đúng quy tắc này:
///  - `%lld` / `%N$lld` ← `UiTextArg.int`. Tham số kiểu khác vào chỗ này là LỖI (test đỏ).
///  - `%@` / `%N$@` ← `.string`, `.text` (đổi ra chữ trước). Android truyền SỐ vào `%s` thì iOS là `%@` nhận
///    `.int` / `.double` — đổi số ra chữ như Kotlin `toString()` (`1`, `2.5`).
///  - `%%` → `%`.
enum TestStrings {
    private struct Table: Sendable {
        let strings: [String: String]
        let plurals: [String: [String: String]]
    }

    private static let tables: [String: Table] = load()

    /// `…/PoseDomain/Tests/PoseDomainTests/Support/TestStrings.swift` → `…/PoseCoach/PoseCoach/Resources/`.
    private static func load() -> [String: Table] {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        url.appendPathComponent("PoseCoach/Resources/Localizable.xcstrings")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["strings"] as? [String: Any] else {
            fatalError("Không đọc được \(url.path)")
        }
        var strings: [String: [String: String]] = [:]
        var plurals: [String: [String: [String: String]]] = [:]
        for (key, raw) in entries {
            guard let locs = (raw as? [String: Any])?["localizations"] as? [String: Any] else { continue }
            for (lang, l) in locs {
                guard let l = l as? [String: Any] else { continue }
                if let v = (l["stringUnit"] as? [String: Any])?["value"] as? String {
                    strings[lang, default: [:]][key] = v
                } else if let p = (l["variations"] as? [String: Any])?["plural"] as? [String: Any] {
                    var q: [String: String] = [:]
                    for (quantity, item) in p {
                        if let v = ((item as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String {
                            q[quantity] = v
                        }
                    }
                    plurals[lang, default: [:]][key] = q
                }
            }
        }
        var out: [String: Table] = [:]
        for lang in Set(strings.keys).union(plurals.keys) {
            out[lang] = Table(strings: strings[lang] ?? [:], plurals: plurals[lang] ?? [:])
        }
        return out
    }

    static func resolve(_ t: UiText, _ lang: String) -> String {
        switch t {
        case let .res(key, args):
            return format(string(key, lang), args, lang)
        case let .plural(key, count, args):
            guard let q = tables[lang]?.plurals[key] else {
                Issue.record("Thiếu plural '\(key)' (\(lang))")
                return key
            }
            // Như Kotlin: count == 1 và có "one" thì lấy "one", còn lại "other".
            let text = (count == 1 ? q["one"] : nil) ?? q["other"] ?? key
            return format(text, args, lang)
        case let .join(parts, separator):
            return parts.map { resolve($0, lang) }.joined(separator: separator)
        case let .raw(value):
            return value
        }
    }

    static func string(_ key: String, _ lang: String) -> String {
        guard let s = tables[lang]?.strings[key] else {
            Issue.record("Thiếu chuỗi '\(key)' (\(lang))")
            return key
        }
        return s
    }

    private static let spec = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?(lld|@|%)"#)

    private static func format(_ text: String, _ args: [UiTextArg], _ lang: String) -> String {
        if args.isEmpty { return text }
        let ns = text as NSString
        var out = ""
        var last = 0
        var next = 0
        for m in spec.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            last = m.range.location + m.range.length
            let kind = ns.substring(with: m.range(at: 2))
            if kind == "%" { out += "%"; continue }
            let index: Int
            if m.range(at: 1).location != NSNotFound {
                index = Int(ns.substring(with: m.range(at: 1)))! - 1
            } else {
                index = next
                next += 1
            }
            guard args.indices.contains(index) else {
                Issue.record("'\(text)': thiếu tham số thứ \(index + 1)")
                continue
            }
            out += render(args[index], kind, text, lang)
        }
        out += ns.substring(from: last)
        return out
    }

    private static func render(_ a: UiTextArg, _ kind: String, _ text: String, _ lang: String) -> String {
        switch (kind, a) {
        case let ("lld", .int(i)), let ("@", .int(i)):
            return "\(i)"
        case let ("@", .double(d)):
            return "\(d)"
        case let ("@", .string(s)):
            return s
        case let ("@", .text(t)):
            return resolve(t, lang)
        default:
            Issue.record("'\(text)': tham số \(a) không ghép được vào %\(kind)")
            return ""
        }
    }
}

extension UiText {
    /// Câu tiếng Việt của mã câu này.
    func vi() -> String { TestStrings.resolve(self, "vi") }
    /// Câu tiếng Anh (ngôn ngữ mặc định) của mã câu này.
    func en() -> String { TestStrings.resolve(self, "en") }
}

/// Chữ tiếng Việt của một chuỗi không có tham số.
func viString(_ key: String) -> String { TestStrings.string(key, "vi") }
