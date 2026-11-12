// Port từ `KT/guidance/GuidanceEngine.kt`.
//
// ⚠️ BƯỚC 2a CHỈ CÓ HẰNG SỐ `DatMayGate` cần. Máy trạng thái theo bước port ở bước 2b.

/// ENGINE HƯỚNG DẪN — ghép `CriterionGate`, `CuePresenter`, đọc `ShotScorer.deviation` (cùng hàm với chấm điểm).
public final class GuidanceEngine {

    /// Máy ngửa/chúc từ mức này trở lên (gần nằm ngang mặt đất) thì độ vẹo từ cảm biến mất tin cậy.
    ///
    /// Mất tin cậy thì quay về mặc định "nhắc máy" — đúng luật máy trước mẫu sau.
    public static let deviceRollTrustPitchDeg = 60.0
}
