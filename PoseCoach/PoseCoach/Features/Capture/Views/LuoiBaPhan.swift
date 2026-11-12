import SwiftUI

/// LƯỚI 3×3 — chỉ giúp MẮT người cầm máy canh bố cục như app camera thường. Port `LuoiBaPhan` (`KT/capture/CaptureScreen.kt`).
///
/// Không tham gia chấm: app đo vị trí người bằng toạ độ liên tục, mịn hơn ô lưới.
struct LuoiBaPhan: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            for i in 1...2 {
                let x = size.width * CGFloat(i) / 3
                let y = size.height * CGFloat(i) / 3
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(p, with: .color(Color(argb: 0x73FFFFFF)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
