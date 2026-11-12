// Port từ `KT/measure/ShotScore.kt` (trừ `CropQuality` → `CropQuality.swift`).
//
// CHẤM ĐIỂM MỘT KHUNG HÌNH so với ảnh mẫu. Hai chỗ dùng chung tầng đo:
//  - Hướng dẫn realtime (`Stage.guidance`) — "đã đạt CHƯA".
//  - Xếp hạng chọn ảnh (`Stage.selection`) — so các khung VỚI NHAU, thêm tiêu chí hậu kỳ.
// Cả hai đọc từ cùng một `TemplateProfile`, nên không thể chấm hai kiểu khác nhau.

/// Độ lệch từng mục giữa một khung hình và ảnh mẫu. `nil` = KHÔNG ĐO ĐƯỢC ở khung này.
public struct ShotDeviation: Equatable, Sendable {
    /// Chênh hướng mẫu, ĐỘ (đã xử lý vòng qua ±180°).
    public let yawDeg: Double?
    /// ĐƯỜNG ĐO đã dùng cho `yawDeg`. Góc mặt và góc thân có gốc 0 khác nhau — phải đọc kèm.
    public let yawSource: YawSource?
    /// Chênh xa/gần, TỈ LỆ TƯƠNG ĐỐI so với mẫu (0,2 = lệch 20%).
    public let scaleRatio: Double?
    /// Chênh trái/phải, theo tỉ lệ bề ngang khung hình.
    public let centerX: Double?
    /// Chênh góc nhìn (mục 3), ĐỘ.
    public let elevationDeg: Double?
    /// Chênh NGHIÊNG NGANG, ĐỘ. Luôn dương.
    public let rollDeg: Double?
    public let rollSource: RollSource?
    /// Chênh ngửa/chúc (mục 4).
    public let pitchCue: Double?
    /// ⚠️ Phải đọc kèm `pitchCue` vì mỗi đường đo có ngưỡng riêng.
    public let pitchSource: PitchSource?
    /// Chênh ĐỘ MẠNH PHỐI CẢNH. Dương = khung hình đứng GẦN hơn ảnh mẫu; âm = XA hơn.
    public let perspective: Double?
    /// Chênh dáng, ĐỘ, trung bình các khớp so được.
    public let poseDeg: Double?
}

/// Chất lượng HẬU KỲ của một khung hình — chỉ dùng ở bước chọn ảnh. Điểm 0..1 (càng cao càng tốt), chấm
/// **chính tấm ảnh chụp ra**, không so với ảnh mẫu.
public struct PostQuality: Equatable, Sendable {
    /// Độ nét đã chuẩn hoá trong nội bộ lần quay.
    public let sharpness: Double?
    /// Mép khung có cắt ngang khớp không. 1 = không cắt vào khớp nào.
    public let crop: Double?
    /// Mắt có mở không, 0..1. `nil` = không đo được, bị bỏ ra chứ không trừ điểm.
    public let eyesOpen: Double?

    public init(sharpness: Double?, crop: Double?, eyesOpen: Double? = nil) {
        self.sharpness = sharpness
        self.crop = crop
        self.eyesOpen = eyesOpen
    }
}

/// Điểm của một khung hình, kèm phần tách nhỏ để soi khi số liệu trông sai.
public struct ShotScore: Equatable, Sendable {
    /// Điểm tổng, 0..100.
    public let total: Double
    public let deviation: ShotDeviation
    /// Điểm từng mục (theo `Criterion.key`), 0..1. Chỉ chứa mục THỰC SỰ được chấm.
    ///
    /// ⚠️ Bản đồ không giữ thứ tự (Kotlin giữ thứ tự chèn). Nơi cần thứ tự phải duyệt theo `Criterion.allCases`.
    public let perCriterion: [String: Double]
    /// Tổng trọng số thực dùng — thấp nghĩa là nhiều mục bị bỏ ra.
    public let weightUsed: Double
    /// HỆ SỐ HƯỚNG MẪU, `ShotScorer.directionFloor`..1. Nhân thẳng vào điểm tổng.
    public let directionFactor: Double

    public init(
        total: Double,
        deviation: ShotDeviation,
        perCriterion: [String: Double],
        weightUsed: Double,
        directionFactor: Double = 1.0
    ) {
        self.total = total
        self.deviation = deviation
        self.perCriterion = perCriterion
        self.weightUsed = weightUsed
        self.directionFactor = directionFactor
    }

