import CoreGraphics
import Foundation
import PoseDomain
import Testing
@testable import PoseCoach

/// Bước 6a — CÔNG CỤ xuất số liệu THÔ của 114 ảnh mẫu cài sẵn chạy bằng runtime iOS: landmark MediaPipe (IMAGE), mặt
/// ML Kit, GeoCalib. Định dạng + cách dùng: `tools/so-sanh-parity/README.md`.
///
/// Không chạy trong lượt test thường (GeoCalib ~2,5 s/ảnh → ~5 phút). Bật bằng
/// `TEST_RUNNER_XUAT_6A=1 xcodebuild … -only-testing:PoseCoachTests/XuatAnhMau6aTests test`; tệp ghi vào thư mục tạm
/// của app, đường dẫn in ra dòng `XUAT_6A …`.
@Suite(.serialized)
struct XuatAnhMau6aTests {

    @Test("xuất số liệu thô 114 ảnh mẫu", .enabled(if: ProcessInfo.processInfo.environment["XUAT_6A"] != nil))
    func xuat() async throws {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let files = e.compactMap { $0 as? URL }
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }
        #expect(files.count == 114)
        let goc = root.path + "/"

        var items: [[String: Any]] = []
        for f in files {
            let item = await Task.detached { Self.mot(f, ten: f.path.replacingOccurrences(of: goc, with: "")) }.value
            items.append(item)
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("6a-ios-anh-mau.json")
        let data = try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: out)
        print("XUAT_6A \(items.count) ảnh → \(out.path)")
    }

    /// Số liệu thô của một ảnh. Mặt chạy trên MỌI ảnh có người (tầng tính lại tự bỏ mặt khi ảnh bị cổng từ chối).
    private static func mot(_ f: URL, ten: String) -> [String: Any] {
        var o: [String: Any] = ["file": ten, "runtime": "ios"]
        guard let img = UprightImage.decode(f) else { return o }
        o["w"] = img.width
        o["h"] = img.height
        let frame = StillPoseAnalyzer.analyze(img)
        if let frame, !frame.isEmpty {
            o["landmarks"] = zip(frame.points, frame.visibility).map { [$0.0.x, $0.0.y, Double($0.1)] }
            o["world"] = frame.world.map { [$0.x, $0.y, $0.z] }
            if let face = FaceAnalyzer().analyze(img) {
                o["face"] = ["yawDeg": face.yawDeg.map { $0 as Any } ?? NSNull(),
                             "eyesOpen": face.eyesOpen.map { $0 as Any } ?? NSNull()]
            } else {
                o["face"] = NSNull()
            }
        } else {
            o["landmarks"] = [[Double]]()
            o["world"] = [[Double]]()
            o["face"] = NSNull()
        }
        if let g = GeoCalibGocMay.phanTich(img) {
            o["geocalib"] = ["pitchDeg": g.pitchDeg, "rollDeg": g.rollDeg, "vfovDeg": g.vfovDeg]
        } else {
            o["geocalib"] = NSNull()
        }
        return o
    }
}
