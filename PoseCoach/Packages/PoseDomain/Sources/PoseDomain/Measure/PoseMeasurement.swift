// Kiểu dữ liệu của TẦNG ĐO ĐẠC. Port từ `KT/measure/PoseMeasurement.kt` (phần khai báo).
// Hàm đo nằm ở `Measurer.swift`.
//
// ⚠️ Các bản đồ (`[Source: Double]`) không giữ thứ tự — nơi đọc PHẢI duyệt theo `Source.allCases`
// (đúng thứ tự khai báo như Kotlin `entries`), không duyệt theo bản đồ.

/// CẶP ĐOẠN dùng để suy ĐỘ MÉO PHỐI CẢNH, xếp theo ưu tiên giảm dần.
///
/// ⚠️ Số của hai cặp KHÁC NHAU không so được với nhau — chúng ở hai thang khác hẳn. Vì vậy
/// `PoseMeasurement.perspectiveIndex` giữ cả bản đồ: tầng so sánh chọn cặp mà cả ảnh mẫu lẫn khung hình
/// cùng có.
public enum PerspectiveSource: CaseIterable, Sendable {
    /// Thân so với CẢ CHÂN (hông→cổ chân). Cặp mạnh nhất — tín hiệu trên nhiễu 4,67 trên 13 ảnh có đáp án.
    case torsoAnkle
    /// Thân so với ĐÙI (hông→gối). Dùng khi khung hình cắt mất cổ chân. Yếu hơn — tín hiệu trên nhiễu 2,97.
    case torsoKnee
}

/// ĐƯỜNG ĐO đã dùng cho mục NGHIÊNG NGANG. Tách nhãn để giữ luật "chỉ so khi cùng đường" (FOOTGUNS 39).
public enum RollSource: CaseIterable, Sendable {
    /// Trục thân (giữa vai → giữa hông). Dài, và không đổi khi mẫu xoay người.
    case spine
    /// Đường nối hai vai. Dùng khi không thấy hông — ảnh chân dung, bán thân.
    case shoulders
}

/// ĐƯỜNG ĐO đã dùng cho mục NGỬA/CHÚC. Hai đường không so được với nhau (khác thang, khác nhiễu 6,5 lần).
public enum PitchSource: CaseIterable, Sendable {
    /// GÓC MÁY THẬT so với phương ngang — ĐỘ. Đường chính, xếp đầu. Âm = chúc xuống, dương = hất lên.
    ///
    /// ⚠️ Hai bên lấy từ hai nguồn khác nhau, có chủ ý: ảnh mẫu từ trục thân 3D hoặc NHÃN GÓC trong tên
    /// file; camera từ CẢM BIẾN trọng lực (FOOTGUNS 80, 91).
    case gocMay
    /// Chân so với thân. Tỉ lệ không đơn vị — đường phụ, gần như không còn dùng tới.
    case legs
}

/// Kết quả đo một khung hình. Ảnh mẫu và khung camera ra cùng một kiểu này, từ cùng một hàm
/// (`Measurer.measure`).
public struct PoseMeasurement: Equatable, Sendable {
    /// Lớp khung hình đã dùng để đo. Luôn là lớp của ảnh mẫu.
    public internal(set) var framing: FramingClass

    /// MỤC 2 — XA/GẦN. Chiều cao của mốc đo, theo tỉ lệ chiều cao khung hình. Lớn hơn = máy GẦN hơn.
    /// `nil` khi mốc của lớp này không nhìn thấy.
    public internal(set) var scale: Double?

    /// MỤC 5 — LỆCH TRÁI/PHẢI. Vị trí ngang của mốc, 0 = mép trái, 1 = mép phải.
    public internal(set) var centerX: Double?

    /// ĐỘ NGHIÊNG CỦA TRỤC ỐNG KÍNH — mục 4, ĐỘ. Âm = chúc xuống, dương = hất lên, 0 = nằm ngang.
    /// Suy từ trục thân trong khung xương 3D. `nil` khi không thấy hông.
    public internal(set) var tiltDeg: Double?

    /// GÓC NHÌN TỪ MÁY TỚI MỐC TRÊN CƠ THỂ — mục 3, ĐỘ.
    ///
    ///     elevation = tiltDeg + (0,5 − y_mốc) × vFOV
    ///
    /// Âm = máy CAO hơn mốc. Dương = máy THẤP hơn. Đại lượng KHÁC `tiltDeg`, không thừa.
    public internal(set) var elevationDeg: Double?

    /// MỤC 1 — HƯỚNG MẪU đo bằng THÂN, ĐỘ. 0 = quay thẳng vào máy, ±180 = quay lưng.
    public internal(set) var yawDeg: Double?

    /// MỤC 1 — HƯỚNG MẪU đo bằng MẶT. `nil` khi không thấy mặt.
    ///
    /// ⚠️ Chỉ được dùng khi CẢ ảnh mẫu LẪN khung hình đều có — trộn hai nguồn giữa hai bên là phá bất biến
    /// "cùng một hàm".
    public internal(set) var faceYawDeg: Double?

    /// HẬU KỲ — mắt có mở không, 0..1. Lấy mắt nhắm hơn trong hai mắt.
    public internal(set) var eyesOpen: Double?

    /// Chiều cao THẬT của đúng cái mốc mà `scale` đo trên ảnh, MÉT. Ghép với `scale` và mức zoom thì ra
    /// khoảng cách máy-tới-mẫu. ⚠️ `nil` với ảnh CHÂN DUNG — `worldLandmarks` không cho chiều cao mặt
    /// đáng tin.
    public internal(set) var anchorHeightMeters: Double?

