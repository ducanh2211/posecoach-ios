// Port từ `KT/guidance/CuePresenter.kt`: CriterionStatus, CuePresenter, cueTextFor.

import Foundation

/// Trạng thái một mục ở một khung hình, đủ dữ liệu để vừa vẽ danh sách tích vừa viết được lời nhắc.
public struct CriterionStatus: Equatable, Sendable {
    public internal(set) var criterion: Criterion
    public internal(set) var state: GateState
    /// Độ lệch TUYỆT ĐỐI so với ảnh mẫu. `nil` = khung này không đo được.
    public internal(set) var deviation: Double?
    /// Hiệu CÓ DẤU (khung hình trừ ảnh mẫu) — chỉ dùng để **chọn chữ** ("lùi lại" hay "tiến lên").
    public internal(set) var signedDelta: Double?
    public internal(set) var band: Band?
    /// Quãng đường cần đi, MÉT. `nil` = không ước lượng được, câu lùi về "một chút".
    public internal(set) var moveMeters: Double? = nil
    /// Mục khung hình phải nói ĐI BỘ thay vì ZOOM — ảnh mẫu không có bước khoảng cách nên đưa cả hai lựa chọn.
    public internal(set) var walkInsteadOfZoom = false
    /// Câu nhắc chỉnh dáng theo khớp lệch nhất. Chỉ có ở mục dáng.
    public internal(set) var poseHint: PoseHint? = nil
    /// MỤC NGHIÊNG NGANG — cảm biến nói lỗi ở MÁY (`true`) hay ở MẪU (`false`). ⚠️ Không tham gia chấm điểm.
    public internal(set) var rollFromDevice = true
    /// Mục 3 đã GỘP với mục 4 vì cùng chiều — câu nhắc nói cả hai động tác.
    public internal(set) var kemChuc = false
    /// Góc máy của ẢNH MẪU, độ — chỉ đặt cho mục ngửa/chúc khi ảnh mẫu KHÔNG có mục máy cao/thấp.
    public internal(set) var gocMauKhongCoCaoThap: Double? = nil
    /// Mục ÁP DỤNG nhưng khung hình hiện tại **không đo được**, đã đủ lâu để cần giải thích (quy tắc số 7).
    public internal(set) var unmeasuredTooLong = false
    /// Người cầm máy CHÍNH LÀ mẫu, và họ nhìn thấy màn hình. Bỏ tiền tố *"Bảo mẫu…"*.
    public internal(set) var tuChup = false
    /// Hình đang xem bị LẬT NGANG. ⚠️ CHỈ ĐẢO CHỮ TRÁI/PHẢI TRONG CÂU NHẮC DÁNG (và chiều xoay hướng mẫu) —
    /// không đụng phép đo, không đụng câu về máy (FOOTGUNS 48).
    public internal(set) var latGuong = false
    /// Dịch máy trên màn hình NGƯỢC CHIỀU camera thường (camera trước). Xem `ShootMode.mayNguocChieu`.
    public internal(set) var mayNguocChieu = false
    /// Khoảng cách chỉnh bằng co/duỗi TAY, không phải bằng bước chân.
    public internal(set) var tamTay = false
    /// Đặt máy tự chụp: máy đứng yên, NGƯỜI di chuyển.
    public internal(set) var datMay = false
    /// Chưa tới lượt xử lý vì một bước trước trong quy trình chưa xong.
    public internal(set) var pending = false
    /// Đã thử đủ lâu trong chế độ tự động nhưng không hội tụ; cho phép đi tiếp.
    public internal(set) var skipped = false
    /// Mức zoom đề nghị sau khi chỗ đứng đã được khoá.
    public internal(set) var targetZoom: Float? = nil
    /// Ảnh mẫu chụp từ trên cao, đứng gần: zoom không được vượt mức này (1x). Xem `KieuChupTren`.
    public internal(set) var zoomToiDa: Float? = nil
    /// Máy đang zoom vào quá `zoomToiDa`.
    public internal(set) var zoomSai = false
    /// Máy có ống góc rộng (zoom ra dưới 1x được) — mới gợi ý kiểu mắt cá.
    public internal(set) var coGocRong = false
    /// Ảnh mẫu chụp từ trên cao, đứng xa rồi zoom.
    public internal(set) var chupTuXa = false
    /// Đã đứng đủ xa (theo ước lượng) cho kiểu chụp từ xa.
    public internal(set) var duXa = false
    /// Ảnh mẫu chụp CHÚC GẮT từ trên xuống — mẫu chiếm quá nhiều khung thì NÂNG MÁY, không lùi ra.
    public internal(set) var mauChucGat = false

