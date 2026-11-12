import PoseDomain
import SwiftUI

/// Hộp thoại ảnh mẫu ĐƯỢC NHẬN — tiêu chí sẽ chấm, việc cần dặn mẫu. Port nhánh `Accepted` của `GateDialog`
/// (`KT/home/HomeScreen.kt`). Nhánh 🔴 từ chối là `alert` ở `HomeView` — chỉ có nút đóng, không có đường vào camera.
///
/// Khác Android: nội dung dài nên dùng `sheet` cuộn được thay cho `AlertDialog`.
struct GateSheet: View {

    let gate: HomeViewModel.Gate
    let accepted: TemplateVerdict.Accepted
    let onProceed: () -> Void
    let onDismiss: () -> Void

    private let green = Color(argb: 0xFF2E7D32)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(uiText("profile_framing", .text(uiText(accepted.framing.labelRes))))
                        .font(.system(size: 14, weight: .bold))
                    if let d = gate.difficulty {
                        Text(uiText("gate_difficulty", .text(uiText(d.labelRes)), .text(uiText(d.hintRes))))
                            .font(.system(size: 13))
                            .foregroundStyle(color(d))
                            .padding(.top, 4)
                    }

                    // --- THỨ TỰ LÀM VIỆC — đọc cho mẫu nghe TRƯỚC khi bấm ---
                    // Cách CHÍNH để tránh mẫu tạo dáng làm hỏng số đo, rẻ hơn mọi chốt chặn kỹ thuật. Phạm vi CỐ Ý HẸP:
                    // chỉ chân di chuyển theo chiều SÂU mới phá số đo; dáng tay làm lúc nào cũng được.
                    heading("gate_tell_model").padding(.top, 10)
                    bullet(uiText("gate_tell_model_feet"))
                    bullet(uiText("gate_tell_model_wait"))

                    if !gate.poseGuide.isEmpty {
                        // ⚠️ Mẫu KHÔNG nhìn được màn hình — phần này để người cầm máy ĐỌC TO LÊN trước khi chụp.
                        heading("gate_pose_to_do").padding(.top, 10)
                        ForEach(Array(gate.poseGuide.enumerated()), id: \.offset) { _, t in bullet(t) }
                    }

                    if let p = gate.profile { profileSection(p).padding(.top, 10) }

                    if !accepted.warnings.isEmpty {
                        heading("gate_notes").padding(.top, 10)
                        ForEach(Array(accepted.warnings.enumerated()), id: \.offset) { _, w in
                            Text(verbatim: "• " + w.resolved())
                                .font(.system(size: 12))
                                .foregroundStyle(Color(argb: 0xFFE65100))
                                .padding(.bottom, 4)
                        }
                    }
                }
                .foregroundStyle(Ds.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Ds.pageH)
            }
            .navigationTitle(Text(LocalizedStringKey("gate_accepted_title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("action_close"), action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("gate_start"), action: onProceed).bold()
                }
            }
        }
    }

    /// Tiêu chí ÁP DỤNG cho riêng ảnh mẫu này, theo thứ tự Kotlin duyệt (`TemplateProfile.thuTuHoSo`).
    @ViewBuilder
    private func profileSection(_ p: TemplateProfile) -> some View {
        let dung = p.activeFor(.guidance)
        let dungTheoThuTu = TemplateProfile.thuTuHoSo.filter { dung.contains($0) }
        heading(uiText("gate_guidance_count", .int(dung.count)))
        ForEach(dungTheoThuTu, id: \.self) { c in
            // Riêng mục dáng: nói rõ chấm những nhóm khớp nào. Chân dung cận sẽ KHÔNG có "chân" ở đây.
            let chiTiet = c == .pose && !p.poseGroups.isEmpty
                ? "  (" + PoseGroup.allCases.filter { p.poseGroups.contains($0) }
                    .map { UiText.res($0.labelRes).resolved() }.joined(separator: ", ") + ")"
                : ""
            Text(verbatim: "✓ " + UiText.res(c.labelRes).resolved() + chiTiet)
                .font(.system(size: 13)).foregroundStyle(green)
        }

        let hauKy = TemplateProfile.thuTuHoSo.filter { p.activeFor(.selection).contains($0) && !dung.contains($0) }
        if !hauKy.isEmpty {
            heading("gate_scored_after").padding(.top, 8)
            ForEach(hauKy, id: \.self) { c in
                Text(verbatim: "✓ " + UiText.res(c.labelRes).resolved()).font(.system(size: 13)).foregroundStyle(green)
            }
        }

        // Nói rõ mục nào KHÔNG áp dụng và vì sao — im lặng bỏ qua thì người dùng không hiểu vì sao app chẳng nhắc.
        let boQua = TemplateProfile.thuTuHoSo.filter { p.skipped[$0] != nil }
        if !boQua.isEmpty {
            heading("gate_not_applicable").padding(.top, 8)
            ForEach(boQua, id: \.self) { c in
                Text(verbatim: "✕ " + UiText.res(c.labelRes).resolved() + " — " + (p.skipped[c]?.resolved() ?? ""))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(argb: 0xFF757575))
                    .padding(.bottom, 4)
            }
        }
    }

    private func heading(_ key: String) -> some View { heading(uiText(key)) }

    private func heading(_ t: UiText) -> some View {
        Text(t).font(.system(size: 13, weight: .bold))
    }

    private func bullet(_ t: UiText) -> some View {
        Text(verbatim: "• " + t.resolved()).font(.system(size: 13))
    }

    private func color(_ d: PoseDescriber.Difficulty) -> Color {
        switch d {
        case .de: Color(argb: 0xFF2E7D32)
        case .trungBinh: Color(argb: 0xFFE65100)
        case .kho: Color(argb: 0xFFC62828)
        }
    }
}
