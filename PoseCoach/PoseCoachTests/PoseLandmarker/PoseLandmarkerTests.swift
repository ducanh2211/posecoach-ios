import CoreImage
import CoreMedia
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import PoseCoach
import PoseDomain

/// Bước 3a — bọc MediaPipe (IMAGE / VIDEO / LIVE_STREAM). Chạy trên My Mac.
@Suite(.serialized)
struct PoseLandmarkerTests {

    // MARK: - Hỗ trợ

    private static let mauDung = "templates/ngang-nam-nen-trang-tay-tui.jpg"

    private func bundleFile(_ path: String) throws -> URL {
        let url = Bundle.main.bundleURL.appendingPathComponent(path)
        try #require(FileManager.default.fileExists(atPath: url.path), "Thiếu \(path) trong bundle")
        return url
    }

    /// Mọi ảnh mẫu trong bundle (quét đệ quy — nhóm đọc từ tiền tố tên file, không từ thư mục).
    private func anhMau() -> [URL] {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var out: [URL] = []
        while let u = e?.nextObject() as? URL {
            if MediaLibrary.imageExt.contains(u.pathExtension.lowercased()) { out.append(u) }
        }
        return out.sorted { $0.path < $1.path }
    }

    /// Trung bình |Δx| + |Δy| trên các điểm cả hai bên cùng tin được.
    private func lech(_ a: PoseFrame, _ b: PoseFrame) -> Double? {
        guard a.points.count == 33, b.points.count == 33 else { return nil }
        var tong = 0.0, n = 0
        for i in 0..<33 where a.visibility[i] >= 0.5 && b.visibility[i] >= 0.5 {
            tong += abs(a.points[i].x - b.points[i].x) + abs(a.points[i].y - b.points[i].y)
            n += 1
        }
        return n == 0 ? nil : tong / Double(n)
    }

    /// Điểm ảnh LƯU ra từ ảnh đã dựng đứng, đúng kiểu ảnh cờ EXIF 6 / camera sau cầm dọc (`.right`): ảnh lưu = ảnh
    /// hiển thị xoay 90° ngược chiều kim đồng hồ.
    private func luuNamNgang(_ upright: CGImage) -> CIImage {
        let ci = CIImage(cgImage: upright).oriented(.left)
        return ci.transformed(by: CGAffineTransform(translationX: -ci.extent.minX, y: -ci.extent.minY))
    }