    /// Câu của mục này là câu để ĐỌC TO CHO MẪU NGHE.
    public var isModelCue: Bool { criterion.forModel }

    /// Số bước để ghép vào câu. Không ước lượng được thì nói "một chút".
    public func stepsPhrase() -> UiText {
        moveMeters.map { DistanceEstimator.stepsPhrase($0) } ?? uiText("steps_a_little")
    }

    /// Lệch gấp mấy lần ngưỡng đạt. Dùng để chọn mức độ của câu chữ.
    public var severity: Double? {
        guard let d = deviation, let a = band?.accept else { return nil }
        return a <= 0.0 ? nil : d / a
    }
}

/// BỘ CHỌN LỜI NHẮC — mỗi lúc đúng MỘT câu.
///
/// | Luật | Chữa gì |
/// |---|---|
/// | Mỗi lúc 1 câu | đọc 3 câu cùng lúc thì không làm được câu nào |
/// | Câu đã hiện ở lại tối thiểu `cueMinDisplayMs` | chữ nhảy nhanh hơn mắt đọc |
/// | Số trong câu chỉ đổi 1 lần/giây | "xoay 7 độ" thành "xoay 9 độ" rồi "xoay 6 độ" trong một giây |
/// | Đóng băng khi lắc mạnh | đang đưa máy thì mọi số đều vô nghĩa |
public final class CuePresenter {

    private var currentCriterion: Criterion?
    private var currentText: UiText?
    private var shownAtMs: Int64 = 0
    private var numberRefreshedAtMs: Int64 = 0

    public init() {}

    /// - Parameters:
    ///   - failing: các mục đang FAILING, **đã lọc và đã sắp theo thứ tự ưu tiên**.
    ///   - angularSpeedDegPerSec: tốc độ quay của máy, để biết có đang lắc không.
    /// - Returns: câu cần hiện, `nil` = không nhắc gì.
    @discardableResult
    public func update(_ failing: [CriterionStatus], _ nowMs: Int64, _ angularSpeedDegPerSec: Double) -> UiText? {
        // Đang lắc mạnh: giữ nguyên câu đang hiện, không đổi chữ cũng không đổi số.
        if angularSpeedDegPerSec > GuidanceTiming.freezeCueAngularSpeedDegPerSec {
            return currentText
        }

        guard let top = failing.first else {
            currentCriterion = nil
            currentText = nil
            return nil
        }

        let current = currentCriterion
        let heldLongEnough = nowMs - shownAtMs >= GuidanceTiming.cueMinDisplayMs
        let currentStillFailing = failing.contains { $0.criterion == current }

        let chosen: CriterionStatus
        if current == nil {
            chosen = top
        } else if !currentStillFailing {
            // ⚠️ ĐÃ GỠ LUẬT "mục ưu tiên cao hơn chen ngang ngay" (06/09/2026) — trên máy thật nó thành máy sinh
            // nhấp nháy. "Sửa máy trước, sửa mẫu sau" bảo đảm ở `GuidanceEngine`.
            // Mục đang hiện đã hết lệch: nhường chỗ ngay.
            chosen = top
        } else if !heldLongEnough {
            // Vẫn mục cũ, và chưa tới lúc được đổi. (`currentStillFailing` bảo đảm luôn tìm thấy.)
            chosen = failing.first { $0.criterion == current } ?? top
        } else {
            chosen = top
        }

        if chosen.criterion != currentCriterion {
            currentCriterion = chosen.criterion
            currentText = cueTextFor(chosen)
            shownAtMs = nowMs
            numberRefreshedAtMs = nowMs
            return currentText
        }

        // Cùng một mục: chỉ cho phép chữ đổi mỗi giây một lần.
        if nowMs - numberRefreshedAtMs >= GuidanceTiming.cueNumberRefreshMs {
            currentText = cueTextFor(chosen)
            numberRefreshedAtMs = nowMs
        }
        return currentText
    }

