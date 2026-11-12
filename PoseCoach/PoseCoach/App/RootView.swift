import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case templates
        case library
        case settings
    }

    @State private var selectedTab: Tab = .templates
    /// Mở màn chụp. Tạm vào thẳng từ tab Ảnh mẫu (chưa có ảnh mẫu) — 4b thay bằng lưới ảnh mẫu + cổng kiểm.
    @State private var showCapture = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text(LocalizedStringKey("tab_templates"))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Button(LocalizedStringKey("gate_start")) { showCapture = true }
                        .buttonStyle(.borderedProminent)
                }
                .fullScreenCover(isPresented: $showCapture) { CaptureView() }
                .navigationTitle(Text(LocalizedStringKey("tab_templates")))
            }
            .tabItem {
                Label(LocalizedStringKey("tab_templates"), systemImage: "photo.on.rectangle.angled")
            }
            .tag(Tab.templates)

            NavigationStack {
                VStack {
                    Text(LocalizedStringKey("tab_library"))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle(Text(LocalizedStringKey("tab_library")))
            }
            .tabItem {
                Label(LocalizedStringKey("tab_library"), systemImage: "photo.stack")
            }
            .tag(Tab.library)

            NavigationStack {
                VStack {
                    Text(LocalizedStringKey("tab_settings"))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle(Text(LocalizedStringKey("tab_settings")))
            }
            .tabItem {
                Label(LocalizedStringKey("tab_settings"), systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
    }
}

#Preview {
    RootView()
}
