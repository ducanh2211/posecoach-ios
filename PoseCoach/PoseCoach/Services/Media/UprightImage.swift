import CoreGraphics
import Foundation
import ImageIO
import os

/// NẠP ẢNH ĐÃ DỰNG ĐÚNG CHIỀU — nơi DUY NHẤT được đọc file ảnh trong app. Port từ `KT/media/UprightBitmap.kt`.
///
/// Điện thoại chụp ảnh dọc nhưng lưu ra file NẰM NGANG kèm cờ EXIF "khi hiển thị thì xoay 90°". Đọc thẳng điểm ảnh
/// mà bỏ cờ thì MediaPipe thấy người nằm ngang → cổng kiểm từ chối "gần như nằm ngang", cao/thấp thành trái/phải
/// (FOOTGUNS 44). Lỗi hiện ra dưới dạng "ảnh không dùng được", không ai đoán được nguyên nhân.
///
/// ⚠️ **Không đọc file ảnh bằng cách nào khác** (`UIImage(contentsOfFile:)`, `CGImageSourceCreateImageAtIndex`…) —
/// rải phép xoay khắp code thì sẽ có chỗ quên, mà chỗ quên không báo lỗi gì.
nonisolated enum UprightImage {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "UprightImage")

    /// Nạp ảnh và xoay/lật về đúng chiều người xem nhìn thấy (đủ 8 giá trị cờ EXIF, kể cả lật gương).
    ///
    /// - Parameter shortSide: cạnh ngắn mong muốn, điểm ảnh. `nil` = nguyên cỡ. Như Android: thu nhỏ theo **luỹ thừa
    ///   của 2** (`inSampleSize`), cạnh ngắn kết quả ≥ `shortSide`.
    static func decode(_ file: URL, shortSide: Int? = nil) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(file as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0
        else {
            log.warning("Không nạp được ảnh \(file.lastPathComponent, privacy: .public)")
            return nil
        }

        var s = 1
        if let shortSide {
            let short = min(w, h)
            // `inSampleSize` chỉ nhận luỹ thừa của 2; giá trị khác bị làm tròn xuống.
            while short / (s * 2) >= shortSide { s *= 2 }
        }

        // Ảnh thu nhỏ của ImageIO có `WithTransform` = áp cờ EXIF, cạnh dài giới hạn bởi `MaxPixelSize`.
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(w, h) / s,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            log.warning("Không giải mã được ảnh \(file.lastPathComponent, privacy: .public)")
            return nil
        }
        return img
    }
}
