// Port từ `KT/guidance/PoseDescriber.kt`: PoseDescriber, Side, PoseFix, PoseHint.

import Foundation

/// MÔ TẢ DÁNG CỦA ẢNH MẪU bằng vài câu ngắn 3-4 từ — hiện ở màn chọn ảnh mẫu, **TRƯỚC khi vào chụp**.
///
/// ⚠️ Mẫu đứng cách máy 2-4m, KHÔNG nhìn được màn hình. Tạo dáng phải chuyển ra trước lúc chụp, bằng lời.
///
/// Quy ước góc (giống `Measurer`): `atan2(dx, dy)` với `dy` hướng XUỐNG: `0°` = chỉ xuống, `±90°` = ngang, `180°` =
/// chỉ lên. Góc khớp `0..180°`, `180°` = duỗi thẳng.
///
/// ⚠️ Trái/phải là **giải phẫu của mẫu** (nhãn `left…`/`right…` của MediaPipe), không phải trái/phải trên ảnh.
public enum PoseDescriber {

    /// Mô tả dáng, mỗi câu 3-4 từ. Rỗng = không đủ mốc để mô tả.
    public static func describe(_ frame: PoseFrame, _ minVis: Float) -> [UiText] {
        phrases(frame, minVis).map(\.text)
    }

    /// Một câu mô tả, kèm cờ "mẫu phải CHỦ ĐỘNG làm" — để tính độ khó mà không phải so chữ.
    private struct Phrase {
        let text: UiText
        var chuDong = true
    }

    private static func phrases(_ frame: PoseFrame, _ minVis: Float) -> [Phrase] {
        var out: [Phrase] = []
        if let p = spine(frame, minVis) { out.append(p) }
        if let p = head(frame, minVis) { out.append(p) }
        if let p = arm(frame, minVis, left: true) { out.append(p) }
        if let p = arm(frame, minVis, left: false) { out.append(p) }
        if let p = leg(frame, minVis, left: true) { out.append(p) }
        if let p = leg(frame, minVis, left: false) { out.append(p) }
        return out
    }

    /// ĐỘ KHÓ của ảnh mẫu: số việc mẫu phải chủ động làm + độ chặt của lớp khung hình.
    public static func difficulty(_ frame: PoseFrame, _ framing: FramingClass, _ minVis: Float) -> Difficulty {
        // Đứng thẳng và tay buông xuôi là tư thế mặc định, không tính là việc phải làm.
        let chuDong = phrases(frame, minVis).filter(\.chuDong).count
        let khungHinh: Int
        switch framing {
        case .head, .chest: khungHinh = 2
        case .half: khungHinh = 1
        case .knee, .full: khungHinh = 0
        }
        switch chuDong + khungHinh {
        case 0, 1: return .de
        case 2, 3: return .trungBinh
        default: return .kho
        }
    }

    public enum Difficulty: CaseIterable, Sendable {
        case de, trungBinh, kho

        public var labelRes: String {
            switch self {
            case .de: "difficulty_easy"
            case .trungBinh: "difficulty_medium"
            case .kho: "difficulty_hard"
            }
        }

        public var hintRes: String {
            switch self {
            case .de: "difficulty_easy_hint"
            case .trungBinh: "difficulty_medium_hint"
            case .kho: "difficulty_hard_hint"
            }
        }
    }

