import Foundation

/// Quy trình hướng dẫn cố định. Bước sau không được chen lên trước bước đang làm (FOOTGUNS 92).
/// Thứ tự khai báo = thứ tự bước (tương đương `ordinal` của Kotlin).
enum GuidanceStep: CaseIterable, Sendable {
    case machineLevel
    case distance
    case cameraAngle
    case zoom
    case composition
    case modelDirection
    case pose
}

func guidanceStepOf(_ criterion: Criterion) -> GuidanceStep {
    switch criterion {
    case .roll: return .machineLevel
    case .perspective: return .distance
    case .elevation, .pitch: return .cameraAngle
    case .scale: return .zoom
    case .center: return .composition
    case .yaw: return .modelDirection
    case .pose: return .pose
    default: return .composition
    }
}

/// Kết quả hướng dẫn của MỘT khung hình.
public struct GuidanceResult: Sendable {
    /// Trạng thái từng mục, đã sắp theo thứ tự ưu tiên. Đây là thứ vẽ ra danh sách tích.
    public let statuses: [CriterionStatus]
    /// Câu nhắc đang hiện. `nil` = không nhắc gì.
    public let cue: UiText?
    /// Cảnh báo về CÁCH CẦM MÁY, không phải về chỗ đứng — những thứ làm **mọi phép đo phía sau mất nghĩa**.
    public let prepWarning: UiText?
    /// Đủ điều kiện để bấm quay chưa.
    public let readyToCapture: Bool
    /// Đã giữ ổn định được bao lâu, mili giây. Dùng để vẽ vòng đếm ngược.
    public let stableForMs: Int64
    /// Câu đang hiện là câu để **ĐỌC TO CHO MẪU NGHE**. Giao diện dùng cờ này để đổi biểu tượng.
    public var cueForModel = false
    /// ĐỘ GIỐNG ẢNH MẪU NGAY LÚC NÀY, 0..100. `nil` = chưa đo được gì.
    ///
    /// ⚠️ Dùng **đúng hàm chấm điểm** của bước chọn ảnh (`ShotScorer.score`) — bất biến số 1 (FOOTGUNS 53).
    public var matchPercent: Int? = nil
    /// Đã đủ giống để bắt đầu chuẩn bị tạo dáng chưa.
    public var readyToPose = false
    /// Mọi mục đang làm dở đều đã vào VÙNG ĐỆM (lệch ≤ ngưỡng nhắc) — mới được nói "gần đúng".
    public var almost = false
    /// Đã xong mọi bước về GÓC MÁY — tới lượt đặt người vào lưới. Giao diện chỉ hiện mốc trên lưới từ lúc này
    /// (PO 11/10/2026): hiện sớm thì người dùng chúc/ngửa máy để đưa người vào vạch, phá đúng bước góc máy.
    public var denBoCuc = false

    public var allPassed: Bool { !statuses.isEmpty && statuses.allSatisfy(resolvedForCapture) }
}

/// Dáng là mục hướng dẫn cuối, không được chặn việc chụp.
func resolvedForCapture(_ status: CriterionStatus) -> Bool {
    status.criterion == .pose || (!status.pending && (status.state == .passing || status.skipped))
}

/// ENGINE HƯỚNG DẪN. Port từ `KT/guidance/GuidanceEngine.kt`.
///
/// Nối tầng đo đạc → `CriterionGate` (khoá/mở) → `CuePresenter` (chọn câu). Bản thân nó **không đo gì cả**.
///
/// ⚠️ BẤT BIẾN SỐ 1: độ lệch lấy từ `ShotScorer.deviation` — **đúng hàm mà bước chấm điểm dùng**.
///
/// ⚠️ Engine đọc `TemplateProfile` để biết **mục nào áp dụng** — ảnh chân dung cận không có mục nào về chân ngay
/// từ hồ sơ, không phải nhờ lọc ở tầng chữ.
public final class GuidanceEngine {

    private let profile: TemplateProfile

    /// Chỉ những mục ảnh mẫu này áp dụng, và chỉ những mục hướng dẫn được realtime — sắp theo (bước, mục).
    private let applicable: [Criterion]

