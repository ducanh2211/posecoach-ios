import CoreGraphics
import Foundation
import PoseDomain

/// MỘT LẦN QUAY — nối tầng đo, phép chấm điểm, bộ giữ khung và kho ảnh. Port `KT/capture/ShotSession.kt`.
///
/// Luồng mỗi khung hình:
/// ```
///   khung ─→ đo (CÙNG hàm với ảnh mẫu) ─→ chấm điểm ─→ bộ giữ khung
///                                                          │
///                  nhận ─→ lưu file mới + XOÁ file bị đá ra ┤
///                  loại ─→ không lưu gì cả ─────────────────┘
/// ```
/// Nhờ vậy **số file trên máy không bao giờ vượt sức chứa của bộ giữ**, kể cả khi quay 30 giây liên tục.
///
/// Không an toàn đa luồng — mỗi lần chấm chạy tuần tự trên một luồng nền.
nonisolated final class ShotSession {

    private let store: ShotStore
    /// HỒ SƠ ẢNH MẪU — suy một lần lúc chọn ảnh. Hướng dẫn realtime và bước chọn ảnh đọc chung hồ sơ này, nên không thể
    /// có chuyện hai bên chấm theo hai bộ tiêu chí khác nhau.
    let profile: TemplateProfile
    private let minVisibility: Float
    private let buffer: BestShotBuffer
    /// `nil` = bỏ qua góc mặt và mắt nhắm — hai mục đó tự bị loại khỏi cách tính, không trừ điểm.
    private let faceAnalyzer: FaceAnalyzer?
    /// Tỉ lệ khung người dùng chọn (ngang/dọc khi cầm dọc). Ảnh ra VÀ khung xương đem chấm đều cắt về tỉ lệ này.
    private let tiLeKhung: Double?

    /// Dữ liệu giữ trong bộ nhớ cho từng khung đang được giữ. Tối đa bằng sức chứa bộ giữ.
    private struct Pending {
        let measurement: PoseMeasurement
        let sharpnessRaw: Double
        /// Điểm "không cắt ngang khớp", 0..1. Tính ngay lúc còn giữ khung hình.
        let crop: Double?
        /// Mắt có mở không, 0..1. Tính ngay vì sau đó ảnh không còn trong bộ nhớ.
        let eyesOpen: Double?
    }

    /// Ảnh mẫu này có bắt buộc phải đo góc MẶT ở từng khung không. Chỉ đúng với ảnh chân dung (CHEST/HEAD): ở đó góc mặt
    /// là nguồn đo hướng chính vì chính xác hơn góc thân (~3-5° so với ~8-10°).
    private let needFacePerFrame: Bool

    private var pending: [Int64: Pending] = [:]
    private var nextId: Int64 = 1

    /// Đã chốt danh sách chưa. Đã chốt thì `discard` không xoá nữa.
    private(set) var finished = false

    var sessionDir: URL { store.sessionDir }
    var keptCount: Int { buffer.size }

    init(_ store: ShotStore, _ profile: TemplateProfile, _ minVisibility: Float,
         buffer: BestShotBuffer = BestShotBuffer(), faceAnalyzer: FaceAnalyzer? = nil, tiLeKhung: Double? = nil) {
        self.store = store
        self.profile = profile
        self.minVisibility = minVisibility
        self.buffer = buffer
        self.faceAnalyzer = faceAnalyzer
        self.tiLeKhung = tiLeKhung
        needFacePerFrame = profile.framing.yawSource == .faceYaw
    }

    /// Tỉ lệ đích theo đúng chiều của ảnh (cầm ngang thì lật).
    private func tiLeCho(_ anh: CGImage) -> Double? {
        tiLeKhung.map { TiLeKhung.theoHuong($0, anh.width, anh.height) }
    }

    /// Ngưỡng ĐẠT của một mục — để `ShotScorer` uốn thang điểm cho ăn khớp với dấu tích.
    private func acceptCua(_ c: Criterion) -> Double? {
        GuidanceConfig.bandFor(c, profile.framing, profile.measurement.scale)?.accept
    }

    /// Đưa một khung hình vào xét. Trả `true` nếu khung được giữ lại (đã lưu ra file).
    @discardableResult
    func offer(_ anhGoc: CGImage, _ poseGoc: PoseFrame, _ timeMs: Int64) -> Bool {
        if finished { return false }
        if poseGoc.isEmpty { return false }
        // Cắt ảnh và khung xương về CÙNG một vùng — vùng người dùng thấy lúc chụp.
        let tl = tiLeCho(anhGoc)
        let bitmap = store.cropToAspect(anhGoc, tl)
        let pose = tl.map { poseGoc.croppedToAspect($0, Double(anhGoc.width) / Double(anhGoc.height)) } ?? poseGoc

        // ⚠️ NHẬN DIỆN MẶT KHÔNG chạy ở đây, trừ khi ảnh mẫu BẮT BUỘC cần (FOOTGUNS 30): chạy trên mọi khung vừa chậm,
        // vừa vô ích — ảnh ~480 px thì mặt trong ảnh toàn thân quá nhỏ để nhận ra. Mắt mở chấm ở `finish` trên ≤ 12
        // khung chung kết, ở độ phân giải cao.
        let face = needFacePerFrame ? faceAnalyzer?.analyze(bitmap) : nil
        // Bỏ góc máy suy từ ảnh: nó lẫn dáng đứng và ống kính, không so được với nhãn góc của ảnh mẫu (FOOTGUNS 91).
        // Cả lần quay đã được canh góc bằng cảm biến từ trước.
        let measurement = Measurer.measure(pose, profile.framing, minVisibility, face: face).boGocMayTuAnh()

        // Chấm KHÔNG kèm độ nét ở bước này — cố ý. Độ nét chỉ so được trong nội bộ một lần quay (xem `Sharpness`); lúc
        // đang quay chưa biết cả loạt ra sao. Lúc chốt mới đưa độ nét vào chấm lại toàn bộ.
        let score = ShotScorer.score(profile, measurement, .selection, nil, acceptOf: acceptCua)

        let id = nextId
        nextId += 1
        let candidate = ShotCandidate(
            id: id, timeMs: timeMs, score: score.total, trustworthy: score.trustworthy,
            // Trải phẳng theo thứ tự nhóm CỐ ĐỊNH, nếu không hai khung cùng dáng nhưng thứ tự nhóm khác nhau sẽ bị coi
            // là khác dáng.
            poseSignature: PoseGroup.allCases.flatMap { measurement.poseAngles[$0] ?? [] }
        )

        guard case let .accepted(evicted) = buffer.offer(candidate) else { return false }

        if !store.save(id, bitmap) {
            // Ghi hỏng thì rút mục vừa thêm ra, nếu không màn kết quả có một ô trỏ tới file không tồn tại.
            _ = buffer.remove(id)
            return false
        }

        pending[id] = Pending(
            measurement: measurement,
            sharpnessRaw: Sharpness.of(bitmap),
            crop: CropQuality.of(pose, profile.framing, minVisibility),
            eyesOpen: face?.eyesOpen
        )

        for e in evicted {
            store.delete(e.id)
            pending[e.id] = nil
        }
        return true
    }

    /// Chốt lần quay: chấm lại có kèm độ nét, giữ `keepCount` khung tốt nhất, **xoá file của phần còn lại**, rồi ghi
    /// bảng kê cho màn kết quả đọc.
    ///
    /// - Parameter highRes: lấy khung ở ĐỘ PHÂN GIẢI CAO tại một mốc thời gian. `nil` = không lấy được — vẫn chốt được
    ///   nhưng thiếu các mục hậu kỳ. Truyền vào dạng hàm vì lớp này cố ý không biết gì về video (nó cũng phục vụ đường
    ///   chụp liên tục).
    /// - Returns: danh sách khung được giữ, tốt nhất đứng đầu.
    @discardableResult
    func finish(keepCount: Int = 5, highRes: ((Int64) async -> CGImage?)? = nil) async -> [ShotCandidate] {
        if finished { return store.readIndex() }

        let candidates = buffer.all()
        if candidates.isEmpty {
            finished = true
            store.writeIndex([])
            return []
        }

        // --- Vòng CHUNG KẾT: tối đa 12 khung, nên làm kỹ được ---
        // Cắt lại ở độ phân giải cao TRƯỚC khi xếp hạng: mắt nhắm và độ nét phải chấm trên chính tấm ảnh sẽ giao.
        // Kotlin `map[id] ?: …`: không thấy mặt (null) cũng lùi về số đo lúc quay — gán `nil` là không ghi.
        var highResEyes: [Int64: Double] = [:]
        var highResSharp: [Int64: Double] = [:]
        if let highRes {
            for c in candidates {
                guard let raw = await highRes(c.timeMs) else { continue }
                let big = store.cropToAspect(raw, tiLeCho(raw))
                _ = store.save(c.id, big)
                highResSharp[c.id] = Sharpness.of(big)
                if let faceAnalyzer {
                    highResEyes[c.id] = faceAnalyzer.analyze(big)?.eyesOpen
                }
            }
        }

        // Chuẩn hoá độ nét theo đúng loạt khung này, rồi chấm lại toàn bộ.
        let raws = candidates.map { highResSharp[$0.id] ?? pending[$0.id]?.sharpnessRaw ?? 0 }
        let norms = Sharpness.normalize(raws)

        let rescored = ShotCandidate.sortedBestFirst(candidates.enumerated().map { i, c in
            guard let p = pending[c.id] else { return c }
            let s = ShotScorer.score(
                profile, p.measurement, .selection,
                // Ưu tiên số đo trên ảnh độ phân giải cao; chỉ lùi về số đo lúc quay khi không cắt lại được.
                PostQuality(sharpness: norms[i], crop: p.crop, eyesOpen: highResEyes[c.id] ?? p.eyesOpen),
                acceptOf: acceptCua
            )
            return ShotCandidate(id: c.id, timeMs: c.timeMs, score: s.total, trustworthy: s.trustworthy,
                                 parts: s.perCriterion, poseSignature: c.poseSignature)
        })

        let kept = Array(rescored.prefix(keepCount))
        let keptIds = Set(kept.map(\.id))

        // Xoá file của những khung không lọt vào danh sách cuối.
        for c in rescored where !keptIds.contains(c.id) { store.delete(c.id) }
        _ = buffer.keepOnly(keptIds)
        pending = pending.filter { keptIds.contains($0.key) }

        store.writeIndex(kept)
        finished = true
        return kept
    }

    /// Bỏ cả lần quay. Xoá sạch, không để lại gì.
    func discard() {
        _ = buffer.clear()
        pending.removeAll()
        store.deleteSession()
        finished = true
    }
}
