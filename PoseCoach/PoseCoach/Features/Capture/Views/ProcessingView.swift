import PoseDomain
import SwiftUI

/// Màn "Đang xử lý" — nền sáng, viền tròn xanh, thanh tiến trình. Port `ProcessingScreen` (`KT/capture/CaptureScreen.kt`).
struct ProcessingView: View {

    let progress: Float
    let note: UiText

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "✨")
                .font(.system(size: 26))
                .frame(width: 62, height: 62)
                .background(Ds.primary, in: Circle())
            Text(LocalizedStringKey("process_title"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Ds.text)
                .padding(.top, 18)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ds.surfaceMuted)
                    Capsule().fill(Ds.primary)
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                }
            }
            .frame(height: 22)
            .containerRelativeFrame(.horizontal) { w, _ in w * 0.82 }
            .padding(.top, 22)
            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(Ds.textMuted)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ds.bg)
    }
}
