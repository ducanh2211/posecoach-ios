import CoreImage
import CoreMedia
import Foundation
import MediaPipeTasksVision
import PoseDomain
import Testing
@testable import PoseCoach

/// ĐỘ LỆCH CPU ↔ GPU của MediaPipe trên đường CAMERA (LIVE_STREAM, khung thu về 640 px như `CaptureController`).
///
/// Vì sao cần: camera chạy GPU cho mát máy (đo 17/11/2026: −31 % điện toàn máy), còn ảnh mẫu vẫn chạy CPU như Android.
/// GPU tính số thực khác CPU → toạ độ lệch một chút → lệch thẳng vào phép đo.
///
/// Ba phép so trên cùng 114 ảnh mẫu, mỗi phép ra lệch toạ độ và `lệch / Band.accept` từng mục:
/// - `cpu-gpu`: camera CPU ↔ camera GPU — riêng phần GPU gây ra
/// - `mau-cpu`: ảnh mẫu (IMAGE, cỡ gốc, CPU — đúng đường `PhanTichAnhMau`) ↔ camera CPU — lệch ĐANG CÓ hôm nay, MỐC SO
/// - `mau-gpu`: ảnh mẫu ↔ camera GPU — lệch nếu chuyển camera sang GPU
/// `mau-gpu` không xấu hơn `mau-cpu` rõ rệt ⇒ GPU không thêm sai số đáng kể so với cái đang sống chung.
///
/// ⚠️ Chạy trên My Mac: GPU của Mac không giống hệt GPU iPhone — đây là ước lượng, không phải số của máy thật.
///
/// Không chạy trong lượt test thường (~2,5 phút, 228 lần tạo bộ nhận diện). Bật bằng
/// `TEST_RUNNER_CPU_GPU=1 xcodebuild … -only-testing:PoseCoachTests/CpuGpuLechTests test`; bảng chi tiết ghi vào thư mục
/// tạm của app, đường dẫn in ra dòng `CPU_GPU …`.
@Suite(.serialized)
struct CpuGpuLechTests {

    private static let minVis: Float = 0.5
    /// Như `CaptureController.analysisLongSide`.
    private static let canhDai = 640
    private static let phepSo = ["cpu-gpu", "mau-cpu", "mau-gpu"]

    @Test("CPU ↔ GPU: lệch toạ độ và số đo trên 114 ảnh mẫu", .enabled(if: ProcessInfo.processInfo.environment["CPU_GPU"] != nil))
    func lechCpuGpu() throws {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let files = e.compactMap { $0 as? URL }
            .filter { MediaLibrary.imageExt.contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }
        #expect(files.count == 114)
        let goc = root.path + "/"

        var gom: [String: Gom] = [:]
        var dong = ["phep_so\tfile\tlop_a\tlop_b\tdiem_tb\tdiem_max\t"
            + Self.muc.map { "\($0.key)_lech/accept" }.joined(separator: "\t")]

        for f in files {
            let ten = f.path.replacingOccurrences(of: goc, with: "")
            let img = try #require(UprightImage.decode(f), "Không đọc được \(ten)")
            let mau = try #require(StillPoseAnalyzer.analyze(img), "\(ten): IMAGE lỗi")
            let sb = try Self.sampleBuffer(CIImage(cgImage: img))
            let cpu = try Self.live(sb, .CPU)
            let gpu = try Self.live(sb, .GPU)

            for (ten2, a, b) in [("cpu-gpu", cpu, gpu), ("mau-cpu", mau, cpu), ("mau-gpu", mau, gpu)] {
                dong.append("\(ten2)\t\(ten)\t" + Self.soSanh(a, b, into: &gom[ten2, default: Gom()]))
            }
        }

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("cpu-gpu-lech.tsv")
        try (dong.joined(separator: "\n") + "\n").write(to: out, atomically: true, encoding: .utf8)
        print("CPU_GPU bảng: \(out.path)")

        for p in Self.phepSo {
            let g = gom[p, default: Gom()]
            print("CPU_GPU [\(p)] có người cả hai: \(g.coNguoi) · một bên không thấy người: \(g.khacNguoi) · khác lớp khung hình: \(g.khacLop)")
            print("CPU_GPU [\(p)] lệch toạ độ (phần khung hình): " + Self.thongKe(g.lechDiem, "%.5f")
                + " · điểm lệch nhất mỗi ảnh: " + Self.thongKe(g.lechDiemMax, "%.5f"))
            for c in Self.muc {
                let v = g.tiLe[c] ?? []
                print("CPU_GPU [\(p)] \(c.key): " + Self.thongKe(v, "%.3f")
                    + " · > accept/3: \(v.filter { $0 > 1.0 / 3.0 }.count) · > accept: \(v.filter { $0 > 1.0 }.count)")
            }
        }

        #expect(gom["cpu-gpu"]?.khacNguoi == 0, "CPU và GPU bất đồng chuyện có người hay không")
    }

    // MARK: - So một cặp

    private struct Gom {
        var tiLe: [Criterion: [Double]] = [:]
        var lechDiem: [Double] = []
        var lechDiemMax: [Double] = []
        var khacNguoi = 0, khacLop = 0, coNguoi = 0
    }