    /// Các bước, mỗi bước một nhóm mục, theo thứ tự bước.
    private let steps: [[Criterion]]

    /// Vị trí bước bố cục trong `steps`; không có bước nào từ bố cục trở đi = cuối danh sách.
    private let boCucIndex: Int

    private var currentStepIndex = 0
    private var currentStepSinceMs: Int64?
    private var skipped = Set<Criterion>()

    private let gates: [Criterion: CriterionGate]

    private let presenter = CuePresenter()

    /// Đếm số khung liên tiếp đo được. Chưa đủ thì chưa tin số đo.
    private var validFrames = 0

    /// Mốc bắt đầu đạt đủ mọi điều kiện. `nil` = đang chưa đạt.
    private var allGoodSinceMs: Int64?

    /// Mốc bắt đầu hiện một câu dành cho MẪU. Trong `modelCueFreezeMs` kể từ mốc này, các mục về MÁY bị
    /// **đóng băng** — lúc quay sang nói với mẫu, người cầm máy hạ máy xuống, mọi mục về máy tuột ngay.
    private var modelCueSinceMs: Int64?

    /// Lần đầu máy đứng yên. `nil` = chưa yên lần nào kể từ khi mở màn chụp.
    private var daYenLanDauMs: Int64?

    public init(_ profile: TemplateProfile) {
        self.profile = profile
        let order = { (c: Criterion) in
            (GuidanceStep.allCases.firstIndex(of: guidanceStepOf(c))!, Criterion.allCases.firstIndex(of: c)!)
        }
        let applicable = profile.activeFor(.guidance).sorted { order($0) < order($1) }
        self.applicable = applicable

        // `applicable` đã sắp theo bước nên gộp các mục liền nhau cùng bước.
        var steps: [[Criterion]] = []
        for c in applicable {
            if let last = steps.last?.first, guidanceStepOf(last) == guidanceStepOf(c) {
                steps[steps.count - 1].append(c)
            } else {
                steps.append([c])
            }
        }
        self.steps = steps

        let composition = GuidanceStep.allCases.firstIndex(of: .composition)!
        boCucIndex = steps.firstIndex {
            GuidanceStep.allCases.firstIndex(of: guidanceStepOf($0[0]))! >= composition
        } ?? steps.count

        gates = Dictionary(uniqueKeysWithValues: applicable.map { ($0, CriterionGate($0)) })
    }

