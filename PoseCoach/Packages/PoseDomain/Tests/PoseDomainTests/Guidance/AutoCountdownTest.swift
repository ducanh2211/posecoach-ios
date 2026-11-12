import Testing
@testable import PoseDomain

/// Port từ `KTT/AutoCountdownTest.kt` — ĐẾM NGƯỢC TỰ BẤM của chế độ tự động.
///
/// ⚠️ Bản Kotlin CHÉP LẠI vòng lặp trong `CaptureScreen` (vì nó nằm trong UI). iOS đưa máy đó vào
/// `PoseDomain/Guidance/AutoCountdown` nên test chạy ĐÚNG code thật. Số giữ như test Kotlin (đếm 5 giây — test cũ
/// viết khi `AUTO_COUNTDOWN_SEC` còn là 5); app dùng mặc định 3.
struct AutoCountdownTest {

    private let stableMs: Int64 = 800
    private let countdownSec = 5

    private func run(_ totalMs: Int64, _ ready: (Int64) -> Bool) -> Int64? {
        var dem = AutoCountdown(countdownSec: countdownSec, stableMs: stableMs, graceMs: 500)
        var t: Int64 = 0
        while t <= totalMs {
            if dem.tick(t, ready: ready(t), busy: false) == .chup { return t }
            t += 100
        }
        return nil
    }

    @Test("đủ giống liên tục thì bấm sau khoảng 6 giây")
    func duGiongLienTuc() throws {
        let fired = try #require(run(20_000) { _ in true }, "Phải bấm được")
        #expect(isClose(Double(fired), 5_800.0, 200.0))
    }

    @Test("tụt chớp nhoáng KHÔNG được huỷ lần đếm")
    func tutChopNhoang() {
        #expect(run(20_000) { t in (t % 600) < 400 } != nil, "Rung tay làm điểm dao động qua lại ngưỡng vài lần mỗi giây")
    }

    @Test("tụt LÂU thì phải huỷ")
    func tutLau() {
        #expect(run(20_000) { t in t < 2_000 } == nil, "Khung hình hỏng hẳn thì không được tự bấm")
    }

    @Test("hỏng giữa chừng rồi tốt lại thì đếm lại từ đầu")
    func hongGiuaChung() throws {
        let fired = try #require(run(30_000) { t in t < 3_000 || t >= 5_000 }, "Phải bấm được sau khi tốt lại")
        #expect(fired >= 5_000 + stableMs + Int64(countdownSec) * 1000, "Phải đếm lại từ đầu, bấm lúc \(fired)")
    }
}
