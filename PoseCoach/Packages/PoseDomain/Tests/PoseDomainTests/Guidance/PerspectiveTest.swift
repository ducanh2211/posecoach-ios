import Testing
@testable import PoseDomain

/// Port từ `KTT/PerspectiveTest.kt` — mục ZOOM & KHOẢNG CÁCH. Kiểm **LUẬT**, không kiểm con số ngưỡng.
///
/// Luật quan trọng nhất: **hai bên phải dùng CÙNG một cặp đoạn** mới so được.
///
/// (Hàm `dev(...)` dựng `ShotDeviation` của bản Kotlin không được bài nào gọi — không port.)
struct PerspectiveTest {

    private func measurement(_ pairs: [PerspectiveSource: Double] = [:]) -> PoseMeasurement {
        PoseMeasurement(
            framing: .full,
            scale: 0.60, centerX: 0.5, tiltDeg: 0.0, elevationDeg: 0.0,
            yawDeg: 0.0, faceYawDeg: nil, eyesOpen: nil,
            anchorHeightMeters: 1.60,
            rollDeg: [:], pitchCue: [:],
            perspectiveIndex: pairs,
            poseAngles: [:]
        )
    }

    // MARK: - Luật "cùng một cặp mốc"

    @Test("hai bên cùng cặp mốc thì so được")
    func cungCapMoc() throws {
        let d = ShotScorer.deviation(measurement([.torsoAnkle: 0.10]), measurement([.torsoAnkle: 0.35]))
        #expect(isClose(try #require(d.perspective), 0.25, 1e-9))
    }

    @Test("khung hình mất cổ chân — hai bên cùng tụt xuống cặp thân-gối")
    func matCoChan() throws {
        let d = ShotScorer.deviation(measurement([.torsoKnee: 0.20]), measurement([.torsoKnee: 0.50]))
        #expect(isClose(try #require(d.perspective), 0.30, 1e-9))
    }

    @Test("KHÔNG được trộn hai cặp mốc khác nhau")
    func khongTronHaiCap() {
        let d = ShotScorer.deviation(measurement([.torsoAnkle: 0.10]), measurement([.torsoKnee: 0.90]))
        #expect(d.perspective == nil)
    }

    @Test("có nhiều cặp chung thì lấy cặp ưu tiên cao nhất")
    func nhieuCapChung() throws {
        let t = measurement([.torsoAnkle: 0.10, .torsoKnee: 5.0])
        let c = measurement([.torsoAnkle: 0.15, .torsoKnee: 9.0])
        // Lấy cặp mạnh hơn (thân/cổ chân = 0,05), không lấy cặp yếu (4,0).
        #expect(isClose(try #require(ShotScorer.deviation(t, c).perspective), 0.05, 1e-9))
    }

    @Test("ảnh chân dung không đo được thì không kết luận bừa")
    func chanDungKhongKetLuan() {
        #expect(ShotScorer.deviation(measurement(), measurement([.torsoAnkle: 0.2])).perspective == nil)
    }

    @Test("hai bên cùng cặp thân-gối thì so được")
    func cungCapThanGoi() throws {
        let d = ShotScorer.deviation(measurement([.torsoKnee: 0.10]), measurement([.torsoKnee: 0.40]))
        #expect(isClose(try #require(d.perspective), 0.30, 1e-9))
    }

    // MARK: - Luật sản phẩm: chân dung không kiểm zoom

    @Test("chỉ lớp thấy chân mới kiểm được zoom")
    func chiLopThayChan() {
        #expect(FramingClass.full.seesLegs)
        #expect(FramingClass.knee.seesLegs)
        #expect(!FramingClass.half.seesLegs)
        #expect(!FramingClass.chest.seesLegs)
        #expect(!FramingClass.head.seesLegs)
    }

    @Test("cặp thân-cổ chân được ưu tiên hơn cặp thân-gối")
    func uuTienThanCoChan() {
        let thuTu = PerspectiveSource.allCases
        #expect(thuTu.firstIndex(of: .torsoAnkle)! < thuTu.firstIndex(of: .torsoKnee)!)
    }

    @Test("dấu của hiệu nói đúng chiều cần đi")
    func dauCuaHieu() throws {
        let tpl = measurement([.torsoAnkle: 0.116])    // ~4m
        let live = measurement([.torsoAnkle: 0.249])   // ~1m
        #expect(isClose(try #require(ShotScorer.deviation(tpl, live).perspective), 0.133, 1e-9))
    }
}
