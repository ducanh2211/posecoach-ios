import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import PoseDomain

/// NHẬN DIỆN KHUÔN MẶT THỜI GIAN THỰC trên khung camera. Port khối `faceLive` trong `KT/capture/CaptureScreen.kt`.
///
/// ⚠️ Trước 12/09/2026 (Android) dữ liệu mặt CHƯA HỀ vào đường này — chỉ chạy lúc phân tích ảnh mẫu và lúc chấm sau khi
/// quay. Với ảnh mẫu chân dung, hướng mẫu (face yaw) không đo được phía camera và tiêu chí bị bỏ.
///
/// Chạy THƯA hơn nhịp khung hình và KHÔNG BAO GIỜ chồng lần nhau: lần trước chưa xong mà vẫn đẩy thêm thì hàng đợi phình
/// ra, độ trễ tích tới vài giây. Khung đưa vào là khung THÔ (dựng đứng, chưa lật gương) — bên gọi tự đảo dấu góc quay
/// mặt với camera trước.
nonisolated final class LiveFaceTracker: @unchecked Sendable {

    /// Nhịp chạy, mili-giây. ~3 lần/giây đủ cho một khuôn mặt — đầu người không đổi hướng nhanh hơn thế, và ngưỡng
    /// "quá cũ" phía ViewModel (600 ms) nên vẫn luôn có số tươi.
    static let faceNhipMs: Int64 = 300

    private let analyzer = FaceAnalyzer()
    private let queue = DispatchQueue(label: "LiveFaceTracker", qos: .userInitiated)
    private let ci = CIContext(options: [.cacheIntermediates: false])
    private let lock = NSLock()
    private var dangChay = false
    private var lanCuoiMs: Int64 = 0
    private let onFace: @Sendable (FaceInfo?) -> Void

    /// - Parameter onFace: kết quả từng lần chạy, `nil` = không thấy mặt. Gọi trên luồng nền.
    init(onFace: @escaping @Sendable (FaceInfo?) -> Void) {
        self.onFace = onFace
    }

    /// Đưa một khung vào. Gọi trên luồng camera; tới nhịp và đang rảnh thì CHÉP khung ra rồi chạy ở luồng riêng.
    func offer(_ buffer: CVPixelBuffer) {
        let now = Int64(ProcessInfo.processInfo.systemUptime * 1000)
        lock.lock()
        guard !dangChay, now - lanCuoiMs >= Self.faceNhipMs else {
            lock.unlock()
            return
        }
        dangChay = true
        lanCuoiMs = now
        lock.unlock()

        // Bộ đệm gốc bị dùng lại ở khung sau — phải chép ra trước khi rời luồng camera.
        let sao = ci.createCGImage(CIImage(cvPixelBuffer: buffer), from: CGRect(
            x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
        guard let sao else {
            lock.withLock { dangChay = false }
            return
        }
        queue.async { [self] in
            let info = analyzer.analyze(sao)
            onFace(info)
            lock.withLock { dangChay = false }
        }
    }
}
