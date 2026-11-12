import CoreImage
import CoreVideo
import ImageIO
import UIKit

/// XOAY KHUNG CAMERA VỀ ĐÚNG CHIỀU trước khi đưa vào MediaPipe — tương đương `Bitmap.rotate` trong
/// `KT/pose/PoseDetector.kt` (Android cũng tự xoay bitmap, không dùng tham số xoay của thư viện).
///
/// ⚠️ KHÔNG dùng `MPImage(…, orientation:)` với hướng khác `.up`: MediaPipe 1.0.0 trên iOS xử lý sai. Đo 12/11/2026
/// (`PoseLandmarkerTests`): cùng một ảnh nằm ngang, `.up` thấy người tin cậy 0,98; `.right` / `.left` ra khung xương
/// rác; `.down` không thấy ai — cả đường `UIImage` lẫn `CVPixelBuffer`. Không có lỗi nào báo ra (FOOTGUNS 5).
///
/// Đầu ra BGRA 32 bit (định dạng MediaPipe đọc được), lấy từ pool để không cấp phát mỗi khung.
nonisolated final class UprightPixelBuffer {

    private let context = CIContext()
    private var pool: CVPixelBufferPool?
    private var poolSize = (w: 0, h: 0)

    /// Khung đã dựng đứng. `.up` thì trả nguyên khung, không tốn gì.
    func upright(_ buffer: CVPixelBuffer, _ orientation: UIImage.Orientation) -> CVPixelBuffer? {
        if orientation == .up { return buffer }
        let image = CIImage(cvPixelBuffer: buffer).oriented(CGImagePropertyOrientation(orientation))
        let w = Int(image.extent.width), h = Int(image.extent.height)
        guard let out = taoBuffer(w, h) else { return nil }
        context.render(
            image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY)),
            to: out
        )
        return out
    }

    private func taoBuffer(_ w: Int, _ h: Int) -> CVPixelBuffer? {
        if pool == nil || poolSize != (w, h) {
            let attrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: w,
                kCVPixelBufferHeightKey: h,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            ]
            var p: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &p)
            pool = p
            poolSize = (w, h)
        }
        guard let pool else { return nil }
        var out: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
        return out
    }
}

nonisolated private extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
