import SwiftUI

/// Điều hướng gốc. Port `AppRoot` trong `KT/MainActivity.kt`: ba tab chính + màn chụp / màn xem lại mở đè toàn màn hình.
///
/// Khác Android: thanh tab dùng `TabView` của iOS (Android tự vẽ ba nút chữ); nút Back của hệ thống không có — màn chụp
/// tự có nút đóng.
struct RootView: View {

    enum Tab: String {
        case templates, library, settings
    }

    /// Màn mở đè lên các tab.
    enum Route {
        /// Ảnh mẫu đã qua cổng kiểm.
        case capture(template: URL)
        /// Phiên vừa chấm xong (`Caches/shots/<phiên>/` + `index.csv`) và ảnh mẫu đã dùng.
        case result(template: URL, sessionDir: URL)
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

            LibraryView()
                .tabItem { Label(LocalizedStringKey("tab_library"), systemImage: "photo.stack") }
                .tag(Tab.library)

            SettingsView()
                .tabItem { Label(LocalizedStringKey("tab_settings"), systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Ds.navActive)
        // MỘT lớp toàn màn hình cho cả chuỗi chụp → xem lại → chụp lại: đổi màn bên trong thay vì đóng lớp này mở lớp
        // khác (SwiftUI bỏ qua lệnh mở lớp mới khi lớp cũ đang đóng dở). Mỗi lần đổi nhánh là view MỚI → ViewModel mới.
        .fullScreenCover(isPresented: Binding(get: { route != nil }, set: { if !$0 { route = nil } })) {
            switch route {
            case let .capture(template):
                CaptureView(
                    template: template,
                    // "Đổi mẫu" → về tab Ảnh mẫu (như `onBack = { screen = Screen.Templates }`).
                    onBack: { tab = .templates; route = nil },
                    onFinished: { route = .result(template: template, sessionDir: $0) },
                    onOpenLibrary: { tab = .library; route = nil }
                )
            case let .result(template, sessionDir):
                // Ba lối ra (17/10/2026): lưu → Thư viện xem ngay; xoá để chụp lại → camera; quay lại (đã hỏi lưu hay
                // bỏ) → màn Ảnh mẫu.
                ResultView(sessionDir: sessionDir, templateFile: template) { exit in
                    switch exit {
                    case .library: tab = .library; route = nil
                    case .camera: route = .capture(template: template)
                    case .templates: tab = .templates; route = nil
                    }
                }
            case nil:
                EmptyView()
            }
        }
    }
}
