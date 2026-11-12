import Foundation

/// BỘ GIẢI PHỐI CẢNH — phần 2 của GeoCalib (08/10/2026). Port từ `KT/geocalib/GiaiPhoiCanh.kt`.
///
/// Mạng GeoCalib (chạy ở `Services/GeoCalib`, ONNX) cho ra hai bản đồ: mỗi điểm ảnh biết **hướng lên** ở đó (vectơ
/// 2D) và **vĩ độ** của nó, kèm độ tin cậy. Hàm này tìm camera (độ vẹo, độ chúc, tiêu cự) sao cho bản đồ camera đó
/// tạo ra khớp nhất với hai bản đồ mạng đoán — Levenberg–Marquardt có trọng số tin cậy và hàm Huber (FOOTGUNS 103).
///
/// Quy ước: độ chúc ÂM = máy chúc xuống, giống app. Toạ độ điểm ảnh như GeoCalib: x, y từ 0, tâm quang học ở
/// (W/2, H/2).
public enum GiaiPhoiCanh {

    public struct Camera: Equatable, Sendable {
        public let rollDeg: Double
        public let pitchDeg: Double
        public let vfovDeg: Double
    }

    /// Lấy một điểm mỗi `buocLuoi` điểm ảnh mỗi chiều: nhanh hơn 17 lần, lệch thêm < 0,5° (đã đo).
    public static let buocLuoi = 4
    private static let soVong = 30
    private static let thangHuber = 1e-2
    private static let eps = 1e-4

    /// - Parameters:
    ///   - up: bản đồ hướng lên, bố cục [2, h, w] (kênh 0 = x, kênh 1 = y).
    ///   - upTinCay: độ tin cậy, [h, w].
    ///   - viDo: vĩ độ theo RADIAN, [h, w].
    ///   - viDoTinCay: độ tin cậy, [h, w].
    public static func giai(
        _ up: [Float],
        _ upTinCay: [Float],
        _ viDo: [Float],
        _ viDoTinCay: [Float],
        _ h: Int,
        _ w: Int,
        buocLuoi: Int = GiaiPhoiCanh.buocLuoi
    ) -> Camera {
        precondition(up.count == 2 * h * w && upTinCay.count == h * w && viDo.count == h * w && viDoTinCay.count == h * w)
        let n = ((h + buocLuoi - 1) / buocLuoi) * ((w + buocLuoi - 1) / buocLuoi)
        var xs = [Double](repeating: 0, count: n), ys = [Double](repeating: 0, count: n)
        var upx = [Double](repeating: 0, count: n), upy = [Double](repeating: 0, count: n)
        var cu = [Double](repeating: 0, count: n)
        var sl = [Double](repeating: 0, count: n), cl = [Double](repeating: 0, count: n)
        var k = 0
        for y in stride(from: 0, to: h, by: buocLuoi) {
            for x in stride(from: 0, to: w, by: buocLuoi) {
                let i = y * w + x
                xs[k] = Double(x); ys[k] = Double(y)
                upx[k] = Double(up[i]); upy[k] = Double(up[h * w + i]); cu[k] = Double(upTinCay[i])
                sl[k] = sin(Double(viDo[i])); cl[k] = Double(viDoTinCay[i])
                k += 1
            }
        }

        func duSo(_ t: [Double], _ outU: inout [Double], _ outL: inout [Double]) {
            let f = exp(t[2])
            let g0 = -sin(t[0]) * cos(t[1]), g1 = -cos(t[0]) * cos(t[1]), g2 = sin(t[1])
            for j in 0..<n {
                let u = (xs[j] - Double(w) / 2.0) / f
                let v = (ys[j] - Double(h) / 2.0) / f
                var ax = g0 - g2 * u, ay = g1 - g2 * v
                let m = (ax * ax + ay * ay).squareRoot() + 1e-12
                ax /= m; ay /= m
                outU[2 * j] = upx[j] - ax; outU[2 * j + 1] = upy[j] - ay
                outL[j] = sl[j] - (u * g0 + v * g1 + g2) / (u * u + v * v + 1).squareRoot()
            }
        }

        // Huber của GeoCalib: x ≤ 1 thì x, còn lại 2√x − 1 (x đã chia thang). Trả chi phí, ghi trọng số.
        var wu = [Double](repeating: 0, count: n), wl = [Double](repeating: 0, count: n)
        func chiPhi(_ u: [Double], _ l: [Double], _ ghiTrongSo: Bool) -> Double {
            var c1 = 0.0, c2 = 0.0
            for j in 0..<n {
                let xu = (u[2 * j] * u[2 * j] + u[2 * j + 1] * u[2 * j + 1]) / thangHuber
                let xl = l[j] * l[j] / thangHuber
                c1 += (xu <= 1 ? xu : 2 * xu.squareRoot() - 1) * thangHuber * cu[j]
                c2 += (xl <= 1 ? xl : 2 * xl.squareRoot() - 1) * thangHuber * cl[j]
                if ghiTrongSo {
                    wu[j] = (xu <= 1 ? 1.0 : 1 / xu.squareRoot()) * cu[j]
                    wl[j] = (xl <= 1 ? 1.0 : 1 / xl.squareRoot()) * cl[j]
                }
            }
            return (c1 + c2) / Double(n)
        }

        var ru = [Double](repeating: 0, count: 2 * n), rl = [Double](repeating: 0, count: n)
        var theta = [0.0, 0.0, log(0.7 * Double(max(h, w)))]
        duSo(theta, &ru, &rl)
        var cost = chiPhi(ru, rl, true)
        var lam = 0.1
        var ju = [[Double]](repeating: [Double](repeating: 0, count: 2 * n), count: 3)
        var jl = [[Double]](repeating: [Double](repeating: 0, count: n), count: 3)
        var tu = [Double](repeating: 0, count: 2 * n), tl = [Double](repeating: 0, count: n)
        var t2 = [Double](repeating: 0, count: 3)
        for _ in 0..<soVong {
            for p in 0..<3 {
                t2 = theta; t2[p] += eps
                duSo(t2, &tu, &tl)
                for q in 0..<(2 * n) { ju[p][q] = (tu[q] - ru[q]) / eps }
                for q in 0..<n { jl[p][q] = (tl[q] - rl[q]) / eps }
            }
            var hm = [[Double]](repeating: [0, 0, 0], count: 3)
            var gr = [0.0, 0.0, 0.0]
            for j in 0..<n {
                for a in 0..<3 {
                    let ax = ju[a][2 * j], ay = ju[a][2 * j + 1], al = jl[a][j]
                    gr[a] += wu[j] * (ax * ru[2 * j] + ay * ru[2 * j + 1]) + wl[j] * al * rl[j]
                    for b in a..<3 {
                        hm[a][b] += wu[j] * (ax * ju[b][2 * j] + ay * ju[b][2 * j + 1]) + wl[j] * al * jl[b][j]
                    }
                }
            }
            for a in 0..<3 { for b in 0..<a { hm[a][b] = hm[b][a] } }
            let giam = (0..<3).map { a in (0..<3).map { b in hm[a][b] + (a == b ? lam * hm[a][a] + 1e-9 : 0.0) } }
            guard let d = giaiHe3(giam, gr.map { -$0 }) else { break }
            for p in 0..<3 { t2[p] = theta[p] + d[p] }
            duSo(t2, &tu, &tl)
            let c2 = chiPhi(tu, tl, false)
            if c2 < cost {
                theta = t2; ru = tu; rl = tl
                cost = chiPhi(ru, rl, true)
                lam = max(lam / 10, 1e-6)
                if d.map(abs).max()! < 1e-6 { break }
            } else {
                lam = min(lam * 10, 1e2)
            }
        }
        let vfov = 2 * atan(Double(h) / 2.0 / exp(theta[2]))
        return Camera(rollDeg: toDegrees(theta[0]), pitchDeg: toDegrees(theta[1]), vfovDeg: toDegrees(vfov))
    }

