import Testing
@testable import PoseDomain

/// Port từ `KTT/CriterionGateTest.kt` — kiểm HÀNH VI của cổng trạng thái, không kiểm con số.
///
/// Mọi bài tự đặt `Band` riêng — không phụ thuộc ngưỡng thật, không hỏng khi buổi đo chỉnh lại ngưỡng.
struct CriterionGateTest {

    private let band = Band(accept: 10.0, enter: 15.0, unlock: 30.0, actionFloor: 2.0)

    private func gate() -> CriterionGate { CriterionGate(.yaw) }

    @Test("một khung nhiễu không lật được trạng thái")
    func motKhungNhieu() {
        let g = gate()
        // Lệch to, nhưng mới đúng một khoảnh khắc.
        #expect(g.update(40.0, band, 0) == .grey)
        // Chưa đủ 0,45 giây thì chưa được phép kêu.
        #expect(g.update(40.0, band, 400) == .grey)
        #expect(g.update(40.0, band, 500) == .failing)
    }

    @Test("đạt phải giữ đủ lâu mới được công nhận")
    func datPhaiGiuDuLau() {
        let g = gate()
        #expect(g.update(5.0, band, 0) == .grey)
        #expect(g.update(5.0, band, 100) == .grey)
        #expect(g.update(5.0, band, 250) == .passing)
        #expect(g.locked)
    }

    @Test("đã đạt rồi thì rung tay nhẹ không làm tuột tích")
    func rungTayNhe() {
        let g = gate()
        g.update(5.0, band, 0)
        g.update(5.0, band, 300)
        #expect(g.locked)

        // Lệch ra khỏi accept nhưng chưa tới unlock: tích phải GIỮ NGUYÊN.
        #expect(g.update(12.0, band, 400) == .passing)
        #expect(g.update(20.0, band, 500) == .passing)
        #expect(g.locked)
    }

    @Test("lệch hẳn ra ngoài thì mới mở khoá")
    func lechHanRaNgoai() {
        let g = gate()
        g.update(5.0, band, 0)
        g.update(5.0, band, 300)
        #expect(g.locked)

        // Vượt unlock (30) → mở khoá ngay trong lượt này.
        let st = g.update(35.0, band, 400)
        #expect(!g.locked)
        // Vừa mở khoá nên chưa kịp đủ thời gian để kêu.
        #expect(st == .grey)
    }

    @Test("không đo được khác với sai")
    func khongDoDuocKhacSai() {
        let g = gate()
        #expect(g.update(nil, band, 0) == .unmeasured)

        // Đã đạt rồi mà mất dấu một lúc: GIỮ tích.
        g.update(5.0, band, 100)
        g.update(5.0, band, 400)
        #expect(g.locked)
        #expect(g.update(nil, band, 500) == .passing)
    }

    @Test("chống kẹt — mục đã khoá trôi QUÁ MỨC ĐÁNG NHẮC quá lâu thì nhắc lại")
    func chongKet() {
        let g = gate()
        g.update(5.0, band, 0)
        g.update(5.0, band, 300)
        #expect(g.locked)

        // Trôi VƯỢT mức đáng nhắc (enter 15) nhưng chưa ra ngoài (unlock 30), rồi nằm lì ở đó.
        let t0: Int64 = 400
        #expect(g.update(20.0, band, t0) == .passing)
        #expect(g.update(20.0, band, t0 + 1000) == .passing)

        // Quá 2,5 giây: phải mở khoá VÀ nhắc lại, nếu không app đứng im vĩnh viễn.
        let after = t0 + GuidanceTiming.stallTimeoutMs + 1
        #expect(g.update(20.0, band, after) == .failing)
        #expect(!g.locked)
    }

    /// ⚠️ Lỗi đã gặp trên máy thật 07/09/2026: *"cứ đạt được 1 tiêu chí, chỉ cần nhích nhẹ máy, lại bị mất"*.
    /// Chống kẹt so với `accept` thay vì `enter` (FOOTGUNS 52–53).
    @Test("trôi trong VÙNG ĐỆM thì GIỮ NGUYÊN tích, dù bao lâu")
    func troiTrongVungDem() {
        let g = gate()
        g.update(5.0, band, 0)
        g.update(5.0, band, 300)
        #expect(g.locked)

        // 12 nằm giữa accept 10 và enter 15 — đúng vùng đệm.
        var t: Int64 = 400
        for _ in 0..<100 {
            t += 200
            #expect(g.update(12.0, band, t) == .passing, "Vùng đệm sinh ra để chịu rung tay (t=\(t))")
        }
        #expect(g.locked, "Vẫn phải còn khoá sau \(t)ms")
    }

    @Test("sau khi chống kẹt mà người dùng sửa đúng thì lại đạt bình thường")
    func sauChongKetSuaDung() {
        let g = gate()
        g.update(5.0, band, 0)
        g.update(5.0, band, 300)
        g.update(20.0, band, 400)
        g.update(20.0, band, 400 + GuidanceTiming.stallTimeoutMs + 1)
        #expect(!g.locked)

        let t: Int64 = 5000
        g.update(4.0, band, t)
        #expect(g.update(4.0, band, t + 300) == .passing)
        #expect(g.locked)
    }

    // MARK: - Ngõ cụt im lặng — mục áp dụng nhưng khung hình không đo được

    @Test("không đo được một lúc ngắn thì CHƯA cần giải thích")
    func khongDoDuocNgan() {
        let g = CriterionGate(.perspective)
        g.update(nil, band, 0)
        #expect(!g.unmeasuredTooLong(1_000))
    }

    @Test("không đo được quá lâu thì PHẢI giải thích")
    func khongDoDuocQuaLau() {
        // Ảnh mẫu ngang gối nên bật mục zoom, khung chặt hơn → đầu gối ra ngoài → dấu gạch mãi mãi.
        let g = CriterionGate(.perspective)
        g.update(nil, band, 0)
        g.update(nil, band, 2_000)
        #expect(g.unmeasuredTooLong(3_000))
    }

    @Test("đo được trở lại thì xoá đồng hồ giải thích")
    func doDuocTroLai() {
        let g = CriterionGate(.perspective)
        g.update(nil, band, 0)
        g.update(0.02, band, 3_000)
        #expect(!g.unmeasuredTooLong(9_000))
    }

    @Test("mục ĐÃ KHOÁ thì không đòi giải thích")
    func mucDaKhoa() {
        let g = CriterionGate(.perspective)
        for i in 0..<5 { g.update(0.01, band, Int64(i) * 300) }
        g.update(0.01, band, 5_000)
        g.update(nil, band, 6_000)
        #expect(!g.unmeasuredTooLong(20_000))
    }
}
