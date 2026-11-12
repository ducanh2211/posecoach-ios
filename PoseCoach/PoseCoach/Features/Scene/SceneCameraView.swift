import PoseDomain
import SwiftUI
import UIKit

/// CAMERA GHI LẠI BỐI CẢNH (09/10/2026). Port `KT/scene/SceneCameraScreen.kt`. PO: *"chỉ có cụm camera control, lật cam,
/// nút chụp quay, mở thư viện, cũng có zoom — mục đích để quay lại bối cảnh chứ không như cam để chụp và hướng dẫn
/// realtime"*. Chỉ có một dòng nhắc nhỏ ở trên.
///
/// Khác Android: quyền đã bị từ chối thì nút "Cho phép dùng camera" mở Cài đặt (iOS không hỏi lại lần hai).
struct SceneCameraView: View {

    @State private var vm: SceneCameraViewModel
    private let onGallery: () -> Void
    private let onClose: () -> Void
    @Environment(\.openURL) private var openURL

    /// - Parameters:
    ///   - onDone: ảnh/video vừa chụp/quay (file tạm của app)
    ///   - onGallery: mở thư viện ảnh của máy thay vì chụp
    ///   - onClose: bỏ ra, xoá những tấm vừa chụp
    init(onDone: @escaping ([URL]) -> Void, onGallery: @escaping () -> Void, onClose: @escaping () -> Void) {
        _vm = State(initialValue: SceneCameraViewModel(onDone: onDone))
        self.onGallery = onGallery
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if vm.permission == .granted { CameraPreviewView(camera: vm.camera).ignoresSafeArea() }
            VStack(spacing: 0) {
                topRow
                if vm.permission != .granted {
                    Button {
                        if vm.permission == .notDetermined {
                            Task { await vm.requestPermission() }
                        } else if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Text(LocalizedStringKey("permission_camera_allow"))
                            .font(.body.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Ds.primary, in: RoundedRectangle(cornerRadius: Ds.rCard))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                bottomColumn
            }
        }
        .statusBarHidden()
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
    }

    private func huy() {
        vm.huy()
        onClose()
    }

    // MARK: - Trên: nút đóng + MỘT dòng nhắc

    private var topRow: some View {
        let (hint, warn) = hintText
        return HStack(alignment: .top, spacing: 10) {
            NutTronPhu(systemImage: "xmark", label: "action_close", enabled: !vm.recording, action: huy)
            Text(hint)
                .font(.system(size: 13, weight: warn ? .bold : .regular))
                .foregroundStyle(warn ? Color(argb: 0xFFFFD180) : .white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(argb: 0x99000000), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(12)
    }

    private var hintText: (UiText, Bool) {
        let goiY = SceneCameraViewModel.goiYSoTam
        if vm.permission != .granted { return (uiText("scene_cam_need_permission"), true) }
        if vm.failed { return (uiText("scene_cam_failed"), true) }
        if vm.recording && vm.tooFast { return (uiText("scene_cam_slow_down"), true) }
        if vm.recording { return (uiText("scene_cam_recording_ok"), false) }
        if vm.videoMode { return (uiText("scene_cam_video_hint"), false) }
        if vm.photos.isEmpty { return (uiText("scene_cam_photo_hint", .int(goiY)), false) }
        if vm.photos.count < goiY { return (uiText("scene_cam_photo_more", .int(vm.photos.count), .int(goiY)), false) }
        return (uiText("scene_cam_photo_enough"), false)
    }

    // MARK: - Dưới: zoom, chế độ, cụm nút

    private var bottomColumn: some View {
        VStack(spacing: 0) {
            if vm.recording {
                let e = vm.elapsed, m = SceneRepository.maxVideoMs
                Text(verbatim: String(format: "● %lld:%02lld / %lld:%02lld", e / 60_000, e / 1000 % 60, m / 60_000, m / 1000 % 60))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Ds.recording)
                    .padding(.bottom, 8)
            }
            if vm.ready {
                HStack(spacing: 6) {
                    ForEach(vm.zoomStops, id: \.self) { z in
                        let on = abs(vm.zoom - z) < 0.05
                        Button { vm.setZoom(z) } label: {
                            Text(verbatim: Self.nhanZoom(z))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(on ? Color(argb: 0xFFFFD54F) : .white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color(argb: 0x66000000), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 10)
            }
            // Đã chụp ít nhất một tấm: hiện "Xong" để đi đề xuất.
            if !vm.photos.isEmpty && !vm.recording {
                Button(action: vm.done) {
                    Text(uiText("scene_cam_done", .int(vm.photos.count)))
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Ds.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }
            if !vm.recording && vm.videoAvailable {
                HStack(spacing: 0) {
                    cheDo("capture_mode_photo", !vm.videoMode) { vm.videoMode = false }
                    cheDo("capture_mode_video", vm.videoMode) { vm.videoMode = true }
                }
                .padding(3)
                .background(Color(argb: 0x66000000), in: Capsule())
                .padding(.bottom, 12)
            }
            HStack {
                NutTronPhu(systemImage: "photo.on.rectangle", label: "scene_add_gallery", enabled: !vm.recording,
                           action: onGallery)
                    .frame(maxWidth: .infinity)
                shutterButton.frame(maxWidth: .infinity)
                NutTronPhu(systemImage: "arrow.triangle.2.circlepath.camera", label: nil,
                           enabled: !vm.recording && vm.ready, action: vm.flip)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 12)
    }

    private var shutterButton: some View {
        Button(action: vm.shutter) {
            ZStack {
                Circle().fill(Color(argb: 0x40FFFFFF)).frame(width: 76, height: 76)
                RoundedRectangle(cornerRadius: vm.recording ? 8 : 30)
                    .fill(vm.videoMode ? Ds.recording : .white)
                    .frame(width: vm.recording ? 30 : 60, height: vm.recording ? 30 : 60)
            }
        }
        .buttonStyle(.plain)
        .disabled(!vm.ready || vm.busy)
        .accessibilityLabel(Text(LocalizedStringKey(vm.videoMode ? "capture_mode_video" : "capture_mode_photo")))
    }

    private func cheDo(_ key: String, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(key))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(selected ? Color.white : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// `"%.1fx"` (Locale.ROOT) dưới 1, `"%.0fx"` từ 1 — các mức cố định 0.5 / 1 / 2 / 5 nên không gặp ca làm tròn.
    private static func nhanZoom(_ z: Float) -> String {
        String(format: z < 1 ? "%.1fx" : "%.0fx", locale: Locale(identifier: "en_US_POSIX"), Double(z))
    }
}