    /// Nạp một khung hình.
    ///
    /// - Parameters:
    ///   - live: số đo khung hình camera, đã đi qua **cùng hàm đo** với ảnh mẫu. `nil` = chưa thấy người.
    ///   - nowMs: mốc thời gian của khung hình.
    ///   - angularSpeedDegPerSec: tốc độ quay của máy, từ con quay hồi chuyển.
    ///   - prepWarning: cảnh báo cầm máy (xoay ngang, đang zoom). `nil` = ổn.
    ///   - zoomRatio: mức zoom hiện tại của camera — để ước lượng khoảng cách ra MÉT.
    ///   - deviceRollDeg: độ vẹo của MÁY theo cảm biến trọng lực, độ. `nil` = không có cảm biến.
    ///   - devicePitchDeg: góc ngẩng của máy theo cảm biến, độ — biết khi nào cảm biến vẹo mất tin cậy
    ///     (`deviceRollTrustPitchDeg`).
    ///   - mode: ai cầm máy, hình có lật gương không. Chỉ đổi CÂU CHỮ, không đụng phép đo.
    ///   - templateFrame: khung xương thô của ảnh mẫu — chỉ để viết câu nhắc dáng theo từng khớp.
    ///   - liveFrame: khung xương thô của khung hình, như trên.
    ///   - allowSkip: chế độ tự động được phép bỏ qua một bước không hội tụ để tránh kẹt vô hạn.
    ///   - vFovDeg: góc mở dọc đang dùng, độ — để ước lượng khoảng cách theo ống kính thật.
    ///   - zoomMin: mức zoom nhỏ nhất máy làm được — máy không có ống góc rộng thì > 0,5.
    @discardableResult
    public func update(
        _ live: PoseMeasurement?,
        _ nowMs: Int64,
        _ angularSpeedDegPerSec: Double,
        prepWarning: UiText? = nil,
        zoomRatio: Float = 1,
        deviceRollDeg: Double? = nil,
        devicePitchDeg: Double? = nil,
        mode: ShootMode = .nguoiKhac,
        templateFrame: PoseFrame? = nil,
        liveFrame: PoseFrame? = nil,
        minVis: Float = 0.5,
        allowSkip: Bool = false,
        vFovDeg: Double? = nil,
        zoomMin: Float = 0.5
    ) -> GuidanceResult {
        // Chưa thấy người: xoá đồng hồ ổn định, nhưng KHÔNG reset các cổng — mất dấu một lúc rồi bắt lại được
        // thì không nên bắt người ta làm lại từ đầu.
        guard let live else {
            validFrames = 0
            allGoodSinceMs = nil
            currentStepSinceMs = nil
            let statuses = applicable.map { c in
                CriterionStatus(
                    criterion: c, state: gates[c]!.state == .passing ? .passing : .unmeasured,
                    deviation: nil, signedDelta: nil, band: bandOf(c)
                )
            }
            // Mất dấu người một lúc không làm mốc lưới tắt rồi bật lại.
            return GuidanceResult(
                statuses: statuses, cue: nil, prepWarning: prepWarning, readyToCapture: false, stableForMs: 0,
                denBoCuc: currentStepIndex >= boCucIndex
            )
        }

        if validFrames < GuidanceTiming.minValidFrames { validFrames += 1 }

        let dev = ShotScorer.deviation(profile.measurement, live)

        // Điểm giống mẫu NGAY LÚC NÀY — cùng hàm với bước chấm ảnh sau khi quay. Truyền ngưỡng ĐẠT vào để điểm
        // ăn khớp với dấu tích: mọi mục xanh thì điểm phải ≥ 90 (`ShotScorer.vungDat`).
        let total = ShotScorer.score(
            profile, live, .guidance,
            acceptOf: { c in self.bandOf(c, dev.pitchSource)?.accept }
        ).total
        let match: Int? = total.isFinite ? min(max(Int(total), 0), 100) : nil
        let t = profile.measurement

        // Cảm biến còn tin được không, rồi mới hỏi nó lỗi nằm ở đâu.
        let tiltTrusted = devicePitchDeg.map { abs($0) < Self.deviceRollTrustPitchDeg } ?? false
        let rollFromDevice: Bool
        if tiltTrusted, let deviceRollDeg {
            rollFromDevice = abs(deviceRollDeg) >= Self.deviceRollBlameDeg
        } else {
            rollFromDevice = true
        }

        // ⚠️ KIỂU CHỤP TỪ TRÊN CAO (19/09/2026) — chỉ ảnh người khác chụp có nhãn này, và chỉ đổi mục khung hình
        // (zoom/khoảng cách). Xem `KieuChupTren`.
        let kieuTren = mode == .nguoiKhac ? profile.kieuChupTren : nil
        // Đứng gần: zoom tự do từ mức nhỏ nhất của máy tới 1x. Chỉ sai khi zoom VÀO quá 1x.
        let zoomToiDa = kieuTren?.zoomToiDa
        let zoomSai = zoomToiDa.map { zoomRatio > $0 + Self.zoomLechToiDa } ?? false
        let duXa = kieuTren == .xaZoom && (
            DistanceEstimator.estimate(
                live.scale, live.anchorHeightMeters, zoomRatio,
                heSo: DistanceEstimator.heSoOngKinh(vFovDeg, zoomRatio)
            ) ?? 0.0
        ) >= DistanceEstimator.minStandoffMeters(profile.framing)

        var statuses = applicable.map { c -> CriterionStatus in
            // ⚠️ Mục ngửa/chúc lấy ngưỡng THEO ĐÚNG đường đo đã dùng cho khung này.
            let band = bandOf(c, c == .pitch ? dev.pitchSource : nil)
            let deviation: Double?
            switch c {
            case .yaw: deviation = dev.yawDeg
            // Sai mức zoom bắt buộc thì cỡ người có khớp cũng là ảnh khác hẳn — coi như lệch quá ngưỡng mở khoá.
            case .scale:
                if zoomSai, let band { deviation = band.unlock + band.accept } else { deviation = dev.scaleRatio }
            case .center: deviation = dev.centerX
            case .elevation: deviation = dev.elevationDeg
            // ⚠️ CẦM MÁY THẲNG — ĐO BẰNG CẢM BIẾN (11/10/2026, PO chốt). Máy gần nằm ngang mặt đất (chúc/ngửa ≥ 60°)
            // thì cảm biến vẹo là nhiễu — không đo được thì KHÔNG chặn (quy tắc số 4): coi như thẳng.
            case .roll:
                if tiltTrusted, let deviceRollDeg { deviation = abs(deviceRollDeg) } else { deviation = 0.0 }
            case .pitch: deviation = dev.pitchCue
            // ⚠️ ĐÃ LÙI ĐỦ XA THÌ THÔI BẮT LÙI (14/09/2026, FOOTGUNS 84) — phần còn lại để zoom lo.
            case .perspective:
                if let d = dev.perspective {
                    let muonLui = (signedDelta(c, t, live) ?? 0.0) > 0.0
                    let dangCach = DistanceEstimator.estimate(
                        live.scale, live.anchorHeightMeters, zoomRatio,
                        heSo: DistanceEstimator.heSoOngKinh(vFovDeg, zoomRatio)
                    )
                    if muonLui, let dangCach, dangCach >= DistanceEstimator.minStandoffMeters(profile.framing) {
                        deviation = 0.0
                    } else {
                        deviation = d
                    }
                } else {
                    deviation = nil
                }
            case .pose: deviation = dev.poseDeg
            default: deviation = nil
            }
            // Chưa đủ khung liên tiếp thì coi như chưa đo được: ba khung đầu sau khi bắt được người nhiễu mạnh.
            let trusted = validFrames >= GuidanceTiming.minValidFrames ? deviation : nil
            let state: GateState = band.map { gates[c]!.update(trusted, $0, nowMs) } ?? .unmeasured

            return CriterionStatus(
                criterion: c,
                state: state,
                deviation: trusted,
                signedDelta: signedDelta(c, t, live, tiltTrusted ? deviceRollDeg : nil),
                band: band,
                moveMeters: moveMetersFor(
                    c, t, live, zoomRatio, vFovDeg,
                    zoomToiDa.map { min(max(zoomRatio, min(zoomMin, $0)), $0) }
                ),
                // Không có bước khoảng cách (ảnh cận, chân chĩa vào máy, ảnh mẫu góc gắt) thì app không biết người
                // dùng đứng sai chỗ hay zoom sai — đưa cả hai lựa chọn.
                walkInsteadOfZoom: c == .scale && !applicable.contains(.perspective),
                poseHint: c == .pose && templateFrame != nil && liveFrame != nil
                    ? PoseDescriber.correction(templateFrame!, liveFrame!, minVis)
                    : nil,
                rollFromDevice: rollFromDevice,
                gocMauKhongCoCaoThap: c == .pitch && !applicable.contains(.elevation) ? t.tiltDeg : nil,
                unmeasuredTooLong: state == .unmeasured && gates[c]!.unmeasuredTooLong(nowMs),
                tuChup: mode.tuChup,
                latGuong: mode.latGuong,
                mayNguocChieu: mode.mayNguocChieu,
                tamTay: mode.tamTay,
                datMay: mode.datMay,
                targetZoom: c == .scale ? targetZoomFor(t, live, zoomRatio) : nil,
                zoomToiDa: c == .scale ? zoomToiDa : nil,
                zoomSai: c == .scale && zoomSai,
                coGocRong: zoomMin <= Self.zoomGocRongToiDa,
                chupTuXa: c == .scale && kieuTren == .xaZoom,
                duXa: duXa,
                mauChucGat: c == .scale && ((t.tiltDeg ?? t.pitchCue[.gocMay]) ?? 0.0) <= -TemplateProfile.gocGatDeg
            )
        }

        // Khoá bước đã đạt để tránh rung tay kéo người dùng quay lại. Vị trí thực sự đổi rất xa (vượt ngưỡng mở
        // khoá của gate) thì phải kiểm bước đó lại.
        let brokenStep = steps.prefix(currentStepIndex).firstIndex { step in
            step.contains { criterion in
                let status = statuses.first { $0.criterion == criterion }!
                guard let d = status.deviation, let b = status.band else { return false }
                return !skipped.contains(criterion) && status.state == .failing && d > b.unlock
            }
        }
        if let brokenStep {
            currentStepIndex = brokenStep
            currentStepSinceMs = nil
            allGoodSinceMs = nil
            presenter.reset()
        }

        // Chỉ một bước được hoạt động. Các bước sau hiện "đang chờ" và không được sinh câu nhắc hoặc dấu tích.
        while currentStepIndex < steps.count {
            let current = steps[currentStepIndex]
            let done = current.allSatisfy { c in
                skipped.contains(c) || statuses.first { $0.criterion == c }!.state == .passing
            }
            if !done { break }
            currentStepIndex += 1
            currentStepSinceMs = nil
            presenter.reset()
        }

        if currentStepIndex < steps.count {
            let currentStep = steps[currentStepIndex]
            // Cảnh báo chuẩn bị đang che câu hướng dẫn, nên khoảng thời gian đó không tính là đã thử mà vẫn kẹt.
            if !allowSkip || prepWarning != nil {
                currentStepSinceMs = nil
            } else {
                let since: Int64
                if let s = currentStepSinceMs { since = s } else { since = nowMs; currentStepSinceMs = nowMs }
                if nowMs - since >= Self.autoSkipAfterMs {
                    for c in currentStep where statuses.first(where: { $0.criterion == c })!.state != .passing {
                        skipped.insert(c)
                    }
                    currentStepIndex += 1
                    currentStepSinceMs = nil
                    presenter.reset()
                }
            }
        }

        let activeCriteria = Set(currentStepIndex < steps.count ? steps[currentStepIndex] : [])
        let completedCriteria = Set(steps.prefix(currentStepIndex).joined())
        statuses = statuses.map { status in
            var s = status
            if skipped.contains(s.criterion) {
                s.skipped = true
            } else if completedCriteria.contains(s.criterion) {
                // Bước đã hoàn tất được khoá cho tới hết phiên.
                s.state = .passing
            } else if activeCriteria.contains(s.criterion) {
                // giữ nguyên
            } else {
                s.pending = true
            }
            return s
        }

        // --- Chọn các mục đáng nhắc ---
        let failing = gopCaoVaChuc(
            statuses
                .filter { !$0.pending && !$0.skipped }
                .filter { s in
                    switch s.state {
                    case .failing:
                        // Sàn hành động: lệch ít tới mức không ai sửa nổi thì im.
                        guard let d = s.deviation, let b = s.band else { return false }
                        return d - b.accept >= b.actionFloor
                    // ⚠️ MỤC KHÔNG ĐO ĐƯỢC QUÁ LÂU CŨNG PHẢI ĐƯỢC NÓI (12/09/2026, FOOTGUNS 72) — thiếu nhánh này
                    // thì `unmeasuredTooLong` của `CuePresenter` là mã chết và ngõ cụt im lặng quay lại.
                    case .unmeasured:
                        return s.unmeasuredTooLong
                    default:
                        return false
                    }
                }
                .sorted { Criterion.allCases.firstIndex(of: $0.criterion)! < Criterion.allCases.firstIndex(of: $1.criterion)! }
        )

        // Chỉ khi toàn bộ bước về máy đã hoàn tất hoặc được bỏ qua thì mới chuyển sang hướng mẫu. GREY/UNMEASURED
        // không phải là đã xong.
        let cameraClean = statuses
            .filter { !$0.criterion.forModel }
            .allSatisfy { !$0.pending && ($0.state == .passing || $0.skipped) }

        // Mục ÁP DỤNG mà khung hình không đo được, kéo dài đủ lâu. Ưu tiên THẤP NHẤT.
        let stuckUnmeasured = statuses.filter { !$0.pending && !$0.skipped && $0.unmeasuredTooLong }

        var cueCandidates = cameraClean ? failing : failing.filter { !$0.criterion.forModel }
        if cueCandidates.isEmpty { cueCandidates = stuckUnmeasured }

        // Đang nói với mẫu: đóng băng các mục về máy vài giây. ⚠️ Tự chụp thì KHÔNG đóng băng — không có ai để nói,
        // máy vẫn đang giơ nguyên chỗ cũ.
        let talking = !mode.tuChup && (modelCueSinceMs.map { nowMs - $0 < Self.modelCueFreezeMs } ?? false)
        if talking {
            let model = cueCandidates.filter { $0.criterion.forModel }
            if !model.isEmpty { cueCandidates = model }
        }

        // ⚠️ CÒN MỤC CHƯA ĐO ĐƯỢC THÌ KHÔNG BAO GIỜ "SẴN SÀNG" (12/09/2026). "Sẵn sàng" = app đã nhìn đủ và mọi thứ
        // đều đạt, không phải app không nhìn thấy gì để chê.
        let readyToPose = cameraClean

        // Đủ giống rồi thì chuyển sang nhắc dáng, không phải im lặng.
        let poseCandidates = cueCandidates.filter { $0.criterion.forModel }
        // ⚠️ IM LẶNG TRONG LÚC NGƯỜI DÙNG ĐANG TỰ ĐẶT MÁY (12/09/2026, FOOTGUNS 93). Chờ máy đứng yên đủ lâu MỘT LẦN
        // rồi mới bắt đầu nói; sau đó không chờ lại nữa.
        if daYenLanDauMs == nil && angularSpeedDegPerSec <= GuidanceTiming.maxAngularSpeedDegPerSec {
            daYenLanDauMs = nowMs
        }
        let daQuaLucDatMay = daYenLanDauMs.map { nowMs - $0 >= Self.choDatMayMs } ?? false

        let cue: UiText?
        if prepWarning != nil {
            cue = nil
        } else if !daQuaLucDatMay {
            cue = nil
        } else if readyToPose {
            cue = presenter.update(poseCandidates, nowMs, angularSpeedDegPerSec)
        } else {
            cue = presenter.update(cueCandidates, nowMs, angularSpeedDegPerSec)
        }

        // ⚠️ Không hỏi `criterion.forModel` — mục NGHIÊNG NGANG là mục nhắc mẫu hay nhắc máy tuỳ khung hình.
        let cueForModel = cue != nil && cueCandidates.first?.isModelCue == true
        if cueForModel && modelCueSinceMs == nil {
            modelCueSinceMs = nowMs
        } else if !cueForModel && !talking {
            modelCueSinceMs = nil
        }

        // --- Cổng chụp ---
        let steady = angularSpeedDegPerSec <= GuidanceTiming.maxAngularSpeedDegPerSec

        let allResolved = !statuses.isEmpty && statuses.allSatisfy(resolvedForCapture)
        let good = prepWarning == nil && allResolved && steady

        if good {
            if allGoodSinceMs == nil { allGoodSinceMs = nowMs }
        } else {
            allGoodSinceMs = nil
        }
        let stableFor = allGoodSinceMs.map { nowMs - $0 } ?? 0

        let dangLam = statuses.filter {
            !$0.pending && !$0.skipped && $0.state != .passing && $0.criterion != .pose
        }
        let almost = !dangLam.isEmpty && dangLam.allSatisfy { s in
            guard let d = s.deviation, let b = s.band else { return false }
            return d <= b.enter
        }

        return GuidanceResult(
            statuses: statuses,
            cue: cue,
            prepWarning: prepWarning,
            readyToCapture: good && stableFor >= GuidanceTiming.dwellMs,
            stableForMs: stableFor,
            cueForModel: cueForModel,
            matchPercent: match,
            readyToPose: readyToPose,
            almost: almost,
            denBoCuc: currentStepIndex >= boCucIndex
        )
    }

