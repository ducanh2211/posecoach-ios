import PoseDomain
import SwiftUI

/// DANH SÁCH ĐIỀU KIỆN CÓ DẤU TÍCH — bám trạng thái thật của từng cổng. Port `CriteriaChecklist` (`KT/ui/GuidanceOverlay.kt`).
///
/// ⚠️ Bốn trạng thái, bốn ký hiệu. Chỗ dễ sai nhất là gộp `unmeasured` vào "chưa đạt": **không đo được KHÁC với sai**
/// (luật số 4). Khung che mất hông thì mục xa/gần không đo được — hiện dấu X ở đó là nói dối rằng họ đứng sai chỗ.
///
/// Nhận tham số rời, không nhận trạng thái màn hình — dùng lại được ở mọi màn.
struct CriteriaChecklist: View {

    let criteria: [CriterionStatus]

    var body: some View {
        if !criteria.isEmpty {
            // UI CHẨN ĐOÁN TRONG GIAI ĐOẠN TEST: giữ toàn bộ tiêu chí và trạng thái chờ/bỏ qua để PO quan sát engine.
            // GỘP theo nhãn: `SCALE` và `PERSPECTIVE` với người dùng chỉ là MỘT câu hỏi — "tôi đứng đủ xa chưa?".
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(groupRows(criteria).enumerated()), id: \.offset) { _, row in
                    line(row.labelRes, row.status)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Ds.overlayScrim, in: RoundedRectangle(cornerRadius: Ds.rSmall))
        }
    }

    private func line(_ labelRes: String, _ item: CriterionStatus) -> some View {
        let label = UiText.res(labelRes).resolved()
        let (mark, tint): (String, Color) = {
            if item.skipped { return ("~", Ds.warning) }
            if item.pending { return ("○", Color(argb: 0x80FFFFFF)) }
            switch item.state {
            case .passing: return ("✓", Ds.success)
            case .failing: return ("!", Ds.dangerText)
            case .grey: return ("◐", Ds.warning)
            case .unmeasured: return ("–", Color(argb: 0x80FFFFFF))
            }
        }()
        let text: UiText = item.skipped ? uiText("checklist_skipped", .string(label))
            : item.pending ? uiText("checklist_waiting", .string(label))
            : .raw(label)
        return HStack(spacing: 6) {
            Text(verbatim: mark).font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(item.state == .passing && !item.pending ? Ds.success : Color(argb: 0xE6FFFFFF))
        }
    }
}
