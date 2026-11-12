import PoseDomain
import SwiftUI

/// Khung xương mờ vẽ đè lên khung xem trước. Port `SkeletonOverlay` trong `KT/capture/CaptureScreen.kt`.
///
/// Người cầm máy dùng nó để biết cần nói gì với mẫu — mẫu đứng xa, không nhìn được màn hình.
struct SkeletonOverlay: View {

    let frame: PoseFrame
    /// Cỡ khung đã cắt theo tỉ lệ khung (`CaptureUiState.frameWidth/Height`).
    let frameWidth: Int
    let frameHeight: Int
    let minVisibility: Float

    var body: some View {
        Canvas { context, size in
            guard !frame.isEmpty, frameWidth > 0, frameHeight > 0 else { return }
            let fw = CGFloat(frameWidth), fh = CGFloat(frameHeight)
            // Phải tính đúng ô chữ nhật mà hình camera thực sự chiếm, nếu không khung xương lệch khỏi người.
            let scale = min(size.width / fw, size.height / fh)
            let dw = fw * scale, dh = fh * scale
            let ox = (size.width - dw) / 2, oy = (size.height - dh) / 2

            func at(_ i: Int) -> CGPoint? {
                guard frame.points.indices.contains(i), frame.visibility[i] >= minVisibility else { return nil }
                let p = frame.points[i]
                return CGPoint(x: ox + CGFloat(p.x) * dw, y: oy + CGFloat(p.y) * dh)
            }

            var bones = Path()
            for (a, b) in Lm.bones {
                guard let pa = at(a), let pb = at(b) else { continue }
                bones.move(to: pa)
                bones.addLine(to: pb)
            }
            context.stroke(bones, with: .color(Color(red: 0, green: 0xE6 / 255, blue: 0x76 / 255, opacity: 0x88 / 255)),
                           lineWidth: 2)

            var joints = Path()
            for i in 0..<Lm.count {
                guard let p = at(i) else { continue }
                joints.addEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
            }
            context.fill(joints, with: .color(Color(red: 1, green: 0xEB / 255, blue: 0x3B / 255, opacity: 0x99 / 255)))
        }
        .allowsHitTesting(false)
    }
}
