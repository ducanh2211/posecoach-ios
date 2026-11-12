// Port từ `KT/guidance/CriterionGate.kt`.

/// Trạng thái hiển thị của một mục trong danh sách điều kiện.
///
/// ⚠️ `unmeasured` KHÔNG phải "chưa đạt" — luật số 4: không đo được khác với sai.
public enum GateState: CaseIterable, Sendable {
    /// Chưa đo được ở khung hình này. Hiện dấu gạch, không phải dấu X.
    case unmeasured
    /// Đang lệch quá nhiều và đã lệch đủ lâu. Mục sinh ra lời nhắc.
    case failing
    /// Vùng đệm: tốt hơn mức đáng nhắc nhưng chưa đủ tốt để công nhận. Tồn tại **chỉ để chống nhấp nháy**.
    case grey
    /// ĐẠT. Hiện dấu tích.
    case passing
}

/// CỔNG TRẠNG THÁI CỦA MỘT TIÊU CHÍ — vùng trễ 3 mức, có chống rung và chống kẹt.
///
/// | Cơ chế | Thiếu nó thì |
/// |---|---|
/// | Vùng trễ 3 mức | tích nhấp nháy khi đứng ngay ranh giới |
/// | Chờ đủ lâu mới đổi (debounce) | một khung hình nhiễu cũng lật trạng thái |
/// | Khoá mục đã đạt | đã đạt rồi vẫn tuột vì rung tay |
/// | Chống kẹt (stall) | **app đứng im vĩnh viễn** |
public final class CriterionGate {

    public let criterion: Criterion

    public private(set) var state: GateState = .unmeasured

    /// Đã đạt và đang được giữ khoá. Chỉ mở khi lệch quá `Band.unlock` hoặc bị kẹt quá lâu.
    public private(set) var locked = false

    /// Vừa bị mở khoá vì kẹt — vùng xám cũng bị coi là FAILING để **nhắc lại**.
    private var stalled = false

    /// Mốc bắt đầu chuỗi "không đo được" hiện tại. `nil` = đang đo được.
    ///
    /// ⚠️ Ảnh mẫu bật mục zoom, người cầm máy lấy khung chặt hơn → đầu gối ra ngoài khung → mục nằm im ở dấu gạch
    /// VĨNH VIỄN. Đủ lâu thì phải nói ra (quy tắc số 7).
    private var unmeasuredSinceMs: Int64?

    private var belowAcceptSince: Int64?
    private var aboveEnterSince: Int64?
    private var greySince: Int64?

    /// Mốc bắt đầu chuỗi "lệch nhỏ hơn mức chỉnh được". Xem `Band.actionFloor`.
    private var duoiSanSince: Int64?

    public init(_ criterion: Criterion) {
        self.criterion = criterion
    }

    /// Đã "không đo được" đủ lâu để cần giải thích cho người dùng chưa.
    public func unmeasuredTooLong(_ nowMs: Int64) -> Bool {
        guard let since = unmeasuredSinceMs else { return false }
        return nowMs - since >= GuidanceTiming.stallTimeoutMs
    }

