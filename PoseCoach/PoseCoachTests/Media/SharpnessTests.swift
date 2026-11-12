import CoreGraphics
import Testing
@testable import PoseCoach

/// Độ nét: ảnh nhiều biên gắt cho số lớn hơn ảnh trơn; quy về 0..1 theo loạt.
struct SharpnessTests {

    private func oCo(_ w: Int, _ h: Int, o: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        for y in stride(from: 0, to: h, by: o) {
            for x in stride(from: 0, to: w, by: o) where (x / o + y / o) % 2 == 0 {
                ctx.fill(CGRect(x: x, y: y, width: o, height: o))
            }
        }
        return ctx.makeImage()!
    }

    @Test func oCoNhoNetHonOCoTo() {
        let net = Sharpness.of(oCo(640, 480, o: 8))
        let tron = Sharpness.of(oCo(640, 480, o: 160))
        #expect(net > tron * 5)
        #expect(Sharpness.of(oCo(4, 4, o: 1)) == 0, "ảnh quá nhỏ thì 0")
    }

    @Test func quyVeThang01TheoLoat() {
        #expect(Sharpness.normalize([]) == [])
        #expect(Sharpness.normalize([100, 103, 101]) == [1, 1, 1], "chênh dưới 5% coi như nhau")
        #expect(Sharpness.normalize([10, 20, 30]) == [0, 0.5, 1])
        #expect(Sharpness.normalize([0, 0]) == [1, 1])
    }
}
