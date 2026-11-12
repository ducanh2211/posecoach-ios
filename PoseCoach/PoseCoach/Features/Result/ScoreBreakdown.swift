import PoseDomain
import SwiftUI

/// BẢNG PHÂN TÍCH — mất điểm ở mục nào. Mặc định thu gọn, bấm để mở. Port `ScoreBreakdown` của
/// `KT/result/ResultScreen.kt`.
///
/// Một con số tổng không nói được gì: "47" có thể là sai hướng hoàn toàn (mọi mục khác đều tốt), cũng có thể là mọi mục
/// đều lệch một chút. Hai chuyện đó khác hẳn nhau, và cách sửa cũng khác hẳn.
struct ScoreBreakdown: View {

    let shot: ResultShot
    @State private var expanded = false

    /// Tên hiển thị của từng mục chấm điểm, theo đúng thứ tự trong bảng kê (`PART_LABELS`).
    private static let partLabels: [(key: String, label: String)] = [
        ("huong", "part_yaw"),
        ("xa_gan", "part_distance"),
        ("trai_phai", "part_center"),
        ("cao_thap", "part_elevation"),
        ("ngua_chuc", "part_pitch"),
        ("dang", "part_pose"),
        ("do_net", "part_sharpness"),
        ("cat_cut", "part_crop"),
        ("mat_mo", "part_eyes_open"),
    ]

    var body: some View {
        let parts = shot.candidate.parts
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(uiText("result_shot_header", .double(Double(shot.candidate.timeMs) / 1000.0), .string(shot.scoreText)))
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Ds.text)
                Spacer()
                Text(LocalizedStringKey(expanded ? "result_collapse" : "result_expand"))
                    .font(.system(size: 12)).foregroundStyle(Ds.primary)
            }

            if !shot.candidate.trustworthy {
                Text(LocalizedStringKey("result_low_confidence"))
                    .font(.system(size: 11)).foregroundStyle(Ds.warning)
            }

            if expanded && !parts.isEmpty {
                Spacer().frame(height: 2)
                // Vắng mặt = không áp dụng, bỏ qua.
                ForEach(Self.partLabels.filter { parts[$0.key] != nil }, id: \.key) { p in
                    row(p.label, parts[p.key]!)
                }
                // Mục vắng mặt = ảnh mẫu này không cần tới nó. Nói rõ ra, đừng để người dùng tự đoán vì sao thiếu dòng.
                let missing = Self.partLabels.filter { parts[$0.key] == nil }.map { uiText($0.label) }
                if !missing.isEmpty {
                    Text(uiText("result_not_applicable", .text(.join(missing, separator: ", "))))
                        .font(.system(size: 10)).foregroundStyle(Ds.textMuted)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ds.surface, in: RoundedRectangle(cornerRadius: Ds.rCard))
        .contentShape(RoundedRectangle(cornerRadius: Ds.rCard))
        .onTapGesture { expanded.toggle() }
    }

    private func row(_ label: String, _ v: Double) -> some View {
        HStack(spacing: 0) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 11)).foregroundStyle(Ds.textMuted)
                .frame(width: 110, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Ds.surfaceMuted
                    (v >= 0.75 ? Ds.success : v >= 0.4 ? Ds.warning : Ds.dangerText)
                        .frame(width: g.size.width * min(max(v, 0), 1))
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 6)
            // Như `(v * 100).toInt()` của Kotlin: cắt phần lẻ về 0, NaN → 0.
            Text(verbatim: "\(v.isNaN ? 0 : Int(v * 100))")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Ds.textMuted)
                .padding(.leading, 6)
                .frame(width: 30, alignment: .leading)
        }
    }
}
