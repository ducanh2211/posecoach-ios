import PoseDomain
import SwiftUI

/// MÀN KẾT QUẢ — dựng theo thiết kế Figma "V2 · 03 Ảnh đẹp nhất". Port `KT/result/ResultScreen.kt`.
///
/// Bố cục: thanh tiêu đề có nút quay lại → dải ảnh ứng viên → ảnh đang chọn cỡ lớn kèm nhãn "Khớp mẫu tốt nhất" → ba
/// nút ghim đáy (Lưu tất cả / Xoá / Lưu ảnh đã chọn).
///
/// Khác thiết kế đúng hai chỗ, cố ý (như Android):
///  - **Bảng phân tích điểm** mở ra được — khi ảnh chọn ra không giống mẫu, đó là câu hỏi đầu tiên người dùng hỏi.
///  - **Cảnh báo khi không tấm nào đạt** (FOOTGUNS 24, luật số 7: không thất bại im lặng).
///
/// Khác Android: không có nút / cử chỉ Back của hệ thống — màn mở toàn màn hình, chỉ thoát bằng nút "‹" (luôn qua hộp
/// "Lưu ảnh vào thư viện?", FOOTGUNS 114). Hộp đó có thêm nút Huỷ = chạm ra ngoài hộp thoại của Android.
struct ResultView: View {

    @State private var vm: ResultViewModel
    /// Rời màn này đi đâu — xem `ResultExit`.
    private let onDone: (ResultExit) -> Void

    init(sessionDir: URL, templateFile: URL, onDone: @escaping (ResultExit) -> Void) {
        _vm = State(initialValue: ResultViewModel(sessionDir: sessionDir, templateFile: templateFile))
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            let s = vm.state
            if s.loading {
                ProgressView().tint(Ds.primary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if s.isEmpty {
                emptyState
            } else {
                content(s)
            }
        }
        .background(Ds.bg)
        .task { await vm.load() }
        // Lưu hoặc xoá xong thì đóng màn, sang đúng chỗ đã định. "Dùng" xong thì xoá ngay (FOOTGUNS 114).
        .onChange(of: vm.state.exitTo) {
            if let e = vm.state.exitTo {
                vm.onExitHandled()
                onDone(e)
            }
        }
        // ⚠️ QUAY LẠI MÀ CHƯA LƯU HAY XOÁ → HỎI (17/10/2026). Thoát luôn thì ảnh nằm lại trong phiên tạm.
        .alert(Text(LocalizedStringKey("result_back_title")), isPresented: binding(\.hoiKhiThoat, .dismissBack)) {
            Button { vm.onAction(.backSave) } label: { Text(LocalizedStringKey("result_save_all")) }
            Button(role: .destructive) { vm.onAction(.backDiscard) } label: { Text(LocalizedStringKey("result_back_discard")) }
            Button(role: .cancel) { vm.onAction(.dismissBack) } label: { Text(LocalizedStringKey("action_cancel")) }
        } message: {
            Text(LocalizedStringKey("result_back_body"))
        }
        .alert(Text(LocalizedStringKey("result_discard_title")), isPresented: binding(\.xacNhanXoa, .cancelDiscard)) {
            Button(role: .destructive) { vm.onAction(.discard) } label: { Text(LocalizedStringKey("action_delete")) }
            Button(role: .cancel) { vm.onAction(.cancelDiscard) } label: { Text(LocalizedStringKey("action_keep")) }
        } message: {
            Text(uiText("result_discard_body", .int(vm.state.shots.count)))
        }
    }

    /// Hộp thoại đóng từ phía hệ thống → báo ViewModel như `onDismissRequest`.
    private func binding(_ key: KeyPath<ResultUiState, Bool>, _ onClose: ResultAction) -> Binding<Bool> {
        Binding(get: { vm.state[keyPath: key] }, set: { if !$0 && vm.state[keyPath: key] { vm.onAction(onClose) } })
    }

    // MARK: - Tiêu đề

    private var header: some View {
        ZStack {
            Text(LocalizedStringKey("result_title"))
                .font(.system(size: 17, weight: .bold)).foregroundStyle(Ds.text)
            HStack {
                Button { vm.onAction(.back) } label: {
                    Text(verbatim: "‹").font(.system(size: 26)).foregroundStyle(Ds.text)
                        .frame(width: 44, height: 44).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey("action_back")))
                .padding(.leading, 10)
                Spacer()
            }
        }
        .frame(height: 60)
    }

    // MARK: - Nội dung

