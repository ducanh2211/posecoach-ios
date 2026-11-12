/// TỈ LỆ KHUNG CHỤP — người dùng tự chọn như app camera của máy (19/09/2026). Port từ `KT/capture/TiLeKhung.kt`.
///
/// PO: *"Tỉ lệ frame preview camera thì lấy theo các tỉ lệ tiêu chuẩn thôi … 3:4, 9:16, 1:1, full"*.
/// Khung KHÔNG còn đổi theo ảnh mẫu (FOOTGUNS 97).
///
/// ⚠️ Một tỉ lệ phải áp ĐỒNG THỜI cho bốn chỗ, lệch một chỗ là người dùng canh một khung mà nhận về ảnh
/// khung khác:
///
/// | Chỗ | Android | iOS |
/// |---|---|---|
/// | Xem trước | `CaptureScreen` — ô đúng tỉ lệ, FILL_CENTER | `Features/Capture` (4c) |
/// | Phép đo live | `CaptureViewModel` — `PoseFrame.croppedToAspect` | `Features/Capture` (4c) |
/// | Góc mở dọc | `CaptureController.verticalFovDeg` | `Services/Camera` (3b) |
/// | Ảnh ra | `ShotSession` — `ShotStore.cropToAspect` + cắt khung xương | `Features/Capture` + `Services/Media` |
///
/// Mọi tỉ lệ đều là phần GIỮA của cảm biến, nên bốn chỗ cắt cùng một vùng.
public enum TiLeKhung: CaseIterable, Sendable {
    case baBon
    case chinMuoiSau
    case vuong
    /// Lấp đầy màn hình — tỉ lệ lấy theo màn hình của từng máy.
    case full

    public var nhan: String {
        switch self {
        case .baBon: return "3:4"
        case .chinMuoiSau: return "9:16"
        case .vuong: return "1:1"
        case .full: return "Full"
        }
    }

    private var rongTrenCao: Double? {
        switch self {
        case .baBon: return 3.0 / 4.0
        case .chinMuoiSau: return 9.0 / 16.0
        case .vuong: return 1.0
        case .full: return nil
        }
    }

    /// Tỉ lệ ngang/dọc khi cầm DỌC. `manHinh` = ngang/dọc của vùng xem trước.
    public func tiLe(_ manHinh: Double) -> Double { rongTrenCao ?? manHinh }

    public func tiep() -> TiLeKhung {
        let entries = TiLeKhung.allCases
        let ordinal = entries.firstIndex(of: self)!
        return entries[(ordinal + 1) % entries.count]
    }

    /// Khung hình nằm ngang (cầm máy ngang) thì lật tỉ lệ cho đúng chiều.
    public static func theoHuong(_ tiLeDoc: Double, _ rong: Int, _ cao: Int) -> Double {
        rong > cao ? 1.0 / tiLeDoc : tiLeDoc
    }
}
