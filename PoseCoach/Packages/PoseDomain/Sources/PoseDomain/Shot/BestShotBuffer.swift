/// BỘ GIỮ KHUNG HÌNH TỐT NHẤT — chạy TRONG LÚC quay, không phải lọc sau khi quay. Port từ
/// `KT/capture/BestShotBuffer.kt`.
///
/// Quay 30 giây ở 10 khung/giây là 300 tấm. Ở đây **số file trên máy không bao giờ vượt quá `capacity`**, và mỗi lần
/// một khung bị đá ra thì người gọi xoá file của nó ngay (chống rác máy lớp 1).
///
/// Hai luật xếp chỗ:
///  1. **Cách nhau về thời gian** (`minGapMs`) HOẶC **khác dáng đủ nhiều** (`minPoseDistance`) — không thì 5 tấm
///     được chọn nằm gọn trong nửa giây, y hệt nhau.
///  2. **Đủ căn cứ thắng thiếu căn cứ** — xem `ShotCandidate.bestFirst`.
public final class BestShotBuffer {

    /// Số khung giữ lại tối đa. Lấy nhiều hơn 5 để còn chỗ so cuối phiên.
    public let capacity: Int
    /// Hai khung được giữ phải cách nhau ít nhất bấy nhiêu ms. 0,9 giây theo bản iOS cũ — 0,4 giây cho ra 5 tấm gần
    /// như giống hệt nhau.
    public let minGapMs: Int64
    /// ...HOẶC phải khác dáng đủ nhiều. 0..1, càng cao càng khắt khe. ⚠️ Là **HOẶC**, không phải VÀ.
    public let minPoseDistance: Double

    private var entries: [ShotCandidate] = []

    public init(capacity: Int = 12, minGapMs: Int64 = 900, minPoseDistance: Double = 0.12) {
        precondition(capacity > 0, "capacity phải lớn hơn 0")
        precondition(minGapMs >= 0, "minGapMs không được âm")
        self.capacity = capacity
        self.minGapMs = minGapMs
        self.minPoseDistance = minPoseDistance
    }

    public var size: Int { entries.count }

    /// Toàn bộ khung đang giữ, tốt nhất đứng trước.
    public func all() -> [ShotCandidate] { ShotCandidate.sortedBestFirst(entries) }

    /// `n` khung tốt nhất. Đây là thứ đem ra cho người dùng chọn.
    public func top(_ n: Int) -> [ShotCandidate] { Array(all().prefix(n)) }

    /// Đưa một khung vào xét.
    ///
    /// - Returns: `.accepted` kèm danh sách khung bị đá ra — người gọi **phải xoá file** của những khung đó. Hoặc
    ///   `.rejected` nếu khung này không đáng giữ, khi đó đừng lưu file nào cả.
    @discardableResult
    public func offer(_ candidate: ShotCandidate) -> OfferResult {
        // Khung đang giữ bị coi là "trùng" với candidate: VỪA quá gần về thời gian, VỪA gần giống về dáng. Phải lấy
        // TẤT CẢ chứ không chỉ cái gần nhất: thay một cái rồi vẫn có thể còn cái khác nằm trong khoảng cấm.
        let near = entries.filter {
            abs($0.timeMs - candidate.timeMs) < minGapMs &&
                Self.poseDistance($0.poseSignature, candidate.poseSignature) < minPoseDistance
        }

        // Đã có khung tốt hơn ở ngay quanh đó rồi thì thôi.
        if near.contains(where: { !Self.isBetter(candidate, $0) }) { return .rejected }

        let remaining = entries.filter { !near.contains($0) }

        if remaining.count < capacity {
            entries = remaining + [candidate]
            return .accepted(evicted: near)
        }

        // Hết chỗ: phải hạ được khung yếu nhất mới được vào.
        //
        // ⚠️ SẮP XẾP RỒI LẤY PHẦN TỬ CUỐI, cố ý dài dòng (FOOTGUNS 21): `min(by:)` với bộ so sánh xếp giảm dần trả về
        // khung ĐIỂM CAO NHẤT — app âm thầm vứt tấm đẹp nhất.
        guard let viTri = ShotCandidate.sortedIndicesBestFirst(remaining).last else { return .rejected }
        let worst = remaining[viTri]
        if !Self.isBetter(candidate, worst) { return .rejected }

        // Bỏ đúng PHẦN TỬ đó theo vị trí (Kotlin so `===`), không so giá trị.
        var giu = remaining
        giu.remove(at: viTri)
        entries = giu + [candidate]
        return .accepted(evicted: near + [worst])
    }

