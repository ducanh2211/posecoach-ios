import CoreGraphics
import PoseDomain
import SwiftUI

/// Một ô lưới ảnh mẫu. Port `TemplateCard` trong `KT/home/HomeScreen.kt` (đổi tên vì `DesignSystem/TemplateCard` là thẻ
/// ảnh mẫu nhỏ trên màn chụp).
///
/// ⚠️ TẢI THEO Ô, ĐÚNG CỠ Ô (FOOTGUNS 111) — không giải mã sẵn mọi ảnh trước khi hiện lưới.
struct TemplateGridCell: View {

    let template: MediaLibrary.Template
    /// Ảnh này đang qua cổng kiểm (1-2 giây) — không hiện thì người dùng tưởng app treo.
    let checking: Bool

    @State private var thumb: CGImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Ds.surfaceMuted
                if let thumb {
                    Image(decorative: thumb, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    ProgressView().tint(Ds.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // Tên đặt ĐÈ lên ảnh với dải tối phía dưới: ảnh cao hơn thì người trong ảnh mẫu dễ nhìn hơn.
                Text(verbatim: template.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(argb: 0x99000000))
                if checking {
                    ZStack {
                        Color(argb: 0xAA000000)
                        VStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text(LocalizedStringKey("template_checking"))
                                .font(.system(size: 11)).foregroundStyle(.white)
                        }
                    }
                }
            }
            .task(id: template.file) {
                let file = template.file
                let side = Int(min(geo.size.width, geo.size.height) * displayScale)
                thumb = await Task.detached { ThumbnailCache.shared.thumbnail(file, shortSide: max(side, 64)) }.value
            }
        }
        .aspectRatio(0.72, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Ds.rTile))
        .accessibilityElement(children: .combine)
    }
}
