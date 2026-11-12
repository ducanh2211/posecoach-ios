import PoseDomain
import SwiftUI

/// Hai công tắc chung MỘT hàng: chụp / quay và thủ công / tự động. Port `ModeSwitch`, `AutoSwitch`, `ModeChip`
/// (`KT/capture/CaptureScreen.kt`). Xếp hai hàng thì cụm dưới quá cao, nút tròn bị ép bẹp (FOOTGUNS 104).
struct CaptureSwitches: View {

    let burstMode: Bool
    let autoMode: Bool
    let onBurstChange: (Bool) -> Void
    let onAutoChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Chụp đứng TRƯỚC: là chế độ mặc định và cho ảnh nét nhất.
            nhom {
                chip(uiText("capture_mode_photo"), burstMode) { onBurstChange(true) }
                chip(uiText("capture_mode_video"), !burstMode) { onBurstChange(false) }
            }
            // ⚠️ Tự động KHÔNG phải khoá nút chụp — nút bấm tay vẫn luôn dùng được.
            nhom {
                chip(uiText("capture_manual"), !autoMode) { onAutoChange(false) }
                chip(uiText("capture_auto_countdown", .int(AutoCountdown.autoCountdownSec)), autoMode) { onAutoChange(true) }
            }
        }
    }

    private func nhom<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 0, content: content)
            .padding(3)
            .background(Ds.overlayScrim, in: Capsule())
    }

    private func chip(_ label: UiText, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? Ds.text : Color(argb: 0xCCFFFFFF))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
