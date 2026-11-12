// Port từ `KT/guidance/GuidanceConfig.kt`: Band, GuidanceConfig, GuidanceTiming.
//
// BẢNG NGƯỠNG VÀ MỐC THỜI GIAN CỦA ENGINE HƯỚNG DẪN.
//
// ⚠️ ĐÂY LÀ CHỖ DUY NHẤT chứa các con số "lệch bao nhiêu thì coi là ĐẠT". Buổi đo trên máy thật chỉ sửa file này.
//
// ⚠️ PHÂN BIỆT VỚI `Criterion.reference`:
// | | Là gì | Dùng ở đâu |
// |---|---|---|
// | `Criterion.reference` | "lệch bao nhiêu thì coi như SAI HOÀN TOÀN" | chấm điểm |
// | `Band.accept` ở đây | "lệch bao nhiêu thì coi là ĐÃ ĐẠT" | hướng dẫn realtime |
//
// ⚠️⚠️ PHẦN LỚN SỐ TRONG FILE NÀY CHƯA TỪNG ĐƯỢC ĐO TRÊN MÁY THẬT. Luật dự án: `accept` ≥ 3 lần độ lệch chuẩn đo
// khi người đứng yên 20 giây, cho cả 5 lớp khung hình. Giữ NGUYÊN số của Android — đổi phải đổi hai bên.

/// Vùng trễ 3 mức của một tiêu chí. Một ngưỡng thì người đứng ngay ranh giới thấy tích **nhấp nháy**; ba mức
/// tạo vùng đệm — vào thì khó, ra cũng khó.
public struct Band: Equatable, Sendable {
    /// Trong mức này = ĐẠT. Im lặng, tính vào cổng chụp.
    public let accept: Double
    /// Phải vượt mức này mới BẮT ĐẦU nhắc. Giữa `accept` và `enter` là vùng xám.
    public let enter: Double
    /// Mục đã đạt chỉ bị MỞ KHOÁ khi vượt mức này.
    public let unlock: Double
    /// Lượng phải sửa nhỏ hơn mức này thì IM — bảo người ta "lùi lại 4 phân" là câu vô nghĩa.
    public let actionFloor: Double

    public init(accept: Double, enter: Double, unlock: Double, actionFloor: Double) {
        self.accept = accept
        self.enter = enter
        self.unlock = unlock
        self.actionFloor = actionFloor
    }
}

public enum GuidanceConfig {

    /// Hai hệ số sinh `Band.enter` và `Band.unlock` từ `Band.accept` — buổi đo đổi `accept` thì vùng trễ tự giãn.
    private static let enterFactor = 1.5
    private static let unlockFactor = 3.0

    /// BẢNG NGƯỠNG THEO LỚP KHUNG HÌNH — tài liệu v3 mục 5. `nil` = mục này không đổi theo lớp, rơi xuống
    /// `acceptFor`.
    ///
    /// ⚠️ Mục 3 và 4 NỚI RỘNG, không còn siết theo lớp (14/09/2026): phía ảnh mẫu là SUY ĐOÁN, sai số cỡ 10°;
    /// ngưỡng hẹp hơn sai số của chính phép đo thì người dùng đuổi theo nhiễu mãi.
    private static func theoLop(_ criterion: Criterion, _ f: FramingClass) -> Double? {
        switch criterion {
        case .yaw:
            switch f {
            case .full, .knee, .half: 30.0
            case .chest: 20.0
            case .head: 15.0
            }
        case .scale:
            switch f {
            case .full, .knee, .half: 0.10
            case .chest: 0.08
            case .head: 0.06
            }
        case .pitch: 12.0
        case .elevation: 10.0
        case .center:
            switch f {
            case .full, .knee, .half: 0.05
            case .chest: 0.04
            case .head: 0.03
            }
        default: nil
        }
    }

    /// Ngưỡng ĐẠT của từng mục, theo ĐÚNG đơn vị tầng đo đạc trả về.
    ///
    /// ⚠️ Giữ đúng thứ tự `theoLop(...) ?? bảng chung` như Kotlin: nhánh ELEVATION 6,0 và PITCH 0,105 bên dưới bị
    /// `theoLop` che, không bao giờ chạy — giữ để đối chiếu lịch sử.
    private static func acceptFor(_ criterion: Criterion, _ framing: FramingClass, _ templateScale: Double?) -> Double? {
        if let v = theoLop(criterion, framing) { return v }
        switch criterion {
        // Độ. Phép đo suy từ tỉ lệ vai/thân sai số 8-10 độ.
        case .yaw: return 30.0
        // Tỉ lệ tương đối |live - mẫu| / mẫu (10%).
        case .scale: return 0.10
        // Phần bề ngang khung hình (5%).
        case .center: return 0.05
        // ĐỘ (đổi đơn vị 12/09/2026). ⚠️ Bị `theoLop` che.
        case .elevation: return 6.0
        // ⚠️ SUY LUẬN, không quy đổi được. ⚠️ Bị `theoLop` che.
        case .pitch: return 0.105
        // Nới từ 3,0 lên 6,0 (12/09/2026): nhiễu TAY CẦM khác hẳn nhiễu tripod (0,92°).
        case .roll: return 6.0
        // ĐÃ ĐO trên 13 ảnh thật: nhiễu ~0,029 / ~0,034 → lấy 0,10 theo cặp yếu hơn.
        case .perspective: return 0.10
        // Độ, trung bình lệch góc các khớp.
        case .pose: return 15.0
        // Hậu kỳ không bao giờ vào hướng dẫn realtime.
        case .sharpness, .crop, .eyesOpen: return nil
        }
    }

