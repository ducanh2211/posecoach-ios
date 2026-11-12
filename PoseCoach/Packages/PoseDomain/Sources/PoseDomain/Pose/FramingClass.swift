/// LỚP KHUNG HÌNH — khái niệm hạng nhất của dự án. Port từ `KT/pose/FramingClass.kt`.
///
/// Suy **MỘT LẦN** từ ảnh mẫu, rồi áp **NGUYÊN XI** cho mọi khung hình camera và mọi khung hình video
/// sau đó. **Không bao giờ để camera live tự chọn mốc đo** (FOOTGUNS 16).
///
/// Đây là chỗ sửa "nguyên nhân thứ 8" — lỗi duy nhất khiến hướng dẫn KHÔNG BAO GIỜ tắt được: ảnh mẫu
/// chân dung đo bằng "đỉnh đầu → hông", còn camera thấy toàn thân nên tự chọn "đỉnh đầu → cổ chân".
/// Hai đại lượng khác bản chất, phép trừ giữa chúng vô nghĩa.
public enum FramingClass: CaseIterable, Sendable {
    case full
    case knee
    case half
    case chest
    case head

    /// Key String Catalog của tên lớp (xem `UiText`).
    public var labelRes: String {
        switch self {
        case .full: return "framing_full"
        case .knee: return "framing_knee"
        case .half: return "framing_half"
        case .chest: return "framing_chest"
        case .head: return "framing_head"
        }
    }

    /// Lớp này có thấy chân không.
    ///
    /// ⚠️ Quyết định KIỂM ZOOM ĐƯỢC HAY KHÔNG nằm ở đây. Phép đo độ méo phối cảnh dựa vào chân — bộ phận
    /// lệch xa tầm máy nhất nên co ngắn mạnh nhất khi đứng gần. Không thấy chân thì chỉ còn cái đầu để đo,
    /// mà đầu xoay tự do nên chỉ số bám theo tư thế đầu chứ không theo khoảng cách máy (FOOTGUNS 37).
    /// Quyết định sản phẩm 04/09/2026: **ảnh chân dung KHÔNG kiểm zoom**.
    public var seesLegs: Bool { self == .full || self == .knee }

    /// Mốc đo tỉ lệ chủ thể trong khung (mục 2 — xa/gần).
    public var scaleAnchor: ScaleAnchor {
        switch self {
        case .full: return .headToAnkle
        case .knee: return .headToKnee
        case .half: return .headToHip
        case .chest, .head: return .faceHeight
        }
    }

    /// Điểm mốc đo GÓC NHÌN của máy (mục 3 — máy cao/thấp).
    ///
    /// ⚠️ Mốc này KHÔNG phải phép đo — nó là một số hạng trong công thức góc:
    ///
    ///     elevation = độ_nghiêng_máy + (0,5 − y_mốc) × vFOV
    ///
    /// Lấy thẳng `y_mốc` làm phép đo là sai: `y` là BỐ CỤC, thiếu hai số hạng kia thì nó nhạy với khoảng
    /// cách hơn cả với độ cao máy (FOOTGUNS 62). Nhưng vứt luôn mốc cũng sai — `y` là một nửa phương trình.
    public var elevationAnchor: ElevationAnchor {
        switch self {
        case .full, .knee: return .midHip
        case .half: return .midTorso
        case .chest, .head: return .eyeLine
        }
    }

    /// Điểm mốc đo lệch trái/phải (mục 5).
    public var centerAnchor: CenterAnchor {
        switch self {
        case .full, .knee, .half: return .torsoCenter
        case .chest: return .shoulderCenter
        case .head: return .faceCenter
        }
    }

    /// Nguồn đo hướng mẫu (mục 1). Chân dung đo hướng bằng góc mặt — chính xác hơn góc thân
    /// (~3-5° so với 8-10°).
    public var yawSource: YawSource {
        switch self {
        case .full, .knee, .half: return .body3d
        case .chest, .head: return .faceYaw
        }
    }