    public func reset() {
        currentCriterion = nil
        currentText = nil
        shownAtMs = 0
        numberRefreshedAtMs = 0
    }
}

/// Một chữ số lẻ, luôn dấu chấm, làm tròn KIỂU JAVA `String.format("%.1f")`: lấy dạng thập phân ngắn nhất của số
/// rồi làm tròn nửa lên (2.25 → "2.3"). `String(format:)` của C làm tròn trên giá trị nhị phân, nửa về chẵn
/// (2.25 → "2.2") — lệch Android đúng ở các mức zoom x.25 / x.75.
private func motChuSoLe(_ z: Float) -> String {
    let d = NSDecimalNumber(string: "\(Double(z))", locale: Locale(identifier: "en_US_POSIX"))
    let r = d.rounding(accordingToBehavior: NSDecimalNumberHandler(
        roundingMode: .plain, scale: 1, raiseOnExactness: false, raiseOnOverflow: false,
        raiseOnUnderflow: false, raiseOnDivideByZero: false
    ))
    let s = r.stringValue
    return s.contains(".") ? s : s + ".0"
}

/// "1x", "0.5x" — không kèm số lẻ thừa.
private func nhanZoom(_ z: Float) -> String {
    let r = (z + 0.5).rounded(.down)   // Math.round(Float)
    return z == r ? "\(Int(r))x" : motChuSoLe(z) + "x"
}

/// Mức zoom một chữ số lẻ, luôn dùng dấu chấm ("1.5").
private func mucZoom(_ z: Float) -> String { motChuSoLe(z) }

/// Ảnh mẫu chúc/ngửa gắt từ mức này trở lên thì máy buộc phải đổi độ cao, không chỉ đổi góc.
private let gocGatDeg = 20.0