    /// Zoom đích ở nguyên vị trí hiện tại: kích thước trong khung tỉ lệ thuận với zoom.
    private func targetZoomFor(_ template: PoseMeasurement, _ live: PoseMeasurement, _ currentZoom: Float) -> Float? {
        guard let (target, current) = ShotScorer.scalePair(template, live) else { return nil }
        if current <= 1e-6 { return nil }
        return max(Float(Double(currentZoom) * (target / current)), 0.1)
    }

    /// GỘP "máy cao/thấp" với "máy ngửa/chúc" thành MỘT câu khi chúng CÙNG CHIỀU (FOOTGUNS 73) — với người cầm
    /// máy thật, nâng máy và chúc máy là MỘT động tác. Ngược chiều thì để từng câu riêng.
    private func gopCaoVaChuc(_ ds: [CriterionStatus]) -> [CriterionStatus] {
        guard let cao = ds.first(where: { $0.criterion == .elevation && $0.state == .failing }) else { return ds }
        guard let chuc = ds.first(where: { $0.criterion == .pitch && $0.state == .failing }) else { return ds }
        guard let a = cao.signedDelta else { return ds }
        guard let b = chuc.signedDelta else { return ds }
        if a * b <= 0.0 { return ds }
        return ds.compactMap { s in
            switch s.criterion {
            case .pitch: return nil
            case .elevation:
                var g = s
                g.kemChuc = true
                return g
            default: return s
            }
        }
    }

