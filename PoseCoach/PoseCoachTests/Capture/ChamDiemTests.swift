import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import PoseDomain
import Testing
@testable import PoseCoach

/// Đi trọn đường CHẤM ĐIỂM SAU KHI CHỤP của màn chụp, trên ảnh mẫu thật: chụp liên tục (8 tấm) và quay video. Mỗi đường
/// phải ra phiên có ảnh + bảng kê, và **XOÁ NGUỒN** (luật chống rác — video thô 60-100 MB, loạt ảnh vài chục MB).
@Suite(.serialized) @MainActor
struct ChamDiemTests {

    private static let tenMau = "ngang-di-bo-ben-ho.jpg"

    private func anhMau() throws -> URL {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return try #require(e.compactMap { $0 as? URL }.first { $0.lastPathComponent == Self.tenMau })
    }

    /// ViewModel đã có hồ sơ ảnh mẫu — như sau bước phân tích ảnh mẫu, chưa mở camera.
    private func vmCoHoSo() async throws -> CaptureViewModel {
        let f = try anhMau()
        let (thumb, frame) = await Task.detached { () -> (CGImage?, PoseFrame?) in
            let bmp = UprightImage.decode(f)
            return (bmp, bmp.flatMap { StillPoseAnalyzer.analyze($0) })
        }.value
        let vm = CaptureViewModel(template: f)
        vm.onTemplateAnalyzed(f.deletingPathExtension().lastPathComponent, thumb, frame, nil)
        #expect(vm.state.templateError == nil)
        #expect(vm.templateProfile != nil)
        return vm
    }

    /// Chờ chấm xong (thành công hoặc báo lỗi).
    private func choXong(_ vm: CaptureViewModel) async throws -> URL {
        for _ in 0..<600 where vm.state.finishedSession == nil && vm.state.cameraError == nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(vm.state.cameraError == nil, "chấm hỏng: \(vm.state.cameraError.map { $0.resolved() } ?? "")")
        #expect(!vm.state.processing)
        return try #require(vm.state.finishedSession)
    }

    private func kiemPhien(_ dir: URL) throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let anh = files.filter { $0.hasSuffix(".jpg") }
        #expect(!anh.isEmpty && anh.count <= 5, "giữ tối đa 5 ảnh, được \(anh.count)")
        #expect(files.contains("index.csv"))
        #expect(ShotStore.openSession(dir).readIndex().count == anh.count, "bảng kê khớp số ảnh")
    }

    @Test func chupLienTucGiuAnhVaXoaLoatGoc() async throws {
        let vm = try await vmCoHoSo()
        let src = try anhMau()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("burst-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let photos = try (0..<CaptureViewModel.burstCount).map { i -> URL in
            let u = dir.appendingPathComponent(String(format: "burst-%02d.jpg", i))
            try FileManager.default.copyItem(at: src, to: u)
            return u
        }

        vm.processBurst(photos)
        #expect(vm.state.processing)
        try kiemPhien(try await choXong(vm))
        #expect(photos.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) }, "ảnh gốc của loạt phải bị xoá")
    }

    @Test func quayVideoGiuAnhVaXoaVideoTho() async throws {
        let vm = try await vmCoHoSo()
        let video = try await quayTuAnh(try anhMau())
        defer { try? FileManager.default.removeItem(at: video) }

        vm.processRecording(video)
        try kiemPhien(try await choXong(vm))
        #expect(!FileManager.default.fileExists(atPath: video.path), "video thô phải bị xoá")
    }

    @Test func khongCoHoSoThiBaoLoiVaXoaNguon() throws {
        let vm = CaptureViewModel(template: URL(fileURLWithPath: "/tmp/ngang-x.jpg"))
        let f = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString).mp4")
        try Data([0]).write(to: f)
        vm.processRecording(f)
        #expect(vm.state.cameraError != nil)
        #expect(!FileManager.default.fileExists(atPath: f.path))
    }

    /// Quay ~1,5 giây từ một ảnh tĩnh (thu về cạnh ngắn 360) — đủ để chấm ra người ở mọi mốc 500 ms.
    private func quayTuAnh(_ file: URL) async throws -> URL {
        let img = try #require(UprightImage.decode(file, shortSide: 360))
        let w = img.width / 2 * 2, h = img.height / 2 * 2
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pb)
        let buf = try #require(pb)
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = try #require(CGContext(
            data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        CVPixelBufferUnlockBaseAddress(buf, [])

        var fmt: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buf, formatDescriptionOut: &fmt)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString).mp4")
        let rec = try VideoRecorder(outputFile: url,
                                    settings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h],
                                    rotationAngle: 0, mirrored: false)
        for i in 0..<45 {
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                            presentationTimeStamp: CMTime(value: Int64(i), timescale: 30),
                                            decodeTimeStamp: .invalid)
            var sb: CMSampleBuffer?
            CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: buf, formatDescription: fmt!,
                                                     sampleTiming: &timing, sampleBufferOut: &sb)
            rec.append(sb!)
            // Bộ nén thời gian thực bỏ khung khi chưa kịp — cho nó thở.
            try await Task.sleep(for: .milliseconds(10))
        }
        let err: Error? = await withCheckedContinuation { c in rec.finish { c.resume(returning: $0) } }
        #expect(err == nil)
        return url
    }
}
