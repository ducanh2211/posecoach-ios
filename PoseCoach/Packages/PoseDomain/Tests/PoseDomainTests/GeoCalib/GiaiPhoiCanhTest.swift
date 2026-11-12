import Testing
@testable import PoseDomain

/// Port từ `KTT/GiaiPhoiCanhTest.kt` — bộ giải phối cảnh (phần 2 của GeoCalib) phải tìm lại đúng camera đã tạo ra bản
/// đồ. Kiểm phần TOÁN; độ chính xác trên ảnh thật phải đo trên máy thật.
struct GiaiPhoiCanhTest {

    private func thu(_ roll: Double, _ pitch: Double, _ vfov: Double, h: Int = 416, w: Int = 320) {
        let (up, lat) = GiaiPhoiCanh.banDoTuCamera(roll, pitch, vfov, h, w)
        let tinCay = [Float](repeating: 1, count: h * w)
        let c = GiaiPhoiCanh.giai(up, tinCay, lat, tinCay, h, w)
        #expect(isClose(c.pitchDeg, pitch, 0.3), "pitch \(c.pitchDeg)")
        #expect(isClose(c.rollDeg, roll, 0.3), "roll \(c.rollDeg)")
        #expect(isClose(c.vfovDeg, vfov, 1.0), "vfov \(c.vfovDeg)")
    }

    @Test("máy ngang") func mayNgang() { thu(0.0, 0.0, 60.0) }
    @Test("chúc xuống 35 độ") func chucXuong35() { thu(0.0, -35.0, 65.0) }
    @Test("hất lên 25 độ và vẹo") func hatLen25() { thu(6.0, 25.0, 55.0) }
    @Test("chúc gắt góc rộng") func chucGatGocRong() { thu(-4.0, -50.0, 90.0) }

    @Test("nhiễu và điểm không tin cậy không kéo lệch kết quả")
    func nhieuKhongKeoLech() {
        let h = 416, w = 320
        var (up, lat) = GiaiPhoiCanh.banDoTuCamera(0.0, -20.0, 60.0, h, w)
        var rnd = JavaRandom(1)
        var tinCay = [Float](repeating: 1, count: h * w)
        // 20% điểm hỏng hẳn nhưng mạng đã báo tin cậy thấp — phải bị lờ đi.
        for i in 0..<(h * w) where rnd.nextDouble() < 0.2 {
            up[i] = 1; up[h * w + i] = 0; lat[i] = 1.2; tinCay[i] = 0.01
        }
        let c = GiaiPhoiCanh.giai(up, tinCay, lat, tinCay, h, w)
        #expect(isClose(c.pitchDeg, -20.0, 1.0), "pitch \(c.pitchDeg)")
    }
}