    /// Có đủ căn cứ để tin điểm này không. Khung chỉ chấm được 1-2 mục vẫn có thể ra điểm cao — điểm cao của
    /// sự thiếu thông tin.
    public var trustworthy: Bool { perCriterion.count >= 3 }
}

public enum ShotScorer {

    /// Lệch đúng bằng ngưỡng đạt thì coi như mất bấy nhiêu phần trọng số (FOOTGUNS 67).
    ///
    /// 0,10 nghĩa là **mọi mục vừa chạm ngưỡng đạt ⇒ điểm tổng 90**. Không chọn 0 để trong vùng đạt vẫn còn
    /// phân biệt được khung nào đẹp hơn.
    public static let vungDat = 0.10

    /// Sàn của hệ số hướng: sai hướng hết cỡ thì điểm còn 12% chứ không về 0 — vẫn xếp hạng được.
    public static let directionFloor = 0.12

    /// Độ lệch cỡ gán cho khung thiếu thân — chắc chắn vượt ngưỡng mở khoá.
    private static let thieuThanRatio = 1.0

    /// So một khung hình với ảnh mẫu.
    ///
    /// - Parameters:
    ///   - profile: hồ sơ ảnh mẫu — quyết định **những mục nào được chấm**.
    ///   - candidate: kết quả đo khung hình đang xét.
    ///   - stage: đang hướng dẫn realtime hay đang chọn ảnh.
    ///   - post: chất lượng hậu kỳ; bỏ qua khi `stage` là `.guidance`.
    ///   - acceptOf: ngưỡng ĐẠT của từng mục, cùng đơn vị với độ lệch. `nil` = không biết. Có nó thì điểm mới ĂN
    ///     KHỚP với dấu tích — xem `vungDat`.
    public static func score(
        _ profile: TemplateProfile,
        _ candidate: PoseMeasurement,
        _ stage: Stage,
        _ post: PostQuality? = nil,
        acceptOf: ((Criterion) -> Double?)? = nil
    ) -> ShotScore {
        let dev = deviation(profile.measurement, candidate)
        let applicable = profile.activeFor(stage)

        var parts: [String: Double] = [:]
        var weighted = 0.0
        var weightSum = 0.0

        /// Uốn thang điểm làm hai đoạn: trong ngưỡng đạt badness chạy 0 → `vungDat`, ngoài ngưỡng chạy tiếp
        /// `vungDat` → 1 cho tới mốc `reference`. Nhờ vậy **mọi mục xanh ⇒ điểm ≥ 90**.
        func uon(_ c: Criterion, _ lech: Double?) -> Double? {
            guard let lech else { return nil }
            guard let accept = acceptOf?(c) else { return lech / c.reference }
            if accept <= 1e-9 { return lech / c.reference }
            if lech <= accept {
                return lech / accept * vungDat
            } else {
                let con = max(c.reference - accept, 1e-9)
                return vungDat + (lech - accept) / con * (1.0 - vungDat)
            }
        }

        /// `badness`: 0 = trùng khớp, 1 = lệch hết cỡ. `nil` = không đo được ở khung này.
        func add(_ c: Criterion, _ badness: Double?) {
            // Mục không thuộc hồ sơ ảnh mẫu thì KHÔNG BAO GIỜ chấm — kể cả khi khung hình tình cờ đo được nó.
            guard applicable.contains(c) else { return }
            guard let badness else { return }
            let s = 1.0 - min(max(badness, 0.0), 1.0)
            // ⚠️ Trọng số theo LỚP KHUNG HÌNH của ảnh mẫu, không phải hằng số.
            let w = c.weightFor(profile.framing)
            parts[c.key] = s
            weighted += s * w
            weightSum += w
        }

        func dao(_ diem: Double?) -> Double? { diem.map { 1.0 - min(max($0, 0.0), 1.0) } }

        // ⚠️ HƯỚNG MẪU KHÔNG nằm trong phép cộng trung bình — nó là HỆ SỐ NHÂN, xử lý riêng bên dưới.
        add(.scale, uon(.scale, dev.scaleRatio))
        add(.center, uon(.center, dev.centerX))
        add(.elevation, uon(.elevation, dev.elevationDeg))
        add(.pitch, uon(.pitch, dev.pitchCue))
        add(.perspective, uon(.perspective, dev.perspective))
        add(.pose, uon(.pose, dev.poseDeg))

        // Hậu kỳ đưa vào dạng ĐIỂM chứ không phải độ lệch, nên đảo lại thành badness.
        add(.sharpness, dao(post?.sharpness))
        add(.crop, dao(post?.crop))
        add(.eyesOpen, dao(post?.eyesOpen))

        // --- HƯỚNG MẪU: hệ số nhân (FOOTGUNS 28) ---
        // Mẫu quay sai hướng thì tấm ảnh đã sai rồi. Trước đây là 1 trong 6 mục cộng trung bình, nên tấm sai
        // hướng hoàn toàn vẫn được 49/100. Giữ `directionFloor` thay vì nhân về 0 để còn xếp hạng được.
        let direction = directionFactor(dev, applicable)

        // Hướng mẫu VẪN phải có trong bảng phân tích: màn kết quả hiển thị nó, và phép "không tấm nào đạt mục
        // nào" cũng đọc từ đây.
        if applicable.contains(.yaw), let yaw = dev.yawDeg {
            parts[Criterion.yaw.key] = 1.0 - min(max(yaw / Criterion.yaw.reference, 0.0), 1.0)
        }

        // Hướng mẫu là mục DUY NHẤT đo được thì chính hệ số hướng là điểm — để 0 sẽ biến "khớp hướng hoàn hảo"
        // thành 0 điểm.
        let yawMeasured = applicable.contains(.yaw) && dev.yawDeg != nil
        let base: Double
        if weightSum > 0.0 {
            base = weighted / weightSum
        } else if yawMeasured {
            base = 1.0
        } else {
            base = 0.0   // không đo được mục nào cả
        }
        let total = base * direction * 100.0

        return ShotScore(total: total, deviation: dev, perCriterion: parts, weightUsed: weightSum, directionFactor: direction)
    }

