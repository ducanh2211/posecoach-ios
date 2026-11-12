import CoreGraphics
import Foundation
import ImageIO
import PoseDomain
import Testing
import UniformTypeIdentifiers
@testable import PoseCoach

/// Màn xem lại (4d): nạp phiên từ đĩa, ba lối ra, hỏi trước khi thoát, giữ ảnh → xoá cả thư mục phiên (FOOTGUNS 114).
///
/// Phiên đặt trong thư mục tạm riêng, KHÔNG trong `Caches/shots/` — `ShotStoreTests` gọi `sweepOrphans` có thể chạy song
/// song và xoá mất.
@Suite(.serialized) @MainActor
struct ResultFlowTests {

    /// Ảnh mẫu cỡ lạ để nhận ra album do test này ghi.
    private static let mauW = 37, mauH = 29

    private func anh(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    /// Phiên 3 tấm: id 1 = 40,5 điểm, id 2 = 80, id 3 = 60 (bảng kê theo thứ tự id) + ảnh mẫu.
    private func taoPhien(rong: Bool = false) throws -> (session: URL, template: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("result-\(UUID().uuidString)")
        let store = ShotStore.openSession(root.appendingPathComponent("s1"))
        let template = root.appendingPathComponent("mau-test.jpg")
        let dest = try #require(CGImageDestinationCreateWithURL(template as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, anh(Self.mauW, Self.mauH), nil)
        #expect(CGImageDestinationFinalize(dest))
        if !rong {
            for id: Int64 in 1...3 { #expect(store.save(id, anh(30, 40))) }
            store.writeIndex([
                ShotCandidate(id: 1, timeMs: 1000, score: 40.5, trustworthy: true, parts: ["huong": 0.9]),
                ShotCandidate(id: 2, timeMs: 2000, score: 80.0, trustworthy: true, parts: ["huong": 0.9]),
                ShotCandidate(id: 3, timeMs: 3000, score: 60.0, trustworthy: false, parts: ["huong": 0.9]),
            ])
        }
        return (store.sessionDir, template)
    }

    private func choToi(_ vm: ResultViewModel, _ dieuKien: () -> Bool) async throws {
        for _ in 0..<500 where !dieuKien() { try await Task.sleep(for: .milliseconds(10)) }
        #expect(dieuKien(), "quá 5 s chưa xong")
    }

    private func albumCuaTest() -> Set<URL> {
        Set(ResultLibrary.albums().filter { a in
            guard let m = a.templateThumb, let img = UprightImage.decode(m) else { return false }
            return img.width == Self.mauW && img.height == Self.mauH
        }.map(\.dir))
    }

    private func conTon(_ u: URL) -> Bool { FileManager.default.fileExists(atPath: u.path) }

    @Test func napTuDiaChonTamDauTien() async throws {
        let p = try taoPhien()
        defer { try? FileManager.default.removeItem(at: p.session.deletingLastPathComponent()) }
        let vm = ResultViewModel(sessionDir: p.session, templateFile: p.template)
        await vm.load()
        #expect(!vm.state.loading && vm.state.shots.map(\.candidate.id) == [1, 2, 3])
        #expect(vm.state.selected?.candidate.id == 1)
        #expect(vm.state.shots.allSatisfy { $0.bitmap != nil })
        #expect(vm.state.shots.map(\.scoreText) == ["41", "80", "60"], "làm tròn nửa lên như Java %.0f")
    }

    @Test func luuTatCaKemAnhMauXepTheoDiemRoiXoaPhien() async throws {
        let p = try taoPhien()
        defer { try? FileManager.default.removeItem(at: p.session.deletingLastPathComponent()) }
        let truoc = albumCuaTest()
        let vm = ResultViewModel(sessionDir: p.session, templateFile: p.template)
        await vm.load()
        vm.onAction(.saveAll)
        try await choToi(vm) { vm.state.exitTo != nil }
        #expect(vm.state.exitTo == .library && !vm.state.busy && vm.state.message == nil)
        #expect(!conTon(p.session), "giữ xong phải xoá cả thư mục phiên")

        let moi = albumCuaTest().subtracting(truoc)
        #expect(moi.count == 1)
        let album = try #require(moi.first)
        defer { try? FileManager.default.removeItem(at: album) }
        let diem = try String(contentsOf: album.appendingPathComponent("_diem.txt"), encoding: .utf8)
        #expect(diem == "anh-01.jpg=80\nanh-02.jpg=60\nanh-03.jpg=41\n")

        vm.onExitHandled()
        #expect(vm.state.exitTo == nil)
    }

    @Test func luuAnhDaChonChiGhiAnhDaTich() async throws {
        let p = try taoPhien()
        defer { try? FileManager.default.removeItem(at: p.session.deletingLastPathComponent()) }
        let truoc = albumCuaTest()
        let vm = ResultViewModel(sessionDir: p.session, templateFile: p.template)
        await vm.load()
        vm.onAction(.toggleCheck(3))
        vm.onAction(.toggleCheck(1))
        vm.onAction(.toggleCheck(1))
        #expect(vm.state.checked == [3])
        vm.onAction(.saveChecked)
        try await choToi(vm) { vm.state.exitTo != nil }
        let album = try #require(albumCuaTest().subtracting(truoc).first)
        defer { try? FileManager.default.removeItem(at: album) }
        #expect(try String(contentsOf: album.appendingPathComponent("_diem.txt"), encoding: .utf8) == "anh-01.jpg=60\n")
    }

    @Test func quayLaiPhaiHoiKhongLuuThiXoaPhien() async throws {
        let p = try taoPhien()
        defer { try? FileManager.default.removeItem(at: p.session.deletingLastPathComponent()) }
        let truoc = albumCuaTest()
        let vm = ResultViewModel(sessionDir: p.session, templateFile: p.template)
        await vm.load()
        vm.onAction(.back)
        #expect(vm.state.hoiKhiThoat && vm.state.exitTo == nil, "còn ảnh chưa lưu hay xoá thì phải hỏi")
        vm.onAction(.dismissBack)
        #expect(!vm.state.hoiKhiThoat && conTon(p.session))
        vm.onAction(.back)
        vm.onAction(.backDiscard)
        try await choToi(vm) { vm.state.exitTo != nil }
        #expect(vm.state.exitTo == .templates && !vm.state.hoiKhiThoat)
        #expect(!conTon(p.session))
        #expect(albumCuaTest() == truoc, "không lưu thì không được ghi album")
    }

    @Test func xoaDeChupLaiVeCamera() async throws {
        let p = try taoPhien()
        defer { try? FileManager.default.removeItem(at: p.session.deletingLastPathComponent()) }
        let vm = ResultViewModel(sessionDir: p.session, templateFile: p.template)
        await vm.load()
        vm.onAction(.askDiscard)
        #expect(vm.state.xacNhanXoa)
        vm.onAction(.cancelDiscard)
        #expect(!vm.state.xacNhanXoa && conTon(p.session))
        vm.onAction(.askDiscard)
        vm.onAction(.discard)
        try await choToi(vm) { vm.state.exitTo != nil }
        #expect(vm.state.exitTo == .camera && !vm.state.xacNhanXoa && !conTon(p.session))
    }

    @Test func phienRongThoatLuonKhongHoi() async throws {
        let p = try taoPhien(rong: true)
        defer { try? FileManager.default.removeItem(at: p.session.deletingLastPathComponent()) }
        let vm = ResultViewModel(sessionDir: p.session, templateFile: p.template)
        await vm.load()
        #expect(vm.state.isEmpty)
        vm.onAction(.back)
        #expect(!vm.state.hoiKhiThoat)
        try await choToi(vm) { vm.state.exitTo != nil }
        #expect(vm.state.exitTo == .templates && !conTon(p.session))
    }

    /// Chép hỏng → báo lỗi, KHÔNG xoá phiên, không rời màn — người dùng thử lại được.
    @Test func luuHongThiBaoVaGiuPhien() async throws {
        let p = try taoPhien()
        defer { try? FileManager.default.removeItem(at: p.session.deletingLastPathComponent()) }
        let vm = ResultViewModel(sessionDir: p.session, templateFile: p.template)
        await vm.load()
        for id in 1...3 { try FileManager.default.removeItem(at: p.session.appendingPathComponent("\(id).jpg")) }
        vm.onAction(.saveAll)
        try await choToi(vm) { !vm.state.busy }
        #expect(vm.state.message == uiText("result_save_all_failed"))
        #expect(vm.state.exitTo == nil && conTon(p.session))
    }
}
