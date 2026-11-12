import CoreGraphics
import Testing
@testable import PoseCoach

/// Transform rãnh hình của video quay: khung cảm biến 1920×1080 (góc 0°) phải ra đúng chiều xem, nằm gọn từ gốc toạ độ.
struct VideoRecorderTests {

    private func apply(_ t: CGAffineTransform, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y).applying(t)
    }

    @Test func camDocLaXoay90NhuVideoIPhone() {
        // Video iPhone quay dọc có preferredTransform [0 1 -1 0 h 0].
        let t = VideoRecorder.transform(width: 1920, height: 1080, rotationAngle: 90, mirrored: false)
        let want = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        for (a, b) in [(t.a, want.a), (t.b, want.b), (t.c, want.c), (t.d, want.d), (t.tx, want.tx), (t.ty, want.ty)] {
            #expect(abs(a - b) < 1e-9)
        }
        // Góc trên-trái của khung cảm biến ra góc trên-PHẢI của hình dựng đứng (xoay thuận chiều kim đồng hồ).
        #expect(apply(t, 0, 0) == CGPoint(x: 1080, y: 0))
    }

    @Test func gocKhongLaNguyenKhung() {
        let t = VideoRecorder.transform(width: 1920, height: 1080, rotationAngle: 0, mirrored: false)
        #expect(t.isIdentity)
    }

    @Test func mocHinhNamGonTuGocToaDo() {
        for angle: CGFloat in [0, 90, 180, 270] {
            for mirrored in [false, true] {
                let t = VideoRecorder.transform(width: 1920, height: 1080, rotationAngle: angle, mirrored: mirrored)
                let box = CGRect(x: 0, y: 0, width: 1920, height: 1080).applying(t)
                #expect(abs(box.minX) < 1e-6 && abs(box.minY) < 1e-6, "góc \(angle), lật \(mirrored)")
                let dung = angle == 90 || angle == 270
                #expect(abs(box.width - (dung ? 1080 : 1920)) < 1e-6)
            }
        }
    }

    @Test func latGuongLaLatNgangCuaHinhDaDungDung() {
        // Lật phải đổi TRÁI ↔ PHẢI của hình đã dựng đứng, giữ nguyên trên/dưới.
        let t = VideoRecorder.transform(width: 1920, height: 1080, rotationAngle: 90, mirrored: false)
        let m = VideoRecorder.transform(width: 1920, height: 1080, rotationAngle: 90, mirrored: true)
        for (x, y) in [(0.0, 0.0), (1920.0, 0.0), (300.0, 700.0)] as [(CGFloat, CGFloat)] {
            let p = apply(t, x, y), q = apply(m, x, y)
            #expect(abs(q.x - (1080 - p.x)) < 1e-6)
            #expect(abs(q.y - p.y) < 1e-6)
        }
    }
}
