// Port từ `KT/guidance/ShootMode.kt`.

/// AI ĐANG CẦM MÁY, và hình có bị lật gương không.
///
/// | | Ai cầm máy | Hình có lật không |
/// |---|---|---|
/// | `nguoiKhac` | Người thứ hai | Không |
/// | `tuChupGuong` | **Chính người mẫu** | **Có** — do gương, không phải do app |
///
/// Tự chụp thì chỉ có MỘT người và người đó **nhìn thấy màn hình** — câu *"Bảo mẫu xoay người"* thành vô nghĩa.
/// Lật gương **đảo chiều** hai câu nhắc: lệch trái/phải và nghiêng ngang (FOOTGUNS 48, 54, 78).
public enum ShootMode: CaseIterable, Sendable {
    /// Người thứ hai cầm máy. Mặc định.
    case nguoiKhac
    /// Tự chụp bằng cách chĩa camera SAU vào gương.
    case tuChupGuong
    /// Tự chụp bằng camera TRƯỚC, cầm trên tay.
    case tuChupCamTruoc
    /// ĐẶT MÁY TỰ CHỤP (17/10/2026): camera TRƯỚC, máy đứng yên, người dùng đứng làm mẫu, máy tự đếm ngược rồi
    /// chụp. Đi theo ảnh mẫu nhóm `tripod-`. Hai giai đoạn: đặt máy (`DatMayGate`) rồi vào khung.
    case datMay

    /// Người cầm máy có phải chính là mẫu không. Đổi GIỌNG câu nhắc.
    public var tuChup: Bool { self != .nguoiKhac }

    /// Hình lưu ra có bị LẬT NGANG không. Đổi CHỮ trái/phải ở câu nhắc dáng.
    ///
    /// Gương thì do vật lý. Camera trước thì do app cố tình lật khi ghi — *người dùng nhìn màn hình thế nào thì
    /// muốn ảnh ra thế đó* (06/09/2026).
    public var latGuong: Bool { self != .nguoiKhac }

    /// Dịch máy trên màn hình có NGƯỢC CHIỀU so với camera thường không.
    ///
    /// ⚠️ Khác nhau giữa hai kiểu tự chụp (FOOTGUNS 49): soi gương → `false` (cảnh trong gương là cảnh TĨNH);
    /// camera trước → `true` (chính APP lật khung xem trước).
    public var mayNguocChieu: Bool { self == .tuChupCamTruoc }

    /// Khoảng cách bị chặn ở TẦM TAY (~0,3-0,8m) — câu *"lùi lại 2 bước"* thành co/duỗi tay.
    public var tamTay: Bool { self == .tuChupCamTruoc }

    /// Dùng camera trước hay camera sau.
    public var camTruoc: Bool { self == .tuChupCamTruoc || self == .datMay }

    /// Máy đứng yên, người tự đi vào khung — câu nhắc chỗ đứng nói bước chân, không nói dịch máy.
    public var datMay: Bool { self == .datMay }
}