    /// Bỏ một khung ra khỏi bộ giữ. Dùng khi lưu file hỏng — giữ mục trỏ tới file không tồn tại thì màn kết quả
    /// hiện ô ảnh trống.
    @discardableResult
    public func remove(_ id: Int64) -> Bool {
        let truoc = entries.count
        entries.removeAll { $0.id == id }
        return entries.count != truoc
    }

    /// Bỏ hết. Trả lại danh sách để người gọi xoá file.
    @discardableResult
    public func clear() -> [ShotCandidate] {
        let out = entries
        entries.removeAll()
        return out
    }

    /// Bỏ những khung KHÔNG nằm trong danh sách giữ lại. Dùng lúc người dùng đã chọn xong ảnh.
    @discardableResult
    public func keepOnly(_ ids: Set<Int64>) -> [ShotCandidate] {
        let dropped = entries.filter { !ids.contains($0.id) }
        entries.removeAll { !ids.contains($0.id) }
        return dropped
    }

    private static func isBetter(_ a: ShotCandidate, _ b: ShotCandidate) -> Bool { ShotCandidate.bestFirst(a, b) }

    /// Khoảng cách dáng giữa hai khung, 0..1. 0 = dáng y hệt. Trung bình chênh góc các khớp, chia 180.
    ///
    /// Không so được (thiếu dữ liệu, số khớp khác nhau) thì trả **0** — "coi như giống nhau", phía an toàn: cho qua
    /// khi không biết sinh ra hai tấm trùng, chặn khi không biết chỉ mất một ứng viên.
    static func poseDistance(_ a: [Double], _ b: [Double]) -> Double {
        if a.isEmpty || b.isEmpty || a.count != b.count { return 0.0 }
        var sum = 0.0
        for i in a.indices {
            var d = abs(a[i] - b[i]).truncatingRemainder(dividingBy: 360.0)
            if d > 180.0 { d = 360.0 - d }
            sum += d
        }
        return min(max(sum / Double(a.count) / 180.0, 0.0), 1.0)
    }
}

/// Một khung hình đang được giữ. Cố ý KHÔNG chứa ảnh — ảnh nằm ngoài dưới dạng file, tra theo `id`.
public struct ShotCandidate: Equatable, Sendable {
    /// Định danh duy nhất, cũng là tên file ảnh.
    public let id: Int64
    /// Thời điểm trong phiên quay, ms.
    public let timeMs: Int64
    /// Điểm giống ảnh mẫu, 0..100.
    public let score: Double
    /// Có đo được đủ mục để tin điểm này không.
    public let trustworthy: Bool
    /// Điểm từng mục 0..1, chỉ gồm mục ĐO ĐƯỢC — để biết **mất điểm ở đâu**.
    public let parts: [String: Double]
    /// Góc các khớp đã trải phẳng, để đo hai khung có KHÁC DÁNG không.
    public let poseSignature: [Double]

    public init(
        id: Int64, timeMs: Int64, score: Double, trustworthy: Bool,
        parts: [String: Double] = [:], poseSignature: [Double] = []
    ) {
        self.id = id
        self.timeMs = timeMs
        self.score = score
        self.trustworthy = trustworthy
        self.parts = parts
        self.poseSignature = poseSignature
    }

    /// THỨ TỰ "TỐT HƠN" DUY NHẤT CỦA DỰ ÁN: đủ căn cứ trước, rồi tới điểm cao. `true` = `a` đứng trước `b`.
    ///
    /// Ba nơi cần xếp hạng (chen chỗ khi quay, chấm lại kèm độ nét, màn kết quả) — mỗi nơi tự viết một phép so là
    /// cách chắc chắn nhất để chọn sai ảnh mà không có gì báo lỗi.
    public static func bestFirst(_ a: ShotCandidate, _ b: ShotCandidate) -> Bool {
        if a.trustworthy != b.trustworthy { return a.trustworthy }
        return a.score > b.score
    }

    /// Sắp theo `bestFirst`, GIỮ thứ tự cũ khi hoà (như `sortedWith` của Kotlin) — `sort` của Swift không hứa ổn định.
    public static func sortedBestFirst(_ xs: [ShotCandidate]) -> [ShotCandidate] {
        sortedIndicesBestFirst(xs).map { xs[$0] }
    }

    /// Vị trí các phần tử theo thứ tự `sortedBestFirst`.
    static func sortedIndicesBestFirst(_ xs: [ShotCandidate]) -> [Int] {
        xs.indices.sorted { i, j in
            bestFirst(xs[i], xs[j]) || (!bestFirst(xs[j], xs[i]) && i < j)
        }
    }
}

public enum OfferResult: Equatable, Sendable {
    /// Không đáng giữ — đừng lưu file.
    case rejected
    /// Đã nhận. Người gọi phải lưu file của khung mới và **xoá file** của `evicted`.
    case accepted(evicted: [ShotCandidate])
}
