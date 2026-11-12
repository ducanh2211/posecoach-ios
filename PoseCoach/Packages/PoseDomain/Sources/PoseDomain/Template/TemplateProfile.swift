// Port từ `KT/template/TemplateProfile.kt`: Stage, Criterion, TemplateProfile và hai bảng nhãn
// (`PoseGroup.labelRes`, `FramingClass.scaleAnchorLabelRes`).
//
// `…Res` là KEY String Catalog (quy tắc 3b của AGENTS.md).

/// Hai chỗ dùng tới bộ tiêu chí, và chúng KHÁC NHAU.
///
/// Có tiêu chí **chỉ chấm được sau khi đã có ảnh** — bảo người cầm máy *"làm cho ảnh nét hơn"* lúc đang quay là
/// câu vô nghĩa.
public enum Stage: CaseIterable, Sendable {
    /// Hướng dẫn thời gian thực trên màn camera — chỉ những gì người dùng SỬA ĐƯỢC NGAY.
    case guidance
    /// Chọn 5 ảnh sau khi quay — thêm các tiêu chí hậu kỳ.
    case selection
}

/// MỘT TIÊU CHÍ CHẤM ĐIỂM.
///
/// ⚠️ ĐÂY LÀ CHỖ DUY NHẤT chứa trọng số và mốc quy đổi của toàn dự án.
///  - `weight` — mục nào quan trọng hơn. Quyết định SẢN PHẨM.
///  - `reference` — "lệch bao nhiêu thì coi như sai hoàn toàn". **Không phải** ngưỡng đạt/không đạt.
///
/// ⚠️ THỨ TỰ KHAI BÁO LÀ THỨ TỰ KIỂM VÀ THỨ TỰ NHẮC (`GuidanceEngine` sắp theo thứ tự trong `allCases`,
/// tương đương `ordinal` của Kotlin). Đổi chỗ ở đây là đổi thứ tự hướng dẫn. `roll` đứng sau cùng nhóm hình học
/// có chủ ý — trước 12/09/2026 nó đứng đầu và bịt kín kênh hướng dẫn 7/9 tới 9/11 khung hình.
public enum Criterion: CaseIterable, Sendable {
    /// MỤC 1 — HƯỚNG MẪU. Là HỆ SỐ NHÂN khi chấm điểm, không cộng trung bình (FOOTGUNS 28).
    case yaw
    /// MỤC 7 — ZOOM & KHOẢNG CÁCH, đo bằng độ méo phối cảnh (miễn nhiễm zoom). Chỉ áp dụng cho ảnh THẤY CHÂN.
    /// `reference` 0,30 suy từ dải đo được (1m→4m chênh 0,133) nhân hệ số an toàn.
    case perspective
    case scale
    case elevation
    /// MỤC 4 — MÁY NGỬA/CHÚC. ⚠️ `reference` 0,35 là PHỎNG ĐOÁN, chưa đo trên máy thật.
    case pitch
    case center
    case pose
    /// MỤC 8 — NGHIÊNG NGANG. `reference` 25°: quá mức này bức ảnh nghiêng hỏng hẳn.
    case roll
    /// HẬU KỲ — nhoè do CHỦ THỂ cử động (không phải rung tay / ánh sáng — đã chốt bỏ qua).
    case sharpness
    /// HẬU KỲ — mép khung cắt ngay tại khớp (cổ chân, gối, cổ tay, khuỷu).
    case crop
    /// HẬU KỲ — mẫu có nhắm mắt không. Trọng số nhỏ, chỉ để phân định giữa những tấm đã ngang nhau.
    case eyesOpen

    /// Tổng trọng số của nhóm hình học. Dáng 1,0 + độ nét 2,0 + cắt cụt 1,5 = 4,5.
    public static let geometryTotal = 5.5

    public var key: String {
        switch self {
        case .yaw: "huong"
        case .perspective: "zoom_khoangcach"
        case .scale: "xa_gan"
        case .elevation: "cao_thap"
        case .pitch: "ngua_chuc"
        case .center: "trai_phai"
        case .pose: "dang"
        case .roll: "nghieng_ngang"
        case .sharpness: "do_net"
        case .crop: "cat_cut"
        case .eyesOpen: "mat_mo"
        }
    }

    public var labelRes: String {
        switch self {
        case .yaw: "crit_yaw"
        case .perspective: "crit_perspective"
        case .scale: "crit_scale"
        case .elevation: "crit_elevation"
        case .pitch: "crit_pitch"
        case .center: "crit_center"
        case .pose: "crit_pose"
        case .roll: "crit_roll"
        case .sharpness: "crit_sharpness"
        case .crop: "crit_crop"
        case .eyesOpen: "crit_eyes_open"
        }
    }