    /// So `a` (vai ảnh mẫu) với `b` (vai camera). Lớp khung hình suy từ `a`, áp nguyên xi cho cả hai — đúng luật
    /// FramingClass. Trả phần còn lại của một dòng bảng.
    private static func soSanh(_ a: PoseFrame, _ b: PoseFrame, into g: inout Gom) -> String {
        if a.isEmpty != b.isEmpty {
            g.khacNguoi += 1
            return "\(a.isEmpty ? "-" : "co")\t\(b.isEmpty ? "-" : "co")\tKHAC_NGUOI"
        }
        guard !a.isEmpty else { return "-\t-\tKHONG_NGUOI" }
        g.coNguoi += 1

        var tong = 0.0, n = 0, lonNhat = 0.0
        for i in 0..<33 where a.visibility[i] >= minVis && b.visibility[i] >= minVis {
            let d = max(abs(a.points[i].x - b.points[i].x), abs(a.points[i].y - b.points[i].y))
            g.lechDiem.append(d)
            tong += d
            n += 1
            lonNhat = max(lonNhat, d)
        }
        g.lechDiemMax.append(lonNhat)

        let lopA = FramingClass.detect(a, minVis)
        let lopB = FramingClass.detect(b, minVis)
        if lopA != lopB { g.khacLop += 1 }
        let lop = lopA ?? .full
        let mA = Measurer.measure(a, lop, minVis)
        let mB = Measurer.measure(b, lop, minVis)
        let dev = ShotScorer.deviation(mA, mB)

        var cot: [String] = []
        for c in muc {
            guard let (lech, nguon) = lech(dev, c), let band = GuidanceConfig.bandFor(c, lop, mA.scale, nguon) else {
                cot.append("")
                continue
            }
            let r = lech / band.accept
            g.tiLe[c, default: []].append(r)
            cot.append(String(format: "%.3f", r))
        }
        return "\(lopA.map { "\($0)" } ?? "-")\t\(lopB.map { "\($0)" } ?? "-")\t"
            + String(format: "%.5f\t%.5f\t", n > 0 ? tong / Double(n) : 0, lonNhat) + cot.joined(separator: "\t")
    }

    /// Các mục hướng dẫn realtime đo từ ẢNH. `elevation` / `pitch` phía camera lấy từ CẢM BIẾN, không từ khung xương —
    /// vẫn in ra để biết, nhưng lệch của chúng không ảnh hưởng camera.
    private static let muc: [Criterion] = [.yaw, .perspective, .scale, .center, .pose, .roll, .elevation, .pitch]

    private static func lech(_ d: ShotDeviation, _ c: Criterion) -> (Double, PitchSource?)? {
        switch c {
        case .yaw: d.yawDeg.map { ($0, nil) }
        case .perspective: d.perspective.map { ($0, nil) }
        case .scale: d.scaleRatio.map { ($0, nil) }
        case .center: d.centerX.map { ($0, nil) }
        case .pose: d.poseDeg.map { ($0, nil) }
        case .roll: d.rollDeg.map { ($0, nil) }
        case .elevation: d.elevationDeg.map { ($0, nil) }
        case .pitch: d.pitchCue.map { ($0, d.pitchSource) }
        default: nil
        }
    }

    private static func thongKe(_ v: [Double], _ fmt: String) -> String {
        guard !v.isEmpty else { return "không có số" }
        let s = v.sorted()
        func p(_ q: Double) -> Double { s[min(s.count - 1, Int(Double(s.count - 1) * q))] }
        return "n=\(s.count) trung vị " + String(format: fmt, p(0.5)) + " · p95 " + String(format: fmt, p(0.95))
            + " · max " + String(format: fmt, s.last!)
    }

    // MARK: - Nhận diện

    /// Một khung LIVE_STREAM với bộ nhận diện MỚI (không mang vùng bám của ảnh trước), chờ kết quả tối đa 10 giây.
    private static func live(_ sb: CMSampleBuffer, _ delegate: Delegate) throws -> PoseFrame {
        let done = DispatchSemaphore(value: 0)
        let box = Hop()
        let detector = PoseDetector(
            config: PoseDetector.Config(delegate: delegate),
            onResult: { frame, _ in box.frame = frame; done.signal() },
            onError: { err in box.loi = err; done.signal() }
        )
        detector.setup()
        try #require(detector.isReady, "Không tạo được bộ nhận diện \(delegate == .GPU ? "GPU" : "CPU")")
        detector.detect(sb, orientation: .up, maxLongSide: canhDai)
        #expect(done.wait(timeout: .now() + 10) == .success, "LIVE_STREAM không trả kết quả")
        detector.close()
        try #require(box.loi == nil, "Lỗi: \(String(describing: box.loi))")
        return try #require(box.frame)
    }

    private final class Hop: @unchecked Sendable {
        var frame: PoseFrame?
        var loi: UiText?
    }

    private static func sampleBuffer(_ ci: CIImage) throws -> CMSampleBuffer {
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
}