    /// QUÃNG ĐƯỜNG CẦN ĐI, mét — chỉ cho hai mục liên quan tới chỗ đứng.
    ///
    /// `đích = MAX(mốc tối thiểu của lớp ảnh, khoảng cách để khớp khung ở 1x)` — vế thứ hai một mình sẽ đẩy người
    /// dùng tới rất gần; vế thứ nhất ép đúng công thức "lùi ra một khoảng rồi zoom lên".
    ///
    /// - Parameter zoomYeuCau: kiểu chụp đứng gần — đi bộ tới đúng cỡ ở mức zoom này (không áp khoảng cách tối thiểu).
    private func moveMetersFor(
        _ c: Criterion,
        _ t: PoseMeasurement,
        _ live: PoseMeasurement,
        _ zoomRatio: Float,
        _ vFovDeg: Double?,
        _ zoomYeuCau: Float? = nil
    ) -> Double? {
        if c != .perspective && c != .scale { return nil }
        let heSo = DistanceEstimator.heSoOngKinh(vFovDeg, zoomRatio)
        guard let now = DistanceEstimator.estimate(live.scale, live.anchorHeightMeters, zoomRatio, heSo: heSo) else {
            return nil
        }
        // Khoảng cách đứng nếu chụp đúng khung của ảnh mẫu mà KHÔNG zoom.
        let atOneX = DistanceEstimator.estimate(t.scale, live.anchorHeightMeters, 1, heSo: heSo)
        let target: Double
        if let zoomYeuCau {
            // Zoom cố định (đứng gần 1x, góc rộng 0.5x): đứng sát là đúng ý ảnh.
            guard let z = DistanceEstimator.estimate(t.scale, live.anchorHeightMeters, zoomYeuCau, heSo: heSo) else {
                return nil
            }
            target = z
        } else {
            target = max(DistanceEstimator.minStandoffMeters(profile.framing), atOneX ?? 0.0)
        }
        return abs(target - now)
    }

