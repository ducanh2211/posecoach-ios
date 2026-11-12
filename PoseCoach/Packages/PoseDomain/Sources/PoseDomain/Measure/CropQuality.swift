// Port từ `KT/measure/ShotScore.kt` (object `CropQuality`).

/// TIÊU CHÍ HẬU KỲ: mép khung có cắt ngang khớp không.
///
/// Cắt ngay tại cổ chân, đầu gối, cổ tay hay khuỷu làm chi trông như bị cụt; cắt ở GIỮA hai khớp thì tự nhiên.
/// Chỉ đánh giá được **sau khi đã có ảnh** — không đưa vào hướng dẫn realtime.
public enum CropQuality {

    /// Khớp nằm trong dải này quanh mép khung thì coi như bị cắt ngang.
    private static let edgeBand = 0.06

    /// Khớp nào đáng xét, tuỳ lớp khung hình.
    ///
    /// ⚠️ Ảnh bán thân thì cổ chân **đương nhiên** nằm ngoài khung — chủ ý của bức ảnh, không phải lỗi cắt cụt.
    public static func jointsFor(_ framing: FramingClass) -> [Int] {
        switch framing {
        case .full:
            [Lm.leftAnkle, Lm.rightAnkle, Lm.leftKnee, Lm.rightKnee,
             Lm.leftWrist, Lm.rightWrist, Lm.leftElbow, Lm.rightElbow]
        case .knee:
            [Lm.leftKnee, Lm.rightKnee, Lm.leftWrist, Lm.rightWrist, Lm.leftElbow, Lm.rightElbow]
        case .half:
            [Lm.leftWrist, Lm.rightWrist, Lm.leftElbow, Lm.rightElbow]
        case .chest:
            [Lm.leftElbow, Lm.rightElbow]
        // Chân dung cận: không khớp nào đáng xét, mục này không áp dụng.
        case .head:
            []
        }
    }

    public static func appliesTo(_ framing: FramingClass) -> Bool { !jointsFor(framing).isEmpty }

    /// - Returns: 1 = không khớp nào bị cắt ngang, 0 = mọi khớp đều sát mép. `nil` khi không có khớp nào để xét.
    ///
    /// ⚠️ Đếm theo điểm THÔ (`points` / `visibility`), không qua `PoseFrame.at()` — khớp nằm ngoài khung vẫn được
    /// đếm và tính là sát mép, đúng như Kotlin.
    public static func of(_ frame: PoseFrame, _ framing: FramingClass, _ minVisibility: Float) -> Double? {
        if frame.isEmpty { return nil }
        let joints = jointsFor(framing)
        if joints.isEmpty { return nil }

        var atEdge = 0
        var counted = 0
        for i in joints {
            if !frame.points.indices.contains(i) { continue }
            if frame.visibility[i] < minVisibility { continue }
            counted += 1
            let p = frame.points[i]
            let nearEdge = p.x <= edgeBand || p.x >= 1.0 - edgeBand ||
                p.y <= edgeBand || p.y >= 1.0 - edgeBand
            if nearEdge { atEdge += 1 }
        }
        if counted == 0 { return nil }
        return min(max(1.0 - Double(atEdge) / Double(counted), 0.0), 1.0)
    }
}
