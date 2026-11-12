import Foundation

/// Kết quả cổng kiểm ảnh mẫu. Port từ `KT/template/TemplateGate.kt` (`sealed interface TemplateVerdict`).
public enum TemplateVerdict: Equatable, Sendable {
    /// 🔴 Không cho vào màn camera.
    case rejected(Rejected)
    /// 🟡 Cho vào, nhưng phải báo trước những gì sẽ bị bỏ qua.
    case accepted(Accepted)

    public struct Rejected: Equatable, Sendable {
        public let reason: UiText
        public let hint: UiText
    }

    public struct Accepted: Equatable, Sendable {
        public let framing: FramingClass
        public let warnings: [UiText]

        public var hasWarnings: Bool { !warnings.isEmpty }
    }
}

/// CỔNG KIỂM ẢNH MẪU — 3 mức (TONG_QUAN_DU_AN.md §7.7). Port từ `KT/template/TemplateGate.kt`.
///
/// Chạy NGAY LÚC CHỌN ẢNH, trước khi vào màn camera — bản iOS cũ cho vào với mọi ảnh rồi không bao giờ có
/// hướng dẫn nào (ngõ cụt im lặng).
///
/// Mức 🟡 tồn tại để **không từ chối oan** ảnh chỉ thiếu một tiêu chí. Mức 🔴 chỉ dành cho ảnh **không tính
/// được gì cả**.
public enum TemplateGate {

    /// Ngưỡng tin cậy cho nhóm khớp LÕI (vai, hông). Public vì `TemplateProfile` phải suy bằng ĐÚNG ngưỡng
    /// mà cổng kiểm đã dùng.
    public static let coreVis: Float = 0.5

    /// Ngưỡng cho nhóm phụ (mặt, gối, cổ chân) — thiếu thì chỉ mất một tiêu chí.
    private static let auxVis: Float = 0.4

    /// Chủ thể nhỏ hơn mức này thì mọi phép đo đều nhiễu nặng.
    private static let minSubjectHeight = 0.25

    /// Chân có chĩa về phía ống kính không — đúng ngưỡng và phép đo của tầng đo (`Measurer.maxOutOfPlaneDeg`),
    /// để cảnh báo hiện ra đúng lúc tiêu chí zoom bị bỏ.
    private static func legTowardLens(_ f: PoseFrame) -> Bool {
        guard let hip = midWorld(f, Lm.leftHip, Lm.rightHip) else { return false }
        guard let ankle = midWorld(f, Lm.leftAnkle, Lm.rightAnkle) else { return false }
        let flat = hypot(ankle.x - hip.x, ankle.y - hip.y)
        let depth = abs(ankle.z - hip.z)
        let deg = flat < 1e-9 ? 90.0 : toDegrees(atan2(depth, flat))
        return deg > Measurer.maxOutOfPlaneDeg
    }

    private static func midWorld(_ f: PoseFrame, _ a: Int, _ b: Int) -> P3? {
        guard let A = f.world(a, coreVis) else { return nil }
        guard let B = f.world(b, coreVis) else { return nil }
        return P3((A.x + B.x) / 2, (A.y + B.y) / 2, (A.z + B.z) / 2)
    }

    /// ⚠️ CỐ Ý ĐỂ RỘNG — phép đo luôn bị phối cảnh thổi phồng khi chụp từ trên cao/dưới thấp (ảnh tựa tường
    /// chụp từ trên ra ~49° từng bị từ chối oan ở ngưỡng 45°). Chỉ TỪ CHỐI khi gần như nằm ngang; khoảng giữa
    /// thì CẢNH BÁO.
    private static let rejectSpineTiltDeg = 60.0
    private static let warnSpineTiltDeg = 35.0

