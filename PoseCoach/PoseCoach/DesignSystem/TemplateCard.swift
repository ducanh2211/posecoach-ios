import CoreGraphics
import SwiftUI

/// Thẻ ảnh mẫu nhỏ ở góc trên phải, có nhãn "MẪU". Port `TemplateCard` (`KT/ui/GuidanceOverlay.kt`).
struct TemplateCard: View {

    let thumb: CGImage?

    var body: some View {
        if let thumb {
            Image(decorative: thumb, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 132)
                .clipped()
                .background(.black)
                .overlay(alignment: .topTrailing) {
                    Text(LocalizedStringKey("template_badge"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(argb: 0xCC000000), in: Capsule())
                        .padding(5)
                }
                .clipShape(RoundedRectangle(cornerRadius: Ds.rSmall))
                .accessibilityElement()
                .accessibilityLabel(Text(LocalizedStringKey("template_image")))
        }
    }
}