    private func sampleBuffer(_ ci: CIImage) throws -> CMSampleBuffer {
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        CVPixelBufferCreate(nil, Int(ci.extent.width), Int(ci.extent.height), kCVPixelFormatType_32BGRA, attrs, &pb)
        let buffer = try #require(pb)
        CIContext().render(ci, to: buffer)
        var fmt: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer, formatDescriptionOut: &fmt)
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sb: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil, imageBuffer: buffer, formatDescription: try #require(fmt),
            sampleTiming: &timing, sampleBufferOut: &sb
        )
        return try #require(sb)
    }

    /// Chạy LIVE_STREAM một khung, chờ kết quả (tối đa 10 giây).
    private func live(_ sb: CMSampleBuffer, _ orientation: UIImage.Orientation) throws -> PoseFrame {
        let done = DispatchSemaphore(value: 0)
        let box = Hop()
        let detector = PoseDetector(
            onResult: { frame, _ in box.frame = frame; done.signal() },
            onError: { err in box.loi = err; done.signal() }
        )
        detector.setup()
        try #require(detector.isReady)
        detector.detect(sb, orientation: orientation)
        #expect(done.wait(timeout: .now() + 10) == .success, "LIVE_STREAM không trả kết quả")
        detector.close()
        try #require(box.loi == nil, "Lỗi: \(String(describing: box.loi))")
        return try #require(box.frame)
    }

    private final class Hop: @unchecked Sendable {
        var frame: PoseFrame?
        var loi: UiText?
    }

    // MARK: - IMAGE trên toàn bộ ảnh mẫu

    @Test("IMAGE: 114 ảnh mẫu đều ra 33 điểm hoặc khung rỗng, qua cổng kiểm có kết quả rõ")
    func toanBoAnhMau() throws {
        let files = anhMau()
        #expect(files.count == 114)
        let root = Bundle.main.bundleURL.appendingPathComponent("templates").path + "/"

        func khoa(_ t: UiText) -> String {
            if case let .res(k, _) = t { return k }
            return "\(t)"
        }

        var dong = ["file\tw\th\tdiem\tcong\tframing\tly_do"]
        var dem = ["xanh": 0, "vang": 0, "do": 0]
        for f in files {
            let ten = f.path.replacingOccurrences(of: root, with: "")
            let img = try #require(UprightImage.decode(f), "Không đọc được \(ten)")
            let frame = try #require(StillPoseAnalyzer.analyze(img), "\(ten): không phân tích được")
            #expect(frame.points.count == 33 || frame.isEmpty, "\(ten): \(frame.points.count) điểm")
            let cong: String, framing: String, lyDo: String
            switch TemplateGate.check(frame) {
            case let .rejected(r):
                cong = "do"; framing = "-"; lyDo = khoa(r.reason)
            case let .accepted(a):
                cong = a.hasWarnings ? "vang" : "xanh"
                framing = "\(a.framing)"
                lyDo = a.warnings.map(khoa).joined(separator: ",")
            }
            dem[cong, default: 0] += 1
            dong.append("\(ten)\t\(img.width)\t\(img.height)\t\(frame.points.count)\t\(cong)\t\(framing)\t\(lyDo)")
        }
        let bang = dong.joined(separator: "\n") + "\n"
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("3a-anh-mau-cong-kiem.tsv")
        try bang.write(to: out, atomically: true, encoding: .utf8)
        print("BANG_3A \(out.path) xanh=\(dem["xanh"]!) vang=\(dem["vang"]!) do=\(dem["do"]!)")
    }

    @Test("IMAGE: y hướng XUỐNG — mũi nằm trên cổ chân (FG 3)")
    func yHuongXuong() throws {
        let img = try #require(UprightImage.decode(try bundleFile(Self.mauDung)))
        let f = try #require(StillPoseAnalyzer.analyze(img))
        try #require(f.points.count == 33)
        #expect(f.points[Lm.nose].y < f.points[Lm.leftAnkle].y)
        #expect(f.points[Lm.nose].y < f.points[Lm.rightAnkle].y)
    }

    @Test("Ảnh lưu nằm ngang kèm cờ EXIF 6 ra cùng khung xương với ảnh gốc (FG 44)")
    func exifXoay() throws {
        let goc = try #require(UprightImage.decode(try bundleFile(Self.mauDung)))
        let luu = try #require(CIContext().createCGImage(luuNamNgang(goc), from: luuNamNgang(goc).extent))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("exif6.jpg")
        let dest = try #require(CGImageDestinationCreateWithURL(file as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, luu, [kCGImagePropertyOrientation: 6] as CFDictionary)
        try #require(CGImageDestinationFinalize(dest))

        let doc = try #require(UprightImage.decode(file))
        #expect(doc.width == goc.width && doc.height == goc.height, "Phải dựng lại đúng chiều dọc")
        let a = try #require(StillPoseAnalyzer.analyze(goc))
        let b = try #require(StillPoseAnalyzer.analyze(doc))
        let d = try #require(lech(a, b), "Phải thấy người ở cả hai")
        #expect(d < 0.02, "Lệch trung bình \(d)")
    }

    @Test("UprightImage thu nhỏ theo luỹ thừa của 2, cạnh ngắn không dưới mức xin")
    func thuNho() throws {
        let f = try bundleFile(Self.mauDung)
        let full = try #require(UprightImage.decode(f))
        let nho = try #require(UprightImage.decode(f, shortSide: 64))
        // Chia theo cạnh DÀI: cạnh ngắn bị làm tròn (1080 / 16 = 67,5 → 68).
        let s = max(full.width, full.height) / max(nho.width, nho.height)
        #expect(s >= 1 && (s & (s - 1)) == 0, "Hệ số \(s) không phải luỹ thừa của 2")
        #expect(min(nho.width, nho.height) >= 64)
    }

    // MARK: - LIVE_STREAM

    @Test("LIVE_STREAM: khung dựng đứng ra cùng khung xương với IMAGE")
    func liveDungDung() throws {
        let img = try #require(UprightImage.decode(try bundleFile(Self.mauDung)))
        let still = try #require(StillPoseAnalyzer.analyze(img))
        let f = try live(try sampleBuffer(CIImage(cgImage: img)), .up)
        let d = try #require(lech(still, f), "LIVE_STREAM không thấy người")
        #expect(d < 0.02, "Lệch trung bình \(d)")
    }

    @Test("LIVE_STREAM: khung cảm biến nằm ngang + hướng .right ra cùng khung xương (FG 5)")
    func liveXoay() throws {
        let img = try #require(UprightImage.decode(try bundleFile(Self.mauDung)))
        let still = try #require(StillPoseAnalyzer.analyze(img))
        let f = try live(try sampleBuffer(luuNamNgang(img)), .right)
        let d = try #require(lech(still, f), "LIVE_STREAM không thấy người")
        #expect(d < 0.02, "Lệch trung bình \(d) — hướng sai là hoán trục X/Y")
    }

    @Test("LIVE_STREAM: model không nạp được thì báo lỗi, không im lặng")
    func liveModelHong() {
        let box = Hop()
        let detector = PoseDetector(
            config: PoseDetector.Config(modelAsset: "khong-co.task"),
            onResult: { _, _ in },
            onError: { box.loi = $0 }
        )
        detector.setup()
        #expect(!detector.isReady)
        guard case let .res(key, _)? = box.loi else {
            Issue.record("Phải gọi onError, nhận \(String(describing: box.loi))")
            return
        }
        #expect(key == "detector_err_load")
    }

    // MARK: - VIDEO

    @Test("VIDEO: mốc thời gian bị ép tăng nghiêm ngặt, vẫn ra khung")
    func videoMocThoiGian() throws {
        let img = try #require(UprightImage.decode(try bundleFile(Self.mauDung)))
        let v = VideoPoseAnalyzer()
        defer { v.close() }
        try #require(v.isReady)
        let ts = try [100, 100, 50].map { try #require(v.analyze(img, Int64($0))).timestampMs }
        #expect(ts == [100, 101, 102])
    }

    @Test("Model không nạp được: IMAGE trả nil, VIDEO không sẵn sàng")
    func modelHong() throws {
        let img = try #require(UprightImage.decode(try bundleFile(Self.mauDung)))
        #expect(StillPoseAnalyzer.analyze(img, modelAsset: "khong-co.task") == nil)
        let v = VideoPoseAnalyzer(modelAsset: "khong-co.task")
        #expect(!v.isReady)
        #expect(v.analyze(img, 0) == nil)
        // Quay lại model thật vẫn chạy được.
        #expect(StillPoseAnalyzer.analyze(img) != nil)
    }

    // MARK: - FOOTGUNS 17

    @Test("Tạo / huỷ bộ nhận diện đồng thời từ nhiều luồng không sập (FG 17)")
    func taoHuyDongThoi() throws {
        let img = try #require(UprightImage.decode(try bundleFile(Self.mauDung)))
        DispatchQueue.concurrentPerform(iterations: 6) { i in
            if i % 2 == 0 {
                let v = VideoPoseAnalyzer()
                _ = v.analyze(img, 0)
                v.close()
            } else {
                let d = PoseDetector(onResult: { _, _ in }, onError: { _ in })
                d.setup()
                d.close()
                _ = StillPoseAnalyzer.analyze(img)
            }
        }
    }
}
