import CoreGraphics
import SwiftUI

/// MÀN CHỜ trong lúc sinh tiêu chí từ ảnh mẫu (1-2 giây). Port `TemplateAnalyzingScreen` (`KT/capture/CaptureScreen.kt`).
///
/// ⚠️ Có vì một lý do cụ thể: trước đây màn camera hiện NGAY với bảng tiêu chí RỖNG rồi mới điền dần — người dùng không
/// phân biệt được "đang tính" với "hỏng". Chờ có giải thích hơn màn hình trống im lặng (luật số 7).
struct TemplateAnalyzingView: View {

    let thumb: CGImage?

    var body: some View {
        VStack(spacing: 0) {
            if let thumb {
                Image(decorative: thumb, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: Ds.rSmall))
                    .accessibilityLabel(Text(LocalizedStringKey("analyzing_template_image")))
                    .padding(.bottom, 20)
            }
            ProgressView().tint(.white)
            Text(LocalizedStringKey("analyzing_template_title"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 16)
            Text(LocalizedStringKey("analyzing_template_sub"))
                .font(.system(size: 12))
                .foregroundStyle(Color(argb: 0xB3FFFFFF))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
