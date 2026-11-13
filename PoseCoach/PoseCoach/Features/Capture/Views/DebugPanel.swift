import PoseDomain
import SwiftUI

/// Bảng số liệu thô — công cụ đo đạc, ẩn mặc định, bấm vào dòng trạng thái để mở. Port `DebugPanel`
/// (`KT/capture/CaptureScreen.kt`). Không phải code `⚠️ TẠM` — là công cụ chỉnh ngưỡng bằng số liệu thật.
///
/// Nhãn cho người phát triển viết thẳng tiếng Anh, không đưa vào String Catalog — như Kotlin.
struct DebugPanel: View {

    let templateFraming: FramingClass?
    let live: CaptureLiveState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            dong("Template", templateFraming.map { UiText.res($0.labelRes).resolved() } ?? "?")
            dong("Landmarks", "\(live.visiblePoints) / 33")
            dong("Body yaw", live.bodyYawDeg.map { String(format: "%.1f°", locale: .current, $0) } ?? "—")
            dong("Per frame", "\(live.inferenceMs) ms")
        }
        .padding(8)
        .frame(maxWidth: 220)
        .background(Ds.overlayPanel, in: RoundedRectangle(cornerRadius: Ds.rSmall))
    }

    private func dong(_ label: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: label).foregroundStyle(Color(argb: 0xFFBDBDBD))
            Spacer()
            Text(verbatim: value).foregroundStyle(.white).monospaced()
        }
        .font(.system(size: 10))
    }
}
