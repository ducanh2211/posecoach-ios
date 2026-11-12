/// Một mục mà cả lần quay không có khung nào đạt. Port `FailedCriterion` + `ResultUiState.failedCriteria` +
/// `CRITERION_ADVICE` của `KT/result/ResultUiState.kt` — phần thuần, để test không cần app.
public struct FailedCriterion: Equatable, Sendable {
    /// Key String Catalog tên mục (`part_…`).
    public let labelRes: String
    /// Key String Catalog lời khuyên (`advice_…`).
    public let adviceRes: String

    /// Những mục mà **KHÔNG khung nào trong cả lần quay đạt nổi** (FOOTGUNS 24).
    ///
    /// ⚠️ Lý do tồn tại: app luôn trả về 5 tấm tốt nhất — kể cả khi cả 5 đều sai hoàn toàn. Bày chúng ra dưới tiêu đề
    /// "xếp theo mức giống ảnh mẫu" mà không nói gì là **thất bại im lặng** (luật số 7): người dùng tưởng đó là thứ tốt
    /// nhất có thể đạt, trong khi thực ra họ cần quay lại với mẫu xoay đúng hướng.
    ///
    /// Cố ý KHÔNG dùng ngưỡng phải đo trên máy thật: chỉ báo khi điểm ≈ 0, tức là đã lệch quá mốc "sai hoàn toàn" — một
    /// phát biểu về cấu trúc, không phải một con số cần hiệu chỉnh.
    public static func failedCriteria(_ shots: [ShotCandidate]) -> [FailedCriterion] {
        if shots.isEmpty { return [] }
        return criterionAdvice.compactMap { key, label, advice in
            // Chỉ xét mục ĐO ĐƯỢC ở mọi khung. Mục vắng mặt là "không đo được", đã bị bỏ ra khỏi cách tính rồi, không
            // phải "sai".
            let values = shots.map { $0.parts[key] }
            if values.contains(where: { $0 == nil }) { return nil }
            return values.allSatisfy { $0! <= 0.05 } ? FailedCriterion(labelRes: label, adviceRes: advice) : nil
        }
    }

    /// Lời khuyên cho từng mục.
    ///
    /// ⚠️ Viết theo **góc nhìn của NGƯỜI MẪU**, không theo góc nhìn màn hình — người cầm máy sẽ đọc to lên cho mẫu nghe.
    /// Viết theo màn hình sẽ lộn trái-phải khi nói ra miệng.
    static let criterionAdvice: [(key: String, label: String, advice: String)] = [
        ("huong", "part_yaw", "advice_yaw"),
        ("xa_gan", "part_distance", "advice_distance"),
        ("trai_phai", "part_center", "advice_center"),
        ("cao_thap", "part_elevation", "advice_elevation"),
        ("ngua_chuc", "part_pitch", "advice_pitch"),
        ("dang", "part_pose", "advice_pose"),
        ("do_net", "part_sharpness", "advice_sharpness"),
        ("mat_mo", "part_eyes_open", "advice_eyes_open"),
        ("cat_cut", "part_crop", "advice_crop"),
    ]
}
