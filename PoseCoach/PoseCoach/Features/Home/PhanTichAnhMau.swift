import CoreGraphics
import Foundation
import PoseDomain

/// Kết quả phân tích MỘT LẦN một ảnh mẫu — dùng chung cho cổng kiểm, hồ sơ tiêu chí và bảng gắn nhãn ảnh tự nhập, để
/// không phân tích lại và chắc chắn các bên nói về cùng một kết quả. Port `KT/home/PhanTichAnhMau.kt`.
nonisolated struct PhanTichAnhMau {
    let verdict: TemplateVerdict
    fileprivate(set) var frame: PoseFrame?
    fileprivate(set) var face: FaceInfo?
    let poseGuide: [UiText]
    let difficulty: PoseDescriber.Difficulty?
    /// Đầu to hơn chân bao nhiêu — xem `DoanKieuTren.tiLeTaiChan`. `nil` = không thấy đủ.
    var taiChan: Double?
    /// Số cổ tay KHÔNG thấy trong khung (0–2). Selfie tự cầm máy thì tay cầm máy gần như luôn ra ngoài khung; người khác
    /// chụp thì hai tay thường thấy trọn (đo 08/10/2026: selfie 5/7 ảnh, người khác chụp 0/8).
    var coTayNgoaiKhung: Int?

    var framing: FramingClass? {
        if case let .accepted(a) = verdict { return a.framing }
        return nil
    }

    /// Hồ sơ tiêu chí; `gocMayNhan` là nhãn góc máy nếu có. `nil` khi ảnh bị từ chối.
    func hoSo(_ gocMayNhan: Double?, _ kieuChupTren: KieuChupTren? = nil) -> TemplateProfile? {
        guard let f = frame, let k = framing else { return nil }
        return TemplateProfile.from(f, k, TemplateGate.coreVis, face: face, gocMayNhan: gocMayNhan, kieuChupTren: kieuChupTren)
    }
}

/// Chặn luồng — gọi từ luồng nền.
nonisolated func phanTichAnhMau(_ file: URL) -> PhanTichAnhMau {
    let bmp = UprightImage.decode(file)
    let frame = bmp.flatMap { StillPoseAnalyzer.analyze($0) }
    let v = TemplateGate.check(frame)
    var accepted: TemplateVerdict.Accepted?
    if case let .accepted(a) = v { accepted = a }
    // Nhận diện mặt CHỈ chạy khi ảnh đã qua cổng kiểm — ảnh bị từ chối thì chẳng dùng tới.
    let face: FaceInfo? = (frame != nil && accepted != nil) ? bmp.flatMap { FaceAnalyzer().analyze($0) } : nil
    var poseGuide: [UiText] = []
    var difficulty: PoseDescriber.Difficulty?
    if let frame, let accepted {
        poseGuide = PoseDescriber.describe(frame, TemplateGate.coreVis)
        difficulty = PoseDescriber.difficulty(frame, accepted.framing, TemplateGate.coreVis)
    }
    let coTay: Int? = frame.flatMap { f in
        f.isEmpty ? nil : [Lm.leftWrist, Lm.rightWrist].filter { f.at($0, TemplateGate.coreVis) == nil }.count
    }
    let taiChan: Double? = (frame != nil && bmp != nil) ? DoanKieuTren.tiLeTaiChan(frame!, bmp!.width, bmp!.height) : nil
    return PhanTichAnhMau(
        verdict: v, frame: frame, face: face, poseGuide: poseGuide, difficulty: difficulty,
        taiChan: taiChan, coTayNgoaiKhung: coTay
    )
}