/// Viết câu nhắc cho một mục.
///
/// ⚠️ Câu về DÁNG và HƯỚNG MẪU viết theo GÓC NHÌN NGƯỜI MẪU (người cầm máy đọc to lên). Câu về VỊ TRÍ MÁY nói
/// trái/phải đúng như người cầm máy nhìn trên màn hình — ở cả ba chế độ (FOOTGUNS 54, 78).
func cueTextFor(_ status: CriterionStatus) -> UiText {
    let signed = status.signedDelta ?? 0.0

    // ⚠️ XÉT TRƯỚC MỌI CÂU KHÁC: không đo được thì KHÔNG CÓ GÌ để sửa — phải nói ra app đang thiếu gì.
    if status.unmeasuredTooLong {
        // Tự chụp cầm tay thì không lùi được — khoảng cách là độ duỗi TAY (video test 19/09/2026).
        let tay = status.tamTay
        let key: String
        switch status.criterion {
        case .perspective:
            key = tay ? "cue_unmeasured_perspective_arm" : "cue_unmeasured_perspective"
        // Ảnh mẫu chúc từ trên cao: thấy thêm người bằng cách NÂNG máy, không phải lùi.
        case .scale:
            if status.mauChucGat && tay { key = "cue_arm_extend_up" }
            else if status.mauChucGat && !status.chupTuXa { key = "cue_raise_to_fit" }
            else if tay { key = "cue_unmeasured_scale_arm" }
            else { key = "cue_unmeasured_scale" }
        case .roll, .center, .elevation:
            key = tay ? "cue_unmeasured_body_arm" : "cue_unmeasured_body"
        case .pitch:
            key = tay ? "cue_unmeasured_pitch_arm" : "cue_unmeasured_pitch"
        case .yaw:
            key = tay ? "cue_unmeasured_yaw_arm" : "cue_unmeasured_yaw"
        case .pose:
            key = "cue_unmeasured_pose"
        // Các mục hậu kỳ không bao giờ vào tới đây.
        default:
            key = tay ? "cue_unmeasured_other_arm" : "cue_unmeasured_other"
        }
        return uiText(key)
    }

    switch status.criterion {
    // HƯỚNG MẪU — CÓ nói chiều. Góc dương = mẫu quay về phía TRÁI của họ; signed > 0 = đang quay quá sang trái →
    // xoay ngược lại về bên phải (phải CỦA MẪU).
    case .yaw:
        let lech = abs(signed)
        // Hình lật gương thì trái/phải của mẫu đổi bên.
        let sangPhai = (signed > 0) != status.latGuong
        let me = status.tuChup
        // Ngược hẳn hướng: nói thẳng là phải quay hẳn người lại.
        if lech > 120.0 { return uiText(me ? "cue_yaw_around_self" : "cue_yaw_around_model") }
        if sangPhai { return uiText(me ? "cue_yaw_right_self" : "cue_yaw_right_model") }
        return uiText(me ? "cue_yaw_left_self" : "cue_yaw_left_model")

    // NGHIÊNG NGANG — độ vẹo đo bằng CẢM BIẾN là chiều VẬT LÝ người cầm máy xoay, không đảo theo camera trước/sau
    // (11/10/2026). ⚠️ LUÔN NÓI VỀ MÁY, không đổ cho mẫu (14/09/2026).
    case .roll:
        return uiText(signed > 0 ? "cue_roll_ccw" : "cue_roll_cw")

    case .perspective:
        // Tầm tay thì không đi lùi khỏi cánh tay mình được.
        if status.tamTay && signed > 0 { return uiText("cue_arm_extend") }
        if status.tamTay { return uiText("cue_arm_retract") }
        if signed > 0 { return uiText("cue_step_back", .text(status.stepsPhrase())) }
        return uiText("cue_step_forward", .text(status.stepsPhrase()))

    // KHUNG HÌNH — tới đây thì chỗ đứng đã đúng (PERSPECTIVE ưu tiên cao hơn), việc còn lại chỉ là zoom.
    case .scale:
        // ẢNH MẪU CHỤP TỪ TRÊN CAO có nhãn kiểu chụp — xem `KieuChupTren`.
        if let zoomToiDa = status.zoomToiDa, status.zoomSai {
            return uiText("cue_zoom_back_to", .string(nhanZoom(zoomToiDa)))
        }
        // Chụp chúc từ trên cao mà mẫu quá to trong khung: máy đang quá THẤP.
        if status.mauChucGat && signed > 0 && !status.chupTuXa && !status.tamTay { return uiText("cue_raise_to_fit") }
        // Tự chụp từ trên cao: cùng việc đó nhưng bằng cánh tay.
        if status.mauChucGat && signed > 0 && status.tamTay { return uiText("cue_arm_extend_up") }
        if status.zoomToiDa != nil && signed > 0 { return uiText("cue_step_back", .text(status.stepsPhrase())) }
        if status.zoomToiDa != nil && status.coGocRong { return uiText("cue_close_in_wide", .text(status.stepsPhrase())) }
        if status.zoomToiDa != nil { return uiText("cue_close_in_1x", .text(status.stepsPhrase())) }
        // Đặt máy tự chụp: camera trước gần như không zoom — chỉnh cỡ bằng bước chân.
        if status.datMay && signed > 0 { return uiText("cue_step_back", .text(status.stepsPhrase())) }
        if status.datMay { return uiText("cue_step_forward", .text(status.stepsPhrase())) }
        if status.chupTuXa && !status.duXa { return uiText("cue_far_back_then_zoom", .text(status.stepsPhrase())) }
        if status.chupTuXa, let targetZoom = status.targetZoom {
            return uiText("cue_zoom_set", .string(mucZoom(targetZoom)))
        }
        // Tầm tay: không có bước chân, và camera trước thường không zoom được.
        if status.tamTay && signed > 0 { return uiText("cue_arm_extend") }
        if status.tamTay { return uiText("cue_arm_retract") }
        // ẢNH CHÂN DUNG — app KHÔNG kiểm được zoom ở lớp này: đưa CẢ HAI lựa chọn, KHÔNG thiên vị bên nào.
        if status.walkInsteadOfZoom {
            return signed > 0
                ? uiText("cue_back_or_zoom_out", .text(status.stepsPhrase()))
                : uiText("cue_forward_or_zoom_in", .text(status.stepsPhrase()))
        }
        if let targetZoom = status.targetZoom { return uiText("cue_zoom_set", .string(mucZoom(targetZoom))) }
        return uiText(signed > 0 ? "cue_zoom_out" : "cue_zoom_in")

    // ⚠️ KHÔNG ĐẢO CHIỀU Ở BẤT KỲ CHẾ ĐỘ NÀO: dịch máy về phía bên phải khung → cảnh chạy sang trái. Camera trước
    // đảo hai lần, triệt tiêu. Gương là cảnh tĩnh. Trái là trái, phải là phải, như bạn nhìn trên màn hình.
    case .center:
        // Đặt máy: người đang lệch sang PHẢI màn hình so với ảnh mẫu → bước sang trái.
        if status.datMay { return uiText(signed > 0 ? "cue_step_left" : "cue_step_right") }
        return uiText(signed > 0 ? "cue_move_right" : "cue_move_left")

    // MỤC 3 — GÓC NHÌN, ĐỘ. signed > 0 = tia của ta đang ngẩng hơn ảnh mẫu → máy THẤP hơn cần thiết → nâng lên.
    // ⚠️ NÓI CẢ HAI ĐỘNG TÁC TRONG MỘT CÂU khi gộp với mục 4 (12/09/2026, FOOTGUNS 62).
    case .elevation:
        let key: String
        if status.datMay && status.kemChuc && signed > 0 { key = "cue_place_higher_tilt_down" }
        else if status.datMay && status.kemChuc { key = "cue_place_lower_tilt_up" }
        else if status.datMay && signed > 0 { key = "cue_place_higher" }
        else if status.datMay { key = "cue_place_lower" }
        // Gộp với mục ngửa/chúc: một động tác liền, đúng cách người chụp làm.
        else if status.kemChuc && signed > 0 { key = "cue_raise_tilt_down" }
        else if status.kemChuc { key = "cue_lower_tilt_up" }
        // Chỉ lệch độ cao, góc chúc đã đúng: giữ nguyên góc mà dời máy.
        else if signed > 0 { key = "cue_raise_keep_angle" }
        else { key = "cue_lower_keep_angle" }
        return uiText(key)

    // MỤC 4 — TINH CHỈNH. pitchCue dương = máy đang hất lên.
    // ⚠️ ẢNH MẪU GÓC GẮT MÀ KHÔNG CÓ MỤC MÁY CAO/THẤP (14/09/2026): chúc gắt tới −20° trở xuống thì máy BẮT BUỘC
    // phải ở trên cao — nói luôn cả động tác nâng máy. Ngửa gắt thì ngược lại.
    case .pitch:
        let g = status.gocMauKhongCoCaoThap
        if let g, g <= -gocGatDeg && signed > 0 { return uiText("cue_raise_tilt_down") }
        if let g, g >= gocGatDeg && signed < 0 { return uiText("cue_lower_tilt_up") }
        return uiText(signed > 0 ? "cue_tilt_down_more" : "cue_tilt_up_more")

    // Mục cuối cùng và nhẹ nhất. Câu chi tiết theo KHỚP lệch nhất; không có thì lùi về câu chung.
    case .pose:
        if let hint = status.poseHint {
            return (status.latGuong ? hint.mirrored() : hint).text(status.tuChup)
        }
        return uiText(status.tuChup ? "cue_pose_generic_self" : "cue_pose_generic_model")

    // Ba mục hậu kỳ không bao giờ tới được đây.
    case .sharpness, .crop, .eyesOpen:
        return .raw("")
    }
}
