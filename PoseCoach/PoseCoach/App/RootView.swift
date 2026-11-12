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
        /// Ảnh mẫu đã qua cổng kiểm.
        case capture(template: URL)

        var id: String {
            switch self {
            case let .capture(t): "capture:\(t.path)"
            }
        }
    }

    /// Nhớ TAB đang mở qua lần dựng lại màn hình (như `ScreenSaver` của Kotlin). Màn chụp không nhớ: dựng lại giữa chừng
    /// thì về tab Ảnh mẫu.
    @SceneStorage("RootView.tab") private var tab: Tab = .templates
    @State private var route: Route?

    var body: some View {
        TabView(selection: $tab) {
            HomeView { route = .capture(template: $0) }
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
            case let .capture(template):
                CaptureView(
                    template: template,
                    // "Đổi mẫu" → về tab Ảnh mẫu (như `onBack = { screen = Screen.Templates }`).
                    onBack: { tab = .templates; route = nil },
                    // Màn xem lại port ở 4d. Tới đó chấm xong thì về tab Ảnh mẫu; phiên nằm trong `Caches/shots/` và bị
                    // `ShotStore.sweepOrphans` dọn ở lần mở app sau.
                    onFinished: { _ in tab = .templates; route = nil },
                    onOpenLibrary: { tab = .library; route = nil }
                )
            }
        }
    }

    /// Màn chưa port (Library / Settings Phase 5).
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
