import PoseDomain
import SwiftUI
import UIKit

/// Màn chụp. Port `KT/capture/CaptureScreen.kt` — **mới phần lõi camera** (kéo sớm để kiểm 3b trên iPhone): xem trước
/// đúng tỉ lệ khung, khung xương, chọn Ảnh / Video, nút chụp, đổi camera. Hướng dẫn, ảnh mẫu, lưới, nút tỉ lệ, zoom,
/// đếm ngược thêm ở bước 4c.
struct CaptureView: View {

    @State private var vm: CaptureViewModel

    init(template: URL) {
        _vm = State(initialValue: CaptureViewModel(template: template))
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Khung xương mờ: mặc định BẬT — công cụ của người cầm máy để biết cần nói gì với mẫu.
    @State private var showSkeleton = true
    /// Tỉ lệ khung người dùng chọn. Nút đổi tỉ lệ thêm ở 4c.
    @State private var tiLeChon: TiLeKhung = .baBon

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if vm.permission == .granted {
                cameraArea
            } else {
                permissionPrompt
            }
            controls
        }
        .statusBarHidden()
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
    }

    // MARK: - Khung xem trước

    private var cameraArea: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            // `TiLeKhung` nói theo chiều CẦM DỌC. Giao diện nằm ngang thì ô xem trước cũng nằm ngang — cùng chiều với
            // khung phân tích, để phép cắt (`theoHuong`) và ô xem trước trùng nhau.
            let manHinhDoc = landscape ? geo.size.height / geo.size.width : geo.size.width / geo.size.height
            let tiLeDoc = tiLeChon.tiLe(Double(manHinhDoc))
            ZStack {
                if let c = vm.previewSource {
                    CameraPreviewView(controller: c)
                }
                if vm.state.liveDetectionActive && showSkeleton {
                    SkeletonOverlay(
                        frame: vm.state.pose,
                        frameWidth: vm.state.frameWidth,
                        frameHeight: vm.state.frameHeight,
                        minVisibility: CaptureViewModel.minVis
                    )
                }
            }
            .aspectRatio(landscape ? 1 / tiLeDoc : tiLeDoc, contentMode: .fit)
            .frame(width: geo.size.width, height: geo.size.height)
            .onChange(of: tiLeDoc, initial: true) { vm.onTiLeKhungChanged(tiLeDoc) }
        }
        .ignoresSafeArea()
    }

    // MARK: - Nút bấm

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .accessibilityLabel(Text(LocalizedStringKey("action_close")))
                Spacer()
                if vm.permission == .granted {
                    Button { showSkeleton.toggle() } label: {
                        Text(LocalizedStringKey(showSkeleton ? "capture_hide_skeleton" : "capture_show_skeleton"))
                            .font(.footnote)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.black.opacity(0.4), in: Capsule())
                    }
                }
            }
            if let error = vm.state.cameraError {
                Button { vm.dismissError() } label: {
                    Text(error)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Spacer()
            if vm.permission == .granted { bottomBar }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            statusLine
                .font(.footnote.monospacedDigit())
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.4), in: Capsule())
            HStack(spacing: 8) {
                modeChip("capture_mode_photo", selected: vm.state.burstMode) { vm.onModeChanged(burst: true) }
                modeChip("capture_mode_video", selected: !vm.state.burstMode) { vm.onModeChanged(burst: false) }
            }
            .disabled(vm.state.recording || vm.bursting)
            HStack {
                Color.clear.frame(width: 52, height: 52)
                Spacer()
                shutter
                Spacer()
                Button { vm.flipCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .disabled(vm.state.recording || vm.bursting)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        let s = vm.state
        if s.recording {
            Text(verbatim: String(format: "● %.1fs / %.0fs", Double(s.recordedMs) / 1000.0,
                                  Double(CaptureUiState.maxRecordMs) / 1000.0))
        } else if vm.bursting {
            Text(uiText("capture_burst_taken", .int(s.burstTaken), .int(CaptureViewModel.burstCount)))
        } else if s.burstMode {
            Text(uiText("capture_tap_burst", .int(CaptureViewModel.burstCount)))
        } else {
            Text(LocalizedStringKey("capture_tap_record"))
        }
    }

    private var shutter: some View {
        let s = vm.state
        let enabled = s.cameraReady && !vm.bursting && (!s.recording || s.canStop)
        return Button { vm.shoot() } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                if s.recording {
                    RoundedRectangle(cornerRadius: 6).fill(.red).frame(width: 30, height: 30)
                } else {
                    Circle().fill(s.burstMode ? Color.white : Color.red).frame(width: 62, height: 62)
                }
            }
            .opacity(enabled ? 1 : 0.4)
        }
        .disabled(!enabled)
        .accessibilityLabel(Text(LocalizedStringKey(s.recording ? "capture_tap_to_stop"
                                                    : (s.burstMode ? "capture_mode_photo" : "capture_mode_video"))))
    }

    private func modeChip(_ key: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(key))
                .font(.footnote.weight(selected ? .bold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? Color.white.opacity(0.25) : Color.black.opacity(0.4), in: Capsule())
        }
    }

    // MARK: - Quyền camera

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Text(LocalizedStringKey("permission_camera_reason"))
                .multilineTextAlignment(.center)
            Button {
                if vm.permission == .notDetermined {
                    Task { await vm.requestPermission() }
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    // Đã từ chối thì hệ thống không hỏi lại — mở Cài đặt của app.
                    openURL(url)
                }
            } label: {
                Text(LocalizedStringKey("permission_camera_allow"))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}