    /// Trọng số CƠ SỞ. Với năm mục hình học, con số thật lấy từ `weightFor` vì nó đổi theo lớp khung hình.
    public var weight: Double {
        switch self {
        case .yaw: 3.0
        case .perspective: 1.5
        case .scale: 3.0
        case .elevation: 2.5
        case .pitch: 2.0
        case .center: 2.5
        case .pose: 1.0
        case .roll: 2.5
        case .sharpness: 2.0
        case .crop: 1.5
        case .eyesOpen: 0.6
        }
    }

    public var reference: Double {
        switch self {
        case .yaw: 55.0
        case .perspective: 0.30
        case .scale: 0.30
        case .elevation: 35.0
        case .pitch: 0.35
        case .center: 0.22
        case .pose: 55.0
        case .roll: 25.0
        case .sharpness, .crop, .eyesOpen: 1.0
        }
    }

    /// `true` = chỉ chấm khi CHỌN ẢNH, không đưa vào hướng dẫn realtime.
    public var postOnly: Bool {
        switch self {
        case .sharpness, .crop, .eyesOpen: true
        default: false
        }
    }

    /// Tên hiển thị GỘP trên danh sách tích. `nil` = dùng `labelRes` (Kotlin: `0`).
    ///
    /// `scale` và `perspective` là hai phép đo, nhưng với người dùng chỉ là một câu hỏi — *"tôi đứng đủ xa
    /// chưa?"*. Chỉ gộp ở tầng hiển thị, bên trong vẫn chấm riêng.
    public var groupLabelRes: String? {
        switch self {
        case .perspective, .scale: "crit_group_distance"
        default: nil
        }
    }

    /// Mục này do NGƯỜI MẪU thực hiện, không phải người cầm máy — câu nhắc gắn biểu tượng loa, và đóng băng các
    /// mục về máy trong lúc đang nói.
    public var forModel: Bool { self == .yaw || self == .pose }

    /// Tên hiện trên danh sách tích — gộp nếu mục thuộc một nhóm.
    public var displayLabelRes: String { groupLabelRes ?? labelRes }

    public func appliesTo(_ stage: Stage) -> Bool { !postOnly || stage == .selection }

    /// TRỌNG SỐ THẬT, ĐỔI THEO LỚP KHUNG HÌNH (FOOTGUNS 27).
    ///
    /// ```
    /// toàn thân : yaw .26  cao/thấp .24  ngửa/chúc .20  xa/gần .16  trái/phải .14
    /// nửa người : yaw .24  cao/thấp .22  ngửa/chúc .20  xa/gần .19  trái/phải .15
    /// chân dung : yaw .22  cao/thấp .20  ngửa/chúc .16  xa/gần .24  trái/phải .18
    /// ```
    ///
    /// Nhân `geometryTotal` để giữ tỉ lệ sản phẩm đã chốt: **hình học 0,55 · chất lượng 0,35 · dáng 0,10**.
    public func weightFor(_ framing: FramingClass) -> Double {
        let f: Double
        switch self {
        case .yaw:
            switch framing {
            case .full, .knee: f = 0.26
            case .half: f = 0.24
            case .chest, .head: f = 0.22
            }
        case .elevation:
            switch framing {
            case .full, .knee: f = 0.24
            case .half: f = 0.22
            case .chest, .head: f = 0.20
            }
        case .pitch:
            switch framing {
            case .full, .knee, .half: f = 0.20
            case .chest, .head: f = 0.16
            }
        case .scale:
            switch framing {
            case .full, .knee: f = 0.16
            case .half: f = 0.19
            case .chest, .head: f = 0.24
            }
        case .center:
            switch framing {
            case .full, .knee: f = 0.14
            case .half: f = 0.15
            case .chest, .head: f = 0.18
            }
        // Zoom & khoảng cách chỉ tồn tại ở lớp thấy chân, nên chỉ có hai mức.
        case .perspective:
            switch framing {
            case .full, .knee: f = 0.10
            // Không bao giờ tới đây: hồ sơ đã loại mục này ở các lớp kia.
            default: f = 0.0
            }
        // Dáng và các mục hậu kỳ không đổi theo lớp khung hình.
        default:
            return weight
        }
        return f * Criterion.geometryTotal
    }
}