    /// Nhóm khớp được chấm ở mục 6 — chỉ chấm nhóm còn nằm trong khung.
    public var poseGroups: Set<PoseGroup> {
        switch self {
        case .full: return [.spine, .head, .arms, .legs]
        case .knee, .half: return [.spine, .head, .arms]
        case .chest: return [.head, .arms]
        case .head: return [.head]
        }
    }

    /// Suy lớp khung hình từ một khung hình đã đo.
    ///
    /// ⚠️ PHẢI KIỂM CẢ HAI ĐIỀU KIỆN: **thấy khớp nào** VÀ **đáy khung bao ở đâu** (FOOTGUNS 14). Chỉ kiểm
    /// đáy thì ảnh nửa người (chân cắt ngang đùi, đáy 0,90) bị xếp nhầm "toàn thân".
    ///
    /// Bộ nhận diện vẫn trả về điểm NGOÀI khung bằng ngoại suy. `PoseFrame.at` đã lọc cả độ tin cậy lẫn
    /// toạ độ, nên ở đây chỉ cần hỏi "có điểm không".
    public static func detect(_ frame: PoseFrame, _ minVisibility: Float) -> FramingClass? {
        guard let box = frame.subjectBox(minVisibility) else { return nil }
        let bottom = box.bottom

        func seesAny(_ idx: Int...) -> Bool { idx.contains { frame.at($0, minVisibility) != nil } }

        let seesAnkle = seesAny(Lm.leftAnkle, Lm.rightAnkle)
        let seesKnee = seesAny(Lm.leftKnee, Lm.rightKnee)
        let seesHip = seesAny(Lm.leftHip, Lm.rightHip)

        // Đáy sát mép dưới => phần dưới cơ thể đã bị cắt, con số đáy không tin được.
        let cutAtBottom = bottom > 0.97

        // ⚠️ MỐC NHÌN THẤY THẮNG NGƯỠNG CHIỀU CAO (FOOTGUNS 42).
        //
        // Hai ngưỡng 0,80 và 0,72 viết theo NGƯỜI ĐỨNG. Người NGỒI thấy rõ cả bàn chân mà thân chỉ chạm 65%
        // chiều cao ảnh — sẽ bị xếp nhầm half và mất tiêu chí zoom. Nên mốc đã NHÌN THẤY thì tin thẳng vào
        // nó; ngưỡng chiều cao chỉ dùng để SUY ĐOÁN khi mốc bị che.
        if seesAnkle && !cutAtBottom { return .full }
        if seesKnee && !cutAtBottom { return .knee }
        if seesAnkle && bottom > 0.80 { return .full }
        if seesKnee && bottom > 0.72 { return .knee }
        if seesHip && bottom > 0.55 { return .half }
        if box.height > 0.30 { return .chest }
        return .head
    }
}

public enum ScaleAnchor: Sendable { case headToAnkle, headToKnee, headToHip, faceHeight }

/// Điểm mốc tính góc nhìn của máy. Nhãn dùng cho câu giải thích khi bỏ mục.
///
/// ⚠️ `cueLabel` là chữ tiếng Việt viết thẳng — giữ đúng như Kotlin để đối chiếu. Kotlin hiện không đọc
/// thuộc tính này ở đâu; nếu sau này cần hiển thị thì phải đổi sang key String Catalog.
public enum ElevationAnchor: Sendable {
    case midHip
    case midTorso
    case eyeLine

    public var cueLabel: String {
        switch self {
        case .midHip: return "ngang hông mẫu"
        case .midTorso: return "ngang thân mẫu"
        case .eyeLine: return "ngang mắt mẫu"
        }
    }
}

public enum CenterAnchor: Sendable { case torsoCenter, shoulderCenter, faceCenter }
public enum YawSource: Sendable { case body3d, faceYaw }
public enum PoseGroup: Sendable { case spine, head, arms, legs }