    /// Hệ số hướng mẫu, `directionFloor`..1. Không đo được hướng → **1**, không phạt ("không đo được" khác "sai").
    private static func directionFactor(_ dev: ShotDeviation, _ applicable: Set<Criterion>) -> Double {
        guard applicable.contains(.yaw), let d = dev.yawDeg else { return 1.0 }
        let ok = 1.0 - min(max(d / Criterion.yaw.reference, 0.0), 1.0)
        return directionFloor + (1.0 - directionFloor) * ok
    }

    /// Độ lệch từng mục. Mục nào một trong hai bên không đo được thì trả `nil`.
    public static func deviation(_ template: PoseMeasurement, _ candidate: PoseMeasurement) -> ShotDeviation {
        let yaw = yawDeviation(template, candidate)
        let roll = rollDeviation(template, candidate)
        let pitch = pitchDeviation(template, candidate)
        // Chênh xa/gần theo TỈ LỆ TƯƠNG ĐỐI: lệch 0,05 trên chân dung (mốc ~0,15) là rất nhiều, trên toàn thân
        // (mốc ~0,85) gần như không thấy.
        let scaleRatio: Double? = scalePair(template, candidate).flatMap { t, c in
            if t <= 1e-6 { return nil }
            if thieuThan(template, candidate) { return max(abs(c - t) / t, thieuThanRatio) }
            return abs(c - t) / t
        }
        return ShotDeviation(
            yawDeg: yaw?.1,
            yawSource: yaw?.0,
            scaleRatio: scaleRatio,
            centerX: pair(template.centerX, candidate.centerX) { t, c in abs(c - t) },
            elevationDeg: pair(template.elevationDeg, candidate.elevationDeg) { t, c in abs(c - t) },
            rollDeg: roll?.1,
            rollSource: roll?.0,
            pitchCue: pitch?.1,
            pitchSource: pitch?.0,
            perspective: perspectiveDeviation(template, candidate),
            poseDeg: poseDiff(template.poseAngles, candidate.poseAngles)
        )
    }

    /// Chênh nghiêng ngang — **chỉ so khi hai bên cùng đường đo**. Ưu tiên trục thân.
    private static func rollDeviation(_ t: PoseMeasurement, _ c: PoseMeasurement) -> (RollSource, Double)? {
        for source in RollSource.allCases {
            guard let a = t.rollDeg[source], let b = c.rollDeg[source] else { continue }
            return (source, abs(b - a))
        }
        return nil
    }

    /// Chênh ngửa/chúc — **chỉ so khi hai bên cùng đường đo**, theo thứ tự ưu tiên của `PitchSource`.
    private static func pitchDeviation(_ t: PoseMeasurement, _ c: PoseMeasurement) -> (PitchSource, Double)? {
        for source in PitchSource.allCases {
            guard let a = t.pitchCue[source], let b = c.pitchCue[source] else { continue }
            return (source, abs(b - a))
        }
        return nil
    }

