import SwiftUI

/// Hai cách bắt đầu đề xuất ảnh mẫu theo bối cảnh. Port `SceneStartSheet` + `SceneStartOption` của
/// `KT/home/HomeScreen.kt`.
struct SceneStartSheet: View {

    let onCamera: () -> Void
    let onGallery: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("scene_start_title")).font(.system(size: 18, weight: .bold))
            option("scene_start_camera", "scene_start_camera_hint", onCamera).padding(.top, 12)
            option("scene_start_gallery", "scene_start_gallery_hint", onGallery).padding(.top, 8)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Ds.text)
        .padding(.horizontal, Ds.pageH)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationBackground(Ds.surface)
    }

    private func option(_ title: String, _ hint: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.system(size: 15, weight: .bold))
                Text(LocalizedStringKey(hint)).font(.system(size: 12)).foregroundStyle(Ds.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ds.surfaceMuted, in: RoundedRectangle(cornerRadius: Ds.rCard))
            .contentShape(RoundedRectangle(cornerRadius: Ds.rCard))
        }
        .buttonStyle(.plain)
    }
}