    // MARK: - Hằng số (internal để test đọc, không phải để nơi khác gọi tuỳ tiện)

    /// Zoom vượt mức tối đa quá chừng này thì coi là sai zoom.
    static let zoomLechToiDa: Float = 0.08

    /// Máy zoom ra được tới mức này là có ống góc rộng — mới gợi ý kiểu mắt cá.
    static let zoomGocRongToiDa: Float = 0.7

    /// Giữ im các mục về máy ngần này sau khi bắt đầu nói với mẫu.
    static let modelCueFreezeMs: Int64 = 4_000

    /// Khoảng ba chu kỳ câu nhắc; sau đó chế độ tự động được phép đi tiếp.
    static let autoSkipAfterMs: Int64 = GuidanceTiming.cueMinDisplayMs * 3

    /// Mốc điểm dùng cho hiển thị mức giống và các bài kiểm thử chấm điểm.
    static let readyPercent = 85

    /// Máy phải đứng yên bấy nhiêu ms rồi app mới bắt đầu nói. Chỉ chờ MỘT LẦN mỗi phiên.
    static let choDatMayMs: Int64 = 1_000

    /// Máy vẹo từ mức này trở lên thì coi LỖI Ở MÁY, dưới mức đó thì lỗi ở mẫu.
    static let deviceRollBlameDeg = 3.0

