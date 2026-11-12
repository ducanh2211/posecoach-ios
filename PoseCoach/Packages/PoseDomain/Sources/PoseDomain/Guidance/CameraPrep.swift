// Port từ `KT/guidance/CameraPrep.kt`.

/// CẢNH BÁO VỀ CÁCH CẦM MÁY — kiểm TRƯỚC các tiêu chí.
///
/// Tách khỏi các tiêu chí vì chúng làm **mọi phép đo phía sau mất nghĩa**: cầm máy ngang trong khi ảnh mẫu dọc
/// thì có đứng đúng chỗ tới đâu ảnh ra vẫn không giống. Phải sửa cách cầm máy trước, rồi mới nói tới chỗ đứng.
public enum CameraPrep {

    /// Zoom lệch quá mức này thì cảnh báo. ⚠️ Không còn dùng — cảnh báo zoom đã bỏ 07/09/2026 (xem dưới).
    private static let zoomTolerance: Float = 0.05

    /// - Parameters:
    ///   - devicePortrait: máy đang cầm dọc hay ngang.
    ///   - templatePortrait: ảnh mẫu là ảnh dọc hay ngang. `nil` = chưa biết.
    ///   - zoomRatio: mức zoom hiện tại, 1,0 = tiêu cự gốc.
    /// - Returns: câu cảnh báo, `nil` = cầm máy đang ổn.
    public static func warningFor(_ devicePortrait: Bool, _ templatePortrait: Bool?, _ zoomRatio: Float) -> UiText? {
        // Hướng máy xét trước: cầm sai hướng thì zoom đúng cũng vô nghĩa.
        if let templatePortrait, devicePortrait != templatePortrait {
            return uiText(templatePortrait ? "prep_turn_portrait" : "prep_turn_landscape")
        }

        // ⚠️ ĐÃ BỎ HẲN CẢNH BÁO ZOOM (07/09/2026). Cảnh báo cầm máy CHẶN TOÀN BỘ lời nhắc, nên nó thành ngõ cụt:
        // app vừa bảo *"tiến lên 2 bước, HOẶC zoom vào từ từ"*, người dùng zoom, rồi bị chặn (FOOTGUNS 41, 57).
        return nil
    }
}
