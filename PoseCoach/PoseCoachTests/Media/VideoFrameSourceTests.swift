import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import Testing
@testable import PoseCoach

/// Đi trọn vòng QUAY → ĐỌC: `VideoRecorder` ghi khung cảm biến (nằm ngang, góc 0°) kèm transform xoay / lật, rồi
/// `VideoFrameSource` đọc ra phải đúng chiều xem. Dấu đỏ ở góc TRÊN-TRÁI của khung cảm biến:
/// - cầm dọc (xoay 90° thuận chiều kim đồng hồ) → ra góc TRÊN-PHẢI;
/// - cầm dọc + lật gương (camera trước) → ra góc TRÊN-TRÁI.
@Suite(.serialized)
struct VideoFrameSourceTests {

    private static let w = 320, h = 180

    /// Khung BGRA đen, ô đỏ 80×45 ở góc trên-trái.
    private func khung() -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, Self.w, Self.h, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pb)
        let buf = pb!
        CVPixelBufferLockBaseAddress(buf, [])
        let base = CVPixelBufferGetBaseAddress(buf)!.assumingMemoryBound(to: UInt8.self)
        let row = CVPixelBufferGetBytesPerRow(buf)
        for y in 0..<Self.h {
            for x in 0..<Self.w {
                let p = base + y * row + x * 4
                let red = x < 80 && y < 45
                p[0] = 0; p[1] = 0; p[2] = red ? 255 : 0; p[3] = 255
            }
        }
        CVPixelBufferUnlockBaseAddress(buf, [])
        return buf
    }

    private func sampleBuffer(_ pb: CVPixelBuffer, _ frame: Int64) -> CMSampleBuffer {
        var fmt: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb, formatDescriptionOut: &fmt)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                        presentationTimeStamp: CMTime(value: frame, timescale: 30),
                                        decodeTimeStamp: .invalid)
        var sb: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pb, formatDescription: fmt!,
                                                 sampleTiming: &timing, sampleBufferOut: &sb)
        return sb!
    }

    private func quay(rotation: CGFloat, mirrored: Bool) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vfs-\(UUID().uuidString).mp4")
        let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Self.w, AVVideoHeightKey: Self.h]
        let rec = try VideoRecorder(outputFile: url, settings: settings, rotationAngle: rotation, mirrored: mirrored)
        let pb = khung()
        for i in 0..<15 {
            rec.append(sampleBuffer(pb, Int64(i)))
            // Bộ nén thời gian thực bỏ khung khi chưa kịp — cho nó thở.
            try await Task.sleep(for: .milliseconds(10))
        }
        let err: Error? = await withCheckedContinuation { c in rec.finish { c.resume(returning: $0) } }
        #expect(err == nil, "ghi video hỏng: \(String(describing: err))")
        return url
    }

    /// Màu đỏ ở tâm ô góc (trái/phải × trên) của ảnh.
    private func doO(_ img: CGImage, phai: Bool) -> Bool {
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { b in
            let ctx = CGContext(data: b.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        let x = phai ? w - w / 10 : w / 10
        let y = h / 20 // hàng 0 của bộ đệm = đỉnh ảnh
        let i = (y * w + x) * 4
        return px[i] > 150 && px[i + 1] < 80 && px[i + 2] < 80
    }

    @Test func camDocXoayDungChieu() async throws {
        let url = try await quay(rotation: 90, mirrored: false)
        defer { try? FileManager.default.removeItem(at: url) }
        let src = await VideoFrameSource.open(url)
        #expect(src.isValid)
        #expect(src.rotationDegrees == 90)
        #expect(src.displayWidth == Self.h && src.displayHeight == Self.w, "cầm dọc → khung đứng")
        let img = try #require(await src.frameAt(0, exact: true))
        #expect(img.width == Self.h && img.height == Self.w)
        #expect(doO(img, phai: true), "góc trên-trái cảm biến phải ra góc trên-PHẢI")
        #expect(!doO(img, phai: false))
        src.close()
    }

    @Test func camTruocLatGuong() async throws {
        let url = try await quay(rotation: 90, mirrored: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let src = await VideoFrameSource.open(url)
        let img = try #require(await src.frameAt(0, exact: true))
        #expect(img.width == Self.h && img.height == Self.w)
        #expect(doO(img, phai: false), "lật gương → góc trên-TRÁI")
        #expect(!doO(img, phai: true))
    }

    @Test func camNgangGiuNguyen() async throws {
        let url = try await quay(rotation: 0, mirrored: false)
        defer { try? FileManager.default.removeItem(at: url) }
        let src = await VideoFrameSource.open(url)
        #expect(src.rotationDegrees == 0 && src.displayWidth == Self.w && src.displayHeight == Self.h)
        #expect(src.durationMs > 0)
        let img = try #require(await src.frameAt(200))
        #expect(doO(img, phai: false))
    }

    @Test func fileKhongPhaiVideoThiKhongHopLe() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rac-\(UUID().uuidString).mp4")
        try "khong phai video".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let src = await VideoFrameSource.open(url)
        #expect(!src.isValid)
        #expect(await src.frameAt(0) == nil)
    }
}
