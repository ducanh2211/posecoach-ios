import Testing
@testable import PoseDomain

/// Port từ `KTT/HuongDanTuanTuTest.kt` — HƯỚNG DẪN THEO BƯỚC CỐ ĐỊNH (FOOTGUNS 92): xoay thẳng máy → khoảng cách →
/// góc/độ cao → zoom → bố cục → hướng mẫu → dáng.
struct HuongDanTuanTuTest {

    @Test("xoay thẳng máy rồi lùi và chỉnh góc trước khi zoom")
    func thuTuBuoc() throws {
        let dauVao: [Criterion] = [.pose, .pitch, .scale, .yaw, .perspective, .center, .elevation, .roll]
        let ketQua = dauVao.sorted {
            (ordinal(guidanceStepOf($0)), ordinal($0)) < (ordinal(guidanceStepOf($1)), ordinal($1))
        }
        #expect(ketQua[0] == .roll)
        #expect(ketQua[1] == .perspective)
        let i = { (c: Criterion) in ketQua.firstIndex(of: c)! }
        #expect(i(.pitch) < i(.scale))
        #expect(i(.pitch) < i(.pose))
        #expect(i(.elevation) < i(.yaw))
    }

    @Test("dòng gộp hiện đang chờ zoom sau khi chỗ đứng đã đạt")
    func dongGopDangCho() throws {
        let band = Band(accept: 1.0, enter: 1.5, unlock: 3.0, actionFloor: 0.1)
        let rows = groupRows([
            CriterionStatus(criterion: .perspective, state: .passing, deviation: 0.0, signedDelta: 0.0, band: band),
            CriterionStatus(criterion: .scale, state: .unmeasured, deviation: nil, signedDelta: nil, band: band, pending: true),
        ])
        #expect(rows.count == 1)
        #expect(try #require(rows.first).status.pending)
    }

    @Test("sau khoảng sáu giây mới được bỏ qua tự động")
    func sauSauGiay() {
        #expect(GuidanceEngine.autoSkipAfterMs == 3 * 2_000)
    }
}