    private func content(_ s: ResultUiState) -> some View {
        let failed = s.failedCriteria
        let khoa = s.busy || s.exitTo != nil
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    if !failed.isEmpty { failureNotice(failed) }
                    shotStrip(s)
                    selectedImage(s, failed)
                    if let shot = s.selected { ScoreBreakdown(shot: shot) }
                    Spacer().frame(height: 4)
                }
                .padding(.horizontal, Ds.pageH)
            }

            if let m = s.message {
                Text(verbatim: "⚠ " + m.resolved())
                    .font(.system(size: 12)).foregroundStyle(Ds.dangerText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Ds.pageH)
            }
            // --- Ba lựa chọn, ghim đáy (17/10/2026, PO chốt) ---
            VStack(spacing: 8) {
                nutKetQua(Text(LocalizedStringKey("result_save_all")), Ds.primary, .white, enabled: !khoa) {
                    vm.onAction(.saveAll)
                }
                HStack(spacing: 8) {
                    nutKetQua(Text(LocalizedStringKey("result_discard")), Ds.surface, Ds.dangerText, enabled: !khoa) {
                        vm.onAction(.askDiscard)
                    }
                    nutKetQua(
                        Text(uiText("result_save_checked", .int(s.checked.count))), Ds.surface, Ds.text,
                        enabled: !khoa && !s.checked.isEmpty
                    ) { vm.onAction(.saveChecked) }
                }
            }
            .padding(Ds.pageH)
        }
    }

    private func nutKetQua(
        _ text: Text, _ nen: Color, _ chu: Color, enabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            text.font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? chu : Ds.textMuted)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(enabled ? nen : Ds.surfaceMuted, in: RoundedRectangle(cornerRadius: Ds.rCard))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func failureNotice(_ failed: [FailedCriterion]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(uiText("result_none_passed", .text(.join(failed.map { uiText($0.labelRes) }, separator: " · "))))
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Ds.dangerText)
            ForEach(failed, id: \.labelRes) { f in
                Text(verbatim: "• " + uiText(f.adviceRes).resolved())
                    .font(.system(size: 12)).foregroundStyle(Color(argb: 0xFF8A2B2F))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Ds.dangerSoft, in: RoundedRectangle(cornerRadius: Ds.rCard))
    }

    private func shotStrip(_ s: ResultUiState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(Array(s.shots.enumerated()), id: \.element.candidate.id) { index, shot in
                    shotTile(shot, index, chosen: shot.candidate.id == s.selected?.candidate.id,
                             daTich: s.checked.contains(shot.candidate.id))
                }
            }
        }
    }

    private func shotTile(_ shot: ResultShot, _ index: Int, chosen: Bool, daTich: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Ds.rSmall)
        return ZStack {
            Ds.surfaceMuted
            if let b = shot.bitmap {
                Image(b, scale: 1, label: Text(uiText("result_photo_n", .int(index + 1))))
                    .resizable().scaledToFill()
            }
        }
        .frame(width: 84, height: 104)
        .clipShape(shape)
        .overlay(shape.strokeBorder(chosen ? Ds.primary : .clear, lineWidth: chosen ? 2.5 : 0))
        .contentShape(shape)
        .onTapGesture { vm.onAction(.select(shot.candidate.id)) }
        // Ô tích: chọn ảnh để "Lưu ảnh đã chọn". Bấm vào ảnh là xem to, bấm ô là tích.
        .overlay(alignment: .topLeading) {
            Button { vm.onAction(.toggleCheck(shot.candidate.id)) } label: {
                ZStack {
                    Circle().fill(daTich ? Ds.primary : Color(argb: 0x99000000))
                    Circle().strokeBorder(.white, lineWidth: 1.5)
                    if daTich {
                        Text(verbatim: "✓").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(verbatim: shot.scoreText)
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color(argb: 0xCC000000), in: Capsule())
                .padding(4)
        }
    }

    // --- Ảnh đang chọn, cỡ lớn ---
    private func selectedImage(_ s: ResultUiState, _ failed: [FailedCriterion]) -> some View {
        Color.black
            .aspectRatio(0.75, contentMode: .fit)
            .overlay {
                if let b = s.selected?.bitmap {
                    Image(b, scale: 1, label: Text(LocalizedStringKey("result_selected_image")))
                        .resizable().scaledToFit()
                }
            }
            // Nhãn "khớp nhất" chỉ hiện khi thật sự có tấm đạt — gắn nhãn khen cho một tấm sai hoàn toàn thì còn tệ hơn
            // không gắn gì.
            .overlay(alignment: .topTrailing) {
                if failed.isEmpty, let sel = s.selected {
                    Text(uiText("result_best_match", .string(sel.scoreText)))
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Ds.primary, in: Capsule())
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Ds.rCard))
    }

    // MARK: - Không giữ được ảnh nào

    private var emptyState: some View {
        VStack(spacing: 0) {
            Text(LocalizedStringKey("result_empty_title"))
                .font(.system(size: 17, weight: .bold)).foregroundStyle(Ds.text)
            Spacer().frame(height: 8)
            // Không "thất bại im lặng": nói rõ vì sao và làm gì tiếp.
            Text(LocalizedStringKey("result_empty_hint"))
                .font(.system(size: 13)).foregroundStyle(Ds.textMuted)
            Spacer().frame(height: 16)
            Button { vm.onAction(.back) } label: {
                Text(LocalizedStringKey("action_back"))
                    .font(.body.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Ds.primary, in: RoundedRectangle(cornerRadius: Ds.rCard))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Ds.pageH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
