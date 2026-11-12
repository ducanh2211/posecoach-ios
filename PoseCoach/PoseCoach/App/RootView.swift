import SwiftUI

/// Điều hướng gốc. Port `AppRoot` trong `KT/MainActivity.kt`: ba tab chính + màn chụp / màn xem lại mở đè toàn màn hình.
///
/// Khác Android: thanh tab dùng `TabView` của iOS (Android tự vẽ ba nút chữ); nút Back của hệ thống không có — màn chụp
/// tự có nút đóng.
struct RootView: View {

    enum Tab: String {
        case templates, library, settings
    }

    /// Màn mở đè lên các tab. Màn xem lại thêm ở 4d.
    enum Route: Identifiable {
        /// Bước 4b truyền ảnh mẫu đã qua cổng kiểm.
        case capture

        var id: String {
            switch self {
            case .capture: "capture"
            }
        }
    }

    /// Nhớ TAB đang mở qua lần dựng lại màn hình (như `ScreenSaver` của Kotlin). Màn chụp không nhớ: dựng lại giữa chừng
    /// thì về tab Ảnh mẫu.
    @SceneStorage("RootView.tab") private var tab: Tab = .templates
    @State private var route: Route?

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                placeholder("tab_templates") {
                    // Tạm vào thẳng màn chụp (chưa có ảnh mẫu) — 4b thay bằng lưới ảnh mẫu + cổng kiểm.
                    Button(LocalizedStringKey("gate_start")) { route = .capture }
                        .buttonStyle(.borderedProminent)
                        .tint(Ds.primary)
                }
            }
            .tabItem { Label(LocalizedStringKey("tab_templates"), systemImage: "photo.on.rectangle.angled") }
            .tag(Tab.templates)

            NavigationStack { placeholder("tab_library") { EmptyView() } }
                .tabItem { Label(LocalizedStringKey("tab_library"), systemImage: "photo.stack") }
                .tag(Tab.library)

            NavigationStack { placeholder("tab_settings") { EmptyView() } }
                .tabItem { Label(LocalizedStringKey("tab_settings"), systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Ds.navActive)
        .fullScreenCover(item: $route) { r in
            switch r {
            case .capture:
                // Đóng màn chụp → về tab Ảnh mẫu (như `onBack = { screen = Screen.Templates }`).
                CaptureView()
                    .onDisappear { tab = .templates }
            }
        }
    }

    /// Màn chưa port (Home 4b, Library / Settings Phase 5).
    private func placeholder<Extra: View>(_ titleKey: String, @ViewBuilder _ extra: () -> Extra) -> some View {
        VStack(spacing: 16) {
            Text(LocalizedStringKey(titleKey))
                .font(.title2)
                .foregroundStyle(Ds.textMuted)
            extra()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ds.bg)
        .navigationTitle(Text(LocalizedStringKey(titleKey)))
    }
}