    /// Lượng sửa tối thiểu đáng mở miệng nhắc, cùng đơn vị với `acceptFor`.
    private static func actionFloorFor(_ criterion: Criterion, _ framing: FramingClass, _ templateScale: Double?) -> Double {
        switch criterion {
        case .yaw: 15.0
        // Sàn theo lớp (tài liệu v3: 0,35m / 0,30m / 0,12m / 0,08m), quy về phần chiều cao mẫu.
        case .scale:
            switch framing {
            case .full, .knee: 0.05
            case .half: 0.045
            case .chest: 0.03
            case .head: 0.02
            }
        case .center: 0.02
        // Độ. Dưới mức này thì nâng hay hạ máy cũng không ai thấy ảnh khác đi.
        case .elevation: 4.0
        case .pitch: 0.06
        // Dưới 2 độ thì xoay tay cũng không chỉnh nổi.
        case .roll: 2.0
        case .perspective: 0.05
        case .pose: 12.0
        default: 0.0
        }
    }

    /// Ngưỡng mục 4 khi đo bằng ĐƯỜNG CHÂN — tỉ lệ không đơn vị, giữ từ bản cũ.
    public static let pitchLegsAccept = 0.105

    /// (Không còn dùng — giữ lại để đối chiếu lịch sử.) Ngưỡng mục 4 khi đo bằng trục thân 3D, ĐỘ.
    public static let pitchSpineAcceptDeg = 5.0

    /// (Không còn dùng.) Ngưỡng mục 4 khi đo bằng khung mặt / bề rộng vai — đường đo đã gỡ 12/09/2026.
    public static let pitchFaceAccept = 0.31

    /// Vùng trễ của một mục với một ảnh mẫu cụ thể.
    ///
    /// - Parameters:
    ///   - templateScale: `scale` đo được từ ẢNH MẪU.
    ///   - pitchSource: đường đo đã dùng cho mục NGỬA/CHÚC. ⚠️ Bắt buộc với mục đó.
    /// - Returns: `nil` = mục này không hướng dẫn realtime được.
    public static func bandFor(
        _ criterion: Criterion,
        _ framing: FramingClass,
        _ templateScale: Double?,
        _ pitchSource: PitchSource? = nil
    ) -> Band? {
        guard let base = acceptFor(criterion, framing, templateScale) else { return nil }
        // Mục 4: đường ra ĐỘ dùng bảng theo lớp; riêng đường CHÂN là tỉ lệ không đơn vị nên giữ ngưỡng riêng.
        let accept: Double
        if criterion != .pitch {
            accept = base
        } else if pitchSource == .legs {
            accept = pitchLegsAccept
        } else {
            accept = base
        }
        return Band(
            accept: accept,
            enter: accept * enterFactor,
            unlock: accept * unlockFactor,
            // Mục 4 ra ĐỘ ở đường chính nên sàn cũng bằng độ; đường chân giữ sàn cũ.
            actionFloor: criterion == .pitch && pitchSource != .legs
                ? 3.0
                : actionFloorFor(criterion, framing, templateScale)
        )
    }
}

/// MỐC THỜI GIAN — giải đúng một loại lỗi: **app phản ứng nhanh hơn con người**.
///
/// Nhóm này KHÔNG phụ thuộc thiết bị mà phụ thuộc tốc độ phản xạ của con người — buổi đo không đổi được chúng.
public enum GuidanceTiming {
    /// Vi phạm phải kéo dài ngần này mới hiện lời nhắc. Chặn nhiễu một khung.
    public static let cueEnterHoldMs: Int64 = 450

    /// Đạt phải giữ ngần này mới tắt lời nhắc và đóng tích.
    public static let cueExitHoldMs: Int64 = 200

    /// Lời nhắc đã hiện phải ở lại ngần này. ⚠️ Nâng từ 1,2s lên 2,0s (06/09/2026): đủ để ĐỌC nhưng không đủ để
    /// LÀM THEO.
    public static let cueMinDisplayMs: Int64 = 2_000

    /// Con số trong lời nhắc chỉ đổi mỗi giây một lần.
    public static let cueNumberRefreshMs: Int64 = 1_000

    /// Đủ mọi mục rồi còn phải giữ yên ngần này mới coi là ổn định.
    public static let dwellMs: Int64 = 800

    /// Chống kẹt: quá ngần này thì mở khoá, nhắc lại. Thiếu là *"app đứng im mà không ai hiểu vì sao"*.
    public static let stallTimeoutMs: Int64 = 2_500

    /// Lắc nhanh hơn mức này thì không tính là đang giữ ổn định.
    public static let maxAngularSpeedDegPerSec = 15.0

    /// Lắc nhanh hơn mức này thì ĐÓNG BĂNG lời nhắc đang hiện.
    public static let freezeCueAngularSpeedDegPerSec = 45.0

    /// Phải đo được ngần này khung liên tiếp mới bắt đầu tin số đo.
    public static let minValidFrames = 3
}
