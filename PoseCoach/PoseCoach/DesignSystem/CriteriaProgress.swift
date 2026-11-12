import PoseDomain
import SwiftUI

/// THANH TIẾN ĐỘ — "đã đạt 4/6". Port `CriteriaProgress` (`KT/ui/GuidanceOverlay.kt`).
///
/// Không có nó thì người dùng không biết còn 1 việc hay 5 việc. Đếm theo **dòng đã gộp** — người dùng thấy 6 dòng thì
/// mẫu số phải là 6, không phải 7.
struct CriteriaProgress: View {

    let criteria: [CriterionStatus]
    /// Độ giống ảnh mẫu, 0..100. Hiện SỐ NÀY thay vì đếm tích: 5/7 tích vẫn có thể rất khác mẫu nếu hai mục còn lại
    /// là mục nặng nhất. Người dùng cần biết mình đang tiến gần hay xa ra.
    var matchPercent: Int?

    var body: some View {
        let rows = groupRows(criteria)
        if !rows.isEmpty {
            let done = rows.filter { !$0.status.pending && ($0.status.state == .passing || $0.status.skipped) }.count
            let total = rows.count
            let ratio = matchPercent.map { Double($0) / 100 } ?? Double(done) / Double(total)
            let good = (matchPercent ?? 0) >= 85 || done == total
            VStack(alignment: .leading, spacing: 4) {
                Text(matchPercent.map { uiText("progress_match", .int($0), .int(done), .int(total)) }
                     ?? uiText("progress_done", .int(done), .int(total)))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        matchPercent.map { $0 >= 85 } ?? false || done == total ? Ds.success : Color(argb: 0xE6FFFFFF)
                    )
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(argb: 0x33FFFFFF))
                        Capsule().fill(good ? Ds.success : Ds.warning)
                            .frame(width: geo.size.width * min(max(ratio, 0), 1))
                    }
                }
                .frame(height: 4)
            }
        }
    }
}
