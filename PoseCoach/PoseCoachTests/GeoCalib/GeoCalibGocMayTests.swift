import CoreGraphics
import Foundation
import Testing
@testable import PoseCoach

/// GeoCalib chạy được trên ảnh mẫu thật, ra số nằm trong khoảng hợp lý; ghi `pitch` / `vfov` làm MỐC cho buổi đối chiếu
/// với Android (6a). Model không nạp được → có log + `nil`, không treo.
@Suite(.serialized)
struct GeoCalibGocMayTests {

    /// Năm ảnh mẫu khác nhóm, khác nhãn góc máy (`tren` / `ngang` / `duoi`).
    private static let mau = [
        "duoi-female-001.jpg", "ngang-female-004.jpg", "ngang-nam-nen-trang-tay-tui.jpg",
        "mirror-ngang-phong-thay-do.jpg", "selfie-tren-female-012.jpg",
    ]

    private func anh(_ ten: String) throws -> CGImage {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let url = try #require(e.compactMap { $0 as? URL }.first { $0.lastPathComponent == ten }, "thiếu ảnh mẫu \(ten)")
        return try #require(UprightImage.decode(url))
    }

    @Test func tienXuLyDungCoVaBoiSo32() throws {
        let img = try anh(Self.mau[0])
        let (chw, h, w) = try #require(GeoCalibGocMay.tienXuLy(img))
        #expect(min(h, w) <= 320 && min(h, w) > 320 - 32)
        #expect(h % 32 == 0 && w % 32 == 0)
        #expect(chw.count == 3 * h * w)
        #expect(chw.allSatisfy { (0...1).contains($0) })
    }

    @Test func chayTrenAnhMauGhiMoc() async throws {
        var tsv = "file\tpitch_deg\troll_deg\tvfov_deg\tms\n"
        for ten in Self.mau {
            let img = try anh(ten)
            let kq = try #require(await Task.detached { GeoCalibGocMay.phanTich(img) }.value, "GeoCalib không ra kết quả: \(ten)")
            #expect((-90...90).contains(kq.pitchDeg), "\(ten): pitch \(kq.pitchDeg)")
            #expect((-45...45).contains(kq.rollDeg), "\(ten): roll \(kq.rollDeg)")
            #expect((15...130).contains(kq.vfovDeg), "\(ten): vfov \(kq.vfovDeg)")
            tsv += String(format: "%@\t%.2f\t%.2f\t%.2f\t%lld\n", locale: Locale(identifier: "en_US_POSIX"),
                          ten, kq.pitchDeg, kq.rollDeg, kq.vfovDeg, kq.thoiGianMs)
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("3c-geocalib-anh-mau.tsv")
        try tsv.write(to: out, atomically: true, encoding: .utf8)
        print("GeoCalib TSV: \(out.path)")
    }

    @Test func modelKhongNapDuocThiNil() {
        #expect(GeoCalibGocMay.taoPhien(nil) == nil)
        #expect(GeoCalibGocMay.taoPhien(URL(fileURLWithPath: "/khong-co/geocalib.onnx")) == nil)
    }

    @Test func anhQuaNhoThiNil() {
        let ctx = CGContext(data: nil, width: 20, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        #expect(GeoCalibGocMay.tienXuLy(ctx.makeImage()!) == nil)
    }
}
