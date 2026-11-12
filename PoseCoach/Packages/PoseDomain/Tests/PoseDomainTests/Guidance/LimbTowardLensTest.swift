import Testing
@testable import PoseDomain

/// Port từ `KTT/LimbTowardLensTest.kt` — CHI CHĨA VÀO ỐNG KÍNH (mẫu đá chân hoặc bước về phía máy).
///
/// Mọi công thức phối cảnh CHIA cho chiều dài một đoạn cơ thể trên ảnh; đoạn đó chĩa vào ống kính thì phép chia
/// nổ tung. Ngưỡng `Measurer.maxOutOfPlaneDeg` = 40° (FOOTGUNS 38).
struct LimbTowardLensTest {

    private let minVis: Float = 0.5

    private func lm(_ u: Double, _ v: Double, _ vis: Float, _ wx: Double, _ wy: Double, _ wz: Double) -> (P2, Float, P3) {
        (P2(u, v), vis, P3(wx, wy, wz))
    }

    private func frameOf(_ entries: (Int, (P2, Float, P3))...) -> PoseFrame {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        var wld = Array(repeating: P3(0, 0, 0), count: 33)
        for (i, t) in entries { pts[i] = t.0; vis[i] = t.1; wld[i] = t.2 }
        return PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
    }

    /// NGƯỜI ĐỨNG BÌNH THƯỜNG — toạ độ thật (`z054x-f35-014-img487.jpg`, 1,0 m). Hông→gót chĩa 22,0°.
    private func nguoiDung() -> PoseFrame {
        frameOf(
            (Lm.leftShoulder, lm(0.4067, 0.4286, 0.9999, -0.0952, -0.4636, -0.1364)),
            (Lm.rightShoulder, lm(0.5989, 0.4278, 0.9997, 0.1147, -0.4728, -0.0787)),
            (Lm.leftHip, lm(0.4732, 0.6410, 0.9995, -0.0220, 0.0054, -0.0286)),
            (Lm.rightHip, lm(0.5322, 0.6506, 0.9989, 0.0216, -0.0062, 0.0300)),
            (Lm.leftKnee, lm(0.4815, 0.7969, 0.9684, -0.0543, 0.3868, 0.0899)),
            (Lm.rightKnee, lm(0.5286, 0.7913, 0.8794, 0.0329, 0.3479, 0.1692)),
            (Lm.leftAnkle, lm(0.4911, 0.9181, 0.9394, -0.0197, 0.7337, 0.2513)),
            (Lm.rightAnkle, lm(0.5247, 0.9138, 0.8631, 0.0658, 0.6922, 0.3275))
        )
    }

    /// CÙNG NGƯỜI ĐÓ NHƯNG ĐÁ CHÂN VỀ PHÍA MÁY. Hông→gót chĩa khoảng 71°.
    private func daChanVeMay() -> PoseFrame {
        frameOf(
            (Lm.leftShoulder, lm(0.4067, 0.4286, 0.9999, -0.0952, -0.4636, -0.1364)),
            (Lm.rightShoulder, lm(0.5989, 0.4278, 0.9997, 0.1147, -0.4728, -0.0787)),
            (Lm.leftHip, lm(0.4732, 0.6410, 0.9995, -0.0220, 0.0054, -0.0286)),
            (Lm.rightHip, lm(0.5322, 0.6506, 0.9989, 0.0216, -0.0062, 0.0300)),
            (Lm.leftKnee, lm(0.4815, 0.7200, 0.9684, -0.0543, 0.2000, -0.4000)),
            (Lm.rightKnee, lm(0.5286, 0.7180, 0.8794, 0.0329, 0.1900, -0.3800)),
            (Lm.leftAnkle, lm(0.4911, 0.7500, 0.9394, -0.0197, 0.2600, -0.8000)),
            (Lm.rightAnkle, lm(0.5247, 0.7480, 0.8631, 0.0658, 0.2500, -0.7800))
        )
    }

