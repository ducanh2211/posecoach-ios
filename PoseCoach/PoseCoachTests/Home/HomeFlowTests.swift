import CoreGraphics
import Foundation
import PoseDomain
import Testing
@testable import PoseCoach

/// Luật của bước 4b: mốc nhóm góc máy, nhận diện ảnh nhập, chế độ chụp theo nhóm ảnh mẫu.
@Suite(.serialized)
struct HomeFlowTests {

    @Test func nhomTuGocTheoMoc15Do() {
        #expect(nhomTuGoc(-15) == .tren)
        #expect(nhomTuGoc(-14.9) == .ngang)
        #expect(nhomTuGoc(0) == .ngang)
        #expect(nhomTuGoc(14.9) == .ngang)
        #expect(nhomTuGoc(15) == .duoi)
    }

    /// Chép một ảnh cài sẵn ra file tạm mang tên ảnh nhập.
    private func anhNhapTam(_ ten: String) throws -> URL {
        let root = Bundle.main.bundleURL.appendingPathComponent("templates")
        let e = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let src = try #require(e.compactMap { $0 as? URL }.first { $0.lastPathComponent == ten }, "thiếu ảnh mẫu \(ten)")
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(MediaLibrary.tienToNhap)\(UUID().uuidString).jpg")
        try FileManager.default.copyItem(at: src, to: dest)
        return dest
    }

    /// Nhận diện chạy trọn: qua cổng kiểm, báo tiến độ đủ bốn bước liền nhau, đoán được góc máy.
    @Test func nhanDienAnhCaiSan() async throws {
        let f = try anhNhapTam("ngang-di-bo-ben-ho.jpg")
        defer { try? FileManager.default.removeItem(at: f) }
        let buoc = Buoc()
        let kq = await Task.detached { nhanDienNhap(f) { tu, den, _ in buoc.them(tu, den) } }.value
        guard case .accepted = kq.phanTich.verdict else {
            Issue.record("ảnh cài sẵn phải qua cổng kiểm")
            return
        }
        #expect(buoc.ds.map(\.0) == [0, 0.35, 0.45, 0.97])
        #expect(buoc.ds.map(\.1) == [0.35, 0.45, 0.97, 1])
        #expect(kq.geo != nil, "GeoCalib phải đo được ảnh ngoài trời")
        // `duChac` chỉ đúng khi mọi câu đều chắc.
        if kq.duChac { #expect(kq.kieuChac && kq.gocChac && kq.goc != nil) }
    }

    /// Chỉ ảnh tự nhập mới được gắn bù — ảnh cài sẵn giữ nguyên tên.
    @Test func boSungNhanGocBoQuaAnhCaiSan() async throws {
        let f = Bundle.main.bundleURL.appendingPathComponent("templates/ngang-di-bo-ben-ho.jpg")
        let ra = await Task.detached { boSungNhanGoc(f, phanTichAnhMau(f)) }.value
        #expect(ra == f)
    }

    @MainActor @Test func cheDoChupTheoNhomAnhMau() {
        let ca: [(String, ShootMode, ShootMode)] = [
            // tên file, chế độ lúc mở, chế độ sau khi xoay camera
            ("selfie-a.jpg", .tuChupCamTruoc, .nguoiKhac),
            ("mirror-a.jpg", .tuChupGuong, .tuChupCamTruoc),
            ("ngang-a.jpg", .nguoiKhac, .tuChupCamTruoc),
            ("tripod-a.jpg", .datMay, .nguoiKhac),
        ]
        for (ten, dau, sau) in ca {
            let vm = CaptureViewModel(template: URL(fileURLWithPath: "/tmp/\(ten)"))
            #expect(vm.state.mode == dau, "\(ten)")
            vm.flipCamera()
            #expect(vm.state.mode == sau, "\(ten) xoay lần 1")
            vm.flipCamera()
            #expect(vm.state.mode == dau, "\(ten) xoay lần 2 về chế độ ban đầu")
        }
    }
}

private final class Buoc: @unchecked Sendable {
    private let lock = NSLock()
    private var _ds: [(Float, Float)] = []
    var ds: [(Float, Float)] { lock.withLock { _ds } }
    func them(_ tu: Float, _ den: Float) { lock.withLock { _ds.append((tu, den)) } }
}
