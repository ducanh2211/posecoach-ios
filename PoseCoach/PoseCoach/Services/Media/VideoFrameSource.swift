import AVFoundation
import CoreGraphics
import os

/// Lấy từng khung hình ra khỏi file video. Port từ `KT/media/VideoFrameSource.kt`.
///
/// Đường sản phẩm dùng ở bước chấm điểm sau khi quay 15-30 giây. Giải mã thẳng ở kích thước nhỏ (`maximumSize`, như
/// `getScaledFrameAtTime`) thay vì giải mã đủ cỡ rồi thu nhỏ: nhanh hơn nhiều và không phình bộ nhớ.
///
/// Khác Android: `MediaMetadataRetriever` → `AVAssetImageGenerator` (cũng lấy khung theo mốc thời gian, cũng tự áp
/// hướng xoay của video). API của iOS là bất đồng bộ nên `open` / `frameAt` là `async`. Bên gọi vẫn phải xin khung
/// THEO THỨ TỰ thời gian khi đưa vào `VideoPoseAnalyzer` (FOOTGUNS 18).
///
/// ⚠️ Video app tự quay (`VideoRecorder`) ghi hướng cầm máy VÀ phép lật camera trước vào `preferredTransform`, không
/// xoay/lật điểm ảnh. `appliesPreferredTrackTransform` áp đủ cả hai — đừng tắt nó.
nonisolated final class VideoFrameSource: @unchecked Sendable {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "VideoFrameSource")

    /// Độ dài video, mili-giây. 0 nếu không đọc được.
    let durationMs: Int64

    /// Góc xoay ghi trong video (phần xoay của `preferredTransform`), độ.
    ///
    /// Điện thoại quay dọc lưu khung NẰM NGANG kèm góc 90° — không xử lý thì người trong khung nằm ngang và bộ nhận diện
    /// không tìm ra (FOOTGUNS 10).
    let rotationDegrees: Int

    /// Kích thước khung SAU khi áp hướng xoay.
    let displayWidth: Int
    let displayHeight: Int

    private let srcWidth: Int
    private let srcHeight: Int
    /// Lấy khung khoá gần nhất — nhanh (như `OPTION_CLOSEST_SYNC`).
    private let syncGenerator: AVAssetImageGenerator?
    /// Lấy đúng khung tại mốc — chậm (như `OPTION_CLOSEST`), chỉ cho bước cắt lại vài ảnh cuối.
    private let exactGenerator: AVAssetImageGenerator?

    var isValid: Bool { durationMs > 0 && srcWidth > 0 && srcHeight > 0 }

    private init(durationMs: Int64, transform: CGAffineTransform, natural: CGSize, asset: AVAsset?, targetShortSide: Int) {
        self.durationMs = durationMs
        srcWidth = Int(natural.width)
        srcHeight = Int(natural.height)
        let deg = Int((atan2(transform.b, transform.a) * 180 / .pi).rounded())
        rotationDegrees = ((deg % 360) + 360) % 360
        let box = CGRect(origin: .zero, size: natural).applying(transform)
        displayWidth = Int(abs(box.width).rounded())
        displayHeight = Int(abs(box.height).rounded())

        let w = max(displayWidth, 1)
        let h = max(displayHeight, 1)
        let shortSide = min(w, h)
        let factor = shortSide <= targetShortSide ? 1.0 : Double(targetShortSide) / Double(shortSide)
        let size = CGSize(width: max(Int(Double(w) * factor), 1), height: max(Int(Double(h) * factor), 1))

        func generator(exact: Bool) -> AVAssetImageGenerator? {
            guard let asset else { return nil }
            let g = AVAssetImageGenerator(asset: asset)
            g.appliesPreferredTrackTransform = true
            g.maximumSize = size
            // ⚠️ ĐÂY LÀ THỦ PHẠM CHÍNH CỦA VIỆC LỌC ẢNH CHẬM bên Android (04/09/2026): lấy đúng khung phải giải mã lại từ
            // khung khoá gần nhất trở đi — mỗi lần gọi tới cả chục khung. Lấy khung khoá gần nhất thì không giải mã lại.
            // Đánh đổi chỉ ~1 khung/giây — chấp nhận được vì `BestShotBuffer.minGapMs` đã đòi cách nhau ≥ 0,9 giây.
            g.requestedTimeToleranceBefore = exact ? .zero : .positiveInfinity
            g.requestedTimeToleranceAfter = exact ? .zero : .positiveInfinity
            return g
        }
        syncGenerator = generator(exact: false)
        exactGenerator = generator(exact: true)
    }

    /// Mở video. Không đọc được thì trả nguồn `isValid == false` (không ném lỗi).
    static func open(_ file: URL, targetShortSide: Int = 480) async -> VideoFrameSource {
        let asset = AVURLAsset(url: file)
        do {
            let duration = try await asset.load(.duration)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                log.error("Video không có rãnh hình: \(file.lastPathComponent, privacy: .public)")
                return VideoFrameSource(durationMs: 0, transform: .identity, natural: .zero, asset: nil, targetShortSide: targetShortSide)
            }
            let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
            let ms = duration.isNumeric ? Int64(duration.seconds * 1000) : 0
            return VideoFrameSource(durationMs: ms, transform: transform, natural: natural, asset: asset,
                                    targetShortSide: targetShortSide)
        } catch {
            log.error("Không mở được video \(file.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return VideoFrameSource(durationMs: 0, transform: .identity, natural: .zero, asset: nil, targetShortSide: targetShortSide)
        }
    }

    /// Khung hình tại `timeMs`, đã dựng đúng chiều. `nil` nếu không lấy được.
    ///
    /// - Parameter exact: `true` = đúng khung tại mốc (bước cắt lại ảnh cuối ở độ phân giải cao — ít lần gọi nên chậm
    ///   không đáng kể); `false` = khung khoá gần nhất.
    func frameAt(_ timeMs: Int64, exact: Bool = false) async -> CGImage? {
        guard let g = exact ? exactGenerator : syncGenerator else { return nil }
        do {
            return try await g.image(at: CMTime(value: timeMs, timescale: 1000)).image
        } catch {
            Self.log.error("Không lấy được khung hình tại \(timeMs)ms: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func close() {
        syncGenerator?.cancelAllCGImageGeneration()
        exactGenerator?.cancelAllCGImageGeneration()
    }
}
