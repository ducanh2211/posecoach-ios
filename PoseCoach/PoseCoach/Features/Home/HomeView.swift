import PhotosUI
import PoseDomain
import SwiftUI

/// Màn Ảnh mẫu. Port giao diện `KT/home/HomeScreen.kt`: tiêu đề, thẻ nhập ảnh, hàng lọc theo nhóm, lưới ảnh mẫu, rồi
/// cổng kiểm ảnh trước khi vào màn chụp.
///
/// Khác Android: nút tìm theo bối cảnh (`home_scene_search`) chưa có — màn Bối cảnh port ở Phase 5. Hộp thoại nhận ảnh là
/// một bảng kéo lên (`GateSheet`) thay vì `AlertDialog` — nội dung dài, cần cuộn.
struct HomeView: View {

    @State private var vm = HomeViewModel()
    private let onPickTemplate: (URL) -> Void

    init(onPickTemplate: @escaping (URL) -> Void) {
        self.onPickTemplate = onPickTemplate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("home_title"))
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 10)
            Text(LocalizedStringKey("home_subtitle"))
                .font(.system(size: 12)).foregroundStyle(Ds.textMuted)
                .padding(.top, 3)

            ImportCard(busy: vm.importing) { vm.showPicker = true }
                .disabled(vm.busy)
                .padding(.top, 14)

            // Chỉ hiện hàng lọc khi thư viện thật sự có nhiều hơn một nhóm — chip bấm cái nào cũng ra y hệt thì chỉ chiếm chỗ.
            if vm.kinds.count > 1 {
                KindFilterRow(kinds: vm.kinds, selected: $vm.filter)
                    .padding(.top, 14)
            }

            content.padding(.top, 12)
        }
        .foregroundStyle(Ds.text)
        .padding(.horizontal, Ds.pageH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ds.bg)
        .task {
            vm.onPickTemplate = onPickTemplate
            await vm.reloadLibrary()
        }
        .photosPicker(isPresented: $vm.showPicker, selection: $vm.pickerItem, matching: .images,
                      preferredItemEncoding: .compatible)
        .onChange(of: vm.pickerItem) { if vm.pickerItem != nil { vm.importPicked() } }
        // Lớp chờ tự nhận diện (vài giây), có phần trăm. ⚠️ Phải là hộp phủ thật, che cả thanh tab (08/10/2026): bản
        // Android trước vẽ lớp phủ bị khuất, PO tưởng app đứng im.
        .fullScreenCover(isPresented: .constant(vm.dangNhanDien), onDismiss: vm.modalDaDong) {
            ImportProgress(buoc: vm.buocTienDo)
                .presentationBackground(Ds.overlayScrim)
        }
        .alert(LocalizedStringKey("import_err_title"), isPresented: importErrorShown) {
            Button(LocalizedStringKey("action_close"), role: .cancel) {}
        } message: {
            if let e = vm.importError { Text(e) }
        }
        // 🔴 Từ chối: chỉ có nút đóng — không có đường vào màn camera.
        .alert(LocalizedStringKey("gate_rejected_title"), isPresented: rejectedShown) {
            Button(LocalizedStringKey("action_pick_other"), role: .cancel) {}
        } message: {
            if let r = vm.gate?.rejected { Text(verbatim: "\(r.reason.resolved())\n\n\(r.hint.resolved())") }
        }
        .sheet(item: acceptedGate, onDismiss: vm.modalDaDong) { g in
            if let a = g.accepted {
                GateSheet(gate: g, accepted: a, onProceed: vm.proceed, onDismiss: { vm.gate = nil })
            }
        }
        .sheet(item: nhapShown, onDismiss: vm.modalDaDong) { n in
            NhapAnhSheet(nhap: n, onHuy: vm.nhapHuy, onChonAnhKhac: vm.nhapChonAnhKhac, onLuu: vm.nhapLuu)
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.dangChuanBi {
            VStack(spacing: 10) {
                ProgressView()
                Text(LocalizedStringKey("home_preparing")).font(.system(size: 13)).foregroundStyle(Ds.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if vm.shown.isEmpty {
            VStack(spacing: 8) {
                Text(LocalizedStringKey("home_empty")).font(.system(size: 16, weight: .bold))
                Text(LocalizedStringKey("home_empty_hint")).font(.system(size: 12)).foregroundStyle(Ds.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Ds.gap), count: 2), spacing: Ds.gap) {
                    ForEach(vm.shown, id: \.file) { t in
                        Button { vm.selectTemplate(t.file) } label: {
                            TemplateGridCell(template: t, checking: vm.checking == t.file)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.checking != nil)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Binding cho các hộp

    private var importErrorShown: Binding<Bool> {
        Binding(get: { vm.importError != nil }, set: { if !$0 { vm.importError = nil } })
    }

    private var rejectedShown: Binding<Bool> {
        Binding(get: { vm.gate?.rejected != nil }, set: { if !$0 { vm.gate = nil } })
    }

    private var acceptedGate: Binding<HomeViewModel.Gate?> {
        Binding(get: { vm.gate?.accepted != nil ? vm.gate : nil }, set: { if $0 == nil { vm.gate = nil } })
    }

    /// Vuốt đóng bảng = Huỷ: xoá file tạm (FOOTGUNS 86).
    private var nhapShown: Binding<HomeViewModel.Nhap?> {
        Binding(get: { vm.nhap }, set: { if $0 == nil { vm.nhapHuy() } })
    }
}

private extension HomeViewModel.Gate {
    var accepted: TemplateVerdict.Accepted? {
        if case let .accepted(a) = verdict { a } else { nil }
    }

    var rejected: TemplateVerdict.Rejected? {
        if case let .rejected(r) = verdict { r } else { nil }
    }
}

/// Thẻ "Nhập ảnh mẫu của bạn" — khối xanh nổi bật ngay dưới tiêu đề. Đặt TRÊN lưới: tự đưa ảnh vào là đường đi chính
/// ngang hàng với thư viện soạn sẵn, không phải tính năng phụ.
private struct ImportCard: View {

    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Ds.rSmall).fill(Color(argb: 0x33FFFFFF))
                    if busy {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                    }
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(busy ? "import_busy" : "import_title"))
                        .font(.system(size: 15, weight: .bold))
                    Text(LocalizedStringKey("import_subtitle"))
                        .font(.system(size: 12)).foregroundStyle(Color(argb: 0xCCFFFFFF))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Color(argb: 0xCCFFFFFF))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(Ds.primary, in: RoundedRectangle(cornerRadius: Ds.rCard))
            .contentShape(RoundedRectangle(cornerRadius: Ds.rCard))
        }
        .buttonStyle(.plain)
    }
}