    /// Chênh độ méo phối cảnh — lấy cặp mốc đầu tiên mà **cả hai bên cùng đo được**. ⚠️ Không bao giờ lấy cặp
    /// tốt nhất của mỗi bên rồi trừ nhau: hai thang khác hẳn.
    private static func perspectiveDeviation(_ t: PoseMeasurement, _ c: PoseMeasurement) -> Double? {
        for source in PerspectiveSource.allCases {
            guard let a = t.perspectiveIndex[source], let b = c.perspectiveIndex[source] else { continue }
            return abs(b - a)
        }
        return nil
    }

    private static func pair(_ t: Double?, _ c: Double?, _ f: (Double, Double) -> Double?) -> Double? {
        guard let t, let c else { return nil }
        return f(t, c)
    }

    /// Cỡ mẫu đang đo bằng MẶT (ảnh mẫu mất mốc thân) mà khung hình thấy cơ thể ít hơn ảnh mẫu — tức máy đang
    /// quá gần / quá thấp. Video test 10/10/2026: mục khung hình tích xanh, ảnh ra chỉ có mặt.
    static func thieuThan(_ t: PoseMeasurement, _ c: PoseMeasurement) -> Bool {
        if t.scale != nil || t.faceScale == nil { return false }
        guard let canThay = t.tamThan else { return false }
        return (c.tamThan ?? -1) < canThay
    }

    /// Cặp số đo cỡ mẫu (ảnh mẫu, khung hình) — chọn MỐC theo ẢNH MẪU, không theo khung hình (FOOTGUNS 77).
    static func scalePair(_ t: PoseMeasurement, _ c: PoseMeasurement) -> (Double, Double)? {
        if let ts = t.scale { return c.scale.map { (ts, $0) } }
        if let tf = t.faceScale { return c.faceScale.map { (tf, $0) } }
        return nil
    }

    /// Chênh hướng mẫu, chọn nguồn theo lớp khung hình của ảnh mẫu.
    ///
    /// ⚠️ LUẬT "CHỈ SO KHI CÙNG ĐƯỜNG ĐO" (FOOTGUNS 77): thiếu đường ưu tiên ở một bên thì trả `nil`, KHÔNG lùi
    /// sang đường khác — góc mặt và góc thân có gốc 0 khác nhau.
    private static func yawDeviation(_ t: PoseMeasurement, _ c: PoseMeasurement) -> (YawSource, Double)? {
        switch t.framing.yawSource {
        case .faceYaw:
            guard let a = t.faceYawDeg, let b = c.faceYawDeg else { return nil }
            return (.faceYaw, angleDiff(a, b))
        case .body3d:
            guard let a = t.yawDeg, let b = c.yawDeg else { return nil }
            return (.body3d, angleDiff(a, b))
        }
    }

    /// Chênh lệch hai góc, luôn lấy đường ngắn nhất trên vòng tròn, kết quả 0..180.
    ///
    /// Không có phép này thì −171° so với +176° ra 347° — trong khi thực tế lệch 13°.
    public static func angleDiff(_ a: Double, _ b: Double) -> Double {
        var d = abs(a - b).truncatingRemainder(dividingBy: 360.0)
        if d > 180.0 { d = 360.0 - d }
        return d
    }

    /// Chênh dáng: trung bình độ lệch góc, chỉ tính nhóm CẢ HAI BÊN đều đo được và có cùng số khớp.
    ///
    /// Duyệt `PoseGroup.allCases` thay cho thứ tự bản đồ của Kotlin — tổng các số thực phụ thuộc thứ tự cộng.
    private static func poseDiff(_ template: [PoseGroup: [Double]], _ candidate: [PoseGroup: [Double]]) -> Double? {
        var sum = 0.0
        var n = 0
        for group in PoseGroup.allCases {
            guard let tAngles = template[group], let cAngles = candidate[group] else { continue }
            // Ghép "tới đâu hay tới đó" khi số khớp khác nhau là SAI: lệch pha, so nhầm khớp.
            if cAngles.count != tAngles.count { continue }
            for i in tAngles.indices {
                // NaN = khớp đó bên này không đo được. Bỏ đúng cặp đó — không đo được KHÁC với sai.
                let t = tAngles[i], c = cAngles[i]
                if t.isNaN || c.isNaN { continue }
                sum += angleDiff(t, c)
                n += 1
            }
        }
        return n == 0 ? nil : sum / Double(n)
    }
}
