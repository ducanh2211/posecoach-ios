import CoreGraphics
import Foundation
import PoseDomain
import Testing
@testable import PoseCoach

/// Kho ảnh tạm: bảng kê đọc lại đúng, mục không đo được giữ trống, cắt tỉ lệ đúng phần giữa, dọn phiên bỏ lại.
@Suite(.serialized)
struct ShotStoreTests {

    private func anh(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    @Test func bangKeGhiDocLaiDungVaGiuMucTrong() throws {
        let store = ShotStore.createSession()
        defer { store.deleteSession() }
        #expect(store.save(1, anh(40, 30)))
        #expect(store.save(2, anh(40, 30)))
        let k0 = ShotStore.partKeys[0], k1 = ShotStore.partKeys[1]
        store.writeIndex([
            ShotCandidate(id: 1, timeMs: 1200, score: 0.899, trustworthy: true, parts: [k0: 0.5]),
            ShotCandidate(id: 2, timeMs: 2400, score: 0.4, trustworthy: false, parts: [k1: 0.25]),
            // File không còn → dòng bị bỏ khi đọc lại.
            ShotCandidate(id: 3, timeMs: 3600, score: 0.7, trustworthy: true),
        ])
        let doc = store.readIndex()
        #expect(doc.map(\.id) == [1, 2])
        #expect(doc[0].timeMs == 1200 && abs(doc[0].score - 0.899) < 1e-9 && doc[0].trustworthy)
        #expect(doc[0].parts == [k0: 0.5], "mục không đo được phải đọc lại là TRỐNG, không phải 0")
        #expect(doc[1].parts == [k1: 0.25] && !doc[1].trustworthy)
    }

    @Test func catTiLeLayPhanGiua() {
        let store = ShotStore.createSession()
        defer { store.deleteSession() }
        let goc = anh(400, 300)
        let doc = store.cropToAspect(goc, 3.0 / 4.0)
        #expect(doc.width == 225 && doc.height == 300)
        let ngang = store.cropToAspect(anh(300, 400), 1.0)
        #expect(ngang.width == 300 && ngang.height == 300)
        #expect(store.cropToAspect(goc, nil) === goc)
        #expect(store.cropToAspect(goc, 4.0 / 3.0 * 1.005) === goc, "lệch dưới 1% thì giữ nguyên")
    }

    @Test func donPhienBoLaiTruPhienDangDung() {
        let a = ShotStore.createSession()
        let b = ShotStore.openSession(ShotStore.rootDir().appendingPathComponent("s-cu"))
        ShotStore.sweepOrphans(keep: a.sessionDir)
        #expect(FileManager.default.fileExists(atPath: a.sessionDir.path))
        #expect(!FileManager.default.fileExists(atPath: b.sessionDir.path))
        a.deleteSession()
    }
}
