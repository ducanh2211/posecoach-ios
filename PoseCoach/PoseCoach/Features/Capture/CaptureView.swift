import PoseDomain
import SwiftUI
import UIKit

/// MÀN CHỤP — màn chụp DUY NHẤT của app. Port giao diện `KT/capture/CaptureScreen.kt`.
///
/// ```
///   camera + nhận diện realtime + hướng dẫn
///      → bấm chụp (hoặc tự động đếm xong) → chụp 8 tấm / quay video
///      → chấm từng khung (cùng hàm đo với ảnh mẫu) → giữ 5 tấm khớp nhất → XOÁ nguồn
///      → màn xem lại
/// ```
///
/// Khác Android: bỏ dòng số đo `⚠️ TẠM` và GeoCalib chạy trên màn chụp (D7); thoát bằng nút "Đổi mẫu" (không có nút Back
/// hệ thống).
struct CaptureView: View {

    @State private var vm: CaptureViewModel
    private let onBack: () -> Void
    private let onFinished: (URL) -> Void
    private let onOpenLibrary: () -> Void
    @Environment(\.openURL) private var openURL

    /// Bảng số liệu thô: ẩn mặc định cho giao diện sạch, bấm dòng trạng thái để mở.
    @State private var showDebug = false
    /// Khung xương mờ: mặc định BẬT — công cụ của người cầm máy để biết cần nói gì với mẫu (mẫu đứng xa, không nhìn được
    /// màn hình).
    @State private var showSkeleton = true
    @State private var tiLeChon: TiLeKhung = .baBon
    /// Lưới BẬT sẵn (PO 11/10/2026): khuyến khích canh bố cục từ đầu; vẫn tắt được.
    @State private var hienLuoi = true
    /// Đang chụm hai ngón để zoom — mức zoom lúc bắt đầu chụm.
    @State private var zoomChum: Float?

    init(template: URL, onBack: @escaping () -> Void, onFinished: @escaping (URL) -> Void,
         onOpenLibrary: @escaping () -> Void) {
        _vm = State(initialValue: CaptureViewModel(template: template))
        self.onBack = onBack
        self.onFinished = onFinished
        self.onOpenLibrary = onOpenLibrary
    }

    var body: some View {
        ZStack {
            let s = vm.state
            if s.processing {
                // Đang chấm điểm thì chiếm trọn màn hình.
                ProcessingView(progress: s.processProgress, note: s.processNote)
            } else if s.analyzingTemplate && s.templateError == nil {
                // ⚠️ CHƯA SINH XONG TIÊU CHÍ thì KHÔNG cho vào màn camera (luật số 7).
                TemplateAnalyzingView(thumb: s.templateThumb)
            } else {
                Color.black.ignoresSafeArea()
                if vm.permission == .granted { cameraArea }
                VStack(spacing: 0) {
                    topRow
                    Spacer(minLength: 0)
                    bottomColumn
                }
            }
        }
        .statusBarHidden()
        .simultaneousGesture(chumZoom, including: vm.state.cameraReady ? .all : .subviews)
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        // Chốt xong thì sang màn xem lại — "dùng" xong xoá ngay (FOOTGUNS 114).
        .onChange(of: vm.state.finishedSession) {
            if let d = vm.state.finishedSession {
                vm.onFinishedHandled()
                onFinished(d)
            }
        }
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
                if hienLuoi {
                    LuoiBaPhan()
                    // Mốc đặt người chỉ hiện khi đã xong các bước góc máy.
                    MocLuoiOverlay(mau: vm.state.mocMau, live: vm.state.mocLive, hien: vm.state.denBoCuc)
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

    /// CHỤM HAI NGÓN ĐỂ ZOOM (18/10/2026). Khung xem trước không tự có cử chỉ này — app tự gắn camera nên phải tự bắt.
    private var chumZoom: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let z0 = zoomChum ?? vm.state.zoomRatio
                zoomChum = z0
                vm.setZoom(z0 * Float(v.magnification))
            }
            .onEnded { _ in zoomChum = nil }
    }

