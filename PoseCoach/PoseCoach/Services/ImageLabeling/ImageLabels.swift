import CoreGraphics
import MLKitImageLabeling
import MLKitVision
import os
import UIKit

/// Nhãn ML Kit Image Labeling của một ảnh — phần `nhanMlKit` trong `KT/home/NhanDienNhap.kt`.
///
/// Dùng để đoán kiểu chụp ảnh tự nhập ("Mobile phone" → gương, "Selfie" → selfie camera trước).
///
/// ⚠️ Chạy ĐỒNG BỘ — chỉ gọi từ luồng nền. Xếp hàng qua `MLKitLock` cùng `FaceAnalyzer`.
nonisolated enum ImageLabels {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "ImageLabels")

    /// Tên nhãn tiếng Anh gốc → độ tin cậy. Rỗng khi lỗi — khi đó bên gọi coi như không chắc.
    static func of(_ image: CGImage) -> [String: Float] {
        // Hạ ngưỡng xuống 0,2 (mặc định 0,5): cần biết cả nhãn yếu mới phân được "chắc không có" với "không chắc".
        let options = ImageLabelerOptions()
        options.confidenceThreshold = 0.2
        let labeler = ImageLabeler.imageLabeler(options: options)
        let vision = VisionImage(image: UIImage(cgImage: image))
        vision.orientation = .up
        do {
            // Như `associate`: nhãn trùng tên thì cái sau thắng.
            var out: [String: Float] = [:]
            for l in try MLKitLock.lock.withLock({ try labeler.results(in: vision) }) { out[l.text] = Float(l.confidence) }
            return out
        } catch {
            log.warning("Không gắn nhãn được ảnh: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }
}
