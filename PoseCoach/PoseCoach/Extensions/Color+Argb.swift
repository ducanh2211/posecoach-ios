import SwiftUI

extension Color {
    /// Màu từ mã `0xAARRGGBB` — cùng cách viết `Color(0xFF2E86FF)` của Compose, để chép mã màu từ Kotlin không phải đổi.
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
