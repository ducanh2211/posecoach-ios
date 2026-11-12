import SwiftUI

/// Nút tròn phụ hai bên nút chụp — màn chụp và camera bối cảnh. Bị khoá thì mờ hẳn chứ không biến mất — biến mất thì
/// hàng nút giật, nút chụp lệch tâm.
struct NutTronPhu: View {

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
