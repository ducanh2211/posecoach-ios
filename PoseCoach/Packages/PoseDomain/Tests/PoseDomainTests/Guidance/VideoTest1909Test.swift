import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/VideoTest1909Test.kt` — những gì video test 19/09/2026 lộ ra, khoá lại để không quay về.
struct VideoTest1909Test {

    private let band = Band(accept: 0.1, enter: 0.15, unlock: 0.3, actionFloor: 0.02)

    private func cau(tamTay: Bool) throws -> String {
        let status = CriterionStatus(
            criterion: .elevation, state: .unmeasured, deviation: nil, signedDelta: nil, band: band,
            unmeasuredTooLong: true, tamTay: tamTay
        )
        return try #require(CuePresenter().update([status], 0, 0.0)).vi()
    }

    @Test("selfie không được bảo lùi ra")
    func selfieKhongBaoLui() throws {
        let t = try cau(tamTay: true)
        #expect(!t.contains("lùi"), "\(t)")
        #expect(t.contains("duỗi tay"), "\(t)")
    }

    @Test("người khác chụp vẫn bảo lùi ra")
    func nguoiKhacVanBaoLui() throws {
        #expect(try cau(tamTay: false).contains("lùi ra"))
    }

    @Test("hệ số ống kính tính từ góc mở thật, trùng hằng số cũ với máy 73 độ")
    func heSoOngKinh() throws {
        let h = try #require(DistanceEstimator.heSoOngKinh(73.0, 1))
        #expect(abs(h - 0.678) < 0.01, "\(h)")
        // Zoom 2x thì góc mở hẹp lại, hệ số quy về 1x phải y nguyên.
        let v2 = toDegrees(2 * atan(tan(toRadians(73.0) / 2) / 2))
        let h2 = try #require(DistanceEstimator.heSoOngKinh(v2, 2))
        #expect(abs(h2 - h) < 1e-9)
        #expect(DistanceEstimator.heSoOngKinh(nil, 1) == nil)
    }
}
