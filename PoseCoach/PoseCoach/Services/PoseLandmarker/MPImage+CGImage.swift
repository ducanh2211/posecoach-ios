import CoreGraphics
import MediaPipeTasksVision
import UIKit

nonisolated extension MPImage {

    /// Đưa ảnh đã dựng đúng chiều vào MediaPipe. Vẽ lại về RGBA 8 bit trước — tương đương bước ép `ARGB_8888` của
    /// Kotlin ("ảnh phải ở định dạng ARGB_8888 thì MediaPipe mới đọc được"): ảnh PNG 16 bit, ảnh xám, ảnh CMYK… thì
    /// MediaPipe không đọc được.
    static func rgba(_ image: CGImage) throws -> MPImage {
        try MPImage(uiImage: UIImage(cgImage: rgba8(image)), orientation: .up)
    }

    private static func rgba8(_ image: CGImage) -> CGImage {
        if image.bitsPerComponent == 8, image.bitsPerPixel == 32,
           image.colorSpace?.model == .rgb,
           image.alphaInfo == .premultipliedLast || image.alphaInfo == .noneSkipLast {
            return image
        }
        guard let ctx = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }
}