/// HỒ SƠ CỦA MỘT ẢNH MẪU — suy MỘT LẦN lúc chọn ảnh, dùng lại cho mọi khung hình.
///
/// ⚠️ PHÂN BIỆT HAI LOẠI "KHÔNG CHẤM" (FOOTGUNS 25):
///
/// | | Ví dụ | Xử lý |
/// |---|---|---|
/// | **Không áp dụng** (tính chất của template) | Chân dung cận → không bao giờ chấm về chân | Loại khỏi hồ sơ, **không bao giờ nhắc tới** |
/// | **Không đo được** (sự cố của một khung) | Khung này tình cờ không thấy hông | Bỏ riêng ở khung đó |
public struct TemplateProfile: Equatable, Sendable {
    public internal(set) var framing: FramingClass
    /// Số đo của chính ảnh mẫu. Mọi khung hình về sau đem so với cái này.
    public internal(set) var measurement: PoseMeasurement
    /// Những tiêu chí ảnh mẫu này ÁP DỤNG.
    public internal(set) var active: Set<Criterion>
    /// Tiêu chí bị loại, kèm lý do — để nói được cho người dùng, không im lặng bỏ.
    ///
    /// ⚠️ Bản đồ không giữ thứ tự. Duyệt theo `TemplateProfile.thuTuHoSo` (xem `describe()`).
    public internal(set) var skipped: [Criterion: UiText]
    /// Nhóm khớp được chấm ở mục dáng. Chân dung cận không có nhóm chân.
    public internal(set) var poseGroups: Set<PoseGroup>
    /// Kiểu chụp từ trên cao. Chỉ đổi câu nhắc khoảng cách/zoom. `nil` = không có nhãn.
    public internal(set) var kieuChupTren: KieuChupTren?

    public init(
        framing: FramingClass,
        measurement: PoseMeasurement,
        active: Set<Criterion>,
        skipped: [Criterion: UiText],
        poseGroups: Set<PoseGroup>,
        kieuChupTren: KieuChupTren? = nil
    ) {
        self.framing = framing
        self.measurement = measurement
        self.active = active
        self.skipped = skipped
        self.poseGroups = poseGroups
        self.kieuChupTren = kieuChupTren
    }

    /// Ảnh mẫu góc máy gắt từ mức này thì bỏ mục độ méo — FOOTGUNS 99. Nhãn góc chỉ có −35 / 0 / +25 nên mức
    /// nằm giữa 0 và 25 là tách đúng "trên/dưới" khỏi "ngang".
    public static let gocGatDeg = 20.0

    private static let khongNhanGoc = uiText("skip_no_angle_label")

    /// Thứ tự `from()` thêm tiêu chí vào `active` / `skipped`. Kotlin dùng `LinkedHashSet` / `linkedMapOf` nên
    /// `describe()` liệt kê theo đúng thứ tự này — Swift `Set` / `Dictionary` không giữ thứ tự nên phải ghi rõ.
    public static let thuTuHoSo: [Criterion] = [
        .yaw, .scale, .center, .elevation, .roll, .pitch, .perspective, .pose, .sharpness, .eyesOpen, .crop,
    ]

    /// Tiêu chí áp dụng ở một chỗ cụ thể. Hướng dẫn realtime ít mục hơn chọn ảnh.
    public func activeFor(_ stage: Stage) -> Set<Criterion> {
        active.filter { $0.appliesTo(stage) }
    }

    /// Mô tả cho người dùng đọc: sẽ chấm theo gì, bỏ qua gì và vì sao. Hiện ở hộp thoại cổng kiểm.
    public func describe() -> [UiText] {
        var out: [UiText] = [uiText("profile_framing", .text(uiText(framing.labelRes)))]
        let dung = activeFor(.guidance)
        let dungTheoThuTu = TemplateProfile.thuTuHoSo.filter { dung.contains($0) }
        out.append(
            uiText(
                "profile_guides_on", .int(dung.count),
                .text(.join(dungTheoThuTu.map { uiText($0.labelRes) }, separator: ", "))
            )
        )
        for c in TemplateProfile.thuTuHoSo {
            guard let why = skipped[c] else { continue }
            out.append(uiText("profile_skipped", .text(uiText(c.labelRes)), .text(why)))
        }
        return out
    }

