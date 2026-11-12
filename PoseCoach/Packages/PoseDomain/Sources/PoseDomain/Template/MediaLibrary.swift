import Foundation

/// THƯ VIỆN ẢNH MẪU — phần ĐỌC NHÃN TRONG TÊN FILE. Port từ `KT/media/MediaLibrary.kt`.
///
/// ⚠️ Chỉ phần thuần (đọc tên file, tính tên mới). Phần chạm đĩa của bản Kotlin (thư mục ảnh mẫu, chép ảnh cài
/// sẵn, đổi tên file thật) nằm ở `Services/Media` dưới dạng `extension MediaLibrary` (Phase 3).
///
/// Thông tin của ảnh mẫu nằm ngay trong TÊN FILE: `<nhóm>-<góc>-[<kiểu trên>-]<tên>.<đuôi>`, vd.
/// `selfie-tren-tai-nghe-nhin-nghieng.jpg`. Ảnh cài sẵn và ảnh tự nhập đi ĐÚNG MỘT đường code.
public enum MediaLibrary {

    public static let imageExt: Set<String> = ["jpg", "jpeg", "png", "webp", "jfif"]

    /// NHÓM ẢNH MẪU — ai cầm máy khi chụp ra bức ảnh đó. Nhận bằng TIỀN TỐ TÊN FILE:
    /// `selfie-*` → selfie · `mirror-*` → mirror · `tripod-*` → tripod · còn lại → photographer.
    /// Quyết định chế độ chụp, xem `ShootMode`.
    public enum TemplateKind: CaseIterable, Sendable {
        case photographer
        case selfie
        case mirror
        /// Đặt máy tự chụp bằng camera trước (17/10/2026). Xem `ShootMode.datMay`.
        case tripod

        /// Key String Catalog (xem `UiText`).
        public var labelRes: String {
            switch self {
            case .photographer: return "kind_photographer"
            case .selfie: return "kind_selfie"
            case .mirror: return "kind_mirror"
            case .tripod: return "kind_tripod"
            }
        }

        public var prefix: String {
            switch self {
            case .photographer: return ""
            case .selfie: return "selfie-"
            case .mirror: return "mirror-"
            case .tripod: return "tripod-"
            }
        }

        public static func of(_ fileName: String) -> TemplateKind {
            let n = fileName.lowercased()
            return allCases.first { !$0.prefix.isEmpty && n.hasPrefix($0.prefix) } ?? .photographer
        }
    }

    /// Một ảnh mẫu trong thư viện.
    public struct Template: Hashable, Sendable {
        public let file: URL

        public init(_ file: URL) { self.file = file }

        public var kind: TemplateKind { TemplateKind.of(file.lastPathComponent) }

        /// Tên hiển thị: bỏ tiền tố nhóm, bỏ nhãn góc, bỏ đuôi, gạch ngang thành khoảng trắng.
        public var displayName: String {
            boNhanGoc(
                nameWithoutExtension(file.lastPathComponent).removingPrefix(String(kind.prefix.removingSuffix("-")) + "-")
            )
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        }
    }

    /// NHÃN GÓC MÁY trong tên file ảnh mẫu → độ nghiêng máy cần có, ĐỘ. Từ đầu tiên sau tiền tố nhóm:
    /// `tren` −35° · `ngang` 0° · `duoi` +25°.
    ///
    /// Gán tay cho MỌI ảnh mẫu (16/09/2026): suy góc máy từ ảnh lẫn cả dáng đứng lẫn ống kính (FOOTGUNS 91), và
    /// ảnh selfie không có cách nào suy được. Có nhãn thì nhãn THẮNG phép suy từ ảnh. `nil` = không có nhãn.
    public static func gocMayTheoNhan(_ nameWithoutExtension: String) -> Double? {
        GocMayNhan.cua(nameWithoutExtension)?.doNghieng
    }

    /// Ba mức góc máy gán tay. Xem `gocMayTheoNhan`.
    public enum GocMayNhan: CaseIterable, Sendable {
        case tren
        case ngang
        case duoi

        public var tu: String {
            switch self {
            case .tren: return "tren"
            case .ngang: return "ngang"
            case .duoi: return "duoi"
            }
        }

        /// Key String Catalog (xem `UiText`).
        public var nhanRes: String {
            switch self {
            case .tren: return "angle_high"
            case .ngang: return "angle_level"
            case .duoi: return "angle_low"
            }
        }

        public var doNghieng: Double {
            switch self {
            case .tren: return -35.0
            case .ngang: return 0.0
            case .duoi: return 25.0
            }
        }

        public static func cua(_ nameWithoutExtension: String) -> GocMayNhan? {
            let tu = tuDauSauTienTo(nameWithoutExtension)
            return allCases.first { $0.tu == tu }
        }
    }