    /// CÂU NHẮC CHỈNH DÁNG lúc chụp — chỉ **một khớp lệch nhất**.
    ///
    /// ⚠️ Chỉ đáng tin SAU KHI hướng mẫu đã khớp: góc đo trên toạ độ 2 chiều của ảnh, mẫu xoay người là góc chiếu
    /// đổi dù dáng thật không đổi. Lý do KỸ THUẬT khiến mục dáng nằm CUỐI.
    public static func correction(_ template: PoseFrame, _ live: PoseFrame, _ minVis: Float) -> PoseHint? {
        var worstDiff = 0.0
        var worstText: PoseHint?
        func offer(_ diff: Double?, _ text: PoseHint) {
            guard let d = diff else { return }
            if d < noticeableDeg { return }
            if d > worstDiff { worstDiff = d; worstText = text }
        }

        for left in [true, false] {
            let side: Side = left ? .left : .right
            let sIdx = left ? Lm.leftShoulder : Lm.rightShoulder
            let eIdx = left ? Lm.leftElbow : Lm.rightElbow
            let wIdx = left ? Lm.leftWrist : Lm.rightWrist

            if let tDir = upperArmDir(template, sIdx, eIdx, minVis), let lDir = upperArmDir(live, sIdx, eIdx, minVis) {
                offer(abs(tDir - lDir), lDir < tDir ? PoseHint(.armRaise, side) : PoseHint(.armLower, side))
            }

            if let tEl = elbow(template, sIdx, eIdx, wIdx, minVis), let lEl = elbow(live, sIdx, eIdx, wIdx, minVis) {
                offer(abs(tEl - lEl), lEl < tEl ? PoseHint(.armStraighten, side) : PoseHint(.armBend, side))
            }
        }

        for left in [true, false] {
            let side: Side = left ? .left : .right
            if let tK = knee(template, left, minVis), let lK = knee(live, left, minVis) {
                offer(abs(tK - lK), lK < tK ? PoseHint(.legStraighten, side) : PoseHint(.kneeBend, side))
            }
        }

        if let tS = spineAngle(template, minVis), let lS = spineAngle(live, minVis) {
            offer(abs(tS - lS), PoseHint(.lean))
        }

        return worstText
    }

    private static func upperArmDir(_ f: PoseFrame, _ s: Int, _ e: Int, _ v: Float) -> Double? {
        guard let sh = f.at(s, v), let el = f.at(e, v) else { return nil }
        return segAngle(sh.x, sh.y, el.x, el.y).map { abs($0) }
    }

    private static func elbow(_ f: PoseFrame, _ s: Int, _ e: Int, _ w: Int, _ v: Float) -> Double? {
        guard let sh = f.at(s, v), let el = f.at(e, v), let wr = f.at(w, v) else { return nil }
        return jointAngle(sh.x, sh.y, el.x, el.y, wr.x, wr.y)
    }

    private static func knee(_ f: PoseFrame, _ left: Bool, _ v: Float) -> Double? {
        guard let h = f.at(left ? Lm.leftHip : Lm.rightHip, v),
              let k = f.at(left ? Lm.leftKnee : Lm.rightKnee, v),
              let a = f.at(left ? Lm.leftAnkle : Lm.rightAnkle, v) else { return nil }
        return jointAngle(h.x, h.y, k.x, k.y, a.x, a.y)
    }

    private static func spineAngle(_ f: PoseFrame, _ v: Float) -> Double? {
        guard let neck = f.neck(v), let root = f.root(v) else { return nil }
        return segAngle(neck.x, neck.y, root.x, root.y)
    }

    /// Lệch dưới mức này thì KHÔNG nhắc — "nâng tay lên 8 độ" là câu không ai làm được.
    private static let noticeableDeg = 20.0

    // MARK: -

    private static func spine(_ f: PoseFrame, _ v: Float) -> Phrase? {
        guard let neck = f.neck(v), let root = f.root(v),
              let a = segAngle(neck.x, neck.y, root.x, root.y) else { return nil }
        // root nằm DƯỚI neck nên góc quanh 0 khi đứng thẳng.
        if abs(a) < spineStraightDeg { return Phrase(text: uiText("pose_stand_straight"), chuDong: false) }
        // a > 0 = hông lệch sang phải ẢNH = mẫu nghiêng sang TRÁI của họ.
        if a > 0 { return Phrase(text: uiText("pose_lean_left")) }
        return Phrase(text: uiText("pose_lean_right"))
    }