    /// Máy chúc/ngửa quá mức này thì NGỪNG tin cảm biến vẹo — `atan2(-gx, gy)` của hai số gần 0 là nhiễu thuần.
    /// Public vì `DatMayGate` và tầng cảm biến dùng chung.
    public static let deviceRollTrustPitchDeg = 60.0

    private func bandOf(_ c: Criterion, _ pitchSource: PitchSource? = nil) -> Band? {
        GuidanceConfig.bandFor(c, profile.framing, profile.measurement.scale, pitchSource)
    }

    /// Hiệu CÓ DẤU giữa khung hình và ảnh mẫu — chỉ để chọn chữ ("lùi lại" hay "tiến lên"), không dùng để chấm.
    /// Phép TRỪ trên hai số đã đo xong, không phải phép đo thứ hai.
    private func signedDelta(
        _ c: Criterion,
        _ t: PoseMeasurement,
        _ live: PoseMeasurement,
        _ deviceRoll: Double? = nil
    ) -> Double? {
        switch c {
        // ⚠️ ĐÃ KIỂM CHỨNG DẤU 12/09/2026: góc DƯƠNG = mẫu quay về phía TRÁI CỦA HỌ. Chỉ so khi cùng đường đo —
        // thiếu đường ưu tiên thì BỎ, KHÔNG lùi sang đường khác.
        case .yaw:
            let a: Double?
            let b: Double?
            switch t.framing.yawSource {
            case .faceYaw: a = t.faceYawDeg; b = live.faceYawDeg
            case .body3d: a = t.yawDeg; b = live.yawDeg
            }
            guard let a, let b else { return nil }
            // Đưa về đường ngắn nhất trên vòng tròn, giữ dấu.
            var d = b - a
            while d > 180.0 { d -= 360.0 }
            while d <= -180.0 { d += 360.0 }
            return d
        case .scale:
            guard let (a, b) = ShotScorer.scalePair(t, live) else { return nil }
            if a <= 1e-6 { return nil }
            // Thiếu thân là mẫu QUÁ TO trong khung, dù cỡ mặt nói gì.
            if ShotScorer.thieuThan(t, live) { return max((b - a) / a, 1.0) }
            return (b - a) / a
        // Độ vẹo của máy theo cảm biến: dương = máy xoay THEO chiều kim đồng hồ (nhìn vào màn hình).
        case .roll: return deviceRoll
        case .center: return diff(t.centerX, live.centerX)
        case .elevation: return diff(t.elevationDeg, live.elevationDeg)
        // Cùng luật "chỉ so khi cùng đường đo".
        case .pitch:
            for src in PitchSource.allCases {
                guard let a = t.pitchCue[src], let b = live.pitchCue[src] else { continue }
                return b - a
            }
            return nil
        // Chọn đúng cặp đoạn mà cả hai bên cùng có — giống hệt phép so lệch.
        case .perspective:
            for src in PerspectiveSource.allCases {
                guard let a = t.perspectiveIndex[src], let b = live.perspectiveIndex[src] else { continue }
                return b - a
            }
            return nil
        default: return nil
        }
    }

    private func diff(_ t: Double?, _ c: Double?) -> Double? {
        guard let t, let c else { return nil }
        return c - t
    }

    /// Về trạng thái ban đầu. Gọi khi vào lại màn hình hoặc đổi ảnh mẫu.
    /// (Như Kotlin: không xoá `modelCueSinceMs`, `daYenLanDauMs`.)
    public func reset() {
        gates.values.forEach { $0.reset() }
        presenter.reset()
        validFrames = 0
        allGoodSinceMs = nil
        currentStepIndex = 0
        currentStepSinceMs = nil
        skipped.removeAll()
    }
}