    /// Nạp số đo của một khung hình.
    ///
    /// - Parameters:
    ///   - deviation: độ lệch TUYỆT ĐỐI so với ảnh mẫu, cùng đơn vị với `band`. `nil` = khung này không đo được.
    ///   - nowMs: mốc thời gian của khung hình, mili giây.
    @discardableResult
    public func update(_ deviation: Double?, _ band: Band, _ nowMs: Int64) -> GateState {
        guard let deviation else {
            // Không đo được: dừng mọi đồng hồ, KHÔNG coi là sai. Mục đã khoá thì giữ nguyên tích.
            belowAcceptSince = nil
            aboveEnterSince = nil
            greySince = nil
            duoiSanSince = nil
            // Đếm giờ để biết khi nào cần GIẢI THÍCH. Mục đã khoá thì không đếm.
            if !locked && unmeasuredSinceMs == nil { unmeasuredSinceMs = nowMs }
            state = locked ? .passing : .unmeasured
            return state
        }

        // Đo được rồi thì xoá đồng hồ giải thích.
        unmeasuredSinceMs = nil

        // ⚠️ LỆCH NHỎ HƠN MỨC CHỈNH ĐƯỢC THÌ CHO QUA (10/10/2026, PO duyệt phương án A). Chưa vào ngưỡng đạt thì
        // không tích, mà phần phải sửa nhỏ hơn `actionFloor` thì engine KHÔNG nhắc — đứng ở giữa là app im mãi.
        // Giữ đủ lâu thì tính là ĐẠT (FOOTGUNS 109).
        let duoiSan = deviation > band.accept && deviation - band.accept < band.actionFloor

        if locked {
            if deviation > band.unlock {
                // Lệch hẳn ra ngoài: mở khoá, xét lại từ đầu ngay trong lượt này.
                locked = false
                greySince = nil
            } else if deviation > band.enter && !duoiSan {
                // ⚠️ TRÔI QUÁ MỨC ĐÁNG NHẮC mới tính là kẹt — so với `enter`, KHÔNG so với `accept` (FOOTGUNS
                // 52–53). Khoảng giữa hai mức là vùng đệm chống nhấp nháy, cầm máy trên tay thì số đo nằm trong
                // đó gần như thường trực.
                let since = greySince ?? nowMs
                greySince = since
                if nowMs - since >= GuidanceTiming.stallTimeoutMs {
                    locked = false
                    stalled = true
                    greySince = nil
                } else {
                    state = .passing
                    return state
                }
            } else {
                // Trong vùng đệm hoặc vẫn trong ngưỡng đạt: GIỮ NGUYÊN TÍCH, không đếm giờ.
                greySince = nil
                state = .passing
                return state
            }
        }

        if duoiSan {
            let since = duoiSanSince ?? nowMs
            duoiSanSince = since
            if nowMs - since >= GuidanceTiming.stallTimeoutMs {
                locked = true
                stalled = false
                belowAcceptSince = nil
                aboveEnterSince = nil
                greySince = nil
                duoiSanSince = nil
                state = .passing
                return state
            }
        } else {
            duoiSanSince = nil
        }

        if deviation <= band.accept {
            aboveEnterSince = nil
            greySince = nil
            stalled = false
            let since = belowAcceptSince ?? nowMs
            belowAcceptSince = since
            if nowMs - since >= GuidanceTiming.cueExitHoldMs {
                locked = true
                state = .passing
            } else {
                // Đã tốt nhưng chưa giữ đủ lâu để công nhận.
                state = .grey
            }
        } else if deviation > band.enter {
            belowAcceptSince = nil
            greySince = nil
            let since = aboveEnterSince ?? nowMs
            aboveEnterSince = since
            // ⚠️ Vừa mở khoá vì kẹt thì nhắc NGAY — nó đã trôi suốt khoảng chống kẹt rồi.
            if stalled || nowMs - since >= GuidanceTiming.cueEnterHoldMs {
                state = .failing
            } else {
                // Chưa lệch đủ lâu — có thể chỉ là một khung nhiễu.
                state = .grey
            }
        } else {
            // Vùng xám thật sự — CHƯA khoá. ⚠️ ĐÂY mới là chỗ app có thể đứng im vĩnh viễn: không sinh câu nhắc
            // nào, cũng không bao giờ đóng tích. Nằm quá lâu thì phải nhắc.
            belowAcceptSince = nil
            aboveEnterSince = nil
            let since = greySince ?? nowMs
            greySince = since
            if stalled || nowMs - since >= GuidanceTiming.stallTimeoutMs {
                stalled = true
                state = .failing
            } else {
                state = .grey
            }
        }
        return state
    }

    /// Về trạng thái ban đầu. Gọi khi đổi ảnh mẫu hoặc vào lại màn hình.
    public func reset() {
        state = .unmeasured
        unmeasuredSinceMs = nil
        locked = false
        stalled = false
        belowAcceptSince = nil
        aboveEnterSince = nil
        greySince = nil
        duoiSanSince = nil
    }
}
