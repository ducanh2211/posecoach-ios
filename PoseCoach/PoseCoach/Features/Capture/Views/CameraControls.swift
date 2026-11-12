import PoseDomain
import SwiftUI

/// CỤM NÚT CHỤP — nút tròn lớn ở giữa, hai nút phụ hai bên. Port `CameraControls` (`KT/capture/CaptureScreen.kt`).
///
/// Nút giữa đúng quy ước camera gốc: chụp ảnh lõi TRẮNG, video lõi ĐỎ, đang quay lõi đỏ VUÔNG (bấm để dừng).
///
/// Khác Android: icon dùng SF Symbols (Android tự vẽ bằng Canvas vì không có thư viện icon).
struct CameraControls: View {

    let state: CaptureUiState
    let enabled: Bool
    let burstCount: Int
    let onToggle: () -> Void
    let onOpenLibrary: () -> Void
    let onFlipCamera: () -> Void

    var body: some View {
        // Đang quay hoặc đang chụp liên tiếp thì KHOÁ hai nút phụ: rời màn giữa chừng là mất đoạn đang quay, còn xoay
        // camera là phải gắn lại toàn bộ camera.
        let dangBan = state.recording || state.burstTaken > 0
        VStack(spacing: 0) {
            if state.recording {
                Text(verbatim: String(format: "● %.1fs / %.0fs", locale: .current,
                                      Double(state.recordedMs) / 1000, Double(CaptureUiState.maxRecordMs) / 1000))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Ds.recording)
                    .padding(.bottom, 8)
            } else if state.burstTaken > 0 {
                Text(uiText("capture_burst_taken", .int(state.burstTaken), .int(burstCount)))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Ds.recording)
                    .padding(.bottom, 8)
            }

            // Ba ô CHIA ĐỀU nên nút chụp luôn nằm đúng giữa, hai nút phụ đối xứng.
            HStack(spacing: 0) {
                NutTronPhu(systemImage: "photo.on.rectangle", label: "tab_library", enabled: !dangBan,
                           action: onOpenLibrary)
                    .frame(maxWidth: .infinity)
                shutter.frame(maxWidth: .infinity)
                NutTronPhu(systemImage: "arrow.triangle.2.circlepath.camera", label: nil,
                           enabled: !dangBan, action: onFlipCamera)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)

            Text(hint)
                .font(.system(size: 11))
                .foregroundStyle(Color(argb: 0xCCFFFFFF))
                .padding(.top, 8)
        }
        .padding(.bottom, 10)
    }

    private var hint: UiText {
        if state.recording && !state.canStop { return uiText("capture_hold_still") }
        if state.recording { return uiText("capture_tap_to_stop") }
        if state.burstTaken > 0 { return uiText("capture_burst_shooting") }
        if state.burstMode { return uiText("capture_tap_burst", .int(burstCount)) }
        return uiText("capture_tap_record")
    }

    private var shutter: some View {
        let dangQuay = state.recording
        let bamDuoc = enabled && (!state.recording || state.canStop) && state.burstTaken == 0
        let loi: Color = !enabled ? Color(argb: 0x66FFFFFF)
            : dangQuay ? Ds.recording
            : state.burstMode && state.burstTaken > 0 ? Color(argb: 0xFFDDDDDD)
            : state.burstMode ? .white
            : Ds.recording
        return Button(action: onToggle) {
            ZStack {
                Circle().fill(Color(argb: 0x40FFFFFF))
                RoundedRectangle(cornerRadius: dangQuay ? 8 : 30)
                    .fill(loi)
                    .frame(width: dangQuay ? 30 : 60, height: dangQuay ? 30 : 60)
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(.plain)
        .disabled(!bamDuoc)
        .accessibilityLabel(Text(LocalizedStringKey(dangQuay ? "capture_tap_to_stop"
                                                    : state.burstMode ? "capture_mode_photo" : "capture_mode_video")))
    }
}

/// Nút tròn phụ hai bên nút chụp. Bị khoá thì mờ hẳn chứ không biến mất — biến mất thì hàng nút giật, nút chụp lệch tâm.
private struct NutTronPhu: View {

    let systemImage: String
    /// Key nhãn đọc màn hình. `nil` = để tên mặc định của biểu tượng (Kotlin không gắn nhãn).
    let label: String?
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .opacity(enabled ? 1 : 0.35)
                .frame(width: 48, height: 48)
                .background(Color(argb: enabled ? 0x59000000 : 0x26000000), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .modifier(NhanDocManHinh(key: label))
    }
}

private struct NhanDocManHinh: ViewModifier {
    let key: String?
    func body(content: Content) -> some View {
        if let key { content.accessibilityLabel(Text(LocalizedStringKey(key))) } else { content }
    }
}
