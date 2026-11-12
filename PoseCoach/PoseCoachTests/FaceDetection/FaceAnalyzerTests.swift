import CoreGraphics
import Foundation
import PoseDomain
import Testing
@testable import PoseCoach

/// ML Kit nhận diện mặt ra `FaceInfo` trên ảnh chân dung; ảnh không có người thì `nil` (không phải lỗi).
@Suite(.serialized)
struct FaceAnalyzerTests {

    private func anh(_ ten: String) throws -> CGImage {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let url = try #require(e.compactMap { $0 as? URL }.first { $0.lastPathComponent == ten }, "thiếu ảnh mẫu \(ten)")
        return try #require(UprightImage.decode(url))
    }

    /// ML Kit iOS chặn khi gọi trên luồng chính — chạy ở luồng nền như app.
    private func phanTich(_ img: CGImage) async -> FaceInfo? {
        await Task.detached { FaceAnalyzer().analyze(img) }.value
    }

    @Test func anhChanDungRaGocMatVaMatMo() async throws {
        for ten in ["selfie-ngang-male-001.jpg", "selfie-ngang-male-009.jpg", "selfie-tren-male-004.jpg"] {
            let info = try #require(await phanTich(try anh(ten)), "không thấy mặt trong \(ten)")
            let yaw = try #require(info.yawDeg)
            #expect(abs(yaw) < 60, "\(ten): yaw \(yaw)")
            let eyes = try #require(info.eyesOpen, "\(ten): không đo được mắt")
            #expect((0...1).contains(eyes))
        }
    }

    /// Mốc cho buổi đối chiếu với Android (6a): ML Kit thấy mặt ở ảnh nào, góc mặt và mắt mở bao nhiêu.
    @Test func ghiMocCaThuVienAnhMau() async throws {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let urls = e.compactMap { $0 as? URL }
            .filter { ["jpg", "jpeg", "png", "webp", "jfif"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        #expect(urls.count == 114)
        let posix = Locale(identifier: "en_US_POSIX")
        var tsv = "file\tface\tyaw_deg\teyes_open\n"
        var thay = 0
        for u in urls {
            // Nguyên cỡ, như `PhanTichAnhMau.kt` / `CaptureScreen.kt` giải mã ảnh mẫu trước khi chạy mặt.
            guard let img = UprightImage.decode(u) else { continue }
            let info = await phanTich(img)
            if info != nil { thay += 1 }
            let yaw = info?.yawDeg.map { String(format: "%.1f", locale: posix, $0) } ?? ""
            let eyes = info?.eyesOpen.map { String(format: "%.2f", locale: posix, $0) } ?? ""
            tsv += "\(u.lastPathComponent)\t\(info == nil ? 0 : 1)\t\(yaw)\t\(eyes)\n"
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("3c-mat-anh-mau.tsv")
        try tsv.write(to: out, atomically: true, encoding: .utf8)
        print("Face TSV: \(out.path) — thấy mặt \(thay)/\(urls.count)")
        #expect(thay > 0)
    }

    @Test func anhTronKhongCoMat() async {
        let ctx = CGContext(data: nil, width: 400, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        #expect(await phanTich(ctx.makeImage()!) == nil)
    }
}