    /// - Parameter frame: kết quả phân tích ảnh mẫu, `nil` = **không nạp được model** (khác "không thấy người").
    public static func check(_ frame: PoseFrame?) -> TemplateVerdict {
        guard let frame else {
            return rejected("gate_cannot_analyze", "gate_cannot_analyze_hint")
        }

        if frame.isEmpty { return rejected("gate_no_person", "gate_no_person_hint") }

        // --- Nhóm lõi: thiếu là không tính được tiêu chí nào ---
        let neck = frame.neck(coreVis)
        let root = frame.root(coreVis)

        // ⚠️ KHÔNG THẤY VAI THÌ VẪN NHẬN, NẾU THẤY MẶT (12/09/2026, FOOTGUNS 68). Lớp CHEST/HEAD dùng khuôn mặt
        // làm mốc cho hướng mẫu, xa/gần, lệch trái/phải — ảnh khuất vai vẫn chấm được 3-4 mục.
        let coMat = frame.at(Lm.nose, coreVis) != nil &&
            (frame.at(Lm.leftEye, coreVis) != nil || frame.at(Lm.rightEye, coreVis) != nil)

        if neck == nil && !coMat { return rejected("gate_no_shoulders_face", "gate_no_shoulders_face_hint") }

        guard let box = frame.subjectBox(coreVis) else { return rejected("gate_no_position", "gate_pick_clearer") }

        if box.height < minSubjectHeight { return rejected("gate_too_small", "gate_too_small_hint") }

        // --- Dáng đứng: giai đoạn này CHỈ hỗ trợ dáng đứng ---
        let spineTilt = estimateSpineTiltDeg(frame)
        if let spineTilt, spineTilt > rejectSpineTiltDeg { return rejected("gate_lying", "gate_lying_hint") }

        guard let framing = FramingClass.detect(frame, coreVis) else {
            return rejected("gate_no_framing", "gate_pick_clearer")
        }

        // --- Từ đây trở xuống là NHẬN, chỉ cảnh báo những gì sẽ bị bỏ qua ---
        var warnings: [UiText] = []

        if neck == nil {
            warnings.append(uiText("warn_no_shoulders"))
        }

        if let spineTilt, spineTilt > warnSpineTiltDeg {
            // `kotlin.math.round` làm tròn nửa về số chẵn.
            warnings.append(uiText("warn_spine_tilt", .int(Int(spineTilt.rounded(.toNearestOrEven)))))
        }

        if root == nil {
            warnings.append(uiText("warn_no_hips"))
        }

        // --- Chi chĩa thẳng vào ống kính --- đoạn hông→gót gần trùng trục ống kính, chiều dài trên ảnh co về
        // gần 0 mà công thức zoom lại CHIA cho nó. Không từ chối, nhưng phải nói trước (quy tắc số 7).
        if framing.seesLegs && legTowardLens(frame) {
            warnings.append(uiText("warn_leg_toward_lens"))
        }

        // Lớp chân dung/bán thân lấy KHUNG MẶT làm mốc tỉ lệ và ĐƯỜNG MẮT làm mốc góc nhìn.
        let seesFace = frame.at(Lm.nose, auxVis) != nil ||
            frame.at(Lm.leftEye, auxVis) != nil ||
            frame.at(Lm.rightEye, auxVis) != nil
        if !seesFace && (framing == .head || framing == .chest) {
            warnings.append(uiText("warn_portrait_no_face"))
        }

        return .accepted(.init(framing: framing, warnings: warnings))
    }

    private static func rejected(_ reason: String, _ hint: String) -> TemplateVerdict {
        .rejected(.init(reason: uiText(reason), hint: uiText(hint)))
    }

    /// Độ nghiêng trục thân so với phương thẳng đứng, ĐỘ. 0 = thẳng đứng.
    ///
    /// Đo bằng **cả hai** cách (2D trên ảnh, 3D `worldLandmarks`) rồi lấy giá trị **NHỎ HƠN**: phối cảnh chỉ có
    /// thể làm góc lớn hơn thực tế, không bao giờ nhỏ đi.
    private static func estimateSpineTiltDeg(_ frame: PoseFrame) -> Double? {
        let neck2 = frame.neck(coreVis)
        let root2 = frame.root(coreVis)
        var tilt2d: Double?
        if let neck2, let root2 {
            let dy = abs(root2.y - neck2.y)
            tilt2d = dy < 1e-6 ? 90.0 : toDegrees(atan2(abs(neck2.x - root2.x), dy))
        }

        let ls = frame.world(Lm.leftShoulder, coreVis)
        let rs = frame.world(Lm.rightShoulder, coreVis)
        let lh = frame.world(Lm.leftHip, coreVis)
        let rh = frame.world(Lm.rightHip, coreVis)
        var tilt3d: Double?
        if let ls, let rs, let lh, let rh {
            let nx = (ls.x + rs.x) / 2; let ny = (ls.y + rs.y) / 2; let nz = (ls.z + rs.z) / 2
            let hx = (lh.x + rh.x) / 2; let hy = (lh.y + rh.y) / 2; let hz = (lh.z + rh.z) / 2
            let dx = nx - hx; let dy = ny - hy; let dz = nz - hz
            let horizontal = hypot(dx, dz)
            tilt3d = abs(dy) < 1e-6 ? 90.0 : toDegrees(atan2(horizontal, abs(dy)))
        }

        return [tilt2d, tilt3d].compactMap { $0 }.min()
    }
}
