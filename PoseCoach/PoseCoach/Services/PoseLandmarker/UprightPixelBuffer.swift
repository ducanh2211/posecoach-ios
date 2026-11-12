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

    /// Khung đã dựng đứng. `.up` và không cần thu nhỏ thì trả nguyên khung, không tốn gì.
    ///
    /// - Parameter maxLongSide: thu nhỏ để cạnh dài không quá chừng này điểm ảnh — tương đương độ phân giải mặc định
    ///   640×480 của `ImageAnalysis` (CameraX). Thu nhỏ cùng lượt với xoay nên không tốn thêm một lần vẽ. `nil` = giữ cỡ.
    func upright(_ buffer: CVPixelBuffer, _ orientation: UIImage.Orientation, maxLongSide: Int? = nil) -> CVPixelBuffer? {
        let longSide = max(CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer))
        let scale: CGFloat = maxLongSide.map { longSide > $0 ? CGFloat($0) / CGFloat(longSide) : 1 } ?? 1
        if orientation == .up && scale == 1 { return buffer }
        var image = CIImage(cvPixelBuffer: buffer).oriented(CGImagePropertyOrientation(orientation))
        if scale < 1 { image = image.samplingLinear().transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
        let w = Int(image.extent.width.rounded()), h = Int(image.extent.height.rounded())
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
