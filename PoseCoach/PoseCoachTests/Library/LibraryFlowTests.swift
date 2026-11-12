import CoreGraphics
import Foundation
import ImageIO
import PoseDomain
import Testing
import UniformTypeIdentifiers
@testable import PoseCoach

/// Phase 5 — màn Thư viện: nạp các buổi đã lưu, nhãn ảnh, xoá cả buổi.
@Suite(.serialized) @MainActor
struct LibraryFlowTests {

    private func ghiAnh(_ f: URL) throws {
        let ctx = try #require(CGContext(data: nil, width: 20, height: 30, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        ctx.setFillColor(CGColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        let dest = try #require(CGImageDestinationCreateWithURL(f as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, try #require(ctx.makeImage()), nil)
        #expect(CGImageDestinationFinalize(dest))
    }

    @Test func napNhanVaXoaBuoi() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("lib-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let mau = tmp.appendingPathComponent("mau.jpg"), a = tmp.appendingPathComponent("a.jpg"),
            b = tmp.appendingPathComponent("b.jpg")
        for f in [mau, a, b] { try ghiAnh(f) }
        let dir = ResultLibrary.dir().appendingPathComponent("buoi-test-\(UUID().uuidString)")
        #expect(ResultLibrary.ghiAlbum(dir, mau, [(a, 87), (b, 52)]))
        defer { try? FileManager.default.removeItem(at: dir) }

        let vm = LibraryViewModel()
        await vm.reload()
        #expect(vm.loaded)
        let album = try #require(vm.albums.first { $0.dir.lastPathComponent == dir.lastPathComponent })
        #expect(album.count == 2 && album.templateThumb != nil)

        let best = album.photos[0], other = album.photos[1]
        #expect(AlbumView.nhanAnh(album, best, laAnhTotNhat: true) == uiText("library_yours_score", .int(87)))
        #expect(AlbumView.nhanAnh(album, other, laAnhTotNhat: false) == uiText("library_score", .int(52)))
        #expect(!LibraryViewModel.formatTime(album.createdAtMs).isEmpty)

        vm.open = album
        vm.confirmDelete = album
        vm.deleteConfirmed()
        #expect(vm.open == nil && vm.confirmDelete == nil)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
        for _ in 0..<100 where vm.albums.contains(where: { $0.dir.lastPathComponent == dir.lastPathComponent }) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!vm.albums.contains { $0.dir.lastPathComponent == dir.lastPathComponent })
    }
}
