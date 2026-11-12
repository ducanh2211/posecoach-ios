import SwiftUI
import UIKit

/// TAB CÀI ĐẶT. Port `KT/settings/SettingsScreen.kt` theo D4 (chốt 12/11/2026): **ngôn ngữ của hệ thống**.
///
/// Khác Android: Android có danh sách Theo máy / English / Tiếng Việt và tự lưu (`LanguageRepository`). iOS có sẵn mục
/// ngôn ngữ RIÊNG TỪNG APP trong Cài đặt của máy — dòng duy nhất ở đây mở thẳng trang Cài đặt của app. Không port
/// `LanguageRepository` / `AppLanguage` / `AppLanguageTest`. Màn không có trạng thái nên không có ViewModel.
///
/// Mục ghi công CC BY 4.0 (GeoCalib, Laval Indoor HDR) chưa có — người dùng chốt làm trước khi phát hành (12/11/2026).
struct SettingsView: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("settings_title"))
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 10)
            Text(LocalizedStringKey("settings_language"))
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 18)
            Text(LocalizedStringKey("settings_language_hint"))
                .font(.system(size: 12)).foregroundStyle(Ds.textMuted)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                HStack {
                    Text(LocalizedStringKey("settings_language_system")).font(.system(size: 15))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app").foregroundStyle(Ds.textMuted)
                }
                .padding(12)
                .background(Ds.surface, in: RoundedRectangle(cornerRadius: Ds.rCard))
                .contentShape(RoundedRectangle(cornerRadius: Ds.rCard))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Spacer()
        }
        .foregroundStyle(Ds.text)
        .padding(.horizontal, Ds.pageH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Ds.bg)
    }
}