    // MARK: - Hàng trên: tiêu chí (trái) + ảnh mẫu (phải)

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Button { showDebug.toggle() } label: {
                    Text(LocalizedStringKey(vm.state.personDetected ? "capture_model_seen" : "capture_model_not_seen"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(vm.state.personDetected ? Ds.success : Color(argb: 0xFFFF8A80))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Ds.overlayScrim, in: Capsule())
                }
                .buttonStyle(.plain)
                CriteriaProgress(criteria: vm.state.criteria, matchPercent: vm.state.matchPercent)
                    .frame(width: 150)
                    .padding(.top, 8)
                CriteriaChecklist(criteria: vm.state.criteria)
                    .padding(.top, 6)
                NutNho(uiText(showSkeleton ? "capture_hide_skeleton" : "capture_show_skeleton")) { showSkeleton.toggle() }
                    .padding(.top, 6)
                if showDebug {
                    DebugPanel(state: vm.state).padding(.top, 8)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                TemplateCard(thumb: vm.state.templateThumb)
                NutNho(uiText("capture_change_template"), action: onBack)
                // Đổi tỉ lệ giữa lúc quay thì ảnh ra lẫn hai khung — khoá lại.
                NutNho(uiText("capture_frame_ratio", .string(tiLeChon.nhan)),
                       enabled: !vm.state.recording && vm.state.burstTaken == 0) { tiLeChon = tiLeChon.tiep() }
                NutNho(uiText(hienLuoi ? "capture_grid_on" : "capture_grid")) { hienLuoi.toggle() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Hàng dưới: zoom + câu chỉ dẫn + cụm nút chụp

    private var bottomColumn: some View {
        let s = vm.state
        return VStack(spacing: 0) {
            // Chip zoom nằm TRÊN CÙNG cụm dưới, đè lên khung hình. Vẫn hiện trong lúc quay: đổi zoom giữa chừng là hợp lệ.
            if vm.permission == .granted && s.cameraReady {
                ZoomBar(current: s.zoomRatio, range: vm.zoomRange, dangChum: zoomChum != nil) { vm.setZoom($0) }
                    .padding(.bottom, 12)
            }
            if let e = s.templateError { loi(e) }
            if let e = s.cameraError { loi(e) }

            if vm.permission != .granted {
                permissionNotice
            } else {
                CuePill(
                    prepWarning: s.prepWarning,
                    personDetected: s.personDetected,
                    cue: s.cue,
                    readyToCapture: s.readyToCapture,
                    hasCriteria: !s.criteria.isEmpty,
                    cueForModel: s.cueForModel,
                    readyToPose: s.readyToPose,
                    almost: s.almost,
                    countdown: s.countdown,
                    onClickWarning: { vm.resetZoom() }
                )
                Text(LocalizedStringKey(s.autoMode ? "capture_auto_skip_note" : "capture_manual_note"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(argb: 0xCCFFFFFF))
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                // Ẩn trong lúc quay / chụp để không đổi chế độ giữa chừng.
                if !s.recording && s.burstTaken == 0 {
                    CaptureSwitches(
                        burstMode: s.burstMode, autoMode: s.autoMode,
                        onBurstChange: { vm.onModeChanged(burst: $0) },
                        onAutoChange: { vm.onAutoModeChanged($0) }
                    )
                    .padding(.bottom, 10)
                }
                CameraControls(
                    state: s,
                    enabled: vm.readyToRecord,
                    burstCount: CaptureViewModel.burstCount,
                    onToggle: { vm.shootManually() },
                    onOpenLibrary: onOpenLibrary,
                    onFlipCamera: { vm.flipCamera() }
                )
            }
        }
    }

    private func loi(_ text: UiText) -> some View {
        Text(verbatim: "⚠ " + text.resolved())
            .font(.system(size: 12))
            .foregroundStyle(Color(argb: 0xFFFF8A80))
            .padding(.horizontal, 20).padding(.vertical, 4)
    }

    private var permissionNotice: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey("permission_camera_reason"))
                .font(.system(size: 14))
                .foregroundStyle(.white)
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
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Ds.primary, in: RoundedRectangle(cornerRadius: Ds.rCard))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }
}

/// Nút viên nhỏ trên nền mờ (kiểu nút "Đổi mẫu").
private struct NutNho: View {

    let nhan: UiText
    var enabled = true
    let action: () -> Void

    init(_ nhan: UiText, enabled: Bool = true, action: @escaping () -> Void) {
        self.nhan = nhan
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(nhan)
                .font(.system(size: 11))
                .foregroundStyle(enabled ? Color.white : Color(argb: 0x80FFFFFF))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Ds.overlayScrim, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