    /// ⚠️ HAI phép đo riêng: **nghiêng** đọc từ độ dốc đường nối hai tai, **cúi/ngẩng** từ vị trí mũi so với đường
    /// tai. Bản thử đầu dùng đoạn cổ→mũi cho cả hai và báo cúi đầu thành nghiêng đầu.
    private static func head(_ f: PoseFrame, _ v: Float) -> Phrase? {
        let le = f.at(Lm.leftEar, v)
        let re = f.at(Lm.rightEar, v)
        guard let nose = f.at(Lm.nose, v) else { return nil }

        // Không thấy đủ hai tai (mũ che, quay nghiêng) thì KHÔNG đoán bừa.
        guard let le, let re else { return nil }
        let earSpan = hypot(le.x - re.x, le.y - re.y)
        if earSpan < 1e-4 { return nil }

        // NGHIÊNG: độ dốc của đường nối hai tai.
        let roll = toDegrees(atan2(le.y - re.y, le.x - re.x))
        let rollDeg = abs(roll) > 90 ? 180 - abs(roll) : abs(roll)
        if rollDeg >= headRollDeg {
            return Phrase(text: uiText(roll > 0 ? "pose_head_tilt_left" : "pose_head_tilt_right"))
        }

        // CÚI/NGẨNG: mũi cao thấp so với đường tai, đo theo bề ngang đầu.
        let earMidY = (le.y + re.y) / 2.0
        let nod = (nose.y - earMidY) / earSpan
        if nod > headNodRatio { return Phrase(text: uiText("pose_head_down")) }
        if nod < -headNodRatio { return Phrase(text: uiText("pose_head_up")) }
        return nil   // đầu thẳng thì không cần nói gì
    }

    private static func arm(_ f: PoseFrame, _ v: Float, left: Bool) -> Phrase? {
        let sIdx = left ? Lm.leftShoulder : Lm.rightShoulder
        let eIdx = left ? Lm.leftElbow : Lm.rightElbow
        let wIdx = left ? Lm.leftWrist : Lm.rightWrist

        guard let sh = f.at(sIdx, v), let el = f.at(eIdx, v),
              let seg = segAngle(sh.x, sh.y, el.x, el.y) else { return nil }
        let dir = abs(seg)

        // Hướng cánh tay TRÊN: 0 = buông thẳng xuống, 90 = dang ngang, 180 = giơ lên.
        let huong: Int
        if dir < 30 { huong = 0 }          // buông xuôi
        else if dir < 70 { huong = 1 }     // hơi dang ra
        else if dir < 115 { huong = 2 }    // dang ngang
        else { huong = 3 }                 // giơ lên

        // Khuỷu gập hay không — chỉ nói thêm khi thật sự gập.
        let wr = f.at(wIdx, v)
        let elbow = wr.flatMap { jointAngle(sh.x, sh.y, el.x, el.y, $0.x, $0.y) }
        let gap = elbow.map { $0 < elbowBentDeg } ?? false
        let text: String
        if gap && dir < 70 { text = left ? "pose_arm_bent_left" : "pose_arm_bent_right" }
        else if gap && huong == 2 { text = left ? "pose_arm_out_bent_left" : "pose_arm_out_bent_right" }
        else if gap { text = left ? "pose_arm_up_bent_left" : "pose_arm_up_bent_right" }
        else if huong == 0 { text = left ? "pose_arm_down_left" : "pose_arm_down_right" }
        else if huong == 1 { text = left ? "pose_arm_slightly_out_left" : "pose_arm_slightly_out_right" }
        else if huong == 2 { text = left ? "pose_arm_out_left" : "pose_arm_out_right" }
        else { text = left ? "pose_arm_up_left" : "pose_arm_up_right" }
        // Tay buông xuôi, không gập: tư thế mặc định.
        return Phrase(text: uiText(text), chuDong: gap || huong != 0)
    }

    private static func leg(_ f: PoseFrame, _ v: Float, left: Bool) -> Phrase? {
        guard let h = f.at(left ? Lm.leftHip : Lm.rightHip, v),
              let k = f.at(left ? Lm.leftKnee : Lm.rightKnee, v),
              let a = f.at(left ? Lm.leftAnkle : Lm.rightAnkle, v),
              let ang = jointAngle(h.x, h.y, k.x, k.y, a.x, a.y) else { return nil }
        // Chân duỗi thẳng là mặc định, không cần nói. Chỉ nói khi chùng rõ.
        return ang < kneeBentDeg ? Phrase(text: uiText(left ? "pose_knee_bent_left" : "pose_knee_bent_right")) : nil
    }