    private func doNguoiDung(_ framing: FramingClass = .full) -> PoseMeasurement {
        Measurer.measure(nguoiDung(), framing, minVis)
    }

    // MARK: - Chốt chặn: đo được với người đứng, BỎ khi chân chĩa vào ống kính

    @Test("người đứng bình thường thì vẫn đo được zoom")
    func nguoiDungDoDuocZoom() {
        #expect(doNguoiDung().perspectiveIndex[.torsoAnkle] != nil, "Chân 22° nằm trong dải người đứng, không được bỏ")
    }

    @Test("đá chân về phía máy thì BỎ mục zoom, không đoán bừa")
    func daChanBoZoom() {
        #expect(Measurer.measure(daChanVeMay(), .full, minVis).perspectiveIndex[.torsoAnkle] == nil)
    }

    @Test("đá chân về phía máy thì BỎ cả đường đo ngửa/chúc bằng chân")
    func daChanBoNguaChuc() {
        #expect(Measurer.measure(daChanVeMay(), .full, minVis).pitchCue[.legs] == nil)
    }

    @Test("đá chân về phía máy thì BỎ cả mục xa/gần")
    func daChanBoXaGan() {
        // Cổ chân tụt lên trong khung làm mẫu "lùn đi" → app tưởng máy lùi ra xa.
        #expect(Measurer.measure(daChanVeMay(), .full, minVis).scale == nil, "Mốc đo chạm tới chân nên phải bỏ theo")
    }

    // MARK: - Luật "chỉ so khi CÙNG một đường đo" cho mục ngửa/chúc

    @Test("ảnh mẫu đo bằng chân, khung hình đo bằng góc máy thì KHÔNG so")
    func khacDuongDoKhongSo() {
        var tpl = doNguoiDung()
        tpl.pitchCue = [.legs: 0.20]
        var live = doNguoiDung()
        live.pitchCue = [.gocMay: 0.20]
        #expect(ShotScorer.deviation(tpl, live).pitchCue == nil, "Hai thang khác hẳn — trừ nhau ra 0 là lỗi im lặng")
    }

    @Test("cùng đường đo thì so bình thường")
    func cungDuongDo() throws {
        var tpl = doNguoiDung()
        tpl.pitchCue = [.gocMay: 0.20]
        var live = doNguoiDung()
        live.pitchCue = [.gocMay: 0.50]
        let dev = ShotScorer.deviation(tpl, live)
        #expect(isClose(try #require(dev.pitchCue), 0.30, 1e-9))
        #expect(dev.pitchSource == .gocMay)
    }

    /// ⚠️ ĐỔI CHỦ Ý 14/09/2026: góc máy phía camera lấy thẳng từ cảm biến trọng lực, sai số dưới 1°.
    @Test("có cả hai đường đo thì ưu tiên GÓC MÁY")
    func uuTienGocMay() {
        let both: [PitchSource: Double] = [.legs: 0.10, .gocMay: 0.90]
        var tpl = doNguoiDung()
        tpl.pitchCue = both
        var live = doNguoiDung()
        live.pitchCue = both
        #expect(ShotScorer.deviation(tpl, live).pitchSource == .gocMay)
    }

    // MARK: - Ngưỡng phải đi theo đường đo

    @Test("mỗi đường đo một đơn vị, mỗi đơn vị một ngưỡng")
    func moiDuongMotNguong() throws {
        let legs = try #require(GuidanceConfig.bandFor(.pitch, .full, 0.60, .legs))
        let than = try #require(GuidanceConfig.bandFor(.pitch, .full, 0.60, .gocMay))
        let mat = try #require(GuidanceConfig.bandFor(.pitch, .chest, 0.60, .gocMay))

        // Đường CHÂN là tỉ lệ không đơn vị — giữ ngưỡng cũ.
        #expect(isClose(legs.accept, GuidanceConfig.pitchLegsAccept, 1e-9))
        // Đường góc máy ra ĐỘ, nới 12° cho mọi lớp (14/09/2026).
        #expect(isClose(than.accept, 12.0, 1e-9))
        #expect(isClose(mat.accept, 12.0, 1e-9))
    }

