import SwiftUI

/// CHỌN MỨC ZOOM. Port `ZoomBar` + `ThuocZoom` (`KT/capture/CaptureScreen.kt`).
///
/// Ba chip tròn CỐ ĐỊNH (0.5 · 1 · 2), nổi đè lên khung hình ngay trên nút chụp. Chip sáng là mức gần nhất bên dưới mức
/// đang dùng và GHI ĐÚNG mức đó ("1.4x") — như camera iPhone (18/10/2026). Chạm rồi kéo thì dãy chip GIÃN RA thành thước
/// chi tiết ngay tại chỗ, thả tay một lúc thì thu lại.
///
/// ⚠️ Zoom là công cụ hợp lệ, không phải đường lách tiêu chí xa/gần: `DistanceEstimator` nhận `zoomRatio`. Đã thử GHIM
/// zoom theo ảnh mẫu (12/09/2026) rồi BỎ — app tự đổi zoom sau lưng người dùng là xâm phạm.
struct ZoomBar: View {

    let current: Float
    let range: ClosedRange<Float>
    /// Đang chụm hai ngón trên khung hình — giãn thước ra như lúc kéo.
    var dangChum = false
    let onPick: (Float) -> Void

    /// Ba mức CỐ ĐỊNH, không dựng theo phần cứng — đổi điện thoại là giao diện đổi theo thì mất thói quen.
    private static let mucs: [Float] = [0.5, 1, 2]
    /// Kéo bấy nhiêu điểm = zoom gấp đôi.
    private static let ptMoiLan: CGFloat = 260

    @State private var dangKeo = false
    @State private var zBatDau: Float?

    private var dangO: Float {
        Self.mucs.filter { range.contains($0) }.last { current >= $0 * 0.95 }
            ?? Self.mucs.first { range.contains($0) || $0 == 1 }!
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: String(format: "%.1fx", locale: .current, current))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Ds.success, in: Capsule())

            // ⚠️ Cử chỉ kéo gắn vào KHUNG BỌC, không gắn vào dãy chip — vừa kéo là dãy chip bị thay bằng thước, cử chỉ gắn
            // vào chip bị gỡ giữa chừng (FOOTGUNS 115).
            ZStack {
                if dangKeo || dangChum {
                    ThuocZoom(current: current, range: range, ptMoiLan: Self.ptMoiLan)
                } else {
                    chips
                }
            }
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(keo)
        }
        // Thả tay một lúc (không đổi mức) thì thu thước lại.
        .task(id: "\(dangKeo)-\(current)") {
            guard dangKeo else { return }
            try? await Task.sleep(for: .milliseconds(1_600))
            if !Task.isCancelled && zBatDau == nil { dangKeo = false }
        }
    }

    private var keo: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                dangKeo = true
                let z0 = zBatDau ?? current
                zBatDau = z0
                // ⚠️ KÉO SANG TRÁI = ZOOM VÀO — dấu trừ cố ý, giống vòng xoay zoom của camera iOS.
                let z = z0 * Float(pow(2, -v.translation.width / Self.ptMoiLan))
                onPick(min(max(z, range.lowerBound), range.upperBound))
            }
            .onEnded { _ in zBatDau = nil }
    }

    private var chips: some View {
        HStack(spacing: 10) {
            ForEach(Self.mucs, id: \.self) { z in
                let lamDuoc = range.contains(z)
                let on = dangO == z
                Button { onPick(z) } label: {
                    Text(verbatim: on ? Self.nhanZoom(current)
                         : z < 1 ? String(String(format: "%.1f", locale: .current, z).dropFirst())
                         : String(format: "%.0f", locale: .current, z))
                        .font(.system(size: on ? 13 : 12, weight: on ? .bold : .regular))
                        .foregroundStyle(lamDuoc ? Color.white : Color(argb: 0x66FFFFFF))
                        .frame(width: on ? 38 : 32, height: on ? 38 : 32)
                        // Máy không có ống góc rộng thì 0,5x vẫn hiện nhưng mờ — bấm không tác dụng mà không giải thích
                        // gì mới là thứ gây ức chế.
                        .background(on ? Ds.success : !lamDuoc ? Color(argb: 0x33000000) : Color(argb: 0x66000000),
                                    in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!lamDuoc)
            }
        }
    }

    /// "1.4x", nhưng tròn số thì gọn: "1x", "2x", "0.5x".
    static func nhanZoom(_ z: Float) -> String {
        let tron = (z * 10).rounded() / 10
        return tron >= 1 && abs(tron - tron.rounded()) < 0.05
            ? String(format: "%.0fx", locale: .current, tron)
            : String(format: "%.1fx", locale: .current, tron)
    }
}

/// THƯỚC ZOOM CHI TIẾT. Chia theo thang **loga** nên quãng 1x→2x dài đúng bằng 2x→4x. Số ghi từng nấc 0,1x; nhãn nào chen
/// quá sát nhãn trước thì bỏ.
private struct ThuocZoom: View {

    let current: Float
    let range: ClosedRange<Float>
    let ptMoiLan: CGFloat

    private var nac: [Float] {
        let dau = max(Int(range.lowerBound * 10), 1)
        let het = Int(range.upperBound * 10)
        return dau <= het ? (dau...het).map { Float($0) / 10 } : []
    }

    private func xCua(_ z: Float, _ w: CGFloat) -> CGFloat {
        w / 2 + ptMoiLan * CGFloat(log(z / current) / log(2))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, size in
                for z in nac {
                    let x = xCua(z, w)
                    if x < 0 || x > size.width { continue }
                    // Nấc tròn (0,5 · 1,0 · 1,5 · 2,0) vẽ cao và sáng hơn.
                    let tron = Int((z * 10).rounded()) % 5 == 0
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height * (tron ? 0.42 : 0.50)))
                    p.addLine(to: CGPoint(x: x, y: size.height * 0.62))
                    ctx.stroke(p, with: .color(Color(argb: tron ? 0xCCFFFFFF : 0x66FFFFFF)), lineWidth: tron ? 1.5 : 1)
                }
                var giua = Path()
                giua.move(to: CGPoint(x: size.width / 2, y: size.height * 0.34))
                giua.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.70))
                ctx.stroke(giua, with: .color(Ds.success), lineWidth: 2.5)
            }
            ForEach(nhanHien(w), id: \.self) { z in
                Text(verbatim: String(format: "%.1f", locale: .current, z))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(argb: 0xCCFFFFFF))
                    .frame(width: 28)
                    .position(x: xCua(z, w), y: h - 7)
            }
        }
    }

    /// Nấc có nhãn: trong khung (cách mép 14 pt) và cách nhãn trước ≥ 34 pt.
    private func nhanHien(_ w: CGFloat) -> [Float] {
        var out: [Float] = []
        var xTruoc: CGFloat = -999
        for z in nac {
            let x = xCua(z, w)
            if x < 14 || x > w - 14 { continue }
            if x - xTruoc < 34 { continue }
            xTruoc = x
            out.append(z)
        }
        return out
    }
}
