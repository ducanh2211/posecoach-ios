import SwiftUI

/// Bộ mã màu và kích thước lấy từ thiết kế Figma "Photoshot Guide V1". Port `KT/ui/theme/DesignTokens.kt` (`Ds`).
///
/// Gom một chỗ để mọi màn dùng chung — rải màu thẳng vào từng màn là cách chắc chắn nhất để sau vài lần sửa, năm màn
/// có năm sắc xanh khác nhau.
///
/// Khác Android: bỏ `Cues` (câu chỉ dẫn viết cứng tiếng Việt, Kotlin không dùng — câu thật đi qua String Catalog) và bỏ
/// `PosecoachTheme` (Material mặc định, màn nào cũng tự tô bằng `Ds`).
enum Ds {
    // --- Nền và bề mặt ---
    /// Nền màn hình sáng.
    static let bg = Color(argb: 0xFFF4F6FA)
    /// Thẻ, ô, hộp thoại.
    static let surface = Color(argb: 0xFFFFFFFF)
    /// Nền phụ nhạt hơn `surface` một chút — ô ảnh mẫu, thanh tiến trình.
    static let surfaceMuted = Color(argb: 0xFFE9EDF3)

    // --- Chữ ---
    static let text = Color(argb: 0xFF0F1729)
    static let textMuted = Color(argb: 0xFF6B7280)
    static let textOnDark = Color(argb: 0xFFFFFFFF)

    // --- Màu nhấn ---
    /// Xanh chủ đạo: nút chính, thẻ import, thanh tiến trình.
    static let primary = Color(argb: 0xFF2E86FF)
    static let primaryPressed = Color(argb: 0xFF1D6FE0)
    /// Viên điều hướng đang chọn — xanh đen gần như đen.
    static let navActive = Color(argb: 0xFF141B2D)

    // --- Trạng thái ---
    static let success = Color(argb: 0xFF22C55E)
    static let warning = Color(argb: 0xFFF59E0B)
    /// Nút xoá: nền hồng nhạt, chữ đỏ — mềm hơn nút đỏ đặc, tránh doạ người dùng.
    static let dangerSoft = Color(argb: 0xFFFBDDE1)
    static let dangerText = Color(argb: 0xFFE5484D)
    /// Chấm đỏ khi đang quay.
    static let recording = Color(argb: 0xFFEF4444)

    // --- Lớp phủ trên camera ---
    /// Nền tối cho ô thông tin đặt trên hình camera.
    static let overlayPanel = Color(argb: 0xCC10151F)
    static let overlayScrim = Color(argb: 0x66000000)

    // --- Bo góc ---
    static let rCard: CGFloat = 18
    static let rTile: CGFloat = 16
    static let rPill: CGFloat = 999
    static let rSmall: CGFloat = 10

    // --- Khoảng cách ---
    static let pageH: CGFloat = 18
    static let gap: CGFloat = 12
}
