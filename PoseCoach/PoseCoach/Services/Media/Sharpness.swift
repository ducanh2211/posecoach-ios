import CoreGraphics
import Foundation

/// ĐỘ NÉT của một khung hình. Port từ `KT/capture/Sharpness.kt`.
///
/// ⚠️ KHÔNG phải phép chấm chất lượng ảnh nói chung — PO đã chốt bỏ qua rung tay và ánh sáng. Cái duy nhất đo ở đây là
/// **nhoè do CHỦ THỂ cử động**: mẫu vung tay hay xoay người trong lúc quay thì đúng khung đó nhoè, dù máy đứng yên.
///
/// Cách đo: **phương sai của toán tử Laplace**. Ảnh nét nhiều đường biên rõ → số lớn; ảnh nhoè → số nhỏ.
///
/// Con số **không có đơn vị, không so được giữa các phiên**. Chỉ so các khung TRONG CÙNG một lần quay.
nonisolated enum Sharpness {

    /// Thu nhỏ về bề ngang này trước khi tính — cho kịp, và để các khung cùng kích thước thì số đo mới so được.
    private static let workWidth = 160

    /// - Returns: số càng lớn càng nét. `0` khi không tính được.
    static func of(_ image: CGImage) -> Double {
        if image.width < 8 || image.height < 8 { return 0.0 }

        let w = workWidth
        let hh = max(Int(Int64(workWidth) * Int64(image.height) / Int64(image.width)), 8)
        guard let gray = grayPixels(image, w, hh) else { return 0.0 }

        // Toán tử Laplace 3x3: điểm giữa nhân 4 trừ 4 điểm xung quanh. Vùng phẳng ra ~0; đường biên ra số lớn.
        var sum = 0.0
        var sumSq = 0.0
        var n = 0
        for y in 1..<(hh - 1) {
            let row = y * w
            for x in 1..<(w - 1) {
                let i = row + x
                let v = 4 * gray[i] - gray[i - 1] - gray[i + 1] - gray[i - w] - gray[i + w]
                sum += v
                sumSq += v * v
                n += 1
            }
        }
        if n == 0 { return 0.0 }

        let mean = sum / Double(n)
        return (sumSq / Double(n)) - mean * mean
    }

    /// Quy một loạt số đo thô về thang 0..1, 1 = nét nhất của loạt. Cả loạt nét ngang nhau thì trả 1.0 hết.
    static func normalize(_ values: [Double]) -> [Double] {
        guard let max = values.max(), let min = values.min() else { return [] }
        // Chênh lệch không đáng kể → coi như nhau. Ngưỡng tương đối, không tuyệt đối.
        if max <= 0.0 || (max - min) < max * 0.05 { return values.map { _ in 1.0 } }
        return values.map { Swift.min(Swift.max((($0 - min) / (max - min)), 0.0), 1.0) }
    }

    /// Thu nhỏ (song tuyến, như `Bitmap.scale(filter = true)`) rồi đổi sang mức xám theo hệ số độ nhạy của mắt.
    private static func grayPixels(_ image: CGImage, _ w: Int, _ h: Int) -> [Double]? {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let ok = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            ctx.interpolationQuality = .low
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        var gray = [Double](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            gray[i] = 0.299 * Double(rgba[4 * i]) + 0.587 * Double(rgba[4 * i + 1]) + 0.114 * Double(rgba[4 * i + 2])
        }
        return gray
    }
}
