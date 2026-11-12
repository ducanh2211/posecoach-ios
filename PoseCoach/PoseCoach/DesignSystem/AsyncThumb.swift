import SwiftUI

/// Ảnh thu nhỏ lấp đầy ô (cắt giữa), tải theo ô qua `ThumbnailCache` (FOOTGUNS 111) — thay `AsyncImage` của Coil.
/// Dùng ở Thư viện và luồng Bối cảnh.
struct AsyncThumb: View {

    let file: URL
    @State private var image: CGImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
            }
            .task(id: file) {
                let side = max(Int(min(geo.size.width, geo.size.height) * displayScale), 64)
                let f = file
                image = await Task.detached { ThumbnailCache.shared.thumbnail(f, shortSide: side) }.value
            }
        }
    }
}
