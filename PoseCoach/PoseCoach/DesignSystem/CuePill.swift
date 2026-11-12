import PoseDomain
import SwiftUI

enum CueTone { case ok, warn, alert, neutral }

/// VIÊN CÂU CHỈ DẪN — mỗi lúc đúng MỘT câu. Port `CuePill` (`KT/ui/GuidanceOverlay.kt`).
///
/// Thứ tự xét **chính là thứ tự ưu tiên của sản phẩm**:
/// 1. Cầm máy sai (xoay ngang, đang zoom) — làm mọi phép đo phía sau mất nghĩa
/// 2. Chưa thấy mẫu — chưa có gì để đo
/// 3. Câu nhắc từ engine — đã chọn sẵn mục ưu tiên cao nhất
/// 4. Đủ điều kiện
struct CuePill: View {

    let prepWarning: UiText?
    let personDetected: Bool
    let cue: UiText?
    let readyToCapture: Bool
    let hasCriteria: Bool
    /// Câu đang hiện là câu để ĐỌC TO CHO MẪU NGHE — chỉ đổi biểu tượng, không tách thành khu riêng.
    var cueForModel = false
    /// Đã đủ giống ảnh mẫu để chuyển sang giục tạo dáng.
    var readyToPose = false
    /// Mục đang làm dở đã lệch ít. Sai thì chỉ là app đang chờ số đo ổn định.
    var almost = false
    /// Giây còn lại của đồng hồ tự động. `nil` = không đếm.
    var countdown: Int?
    var onClickWarning: (() -> Void)?

    var body: some View {
        let (icon, text, tone) = content
        let row = HStack(spacing: 8) {
            Text(verbatim: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(color(tone))
            Text(text).font(.system(size: 14, weight: .bold)).foregroundStyle(Ds.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(argb: 0xF2FFFFFF), in: Capsule())

        if prepWarning != nil, let onClickWarning {
            Button(action: onClickWarning) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }

    private var content: (String, UiText, CueTone) {
        if let prepWarning { return ("⟳", prepWarning, .alert) }
        if !personDetected { return ("○", uiText("pill_point_at_model"), .neutral) }
        // Đang đếm ngược: KHÔNG nhắc gì khác nữa, người ta đang tạo dáng.
        if let countdown { return ("●", uiText("pill_countdown", .int(countdown)), .ok) }
        if let cue { return (cueForModel ? "🗣" : "→", cue, .warn) }
        if readyToCapture { return ("✓", uiText("pill_ready"), .ok) }
        if readyToPose { return ("✓", uiText("pill_ready_to_pose"), .ok) }
        if !hasCriteria { return ("○", uiText("pill_measuring"), .neutral) }
        // "Gần đúng" CHỈ khi thật sự đã lệch ít; còn lại là app đang chờ số đo ổn định (video 10/10/2026).
        if almost { return ("◐", uiText("pill_almost"), .neutral) }
        return ("○", uiText("pill_measuring"), .neutral)
    }

    private func color(_ tone: CueTone) -> Color {
        switch tone {
        case .ok: Ds.success
        case .warn: Ds.warning
        case .alert: Ds.dangerText
        case .neutral: Ds.textMuted
        }
    }
}