    /// Suy hồ sơ từ ảnh mẫu đã nhận diện: **đo thử ảnh mẫu trước**, mục nào ảnh mẫu không cung cấp nổi mốc so
    /// sánh thì loại. Không đoán theo tên lớp khung hình.
    ///
    /// - Parameters:
    ///   - face: số liệu khuôn mặt của ẢNH MẪU. `nil` = không thấy mặt hoặc chưa chạy.
    ///   - gocMayNhan: góc máy gán tay trong TÊN FILE ảnh mẫu, độ. `nil` = không có nhãn. Có nhãn thì nhãn THẮNG
    ///     phép suy từ ảnh — nhờ đó ảnh selfie có được mục 3 và mục 4.
    ///   - kieuChupTren: nhãn kiểu chụp từ trên cao.
    public static func from(
        _ frame: PoseFrame,
        _ framing: FramingClass,
        _ minVisibility: Float,
        face: FaceInfo? = nil,
        gocMayNhan: Double? = nil,
        kieuChupTren: KieuChupTren? = nil
    ) -> TemplateProfile {
        let doAnh = Measurer.measure(frame, framing, minVisibility, face: face)
        // ⚠️ GÓC MÁY CỦA ẢNH MẪU CHỈ LẤY TỪ NHÃN (16/09/2026) — FOOTGUNS 91.
        // Không nhãn thì bỏ hai mục góc máy (quy tắc số 4), không suy từ ảnh.
        let m: PoseMeasurement
        if let gocMayNhan {
            var c = doAnh
            c.tiltDeg = gocMayNhan
            c.pitchCue[.gocMay] = gocMayNhan
            c.elevationDeg = Measurer.gocNhin(gocMayNhan, doAnh.elevationAnchorY, Measurer.vfovAnhMau)
            m = c
        } else {
            m = doAnh.boGocMayTuAnh()
        }
        // ⚠️ ẢNH MẪU GÓC GẮT THÌ KHÔNG ĐO ĐỘ MÉO (19/09/2026) — FOOTGUNS 99. Chụp từ trên cao thì chân co ngắn
        // lại y như đứng gần; PO test: app bảo "lùi thêm 1 bước" mãi.
        let gocGat = gocMayNhan.map { abs($0) >= gocGatDeg } ?? false
        var active = Set<Criterion>()
        var skipped: [Criterion: UiText] = [:]

        func check(_ c: Criterion, _ ok: Bool, _ why: UiText) {
            if ok { active.insert(c) } else { skipped[c] = why }
        }

        check(.yaw, m.yawDeg != nil, uiText("skip_yaw"))
        // Mốc chính hỏng (chân chĩa vào ống kính) thì dùng khung mặt — xem `PoseMeasurement.faceScale`.
        check(
            .scale, m.scale != nil || m.faceScale != nil,
            uiText("skip_scale", .text(uiText(framing.scaleAnchorLabelRes)))
        )
        check(.center, m.centerX != nil, uiText("skip_center"))
        check(.elevation, m.elevationDeg != nil, gocMayNhan == nil ? khongNhanGoc : uiText("skip_elevation"))
        // Cầm máy thẳng đo bằng CẢM BIẾN, không cần gì từ ảnh mẫu — luôn áp dụng.
        active.insert(.roll)
        check(.pitch, !m.pitchCue.isEmpty, gocMayNhan == nil ? khongNhanGoc : uiText("skip_pitch"))
        // ⚠️ Thứ tự điều kiện để câu giải thích nói đúng nguyên nhân: góc gắt → lớp khung hình → đo được.
        let lyDoPerspective: UiText
        if gocGat {
            lyDoPerspective = uiText("skip_perspective_steep")
        } else if !framing.seesLegs {
            // ⚠️ KHÔNG nói "giữ zoom ở 1x" — mâu thuẫn với lời nhắc realtime (đi bộ HOẶC zoom).
            lyDoPerspective = uiText("skip_perspective_closeup")
        } else {
            lyDoPerspective = uiText("skip_perspective_no_legs")
        }
        check(.perspective, framing.seesLegs && !m.perspectiveIndex.isEmpty && !gocGat, lyDoPerspective)
        check(.pose, !m.poseAngles.isEmpty, uiText("skip_pose"))

        // Hậu kỳ chấm CHÍNH ẢNH CHỤP RA, không cần ảnh mẫu cung cấp mốc nào.
        active.insert(.sharpness)
        active.insert(.eyesOpen)

        // "Cắt ngang khớp" phụ thuộc lớp khung hình: chân dung cận không có khớp nào đáng xét.
        check(.crop, CropQuality.appliesTo(framing), uiText("skip_crop"))

        return TemplateProfile(
            framing: framing,
            measurement: m,
            active: active,
            skipped: skipped,
            poseGroups: framing.poseGroups,
            kieuChupTren: kieuChupTren
        )
    }
}

extension PoseGroup {
    /// Tên nhóm khớp cho người thường đọc — trả lời trực tiếp yêu cầu *"ảnh chân dung thì không chấm về chân"*.
    public var labelRes: String {
        switch self {
        case .spine: "group_spine"
        case .head: "group_head"
        case .arms: "group_arms"
        case .legs: "group_legs"
        }
    }
}

extension FramingClass {
    /// Tên mốc đo tỉ lệ, viết cho người thường đọc.
    fileprivate var scaleAnchorLabelRes: String {
        switch self {
        case .full: "anchor_head_ankle"
        case .knee: "anchor_head_knee"
        case .half: "anchor_head_hip"
        case .chest, .head: "anchor_face"
        }
    }
}
