import Testing
@testable import PoseDomain

/// Port từ `KTT/FailedCriteriaTest.kt` — phần CẢNH BÁO KHÔNG ĐẠT của màn xem lại (FOOTGUNS 24).
///
/// Đây là chỗ sửa một lỗi sản phẩm thật: app luôn trả về 5 tấm tốt nhất, kể cả khi cả 5 đều sai hoàn toàn, rồi bày ra
/// dưới tiêu đề "xếp theo mức giống ảnh mẫu". Gặp thật với ảnh mẫu người quay LƯNG và video chỉ có người quay MẶT.
///
/// Khác Kotlin: so **key** String Catalog (`part_yaw`) thay vì chữ tiếng Việt ("Hướng mẫu") — PoseDomain không đọc
/// String Catalog. Phần "lời khuyên nói với mẫu" kiểm chữ thật ở `PoseCoachTests/Text/UiTextResolveTests`.
struct FailedCriteriaTest {

    private func shot(_ id: Int64, _ parts: [String: Double]) -> ShotCandidate {
        ShotCandidate(id: id, timeMs: id * 1000, score: 50.0, trustworthy: true, parts: parts)
    }

    @Test("mục mà không tấm nào đạt thì bị báo")
    func khongTamNaoDat() {
        let f = FailedCriterion.failedCriteria([
            shot(1, ["huong": 0.0, "xa_gan": 0.8]),
            shot(2, ["huong": 0.0, "xa_gan": 0.7]),
            shot(3, ["huong": 0.0, "xa_gan": 0.9]),
        ])
        #expect(f.map(\.labelRes) == ["part_yaw"])
    }

    /// Ca thật đã gặp trên máy: 4/5 tấm có "xa/gần" bằng 0, nhưng tấm còn lại đạt 0,43. Nghĩa là trong lần quay ĐÃ CÓ
    /// lúc đứng đúng khoảng cách → không phải lỗi hệ thống, không được báo.
    @Test("chỉ một tấm đạt thì không báo mục đó")
    func motTamDat() {
        let f = FailedCriterion.failedCriteria([
            shot(1, ["xa_gan": 0.0]),
            shot(2, ["xa_gan": 0.431]),
            shot(3, ["xa_gan": 0.0]),
        ])
        #expect(f.isEmpty)
    }

    /// "Không đo được" KHÁC "sai" — luật số 4. Mục vắng mặt đã bị bỏ ra khỏi cách tính điểm.
    @Test("mục không đo được ở một tấm thì không bị coi là sai")
    func khongDoDuoc() {
        let f = FailedCriterion.failedCriteria([
            shot(1, ["cao_thap": 0.0]),
            shot(2, [:]),
            shot(3, ["cao_thap": 0.0]),
        ])
        #expect(f.isEmpty)
    }

    @Test("báo được nhiều mục cùng lúc")
    func nhieuMuc() {
        let f = FailedCriterion.failedCriteria([
            shot(1, ["huong": 0.0, "xa_gan": 0.0, "dang": 0.9]),
            shot(2, ["huong": 0.0, "xa_gan": 0.02, "dang": 0.8]),
        ])
        #expect(f.map(\.labelRes) == ["part_yaw", "part_distance"])
    }

    @Test("chưa có tấm nào thì không báo gì")
    func chuaCoTam() {
        #expect(FailedCriterion.failedCriteria([]).isEmpty)
    }

    @Test("mọi mục báo đều kèm lời khuyên cụ thể")
    func kemLoiKhuyen() throws {
        let f = try #require(FailedCriterion.failedCriteria([shot(1, ["huong": 0.0]), shot(2, ["huong": 0.0])]).first)
        #expect(f.adviceRes == "advice_yaw")
        #expect(FailedCriterion.criterionAdvice.allSatisfy { $0.label.hasPrefix("part_") && $0.advice.hasPrefix("advice_") })
    }
}
