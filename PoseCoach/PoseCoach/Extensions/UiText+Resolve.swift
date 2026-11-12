import Foundation
import PoseDomain
import SwiftUI

/// Đổi `UiText` (mã câu + số liệu) ra chữ theo ngôn ngữ của máy. Port phần `resolve` của `KT/ui/UiText.kt`.
///
/// Key = tên resource Android, chữ nằm trong `Localizable.xcstrings`. Tham số lồng `UiText` được dịch trước rồi mới ghép.
nonisolated extension UiText {

    func resolved(_ bundle: Bundle = .main) -> String {
        switch self {
        case let .res(key, args):
            let format = bundle.localizedString(forKey: key, value: nil, table: nil)
            if args.isEmpty { return format }
            return String(format: format, locale: Self.locale(args), arguments: Self.cArgs(args, bundle))
        case let .plural(key, _, args):
            // Như `getQuantityString(id, count, *args)`: biến số nhiều trong String Catalog gắn với tham số đầu tiên,
            // mà nơi tạo luôn để `count` ở đó (vd. `.plural("steps_n", count: 2, [.int(2)])`).
            let format = bundle.localizedString(forKey: key, value: nil, table: nil)
            return String(format: format, locale: Self.locale(args), arguments: Self.cArgs(args, bundle))
        case let .join(parts, separator):
            return parts.map { $0.resolved(bundle) }.joined(separator: separator)
        case let .raw(value):
            return value
        }
    }

    /// Locale để định dạng số. Java (`getString`) viết số thực theo ngôn ngữ (`1,5` tiếng Việt) nhưng KHÔNG nhóm hàng nghìn
    /// số nguyên (`%d` → `11805`); `String(format:locale:)` có locale thì nhóm cả số nguyên (`11.805`). Nên chỉ dùng locale
    /// khi có số thực — hiện chỉ `result_shot_header`, câu đó không có số nguyên.
    private static func locale(_ args: [UiTextArg]) -> Locale? {
        args.contains { if case .double = $0 { true } else { false } } ? .current : nil
    }

    private static func cArgs(_ args: [UiTextArg], _ bundle: Bundle) -> [CVarArg] {
        args.map { arg -> CVarArg in
            switch arg {
            case let .int(v): v
            case let .double(v): v
            case let .string(v): v
            case let .text(t): t.resolved(bundle)
            }
        }
    }
}

extension Text {
    /// `Text` từ `UiText` — chữ đã dịch, không qua tra key lần nữa.
    init(_ text: UiText) {
        self.init(verbatim: text.resolved())
    }
}
