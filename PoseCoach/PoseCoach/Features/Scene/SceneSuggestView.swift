import PoseDomain
import SwiftUI

/// MÀN ĐỀ XUẤT. Port `SuggestScreen` + `InputPanel` + `InputThumb` + `SceneTemplateCard` của `KT/scene/SceneScreen.kt`.
///
/// Phần đầu vào (ảnh, video, chữ):
/// - CÓ ảnh mẫu hợp → GỌN một dòng, bấm mới mở ra.
/// - KHÔNG có → mở sẵn, để người dùng chụp thêm hoặc gõ thêm chữ ngay.
///
/// Khác Android: màu `colorScheme.error` / `tertiary` của Material lấy theo mã mặc định M3 (Ds không có hai màu này).
struct SceneSuggestView: View {

    let vm: SceneViewModel
    let onCapture: () -> Void
    let onGallery: () -> Void
    let onClose: () -> Void
    let onPickTemplate: (URL) -> Void
    let onImport: () -> Void

    @State private var moRong = false

    /// `MaterialTheme.colorScheme.error` / `.tertiary` mặc định của Material 3.
    static let mauLoi = Color(argb: 0xFFB3261E)
    static let mauPhu = Color(argb: 0xFF7D5260)

    var body: some View {
        let state = vm.state
        let coKetQua = !state.matches.isEmpty
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 0) {
                        Button(action: onClose) {
                            Text(verbatim: "‹").font(.system(size: 26)).padding(.horizontal, 12).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(LocalizedStringKey("action_back")))
                        Text(LocalizedStringKey("scene_suggest_title")).font(.system(size: 20, weight: .bold))
                    }
                    SceneInputPanel(vm: vm, expanded: !coKetQua || moRong, canCollapse: coKetQua,
                                    onToggle: { moRong.toggle() }, onCapture: onCapture, onGallery: onGallery)
                    if state.analyzing {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(state.progress ?? uiText("import_analyzing"))
                                .font(.system(size: 13)).foregroundStyle(Ds.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(action: vm.cancel) { Text(LocalizedStringKey("scene_cancel")).font(.system(size: 14)) }
                        }
                    }
                    if let e = state.error {
                        Text(verbatim: "⚠ " + e.resolved()).font(.system(size: 13)).foregroundStyle(Self.mauLoi)
                    }
                    if state.analyzed && !state.analyzing { ketQua(state, coKetQua) }
                }
                .padding(.horizontal, Ds.pageH)
                .padding(.vertical, 12)
            }
            // Màn chờ xáo thẻ phủ lên trên trong lúc phân tích — xem `XaoTheOverlay`.
            XaoTheOverlay(analyzing: state.analyzing, matches: state.matches, progress: state.progress, onCancel: vm.cancel)
        }
        .foregroundStyle(Ds.text)
        .background(Ds.bg)
        // Có kết quả mới thì thu gọn lại; không có thì luôn mở.
        .onChange(of: state.matches) { if !vm.state.matches.isEmpty { moRong = false } }
    }

    @ViewBuilder
    private func ketQua(_ state: SceneUiState, _ coKetQua: Bool) -> some View {
        if coKetQua {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("scene_matches_title")).font(.system(size: 16, weight: .medium))
                Text(uiText("scene_text_summary", .int(state.templateCount)))
                    .font(.system(size: 12)).foregroundStyle(Ds.textMuted)
                if state.unreadableTemplates > 0 {
                    Text(uiText("scene_unreadable", .int(state.unreadableTemplates)))
                        .font(.system(size: 12)).foregroundStyle(Ds.textMuted)
                }
            }
            ForEach(state.matches, id: \.template.file) { card($0) }
        } else {
            // RỖNG — báo rõ là không có, và cho việc làm tiếp (quy tắc số 7).
            VStack(alignment: .leading, spacing: 0) {
                Text(LocalizedStringKey("scene_empty_title")).font(.system(size: 16, weight: .medium))
                Text(LocalizedStringKey(state.tags.isEmpty ? "scene_tags_none"
                                        : state.selected.isEmpty ? "scene_pick_one" : "scene_no_match"))
                    .font(.system(size: 13)).foregroundStyle(Ds.textMuted)
                Button(action: onImport) {
                    Text(LocalizedStringKey("import_title")).font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
        }
    }

    private func card(_ match: SceneMatch) -> some View {
        Button { onPickTemplate(match.template.file) } label: {
            HStack(alignment: .top, spacing: 12) {
                AsyncThumb(file: match.template.file).frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: match.template.name).font(.system(size: 14, weight: .medium))
                    Text(uiText("scene_shared", .text(.join(match.shared.map { uiText($0.titleRes) }, separator: ", "))))
                        .font(.system(size: 14))
                    if !match.missing.isEmpty {
                        Text(uiText("scene_partial_missing",
                                    .text(.join(match.missing.map { uiText($0.titleRes) }, separator: ", "))))
                            .font(.system(size: 14)).foregroundStyle(Self.mauPhu)
                    }
                    Text(LocalizedStringKey("scene_pick_this")).font(.system(size: 14)).foregroundStyle(Ds.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(Ds.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// Khung đầu vào: ảnh/video đã thêm, nút chụp thêm / thêm từ thư viện, ô gõ mô tả, các yếu tố nhận ra được.
private struct SceneInputPanel: View {

    let vm: SceneViewModel
    let expanded: Bool
    let canCollapse: Bool
    let onToggle: () -> Void
    let onCapture: () -> Void
    let onGallery: () -> Void

    @State private var text = ""

    var body: some View {
        let state = vm.state
        VStack(alignment: .leading, spacing: 10) {
            if !expanded {
                gon(state)
            } else {
                HStack {
                    Text(LocalizedStringKey("scene_inputs_title")).font(.system(size: 14, weight: .bold))
                    Spacer()
                    if canCollapse {
                        Button(action: onToggle) {
                            Text(LocalizedStringKey("result_collapse")).font(.system(size: 13)).foregroundStyle(Ds.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !state.inputs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.inputs) { input in
                                InputThumb(input: input, size: 76).overlay(alignment: .topTrailing) {
                                    Button { vm.removeInput(input.id) } label: {
                                        Text(verbatim: "✕").font(.system(size: 11)).foregroundStyle(.white)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color(argb: 0xAA000000), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(3)
                                }
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button(action: onCapture) {
                        Text(LocalizedStringKey("scene_add_capture")).font(.system(size: 13)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: onGallery) {
                        Text(LocalizedStringKey("scene_add_gallery")).font(.system(size: 13)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)

                // Gõ chữ để sửa khi app nhận sai, hoặc bổ sung thứ ảnh không thấy.
                Text(LocalizedStringKey("scene_describe_more")).font(.system(size: 13)).foregroundStyle(Ds.textMuted)
                HStack(spacing: 8) {
                    TextField(text: $text) { Text(LocalizedStringKey("scene_describe_placeholder")) }
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit { vm.searchText(text) }
                        .disabled(state.analyzing)
                    Button { vm.searchText(text) } label: { Text(LocalizedStringKey("scene_search_again")) }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.analyzing
                                  || !(state.hasInput || !text.trimmingCharacters(in: .whitespaces).isEmpty))
                }
                if !state.unknownWords.isEmpty {
                    Text(uiText("scene_text_unknown", .string(state.unknownWords.joined(separator: ", "))))
                        .font(.system(size: 12)).foregroundStyle(SceneSuggestView.mauLoi)
                }

                // Yếu tố nhận ra được — bấm bỏ cái nhận nhầm.
                if !state.tags.isEmpty {
                    Text(LocalizedStringKey("scene_tags_title")).font(.system(size: 13, weight: .bold))
                    Text(LocalizedStringKey("scene_tags_hint")).font(.system(size: 12)).foregroundStyle(Ds.textMuted)
                    FlowLayout(spacing: 6) {
                        ForEach(state.tags, id: \.id) { tag in
                            chip(tag, on: state.selected.contains(tag.id))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ds.surface, in: RoundedRectangle(cornerRadius: Ds.rCard))
        .animation(.default, value: expanded)
        .onChange(of: vm.state.query, initial: true) { text = vm.state.query }
    }

    /// GỌN: một dòng tóm tắt, bấm để mở.
    private func gon(_ state: SceneUiState) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                ForEach(state.inputs.prefix(4)) { InputThumb(input: $0, size: 44) }
                if state.inputs.count > 4 {
                    Text(verbatim: "+\(state.inputs.count - 4)").font(.system(size: 12)).foregroundStyle(Ds.textMuted)
                }
                if !state.query.isEmpty {
                    Text(verbatim: "“\(state.query)”").font(.system(size: 13)).lineLimit(1).padding(.leading, 6)
                }
                Spacer(minLength: 0)
                Text(LocalizedStringKey("scene_inputs_edit")).font(.system(size: 13)).foregroundStyle(Ds.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chip(_ tag: SceneTag, on: Bool) -> some View {
        Button { vm.toggleTag(tag.id) } label: {
            HStack(spacing: 4) {
                if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                Text(uiText(tag.titleRes)).font(.system(size: 13))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(on ? Ds.primary.opacity(0.15) : Ds.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? .clear : Ds.textMuted.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Ảnh thu nhỏ của một đầu vào; video có dấu ▶.
private struct InputThumb: View {

    let input: SceneInput
    let size: CGFloat
    @State private var thumb: CGImage?

    var body: some View {
        ZStack {
            Ds.surfaceMuted
            if let thumb { Image(decorative: thumb, scale: 1).resizable().scaledToFill() }
            if input.video { Text(verbatim: "▶").font(.system(size: size / 3)).foregroundStyle(.white) }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: input.file) {
            let f = input.file
            if input.video {
                let src = await VideoFrameSource.open(f, targetShortSide: 240)
                thumb = await src.frameAt(0)
                src.close()
            } else {
                thumb = await Task.detached { UprightImage.decode(f, shortSide: 240) }.value
            }
        }
    }
}

/// Xếp các phần tử thành hàng, hết chỗ thì xuống dòng — như `FlowRow` của Compose.
private struct FlowLayout: Layout {

    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].items.isEmpty ? s.width : rows[rows.count - 1].width + spacing + s.width
            if needed > maxWidth && !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            var r = rows[rows.count - 1]
            r.width = r.items.isEmpty ? s.width : r.width + spacing + s.width
            r.height = max(r.height, s.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows.filter { !$0.items.isEmpty }
    }
}
