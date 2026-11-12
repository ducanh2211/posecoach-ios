import Testing
@testable import PoseDomain

/// Port từ `KTT/BestShotBufferTest.kt` — kiểm HÀNH VI của bộ giữ khung hình tốt nhất. Đúng/sai không phụ thuộc con số
/// đo nào trên máy thật: kiểm luật xếp chỗ, không kiểm ngưỡng.
struct BestShotBufferTest {

    private func shot(
        _ id: Int64, _ timeMs: Int64, _ score: Double, trust: Bool = true, pose: [Double] = [0.0]
    ) -> ShotCandidate {
        ShotCandidate(id: id, timeMs: timeMs, score: score, trustworthy: trust, poseSignature: pose)
    }

    private func laTuChoi(_ r: OfferResult) -> Bool {
        if case .rejected = r { return true }
        return false
    }

    @Test("không bao giờ giữ quá số lượng cho phép")
    func khongQuaSoLuong() {
        let buf = BestShotBuffer(capacity: 3, minGapMs: 100)
        for i in 0...19 { buf.offer(shot(Int64(i), Int64(i) * 1000, Double(i))) }
        #expect(buf.size == 3)
    }

    @Test("giữ lại đúng những khung điểm cao nhất")
    func giuDiemCaoNhat() {
        let buf = BestShotBuffer(capacity: 3, minGapMs: 100)
        for i in 0...9 { buf.offer(shot(Int64(i), Int64(i) * 1000, Double(i))) }
        #expect(buf.all().map(\.id) == [9, 8, 7])
    }

    @Test("khung quá gần về thời gian và điểm thấp hơn thì bị từ chối")
    func quaGanDiemThap() {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 400)
        buf.offer(shot(1, 1000, 90.0))
        let r = buf.offer(shot(2, 1200, 50.0))
        #expect(laTuChoi(r))
        #expect(buf.all().map(\.id) == [1])
    }

    @Test("khung quá gần nhưng điểm cao hơn thì thay chỗ và báo xoá file cũ")
    func quaGanDiemCao() throws {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 400)
        buf.offer(shot(1, 1000, 50.0))
        let r = buf.offer(shot(2, 1200, 90.0))
        guard case let .accepted(evicted) = r else { Issue.record("Phải nhận"); return }
        #expect(evicted.map(\.id) == [1])
        #expect(buf.all().map(\.id) == [2])
    }

    /// Bẫy thật: thay MỘT khung ở gần có thể khiến khung mới lại nằm sát một khung khác.
    @Test("thay chỗ phải dọn sạch mọi khung nằm trong khoảng cấm")
    func donSachKhoangCam() {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 400)
        buf.offer(shot(1, 1000, 50.0))
        buf.offer(shot(2, 1500, 60.0))
        // t=1250 nằm trong 400ms của CẢ HAI khung trên.
        let r = buf.offer(shot(3, 1250, 95.0))
        guard case let .accepted(evicted) = r else { Issue.record("Phải nhận"); return }
        #expect(Set(evicted.map(\.id)) == [1, 2])
        #expect(buf.all().map(\.id) == [3])
    }

    @Test("mọi khung được giữ đều cách nhau đủ thời gian")
    func cachNhauDuThoiGian() {
        let buf = BestShotBuffer(capacity: 10, minGapMs: 400)
        // Đẩy vào dày đặc 50ms một khung, điểm ngẫu nhiên nhưng cố định để lặp lại được.
        var rnd = JavaRandom(42)
        for i in 0...199 { buf.offer(shot(Int64(i), Int64(i) * 50, rnd.nextDouble() * 100)) }
        let times = buf.all().map(\.timeMs).sorted()
        for i in 1..<times.count {
            #expect(times[i] - times[i - 1] >= 400, "Hai khung cách nhau \(times[i] - times[i - 1])ms, dưới mức 400ms")
        }
    }

    @Test("khung đủ căn cứ thắng khung thiếu căn cứ dù điểm thấp hơn")
    func duCanCuThang() {
        let buf = BestShotBuffer(capacity: 2, minGapMs: 100)
        buf.offer(shot(1, 0, 99.0, trust: false))
        buf.offer(shot(2, 1000, 98.0, trust: false))
        // Điểm thấp hơn hẳn, nhưng đo được đủ mục.
        buf.offer(shot(3, 2000, 40.0, trust: true))
        #expect(buf.all().first?.id == 3)
    }

    @Test("giữ lại ảnh đã chọn và trả về phần còn lại để xoá")
    func giuAnhDaChon() {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 100)
        for i in 1...5 { buf.offer(shot(Int64(i), Int64(i) * 1000, Double(i))) }
        let dropped = buf.keepOnly([2, 4])
        #expect(Set(dropped.map(\.id)) == [1, 3, 5])
        #expect(Set(buf.all().map(\.id)) == [2, 4])
    }

    @Test("xoá hết thì trả về toàn bộ để dọn file")
    func xoaHet() {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 100)
        for i in 1...4 { buf.offer(shot(Int64(i), Int64(i) * 1000, Double(i))) }
        #expect(buf.clear().count == 4)
        #expect(buf.size == 0)
    }

    // MARK: - Luật "cách 0,9 giây HOẶC khác dáng đủ nhiều"

    /// ⚠️ Là **HOẶC**, không phải VÀ — mẫu đổi dáng hẳn trong nửa giây là hai tấm khác nhau thật.
    @Test("khác dáng đủ nhiều thì giữ cả hai dù sát nhau về thời gian")
    func khacDangGiuCaHai() {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 900, minPoseDistance: 0.12)
        buf.offer(shot(1, 1000, 90.0, pose: [0.0, 0.0]))
        // Chỉ cách 200ms nhưng dáng lệch 60° -> khoảng cách 60/180 = 0,33 > 0,12
        let r = buf.offer(shot(2, 1200, 50.0, pose: [60.0, 60.0]))
        #expect(!laTuChoi(r))
        #expect(Set(buf.all().map(\.id)) == [1, 2])
    }

    @Test("sát nhau và cùng dáng thì chỉ giữ tấm điểm cao hơn")
    func satNhauCungDang() {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 900, minPoseDistance: 0.12)
        buf.offer(shot(1, 1000, 90.0, pose: [0.0, 0.0]))
        // Cách 200ms, dáng lệch 5° -> 5/180 = 0,028 < 0,12 -> coi như trùng
        let r = buf.offer(shot(2, 1200, 50.0, pose: [5.0, 5.0]))
        #expect(laTuChoi(r))
        #expect(buf.all().map(\.id) == [1])
    }

    /// Không so được dáng thì coi như GIỐNG nhau — chọn phía an toàn.
    @Test("không so được dáng thì coi như trùng và vẫn áp luật thời gian")
    func khongSoDuocDang() {
        let buf = BestShotBuffer(capacity: 5, minGapMs: 900, minPoseDistance: 0.12)
        buf.offer(shot(1, 1000, 90.0, pose: []))
        let r = buf.offer(shot(2, 1200, 50.0, pose: []))
        #expect(laTuChoi(r))
    }

    @Test("mặc định cách nhau 0,9 giây theo bản iOS")
    func macDinh() {
        #expect(BestShotBuffer().minGapMs == 900)
        #expect(isClose(BestShotBuffer().minPoseDistance, 0.12, 1e-9))
    }
}
