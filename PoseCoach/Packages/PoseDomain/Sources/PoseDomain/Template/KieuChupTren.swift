/// KIỂU CHỤP TỪ TRÊN CAO — nhãn thứ hai, CHỈ cho ảnh người khác chụp gắn nhãn "trên cao" (19/09/2026).
/// Port từ `KT/template/KieuChupTren.kt`.
///
/// PO: *"chụp 1x — cầm máy giơ lên trên đầu, đứng gần mẫu — sẽ khác với chụp đứng trên cao từ xa và zoom
/// xuống"*. Ảnh không tự tách được với góc máy (FOOTGUNS 99), nên hỏi người dùng — cùng cơ chế nhãn với góc
/// máy (FOOTGUNS 91).
///
/// ⚠️ 1x VÀ 0.5x ĐÃ GỘP LÀM MỘT ("đứng gần") — đo 17 ảnh thì hai kiểu chồng nhau hoàn toàn (FOOTGUNS 100).
///
/// Chỉ đổi CÂU NHẮC khoảng cách/zoom của đúng loại ảnh này. Không đụng tiêu chí nào khác.
public enum KieuChupTren: CaseIterable, Sendable {
    case gan
    case xaZoom

    public var tu: String {
        switch self {
        case .gan: return "gan"
        case .xaZoom: return "xa"
        }
    }

    /// Key String Catalog (xem `UiText`).
    public var nhanRes: String {
        switch self {
        case .gan: return "high_close"
        case .xaZoom: return "high_far"
        }
    }

    /// Key String Catalog (xem `UiText`).
    public var goiYRes: String {
        switch self {
        case .gan: return "high_close_hint"
        case .xaZoom: return "high_far_hint"
        }
    }

    /// Mức zoom lớn nhất được phép; `nil` = tự do (kiểu từ xa rồi zoom).
    public var zoomToiDa: Float? {
        switch self {
        case .gan: return 1
        case .xaZoom: return nil
        }
    }

    public static func cuaTu(_ tu: String) -> KieuChupTren? {
        switch tu {
        // Nhãn "rong" (góc rộng) của bản đầu nay thuộc "đứng gần".
        case "rong": return .gan
        default: return allCases.first { $0.tu == tu }
        }
    }
}