    /// Khử Gauss cho hệ 3×3. `nil` khi suy biến.
    private static func giaiHe3(_ a: [[Double]], _ b: [Double]) -> [Double]? {
        var m = (0..<3).map { i in [a[i][0], a[i][1], a[i][2], b[i]] }
        for c in 0..<3 {
            // `maxBy` của Kotlin: lấy phần tử LỚN NHẤT ĐẦU TIÊN.
            var p = c
            for r in (c + 1)..<3 where abs(m[r][c]) > abs(m[p][c]) { p = r }
            if abs(m[p][c]) < 1e-15 { return nil }
            m.swapAt(c, p)
            for r in 0..<3 where r != c {
                let k = m[r][c] / m[c][c]
                for q in c..<4 { m[r][q] -= k * m[c][q] }
            }
        }
        return (0..<3).map { m[$0][3] / m[$0][$0] }
    }

    /// Bản đồ mà một camera cho trước tạo ra — dùng để KIỂM bộ giải (sinh dữ liệu biết đáp án).
    /// Trả (up [2,h,w], vĩ độ [h,w] theo radian).
    static func banDoTuCamera(
        _ rollDeg: Double, _ pitchDeg: Double, _ vfovDeg: Double, _ h: Int, _ w: Int
    ) -> (up: [Float], lat: [Float]) {
        let r = toRadians(rollDeg), p = toRadians(pitchDeg)
        let f = Double(h) / 2.0 / tan(toRadians(vfovDeg) / 2)
        let g0 = -sin(r) * cos(p), g1 = -cos(r) * cos(p), g2 = sin(p)
        var up = [Float](repeating: 0, count: 2 * h * w), lat = [Float](repeating: 0, count: h * w)
        for y in 0..<h {
            for x in 0..<w {
                let u = (Double(x) - Double(w) / 2.0) / f, v = (Double(y) - Double(h) / 2.0) / f
                var ax = g0 - g2 * u, ay = g1 - g2 * v
                let m = (ax * ax + ay * ay).squareRoot(); ax /= m; ay /= m
                let i = y * w + x
                up[i] = Float(ax); up[h * w + i] = Float(ay)
                lat[i] = Float(asin((u * g0 + v * g1 + g2) / (u * u + v * v + 1).squareRoot()))
            }
        }
        return (up, lat)
    }
}
