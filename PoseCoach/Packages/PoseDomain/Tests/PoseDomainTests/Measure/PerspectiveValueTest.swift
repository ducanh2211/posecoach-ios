import Testing
@testable import PoseDomain

/// Port từ `KTT/PerspectiveValueTest.kt` — KIỂM CON SỐ của phép đo zoom, bằng TOẠ ĐỘ KHỚP THẬT.
///
/// Công thức đo zoom được tìm và kiểm chứng bằng Python trên toạ độ khớp xuất từ app. Bản port có thể sai
/// lặt vặt (nhầm trung điểm, thiếu một trục trong khoảng cách 3 chiều, đảo dấu logarit) mà test luật không
/// đỏ — chỉ con số là sai. File này gắn cứng toạ độ thật kèm đáp án đã biết.
///
/// Dữ liệu: ba tấm trong `test-media/4-do-khoang-cach/` bên Android, cùng một người, khoảng cách đo bằng
/// thước. Chỉ lấy mốc `PoseFrame.at()` chấp nhận (tin cậy ≥ 0,5 và nằm trong khung).
struct PerspectiveValueTest {

    private let minVis: Float = 0.5

    private func lm(_ u: Double, _ v: Double, _ vis: Float, _ wx: Double, _ wy: Double, _ wz: Double) -> (P2, Float, P3) {
        (P2(u, v), vis, P3(wx, wy, wz))
    }

    /// Dựng PoseFrame 33 điểm; mốc không truyền vào để tin cậy 0 nên bị bỏ qua.
    private func frameOf(_ entries: (Int, (P2, Float, P3))...) -> PoseFrame {
        var pts = Array(repeating: P2(0, 0), count: 33)
        var vis = Array(repeating: Float(0), count: 33)
        var wld = Array(repeating: P3(0, 0, 0), count: 33)
        for (i, t) in entries { pts[i] = t.0; vis[i] = t.1; wld[i] = t.2 }
        return PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
    }

    private func perspective(_ f: PoseFrame, _ src: PerspectiveSource) -> Double? {
        Measurer.measure(f, .full, minVis).perspectiveIndex[src]
    }

    /// Khoảng cách đo bằng thước: 1.0 m. Nguồn: `z054x-f35-014-img487.jpg`. Kỳ vọng +0.2554 (Python).
    private func anh054x_014_img487() -> PoseFrame {
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

    /// Khoảng cách đo bằng thước: 2.5 m. Nguồn: `z154x-f35-040-img472.jpg`. Kỳ vọng +0.1789 (Python).
    private func anh154x_040_img472() -> PoseFrame {
        frameOf(
            (Lm.leftShoulder, lm(0.5820, 0.4003, 1.0000, 0.1271, -0.5009, 0.0053)),
            (Lm.rightShoulder, lm(0.4098, 0.4110, 0.9999, -0.1774, -0.4720, -0.0286)),
            (Lm.leftHip, lm(0.5616, 0.6209, 0.9998, 0.1056, -0.0055, 0.0178)),
            (Lm.rightHip, lm(0.4602, 0.6226, 0.9997, -0.1061, 0.0050, -0.0167)),
            (Lm.leftKnee, lm(0.5559, 0.7697, 0.9828, 0.0752, 0.3984, 0.0571)),
            (Lm.rightKnee, lm(0.4649, 0.7758, 0.9789, -0.0593, 0.3807, 0.0551)),
            (Lm.leftAnkle, lm(0.5470, 0.8965, 0.9561, 0.0848, 0.7113, 0.2473)),
            (Lm.rightAnkle, lm(0.4753, 0.8975, 0.9519, -0.0245, 0.6949, 0.2100))
        )
    }

    /// Khoảng cách đo bằng thước: 4.0 m. Nguồn: `z312x-f35-081-img486.jpg`. Kỳ vọng +0.0736 (Python).
    private func anh312x_081_img486() -> PoseFrame {
        frameOf(
            (Lm.leftShoulder, lm(0.6232, 0.3689, 0.9999, 0.1654, -0.4737, -0.1304)),
            (Lm.rightShoulder, lm(0.4339, 0.3715, 0.9998, -0.1654, -0.4642, -0.1404)),
            (Lm.leftHip, lm(0.5734, 0.5951, 0.9985, 0.1111, 0.0024, -0.0056)),
            (Lm.rightHip, lm(0.4815, 0.5969, 0.9982, -0.1116, -0.0030, 0.0067)),
            (Lm.leftKnee, lm(0.5701, 0.7683, 0.9488, 0.0728, 0.3992, -0.0109)),
            (Lm.rightKnee, lm(0.4932, 0.7715, 0.9340, -0.0531, 0.3858, 0.0247)),
            (Lm.leftAnkle, lm(0.5673, 0.9207, 0.9303, 0.0859, 0.7415, 0.1178)),
            (Lm.rightAnkle, lm(0.5070, 0.9138, 0.9039, -0.0052, 0.7274, 0.1475))
        )
    }

    @Test("ảnh chụp cách 1,0 mét ra đúng chỉ số")
    func anhCach1Met() throws {
        let p = try #require(perspective(anh054x_014_img487(), .torsoAnkle), "phải đo được")
        #expect(isClose(p, 0.2554, 1e-3))
    }

    @Test("ảnh chụp cách 2,5 mét ra đúng chỉ số")
    func anhCach25Met() throws {
        let p = try #require(perspective(anh154x_040_img472(), .torsoAnkle), "phải đo được")
        #expect(isClose(p, 0.1789, 1e-3))
    }

    @Test("ảnh chụp cách 4,0 mét ra đúng chỉ số")
    func anhCach4Met() throws {
        let p = try #require(perspective(anh312x_081_img486(), .torsoAnkle), "phải đo được")
        #expect(isClose(p, 0.0736, 1e-3))
    }

    /// ⚠️ BÀI KIỂM QUAN TRỌNG NHẤT FILE NÀY: chỉ số phải GIẢM khi ra xa. Sai dấu logarit hoặc đảo tử/mẫu vẫn
    /// cho ba con số trông hợp lệ, chỉ khác là app bảo người dùng đi NGƯỢC hướng.
    @Test("chỉ số giảm đơn điệu khi ra xa")
    func chiSoGiamDonDieu() throws {
        let gan = try #require(perspective(anh054x_014_img487(), .torsoAnkle))
        let vua = try #require(perspective(anh154x_040_img472(), .torsoAnkle))
        let xa = try #require(perspective(anh312x_081_img486(), .torsoAnkle))
        #expect(gan > vua, "1m phải lớn hơn 2,5m")
        #expect(vua > xa, "2,5m phải lớn hơn 4m")
    }

    @Test("ảnh toàn thân đo được cả hai cặp mốc")
    func anhToanThanDoDuocCaHaiCap() {
        let f = anh054x_014_img487()
        #expect(perspective(f, .torsoAnkle) != nil)
        #expect(perspective(f, .torsoKnee) != nil)
    }
}
