import CoreGraphics
import Foundation

/// Ảnh thu nhỏ để HIỂN THỊ ô lưới ảnh mẫu — tương đương Coil ở `HomeScreen.kt` (FOOTGUNS 111).
///
/// ⚠️ KHÔNG giải mã sẵn mọi ảnh: 114+ ảnh nguyên cỡ là vài trăm MB. Mỗi ô tự xin ảnh của mình khi hiện ra, thu về cỡ
/// ô, nhớ đệm (bộ nhớ hệ thống thiếu thì tự thả). Vẫn đọc qua `UprightImage` — nơi duy nhất đọc file ảnh (FOOTGUNS 44).
nonisolated final class ThumbnailCache: @unchecked Sendable {

    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, CGImage>()

    private init() {
        // Giới hạn theo BYTE, không theo số ảnh: `UprightImage` thu theo luỹ thừa 2 nên một ô có thể vài trăm KB tới
        // ~2 MB. 64 MB đủ cho vài màn lưới; cuộn xa thì ảnh cũ bị thả, quay lại thì giải mã lại.
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Ảnh thu nhỏ, cạnh ngắn ≥ `shortSide` điểm ảnh. Chặn luồng khi chưa có trong đệm — gọi từ luồng nền.
    func thumbnail(_ file: URL, shortSide: Int) -> CGImage? {
        if let hit = cache.object(forKey: file as NSURL) { return hit }
        guard let img = UprightImage.decode(file, shortSide: shortSide) else { return nil }
        cache.setObject(img, forKey: file as NSURL, cost: img.bytesPerRow * img.height)
        return img
    }

    /// Bỏ ảnh của file (đổi tên, xoá).
    func remove(_ file: URL) {
        cache.removeObject(forKey: file as NSURL)
    }
}
