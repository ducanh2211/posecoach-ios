/// MỐC ĐẶT NGƯỜI TRÊN LƯỚI (11/10/2026) — chỗ người nằm trong khung, theo tỉ lệ 0..1.
/// Port từ `KT/measure/MocLuoi.kt`.
///
/// Đọc bằng `Measurer.mocLuoi` — CÙNG một hàm cho ảnh mẫu và khung camera, như mọi phép đo khác. Chỉ để
/// VẼ lên lưới cho người dùng tự đặt người vào chỗ; KHÔNG phải tiêu chí, không chấm, không chặn chụp.
public struct MocLuoi: Equatable, Sendable {
    /// Mốc trên — đầu (ảnh có thân) hoặc mắt (ảnh chân dung). 0 = mép trên.
    public let trenY: Double?
    /// Mốc dưới — điểm thấp nhất của lớp khung hình: chân / gối / hông / vai.
    public let duoiY: Double?
    /// Trục giữa người theo chiều ngang, cùng mốc với mục "Lệch trái/phải".
    public let giuaX: Double?
    public let loaiTren: LoaiMoc
    public let loaiDuoi: LoaiMoc

    public init(trenY: Double?, duoiY: Double?, giuaX: Double?, loaiTren: LoaiMoc, loaiDuoi: LoaiMoc) {
        self.trenY = trenY
        self.duoiY = duoiY
        self.giuaX = giuaX
        self.loaiTren = loaiTren
        self.loaiDuoi = loaiDuoi
    }
}

/// Tên mốc để ghi nhãn cạnh vạch.
public enum LoaiMoc: Sendable { case dau, mat, chan, goi, hong, vai }