    /// NHÃN KIỂU CHỤP TỪ TRÊN CAO — từ THỨ HAI sau tiền tố nhóm, chỉ có nghĩa khi từ thứ nhất là `tren`:
    /// `tren-gan-…` · `tren-xa-…` (`tren-rong-…` cũ đọc thành gần). Xem `KieuChupTren`.
    public static func kieuChupTrenTheoNhan(_ nameWithoutExtension: String) -> KieuChupTren? {
        if GocMayNhan.cua(nameWithoutExtension) != .tren { return nil }
        let n = nameWithoutExtension.lowercased()
        let kind = TemplateKind.of(n)
        let sau = !kind.prefix.isEmpty ? n.removingPrefix(kind.prefix) : n
        return KieuChupTren.cuaTu(sau.substringAfter("-", missing: "").substringBefore("-"))
    }

    /// Ảnh người dùng tự nhập — tên do `ganNhan` hoặc hàm chép ảnh đặt.
    public static func laAnhNhap(_ file: URL) -> Bool {
        nameWithoutExtension(file.lastPathComponent).contains(tienToNhap)
    }

    /// Gốc tên của ảnh tự nhập, dùng khi chép vào thư viện.
    public static let tienToNhap = "toi-chon-"

    /// GÁN KIỂU CHỤP VÀ GÓC MÁY cho ảnh tự nhập — tính TÊN FILE MỚI.
    ///
    /// Ảnh tự nhập được chép vào dưới tên `toi-chon-<giờ>.jpg` — không mang thông tin gì: không có `selfie-` thì
    /// app mở sai camera, selfie mất hai mục góc máy. Gán vào tên file để ảnh tự nhập chạy đúng một đường code
    /// như ảnh cài sẵn.
    ///
    /// ⚠️ Bản Kotlin đổi tên file luôn và trả `File`. Ở đây chỉ trả TÊN MỚI; việc đổi tên trên đĩa (và trả lại
    /// file cũ khi thất bại) do `Services/Media` làm. Tên mới trùng tên cũ = không cần đổi.
    ///
    /// - Parameter kieuTren: chỉ ghi khi `goc` là `.tren`.
    public static func ganNhan(
        _ fileName: String,
        _ kind: TemplateKind,
        _ goc: GocMayNhan?,
        _ kieuTren: KieuChupTren? = nil
    ) -> String {
        let goc0 = nameWithoutExtension(fileName)
        // Lột mọi tiền tố nhóm và nhãn góc cũ, chỉ giữ phần gốc "toi-chon-<giờ>".
        let loiTen: Substring
        if let r = goc0.range(of: tienToNhap) { loiTen = goc0[r.lowerBound...] } else { loiTen = Substring(goc0) }
        var tenMoi = kind.prefix
        if let goc { tenMoi += goc.tu + "-" }
        if goc == .tren, let kieuTren { tenMoi += kieuTren.tu + "-" }
        tenMoi += loiTen
        return tenMoi + "." + fileExtension(fileName)
    }

    private static func tuDauSauTienTo(_ ten: String) -> String {
        let n = ten.lowercased()
        let kind = TemplateKind.of(n)
        let sau = !kind.prefix.isEmpty ? n.removingPrefix(kind.prefix) : n
        return sau.substringBefore("-")
    }

    private static func boNhanGoc(_ tenSauTienTo: String) -> String {
        let tu = tenSauTienTo.substringBefore("-").lowercased()
        if !(GocMayNhan.allCases.contains { $0.tu == tu } && tenSauTienTo.contains("-")) { return tenSauTienTo }
        let sau = tenSauTienTo.substringAfter("-")
        // Sau nhãn "tren" có thể còn nhãn kiểu chụp — bỏ nốt.
        let tu2 = sau.substringBefore("-").lowercased()
        return tu == GocMayNhan.tren.tu && KieuChupTren.cuaTu(tu2) != nil && sau.contains("-")
            ? sau.substringAfter("-")
            : sau
    }

    /// `File.nameWithoutExtension` của Kotlin: bỏ phần từ dấu chấm CUỐI.
    private static func nameWithoutExtension(_ name: String) -> String {
        guard let r = name.range(of: ".", options: .backwards) else { return name }
        return String(name[..<r.lowerBound])
    }

    /// `File.extension` của Kotlin: phần sau dấu chấm CUỐI, không có thì rỗng.
    private static func fileExtension(_ name: String) -> String {
        guard let r = name.range(of: ".", options: .backwards) else { return "" }
        return String(name[r.upperBound...])
    }
}

// Các hàm chuỗi của Kotlin dùng ở trên — giữ đúng ngữ nghĩa khi không tìm thấy dấu phân cách.
private extension String {
    /// `substringBefore`: không thấy thì trả cả chuỗi.
    func substringBefore(_ d: String) -> String {
        guard let r = range(of: d) else { return self }
        return String(self[..<r.lowerBound])
    }

    /// `substringAfter`: không thấy thì trả `missing` (mặc định cả chuỗi).
    func substringAfter(_ d: String, missing: String? = nil) -> String {
        guard let r = range(of: d) else { return missing ?? self }
        return String(self[r.upperBound...])
    }

    func removingPrefix(_ p: String) -> String { hasPrefix(p) ? String(dropFirst(p.count)) : self }

    func removingSuffix(_ s: String) -> String { hasSuffix(s) ? String(dropLast(s.count)) : self }
}