    /// ⚠️ Đường đo `faceOverShoulders` ĐÃ BỊ GỠ 12/09/2026 (tương quan với góc thật −0,117) — đừng dựng lại.
    @Test("không còn đường đo bằng tỉ lệ khung mặt trên vai")
    func khongConDuongMat() {
        #expect(Set(PitchSource.allCases) == [.gocMay, .legs], "PitchSource chỉ còn hai đường: góc máy (độ) và chân")
    }

    // MARK: - Lớp khung hình: mốc NHÌN THẤY thắng ngưỡng chiều cao

    @Test("người ngồi giữa khung vẫn được xếp FULL nếu thấy cổ chân")
    func nguoiNgoiXepFull() {
        let ngoi = frameOf(
            (Lm.leftShoulder, lm(0.42, 0.30, 0.99, -0.10, -0.45, 0.0)),
            (Lm.rightShoulder, lm(0.58, 0.30, 0.99, 0.10, -0.45, 0.0)),
            (Lm.leftHip, lm(0.46, 0.55, 0.99, -0.05, 0.0, 0.0)),
            (Lm.rightHip, lm(0.54, 0.55, 0.99, 0.05, 0.0, 0.0)),
            (Lm.leftKnee, lm(0.45, 0.66, 0.95, -0.06, 0.25, 0.0)),
            (Lm.rightKnee, lm(0.55, 0.66, 0.95, 0.06, 0.25, 0.0)),
            (Lm.leftAnkle, lm(0.45, 0.75, 0.93, -0.06, 0.50, 0.0)),
            (Lm.rightAnkle, lm(0.55, 0.75, 0.93, 0.06, 0.50, 0.0))
        )
        #expect(FramingClass.detect(ngoi, minVis) == .full, "Thấy cổ chân thì tin vào mốc")
        #expect(FramingClass.detect(ngoi, minVis)?.seesLegs == true)
    }

    // MARK: - ⚠️ Mục hướng mẫu cũng theo luật "cùng một đường đo" (FOOTGUNS 77)

    @Test("ảnh mẫu chân dung mà khung hình mất góc mặt thì BỎ, không lùi về góc thân")
    func matGocMatThiBo() {
        var tpl = doNguoiDung(.chest)
        tpl.faceYawDeg = 20.0
        tpl.yawDeg = 5.0
        var live = doNguoiDung(.chest)
        live.faceYawDeg = nil
        live.yawDeg = 5.0
        let d = ShotScorer.deviation(tpl, live)
        #expect(d.yawDeg == nil, "Lùi về góc thân sẽ ra lệch 0 trong khi đầu mẫu đang quay 20 độ")
        #expect(d.yawSource == nil)
    }

    @Test("cùng đường đo thì so bình thường và ghi rõ đường nào")
    func cungDuongGhiRo() throws {
        var tpl = doNguoiDung(.chest)
        tpl.faceYawDeg = 20.0
        var live = doNguoiDung(.chest)
        live.faceYawDeg = 35.0
        let d = ShotScorer.deviation(tpl, live)
        #expect(isClose(try #require(d.yawDeg), 15.0, 1e-9))
        #expect(d.yawSource == .faceYaw)
    }

    @Test("ảnh toàn thân dùng góc thân, không đòi góc mặt")
    func toanThanDungGocThan() throws {
        var tpl = doNguoiDung()
        tpl.yawDeg = 10.0
        tpl.faceYawDeg = nil
        var live = doNguoiDung()
        live.yawDeg = 40.0
        live.faceYawDeg = nil
        let d = ShotScorer.deviation(tpl, live)
        #expect(isClose(try #require(d.yawDeg), 30.0, 1e-9))
        #expect(d.yawSource == .body3d)
    }
}
