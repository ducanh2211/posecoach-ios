/// GỘP CÁC MỤC CÙNG TÊN HIỂN THỊ thành một dòng trong danh sách điều kiện. Port từ `groupRows` trong
/// `KT/ui/GuidanceOverlay.kt` — tách sang `PoseDomain` vì là logic thuần (plan, mục "File trộn logic + framework").
///
/// Vài mục cùng hiện dưới một tên (`Criterion.displayLabelRes`). Mỗi nhóm hiện mục "tệ nhất": đang trượt →
/// gần đạt → đạt → không đo được; mục đang chờ / đã bỏ qua đứng trên mục đạt, để dòng gộp hiện "đang chờ" khi
/// phần còn lại của nhóm chưa tới lượt. Giữ thứ tự xuất hiện đầu tiên của từng nhóm (như `groupBy` của Kotlin).
public func groupRows(_ criteria: [CriterionStatus]) -> [(labelRes: String, status: CriterionStatus)] {
    func rank(_ s: GateState) -> Int {
        switch s {
        case .failing: return 0
        case .grey: return 1
        case .passing: return 2
        case .unmeasured: return 3
        }
    }
    func key(_ s: CriterionStatus) -> Int {
        if s.pending { return 3 }
        if s.skipped { return 3 }
        if s.state == .passing { return 4 }
        return rank(s.state)
    }

    var order: [String] = []
    var groups: [String: [CriterionStatus]] = [:]
    for c in criteria {
        let label = c.criterion.displayLabelRes
        if groups[label] == nil { order.append(label) }
        groups[label, default: []].append(c)
    }
    return order.map { label in
        let items = groups[label]!
        // `minByOrNull`: lấy phần tử NHỎ NHẤT ĐẦU TIÊN.
        var pick = items[0]
        for it in items.dropFirst() where key(it) < key(pick) { pick = it }
        return (labelRes: label, status: pick)
    }
}