/// Hàng lọc theo nhóm. Nhóm nào thư viện không có thì KHÔNG hiện chip — chip ra danh sách rỗng là ngõ cụt.
private struct KindFilterRow: View {

    let kinds: [MediaLibrary.TemplateKind]
    @Binding var selected: MediaLibrary.TemplateKind?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("filter_all", selected == nil) { selected = nil }
                ForEach(kinds, id: \.self) { k in
                    chip(k.labelRes, selected == k) { selected = selected == k ? nil : k }
                }
            }
        }
    }

    private func chip(_ key: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                Text(LocalizedStringKey(key)).font(.system(size: 13))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(on ? Ds.primary.opacity(0.15) : Ds.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? .clear : Ds.textMuted.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Lớp chờ có phần trăm. Mỗi bước chạy đều từ `max(hiện tại, tu)` tới `den` trong `ms` — như `Animatable.snapTo` +
/// `animateTo(tween(ms, LinearEasing))` của Kotlin.
private struct ImportProgress: View {

    let buoc: (tu: Float, den: Float, ms: Int, batDau: Date)

    /// Bước đang chạy, đã ghép với giá trị lúc đổi bước.
    @State private var tu: Float = 0
    @State private var den: Float = 0
    @State private var ms = 1
    @State private var batDau = Date.distantPast

    var body: some View {
        TimelineView(.animation) { ctx in
            let v = giaTri(ctx.date)
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(Ds.surfaceMuted, lineWidth: 6)
                    Circle().trim(from: 0, to: CGFloat(v))
                        .stroke(Ds.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(verbatim: "\(Int(v * 100))%").font(.system(size: 18, weight: .bold))
                }
                .frame(width: 84, height: 84)
                Text(LocalizedStringKey("import_analyzing"))
                    .font(.system(size: 15, weight: .bold))
                    .padding(.top, 14)
                Text(LocalizedStringKey(v < 0.35 ? "import_step_person" : v < 0.45 ? "import_step_kind" : "import_step_angle"))
                    .font(.system(size: 12)).foregroundStyle(Ds.textMuted)
                    .padding(.top, 4)
            }
            .foregroundStyle(Ds.text)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(Ds.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .onChange(of: buoc.batDau, initial: true) {
            let hienTai = giaTri(Date())
            tu = max(hienTai, buoc.tu)
            den = buoc.den
            ms = max(buoc.ms, 1)
            batDau = buoc.batDau
        }
        .interactiveDismissDisabled()
    }

    private func giaTri(_ now: Date) -> Float {
        let p = Float(min(1, max(0, now.timeIntervalSince(batDau) * 1000 / Double(ms))))
        return tu + (den - tu) * p
    }
}