    // MARK: -

    private static func segAngle(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double? {
        let dx = bx - ax
        let dy = by - ay
        if hypot(dx, dy) < 1e-6 { return nil }
        return toDegrees(atan2(dx, dy))
    }

    private static func jointAngle(
        _ ax: Double, _ ay: Double, _ bx: Double, _ by: Double, _ cx: Double, _ cy: Double
    ) -> Double? {
        let v1x = ax - bx, v1y = ay - by
        let v2x = cx - bx, v2y = cy - by
        let n1 = hypot(v1x, v1y), n2 = hypot(v2x, v2y)
        if n1 < 1e-6 || n2 < 1e-6 { return nil }
        let cos = min(max((v1x * v2x + v1y * v2y) / (n1 * n2), -1.0), 1.0)
        return toDegrees(acos(cos))
    }

    // Các mốc chọn từ 28 ảnh thử. Chúng quyết định câu chữ chứ không quyết định điểm số.
    private static let spineStraightDeg = 10.0
    private static let headRollDeg = 12.0
    private static let headNodRatio = 0.45
    private static let elbowBentDeg = 110.0
    private static let kneeBentDeg = 160.0
}

/// Bên trái/phải theo GIẢI PHẪU của người mẫu (nhãn `left…`/`right…` của MediaPipe).
public enum Side: CaseIterable, Sendable {
    case left, right

    public func flip() -> Side { self == .left ? .right : .left }
}

/// Việc phải sửa ở mục dáng. Xem `PoseDescriber.correction`.
public enum PoseFix: CaseIterable, Sendable {
    case armRaise, armLower, armStraighten, armBend, legStraighten, kneeBend, lean
}

/// CÂU NHẮC DÁNG dạng dữ liệu, chưa thành chữ.
///
/// ⚠️ Ảnh gương phải đổi trái ↔ phải — đổi thẳng `side` rồi mới chọn câu theo ngôn ngữ (không thay chữ trong câu).
public struct PoseHint: Equatable, Sendable {
    public let fix: PoseFix
    /// `nil` với việc không có bên (chỉnh độ nghiêng người).
    public let side: Side?

    public init(_ fix: PoseFix, _ side: Side? = nil) {
        self.fix = fix
        self.side = side
    }

    public func mirrored() -> PoseHint { PoseHint(fix, side?.flip()) }

    /// - Parameter tuChup: người cầm máy chính là mẫu — bỏ "Bảo mẫu …", nói thẳng với họ.
    public func text(_ tuChup: Bool) -> UiText {
        let left = side != .right
        func pick(_ lm: String, _ rm: String, _ ls: String, _ rs: String) -> String {
            tuChup ? (left ? ls : rs) : (left ? lm : rm)
        }
        let id: String
        switch fix {
        case .armRaise:
            id = pick("hint_arm_raise_left_model", "hint_arm_raise_right_model",
                      "hint_arm_raise_left_self", "hint_arm_raise_right_self")
        case .armLower:
            id = pick("hint_arm_lower_left_model", "hint_arm_lower_right_model",
                      "hint_arm_lower_left_self", "hint_arm_lower_right_self")
        case .armStraighten:
            id = pick("hint_arm_straighten_left_model", "hint_arm_straighten_right_model",
                      "hint_arm_straighten_left_self", "hint_arm_straighten_right_self")
        case .armBend:
            id = pick("hint_arm_bend_left_model", "hint_arm_bend_right_model",
                      "hint_arm_bend_left_self", "hint_arm_bend_right_self")
        case .legStraighten:
            id = pick("hint_leg_straighten_left_model", "hint_leg_straighten_right_model",
                      "hint_leg_straighten_left_self", "hint_leg_straighten_right_self")
        case .kneeBend:
            id = pick("hint_knee_bend_left_model", "hint_knee_bend_right_model",
                      "hint_knee_bend_left_self", "hint_knee_bend_right_self")
        case .lean:
            id = tuChup ? "hint_lean_self" : "hint_lean_model"
        }
        return uiText(id)
    }
}
