import PoseDomain
import SwiftUI

/// MỐC ĐẶT NGƯỜI TRÊN LƯỚI (11/10/2026, PO chốt). Port `KT/capture/MocLuoiOverlay.kt`.
///
/// Lưới trơn hiện từ đầu. Mốc chỉ hiện khi `hien` — đã xong các bước góc máy — để người dùng chọn góc trước rồi mới đặt
/// người. Hiện sớm thì họ chúc/ngửa máy để đưa người vào vạch, phá đúng bước góc máy (FOOTGUNS 110).
///
/// Vạch nét đứt = mốc của ẢNH MẪU. Chấm = mốc của người trong camera. Chấm chạm vạch thì vạch xanh. Toạ độ là tỉ lệ khung
/// (0..1): khung camera đã cắt đúng tỉ lệ ô xem trước, nên vẽ thẳng lên ô này.
///
/// ⚠️ Chỉ là CÔNG CỤ ĐẶT NGƯỜI, không phải tiêu chí: không chấm, không chặn chụp.
struct MocLuoiOverlay: View {

    let mau: MocLuoi?
    let live: MocLuoi?
    let hien: Bool

    /// Nửa bề ngang vạch, theo tỉ lệ khung.
    private static let nuaVach = 0.14
    /// Lệch trong mức này (tỉ lệ khung) thì tô xanh. ⚠️ CHƯA ĐO — chỉ để hiển thị, không chấm. 0,04 ≈ 1/8 ô lưới.
    private static let dungChoY = 0.04
    private static let dungChoX = 0.04
    /// Câu "Giờ đặt người vào vạch" hiện bấy nhiêu mili giây khi mốc vừa xuất hiện.
    private static let moiHienMs = 3_000

    /// Câu moi đặt người: hiện vài giây ngay lúc mốc vừa xuất hiện.
    @State private var moi = false

    var body: some View {
        if let mau {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, size in ve(ctx, size, mau) }
                    nhan(mau, geo.size)
                }
                .opacity(hien ? 1 : 0)
                .animation(.easeInOut(duration: 0.45), value: hien)
                .overlay {
                    if moi {
                        Text(LocalizedStringKey("grid_place_hint"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color(argb: 0x99000000), in: Capsule())
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut, value: moi)
            }
            .allowsHitTesting(false)
            .task(id: hien) {
                guard hien else { moi = false; return }
                moi = true
                try? await Task.sleep(for: .milliseconds(Self.moiHienMs))
                if !Task.isCancelled { moi = false }
            }
        }
    }

    /// Nhãn cạnh vạch, đặt ở mép phải của vạch.
    @ViewBuilder
    private func nhan(_ mau: MocLuoi, _ size: CGSize) -> some View {
        nhanVach(mau.trenY, mau.loaiTren, mau, size)
        nhanVach(mau.duoiY, mau.loaiDuoi, mau, size)
    }

    @ViewBuilder
    private func nhanVach(_ y: Double?, _ loai: LoaiMoc, _ mau: MocLuoi, _ size: CGSize) -> some View {
        if let y {
            let x = min(max((mau.giuaX ?? 0.5) + Self.nuaVach, 0), 0.85)
            Text(LocalizedStringKey(loai.nhanRes))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color(argb: 0x66000000), in: RoundedRectangle(cornerRadius: 4))
                .offset(x: size.width * x + 4, y: size.height * y - 8)
        }
    }

    private func ve(_ ctx: GraphicsContext, _ size: CGSize, _ mau: MocLuoi) {
        let gx = mau.giuaX ?? 0.5
        let net: CGFloat = 2
        let dut = StrokeStyle(lineWidth: net, dash: [10, 6])

        func khop(_ a: Double?, _ b: Double?, _ dung: Double) -> Bool {
            guard let a, let b else { return false }
            return abs(a - b) <= dung
        }
        func mauVach(_ dung: Bool) -> Color { dung ? Color(argb: 0xFF00E676) : Color(argb: 0xE6FFFFFF) }

        // Trục giữa của ảnh mẫu — nối mốc trên với mốc dưới.
        let trucDung = khop(gx, live?.giuaX, Self.dungChoX)
        var truc = Path()
        truc.move(to: CGPoint(x: gx * size.width, y: (mau.trenY ?? 0) * size.height))
        truc.addLine(to: CGPoint(x: gx * size.width, y: (mau.duoiY ?? 1) * size.height))
        ctx.stroke(truc, with: .color(mauVach(trucDung).opacity(0.55)), style: dut)

        // Hai vạch ngang: mốc trên và mốc dưới của ảnh mẫu.
        for (yMau, yLive) in [(mau.trenY, live?.trenY), (mau.duoiY, live?.duoiY)] {
            guard let yMau else { continue }
            var v = Path()
            v.move(to: CGPoint(x: max(gx - Self.nuaVach, 0) * size.width, y: yMau * size.height))
            v.addLine(to: CGPoint(x: min(gx + Self.nuaVach, 1) * size.width, y: yMau * size.height))
            ctx.stroke(v, with: .color(mauVach(khop(yMau, yLive, Self.dungChoY))),
                       style: StrokeStyle(lineWidth: net * 1.5, dash: [10, 6]))
        }

        // Chấm: mốc của người trong camera.
        if let live {
            let lx = (live.giuaX ?? gx) * size.width
            for (yLive, yMau) in [(live.trenY, mau.trenY), (live.duoiY, mau.duoiY)] {
                guard let yLive else { continue }
                let c = CGPoint(x: lx, y: yLive * size.height)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)),
                         with: .color(Color(argb: 0x99000000)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)),
                         with: .color(mauVach(khop(yLive, yMau, Self.dungChoY) && trucDung)))
            }
        }
    }
}

private extension LoaiMoc {
    var nhanRes: String {
        switch self {
        case .dau: "grid_mark_head"
        case .mat: "grid_mark_eyes"
        case .chan: "grid_mark_feet"
        case .goi: "grid_mark_knees"
        case .hong: "grid_mark_hips"
        case .vai: "grid_mark_shoulders"
        }
    }
}