    /// MỤC 8 — NGHIÊNG NGANG. Góc trục thân so với phương thẳng đứng CỦA ẢNH, ĐỘ. Dương = nghiêng phải.
    ///
    /// ⚠️ ĐO TỪ ẢNH, KHÔNG TỪ CẢM BIẾN — ảnh mẫu là ảnh tĩnh, không có cảm biến. Cảm biến chỉ dùng để chọn
    /// nhắc ai (máy hay mẫu), xem `GuidanceEngine`.
    public internal(set) var rollDeg: [RollSource: Double]

    /// MỤC 4 — MÁY NGỬA/CHÚC. Dương = hất lên, âm = chúc xuống.
    public internal(set) var pitchCue: [PitchSource: Double]

    /// MỤC 7 — ĐỘ MẠNH PHỐI CẢNH. Chỉ số không đơn vị, MIỄN NHIỄM VỚI ZOOM. Càng LỚN = máy càng gần.
    public internal(set) var perspectiveIndex: [PerspectiveSource: Double]

    /// MỤC 6 — DÁNG. Góc các khớp, ĐỘ, chỉ gồm nhóm khớp thuộc lớp khung hình. Đo trên toạ độ 2 chiều
    /// CỦA ẢNH, cố ý. Nhóm `arms` luôn đủ 4 phần tử, `.nan` cho khớp không đo được (FOOTGUNS 50).
    public internal(set) var poseAngles: [PoseGroup: [Double]]

    /// Toạ độ dọc của mốc góc nhìn trên khung (mục 3). Một SỐ HẠNG, không phải phép đo — giữ lại để phía
    /// camera ghép với độ nghiêng từ cảm biến, và để nhãn góc trong tên file tính được mục 3.
    public internal(set) var elevationAnchorY: Double?

    /// Chiều cao khung mặt trên khung hình — mốc cỡ mẫu DỰ PHÒNG khi mốc chính bị bỏ vì chân chĩa vào
    /// ống kính (ảnh chụp từ trên cao).
    public internal(set) var faceScale: Double?

    /// Khung hình nhìn thấy cơ thể XUỐNG TỚI ĐÂU: 0 vai · 1 hông · 2 gối · 3 cổ chân. `nil` = không thấy cả
    /// vai. Xem `ShotScorer.thieuThan`.
    public internal(set) var tamThan: Int?

    public init(
        framing: FramingClass,
        scale: Double?,
        centerX: Double?,
        tiltDeg: Double?,
        elevationDeg: Double?,
        yawDeg: Double?,
        faceYawDeg: Double?,
        eyesOpen: Double?,
        anchorHeightMeters: Double?,
        rollDeg: [RollSource: Double],
        pitchCue: [PitchSource: Double],
        perspectiveIndex: [PerspectiveSource: Double],
        poseAngles: [PoseGroup: [Double]],
        elevationAnchorY: Double? = nil,
        faceScale: Double? = nil,
        tamThan: Int? = nil
    ) {
        self.framing = framing
        self.scale = scale
        self.centerX = centerX
        self.tiltDeg = tiltDeg
        self.elevationDeg = elevationDeg
        self.yawDeg = yawDeg
        self.faceYawDeg = faceYawDeg
        self.eyesOpen = eyesOpen
        self.anchorHeightMeters = anchorHeightMeters
        self.rollDeg = rollDeg
        self.pitchCue = pitchCue
        self.perspectiveIndex = perspectiveIndex
        self.poseAngles = poseAngles
        self.elevationAnchorY = elevationAnchorY
        self.faceScale = faceScale
        self.tamThan = tamThan
    }

    /// Số mục đo được. Mục không đo được bị bỏ ra khi chấm điểm, KHÔNG bị trừ điểm.
    public var measuredCount: Int {
        [scale, centerX, elevationDeg, yawDeg].compactMap { $0 }.count +
            (pitchCue.isEmpty ? 0 : 1) +
            (rollDeg.isEmpty ? 0 : 1) +
            (poseAngles.isEmpty ? 0 : 1)
    }

    /// Bỏ ba đại lượng góc máy SUY TỪ ẢNH: độ nghiêng, góc nhìn, và nguồn `PitchSource.gocMay`.
    ///
    /// Suy từ trục thân nên lẫn cả dáng đứng lẫn loại ống kính. Góc máy thật chỉ lấy từ NHÃN (ảnh mẫu) và
    /// CẢM BIẾN (camera). Xem FOOTGUNS 91.
    public func boGocMayTuAnh() -> PoseMeasurement {
        var m = self
        m.tiltDeg = nil
        m.elevationDeg = nil
        m.pitchCue[.gocMay] = nil
        return m
    }

    /// GÓC MÁY PHÍA CAMERA LẤY TỪ CẢM BIẾN — độ thật, cùng thang với NHÃN góc của ảnh mẫu. Thay độ nghiêng, nguồn
    /// `PitchSource.gocMay` và góc nhìn (tính lại theo `goc`). Port đoạn `doAnh.copy(…)` trong
    /// `CaptureViewModel.onLiveFrame` (Kotlin).
    ///
    /// - Parameter goc: góc ngẩng của ống kính đang dùng (camera trước đã đảo dấu), độ.
    public func gocMayTuCamBien(_ goc: Double, _ vFovDeg: Double) -> PoseMeasurement {
        var m = self
        m.tiltDeg = goc
        m.pitchCue[.gocMay] = goc
        m.elevationDeg = Measurer.gocNhin(goc, elevationAnchorY, vFovDeg)
        return m
    }
}
