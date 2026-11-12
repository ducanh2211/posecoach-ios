import Foundation

/// TẦNG ĐO ĐẠC — "MỘT HÀM DUY NHẤT". Port từ `object Measurer` trong `KT/measure/PoseMeasurement.kt`.
///
/// Quy một khung hình đã nhận diện thành vài con số mô tả **máy đang đặt ở đâu so với mẫu**. Ảnh mẫu, khung
/// camera và khung video đi qua ĐÚNG hàm `measure`, ĐÚNG tham số `framing` — khác nhau đúng ở chỗ truyền vào
/// cái gì.
///
/// ⚠️ BẤT BIẾN SỐ 1. Không viết hàm đo thứ hai ở bất kỳ đâu (hướng dẫn realtime và chấm ảnh sau khi quay
/// đọc CHUNG kết quả của hàm này). Hai bộ đo song song thì mỗi bên tự đúng, chỉ phép trừ giữa hai bên là
/// vô nghĩa — không có gì báo lỗi.
///
/// ⚠️ BẤT BIẾN SỐ 2. `framing` LUÔN là lớp khung hình suy từ **ẢNH MẪU**, kể cả khi đo khung camera.
///
/// ⚠️ Giữ nguyên thứ tự phép tính của Kotlin — mọi khác biệt làm mất khả năng đối chiếu.
public enum Measurer {

    /// GÓC MỞ DỌC GIẢ ĐỊNH CHO ẢNH MẪU, độ.
    ///
    /// Ảnh mẫu là JPEG trần: không tiêu cự, không EXIF. 65° là góc dọc của ống kính chính điện thoại phổ
    /// thông ở khung 4:3 (~26mm). Đoán sai có chặn trên: số hạng `(0,5 − y) × vFOV` tỉ lệ với khoảng cách
    /// từ mốc tới GIỮA khung.
    public static let vfovAnhMau = 65.0

    /// Trục thân ngắn hơn bấy nhiêu lần bề ngang vai trên ảnh thì coi là co rút.
    public static let thanToiThieuTheoVai = 1.0

    /// Mốc đo lệch khỏi tâm khung quá mức này thì mục 3 không tin được nữa (FOOTGUNS 79).
    public static let mocLechTamToiDa = 0.15

    /// Góc chĩa vào ống kính tối đa mà một đoạn cơ thể còn dùng để đo được, ĐỘ (FOOTGUNS 38). Người đứng
    /// bình thường cho 9,1°-25,8°; mẫu đá chân về phía máy vượt 60°.
    public static let maxOutOfPlaneDeg = 40.0

    /// Bề ngang tối thiểu của đường vai trên ảnh để góc của nó còn nghĩa. Dưới mức này là mẫu quay nghiêng
    /// gần như hoàn toàn: hai vai chồng lên nhau.
    private static let minShoulderSpan = 0.03

    /// Ba mốc của `hieuChinhGocAnh` — số suy từ ảnh và số cảm biến thật tương ứng.
    private static let mocGocAnh: [Double] = [-50.0, -20.0, -8.0]
    private static let mocGocThat: [Double] = [-49.0, -14.0, 5.0]

    /// Đo một khung hình.
    ///
    /// - Parameters:
    ///   - frame: khung hình đã nhận diện (ảnh mẫu hoặc khung camera — cùng đường)
    ///   - framing: lớp khung hình **của ảnh mẫu**, áp nguyên xi cho mọi khung
    ///   - minVisibility: ngưỡng tin cậy tối thiểu của từng điểm khớp
    ///   - face: số liệu khuôn mặt, `nil` khi chưa chạy hoặc không thấy mặt
    ///   - vFovDeg: góc mở DỌC của ống kính, độ. Camera thật đọc từ phần cứng; ảnh mẫu dùng `vfovAnhMau`.
    public static func measure(
        _ frame: PoseFrame,
        _ framing: FramingClass,
        _ minVisibility: Float,
        face: FaceInfo? = nil,
        vFovDeg: Double = vfovAnhMau
    ) -> PoseMeasurement {
        if frame.isEmpty {
            return PoseMeasurement(
                framing: framing, scale: nil, centerX: nil, tiltDeg: nil, elevationDeg: nil, yawDeg: nil,
                faceYawDeg: nil, eyesOpen: nil, anchorHeightMeters: nil,
                rollDeg: [:], pitchCue: [:], perspectiveIndex: [:], poseAngles: [:]
            )
        }
        return PoseMeasurement(
            framing: framing,
            scale: measureScale(frame, framing.scaleAnchor, minVisibility),
            centerX: measureCenterX(frame, framing.centerAnchor, minVisibility),
            tiltDeg: measureTiltDeg(frame, minVisibility),
            elevationDeg: measureElevationDeg(frame, framing, minVisibility, vFovDeg),
            yawDeg: frame.bodyYawDeg(minVisibility),
            faceYawDeg: face?.yawDeg,
            eyesOpen: face?.eyesOpen,
            anchorHeightMeters: measureAnchorHeight(frame, framing, minVisibility),
            rollDeg: measureRoll(frame, minVisibility),
            pitchCue: measurePitchCue(frame, minVisibility),
            perspectiveIndex: measurePerspective(frame, minVisibility),
            poseAngles: measurePose(frame, framing.poseGroups, minVisibility),
            elevationAnchorY: anchorY(frame, framing.elevationAnchor, minVisibility),
            faceScale: faceBox(frame, minVisibility).map(\.height).flatMap { $0 > 1e-4 ? $0 : nil },
            tamThan: measureTamThan(frame, minVisibility)
        )
    }

    // MARK: - MỤC 2 — XA/GẦN

    /// Chiều cao mốc đo, theo tỉ lệ chiều cao khung hình. Mốc thay đổi theo lớp khung hình — đó là toàn bộ
    /// lý do `FramingClass` tồn tại.
    private static func measureScale(_ f: PoseFrame, _ anchor: ScaleAnchor, _ v: Float) -> Double? {
        if anchor == .faceHeight {
            guard let face = faceBox(f, v) else { return nil }
            return face.height > 1e-4 ? face.height : nil
        }

        guard let head = headPoint(f, v) else { return nil }

        // ⚠️ Mốc đo chạm tới CHÂN thì phải kiểm chân có chĩa vào ống kính không. Mẫu đá chân về phía máy làm
        // cổ chân tụt xuống trong khung → app tưởng máy lại gần. Bỏ ra còn hơn đo sai (quy tắc số 4).
        let legOk: Bool
        switch anchor {
        case .headToAnkle:
            legOk = segmentUsable(f, v, Lm.leftHip, Lm.rightHip, Lm.leftAnkle, Lm.rightAnkle)
        case .headToKnee:
            legOk = segmentUsable(f, v, Lm.leftHip, Lm.rightHip, Lm.leftKnee, Lm.rightKnee)
        default:
            legOk = true
        }
        if !legOk { return nil }

        let bottomY: Double?
        switch anchor {
        case .headToAnkle: bottomY = lowestY(f, v, Lm.leftAnkle, Lm.rightAnkle)
        case .headToKnee: bottomY = lowestY(f, v, Lm.leftKnee, Lm.rightKnee)
        case .headToHip: bottomY = f.root(v)?.y
        case .faceHeight: bottomY = nil // đã xử lý ở trên
        }
        guard let bottomY else { return nil }

        // y hướng XUỐNG nên đáy phải lớn hơn đỉnh. Ngược lại là dữ liệu rác.
        let d = bottomY - head.y
        return d > 1e-4 ? d : nil
    }

    /// Chiều cao THẬT của mốc đo, mét — phải khớp ĐÚNG mốc mà `measureScale` dùng. Lấy nhầm mốc thì khoảng
    /// cách sai ~35%, đủ để nói nhầm "2 bước" thành "3 bước".
    private static func measureAnchorHeight(_ f: PoseFrame, _ framing: FramingClass, _ v: Float) -> Double? {
        guard let head = f.world(Lm.nose, v) else { return nil }
        let bottom: (Double, Double, Double)?
        switch framing.scaleAnchor {
        case .headToAnkle: bottom = midWorld3(f, Lm.leftAnkle, Lm.rightAnkle, v)
        case .headToKnee: bottom = midWorld3(f, Lm.leftKnee, Lm.rightKnee, v)
        case .headToHip: bottom = midWorld3(f, Lm.leftHip, Lm.rightHip, v)
        // Chân dung: mốc là khung MẶT, mà worldLandmarks không cho chiều cao khuôn mặt đáng tin.
        case .faceHeight: bottom = nil
        }
        guard let bottom else { return nil }
        let d = dist3((head.x, head.y, head.z), bottom)
        // Người cao dưới 0,5m hoặc trên 2,5m là dữ liệu rác, không phải người.
        return (0.5...2.5).contains(d) ? d : nil
    }

    // MARK: - MỤC 5 — LỆCH TRÁI/PHẢI

    /// Mốc đặt người trên lưới — xem `MocLuoi`. Mốc dưới theo đúng lớp khung hình của ẢNH MẪU (truyền vào),
    /// như mọi phép đo: live không tự chọn mốc.
    public static func mocLuoi(_ f: PoseFrame, _ framing: FramingClass, _ v: Float) -> MocLuoi {
        let chanDung = framing.scaleAnchor == .faceHeight
        let tren = chanDung ? lowestY(f, v, Lm.leftEye, Lm.rightEye) : headPoint(f, v)?.y
        let duoi: Double?
        let loaiDuoi: LoaiMoc
        switch framing.scaleAnchor {
        case .headToAnkle: (duoi, loaiDuoi) = (lowestY(f, v, Lm.leftAnkle, Lm.rightAnkle), .chan)
        case .headToKnee: (duoi, loaiDuoi) = (lowestY(f, v, Lm.leftKnee, Lm.rightKnee), .goi)
        case .headToHip: (duoi, loaiDuoi) = (f.root(v)?.y, .hong)
        case .faceHeight: (duoi, loaiDuoi) = (lowestY(f, v, Lm.leftShoulder, Lm.rightShoulder), .vai)
        }
        return MocLuoi(
            trenY: tren,
            duoiY: duoi,
            giuaX: measureCenterX(f, framing.centerAnchor, v),
            loaiTren: chanDung ? .mat : .dau,
            loaiDuoi: loaiDuoi
        )
    }

    private static func measureCenterX(_ f: PoseFrame, _ anchor: CenterAnchor, _ v: Float) -> Double? {
        switch anchor {
        case .torsoCenter:
            let neck = f.neck(v)
            let root = f.root(v)
            if let neck, let root { return (neck.x + root.x) / 2.0 }
            return neck?.x
        case .shoulderCenter:
            return f.neck(v)?.x
        case .faceCenter:
            return faceBox(f, v).map { ($0.left + $0.right) / 2.0 }
        }
    }

    // MARK: - MỤC 3 — MÁY CAO/THẤP

    /// GÓC NÂNG CỦA MÁY so với chủ thể, ĐỘ. Âm = máy ở trên chúc xuống, dương = máy ở dưới ngửa lên.
    ///
    /// Lấy trục thân trong **khung xương 3D** (`worldLandmarks`) rồi tính góc giữa nó và mặt phẳng ảnh. Miễn
    /// nhiễm với zoom, khoảng cách, và việc ảnh mẫu đã bị cắt cúp.
    ///
    /// ⚠️ CHỈ DÙNG `worldLandmarks` CHO HƯỚNG, KHÔNG CHO KHOẢNG CÁCH (FOOTGUNS 64).
    /// ⚠️ Cần THẤY HÔNG. Không lấy trục cổ→đầu thay thế (FOOTGUNS 66) — trả `nil`.
    static func measureTiltDeg(_ f: PoseFrame, _ v: Float) -> Double? {
        // Đòi cả 2D lẫn 3D: `at()` lọc điểm nằm NGOÀI khung mà MediaPipe vẫn tự tin bịa ra.
        if f.at(Lm.leftHip, v) == nil && f.at(Lm.rightHip, v) == nil { return nil }
        if f.at(Lm.leftShoulder, v) == nil && f.at(Lm.rightShoulder, v) == nil { return nil }

        let lh = f.world(Lm.leftHip, v); let rh = f.world(Lm.rightHip, v)
        let ls = f.world(Lm.leftShoulder, v); let rs = f.world(Lm.rightShoulder, v)
        guard let hip = midP3(lh, rh), let sh = midP3(ls, rs) else { return nil }

        let dy = sh.y - hip.y
        let dz = sh.z - hip.z
        // Trục thân quá ngắn trên ảnh thì góc nhiễu loạn — thà bỏ.
        if hypot(dy, dz) < 1e-3 { return nil }
        // y của MediaPipe hướng XUỐNG, nên -dy là "lên trên".
        // ⚠️ `hieuChinhGocAnh` VẪN ĐƯỢC GỌI ở đây dù FOOTGUNS 91 ghi "mục 87 đã bị thay thế" — code Kotlin
        // thắng tài liệu (plan, mục "Nguồn sự thật").
        return hieuChinhGocAnh(toDegrees(atan2(dz, -dy)))
    }

    /// ĐỔI GÓC SUY TỪ ẢNH RA GÓC MÁY THẬT (15/09/2026).
    ///
    /// Số thô từ trục thân 3D không phải góc máy. Đo trên video (78 cặp có cả số cảm biến lẫn số suy từ ảnh):
    ///
    /// | Số suy từ ảnh | Cảm biến thật |
    /// |---|---|
    /// | −50° | −49° |
    /// | −20° | −14° |
    /// | −8° | +5° |
    ///
    /// Nội suy gãy khúc qua ba mốc trên. Ngoài khoảng đã đo thì giữ độ dốc 1 — không ngoại suy độ dốc của
    /// đoạn giữa ra chỗ chưa có số liệu. ⚠️ Mới đo trên một người, một máy.
    static func hieuChinhGocAnh(_ tho: Double) -> Double {
        let x = mocGocAnh
        let y = mocGocThat
        if tho <= x.first! { return y.first! + (tho - x.first!) }
        if tho >= x.last! { return y.last! + (tho - x.last!) }
        let i = x.firstIndex { $0 > tho }!
        let t = (tho - x[i - 1]) / (x[i] - x[i - 1])
        return y[i - 1] + t * (y[i] - y[i - 1])
    }

    /// Mục 3 — góc nhìn từ máy tới mốc. Cần `measureTiltDeg` chạy được, tức là phải thấy hông.
    private static func measureElevationDeg(
        _ f: PoseFrame, _ framing: FramingClass, _ v: Float, _ vFovDeg: Double
    ) -> Double? {
        guard let tilt = measureTiltDeg(f, v),
              let y = anchorY(f, framing.elevationAnchor, v) else { return nil }
        return gocNhin(tilt, y, vFovDeg)
    }

    /// Góc nhìn từ máy tới mốc, dùng chung cho ảnh mẫu và camera.
    ///
    /// Tách riêng vì phía camera không lấy độ nghiêng từ ảnh mà từ CẢM BIẾN, còn ảnh mẫu có thể lấy từ NHÃN
    /// GÓC trong tên file. Cả hai vẫn đi qua đúng một công thức và đúng một chốt chặn mốc-xa-tâm.
    public static func gocNhin(_ tiltDeg: Double?, _ anchorY: Double?, _ vFovDeg: Double) -> Double? {
        guard let tiltDeg, let anchorY else { return nil }
        let y = anchorY
        let tilt = tiltDeg

        // ⚠️ MỐC NẰM XA TÂM KHUNG THÌ BỎ MỤC NÀY — phép đoán vFOV không đỡ nổi (FOOTGUNS 79).
        //
        // Số hạng `(0,5 − y) × vFOV` tỉ lệ thẳng với khoảng cách từ mốc tới giữa khung. vFOV của ảnh mẫu là số
        // ĐOÁN, sai số cỡ ±20°: |0,5 − y| = 0,224 đã sai 4,5°, gần bằng cả ngưỡng đạt. Thà bỏ và chia lại trọng
        // số (quy tắc số 4) còn hơn nhắc theo một con số bịa.
        if abs(0.5 - y) > mocLechTamToiDa { return nil }

        return tilt + (0.5 - y) * vFovDeg
    }

    /// Toạ độ dọc của mốc trên khung. Một số hạng của mục 3, không phải phép đo.
    private static func anchorY(_ f: PoseFrame, _ anchor: ElevationAnchor, _ v: Float) -> Double? {
        switch anchor {
        case .midHip:
            return f.root(v)?.y
        case .midTorso:
            let neck = f.neck(v); let root = f.root(v)
            if let neck, let root { return (neck.y + root.y) / 2.0 }
            return nil
        case .eyeLine:
            let le = f.at(Lm.leftEye, v); let re = f.at(Lm.rightEye, v)
            if let le, let re { return (le.y + re.y) / 2.0 }
            return (le ?? re)?.y ?? f.at(Lm.nose, v)?.y
        }
    }

    private static func midP3(_ a: P3?, _ b: P3?) -> P3? {
        if let a, let b { return P3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2) }
        return a ?? b
    }

    // MARK: - Góc chĩa vào ống kính (FOOTGUNS 38)

    /// GÓC CHĨA VÀO ỐNG KÍNH của một đoạn cơ thể, ĐỘ. 0° = song song mặt phẳng ảnh; 90° = chĩa thẳng vào ống
    /// kính, chiều dài trên ảnh co về 0 — mà mọi công thức phối cảnh đều CHIA cho chiều dài đó.
    private static func outOfPlaneDeg(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let flat = hypot(b.0 - a.0, b.1 - a.1)
        let depth = abs(b.2 - a.2)
        return flat < 1e-9 ? 90.0 : toDegrees(atan2(depth, flat))
    }

    /// Đoạn nối hai trung điểm có đo được không, hay đang chĩa vào ống kính.
    private static func segmentUsable(_ f: PoseFrame, _ v: Float, _ aL: Int, _ aR: Int, _ bL: Int, _ bR: Int) -> Bool {
        guard let a = midWorld3(f, aL, aR, v), let b = midWorld3(f, bL, bR, v) else { return false }
        return outOfPlaneDeg(a, b) <= maxOutOfPlaneDeg
    }

    // MARK: - MỤC 8 — NGHIÊNG NGANG

    /// Góc nghiêng của thân người trong ảnh, ĐỘ. Dương = nghiêng sang phải. Trả CẢ HAI đường đo khi đo được:
    /// tầng so sánh cần đường mà cả ảnh mẫu lẫn khung camera cùng có.
    ///
    /// Ưu tiên TRỤC THÂN hơn ĐƯỜNG VAI: mẫu quay nghiêng thì hai vai chồng lên nhau, góc thành nhiễu thuần.
    private static func measureRoll(_ f: PoseFrame, _ v: Float) -> [RollSource: Double] {
        var out: [RollSource: Double] = [:]
        let neck = f.neck(v)
        let root = f.root(v)
        let lsTruoc = f.at(Lm.leftShoulder, v)
        let rsTruoc = f.at(Lm.rightShoulder, v)
        // ⚠️ THÂN BỊ CO RÚT THÌ BỎ ĐƯỜNG TRỤC THÂN (14/09/2026). Chụp từ trên cao chúc xuống, cổ và hông gần
        // như chồng lên nhau trên ảnh — lệch vài điểm ảnh là góc nhảy hàng chục độ. Thân ngắn hơn cả bề ngang
        // vai là đã co rút mạnh — lúc đó chỉ tin đường vai.
        let thanCoRut: Bool
        if let neck, let root, let lsTruoc, let rsTruoc {
            thanCoRut = hypot(neck.x - root.x, neck.y - root.y) <
                thanToiThieuTheoVai * hypot(rsTruoc.x - lsTruoc.x, rsTruoc.y - lsTruoc.y)
        } else {
            thanCoRut = false
        }
        if let neck, let root, !thanCoRut {
            // Lấy vector HƯỚNG LÊN (hông → cổ) để dấu đọc thuận: đầu ngả sang phải thì cổ nằm bên phải hông.
            let dx = neck.x - root.x
            // y hướng XUỐNG nên hông luôn có y lớn hơn cổ — dy luôn dương.
            let dy = root.y - neck.y
            if hypot(dx, dy) > 1e-4 {
                out[.spine] = toDegrees(atan2(dx, dy))
            }
        }

        if let ls = f.at(Lm.leftShoulder, v), let rs = f.at(Lm.rightShoulder, v) {
            let dx = rs.x - ls.x
            let dy = rs.y - ls.y
            // Hai vai chồng nhau (mẫu quay nghiêng) thì góc vô nghĩa — bỏ.
            if hypot(dx, dy) > minShoulderSpan {
                // ⚠️ PHẢI QUY VỀ DẢI ±90°, ĐỪNG BỎ BƯỚC NÀY. Tên khớp theo GIẢI PHẪU: mẫu quay mặt vào máy thì vai
                // trái nằm bên PHẢI ảnh, vector trái→phải chỉ ngược trục x, `atan2` ra ~180° thay vì ~0°. Đường
                // vai là ĐOẠN THẲNG, không có chiều — gấp về ±90° là đúng bản chất.
                let raw = toDegrees(atan2(dy, dx))
                let folded: Double
                if raw > 90.0 { folded = raw - 180.0 }
                else if raw <= -90.0 { folded = raw + 180.0 }
                else { folded = raw }
                out[.shoulders] = folded
            }
        }
        return out
    }

    // MARK: - MỤC 4 — MÁY NGỬA/CHÚC

    private static func measurePitchCue(_ f: PoseFrame, _ v: Float) -> [PitchSource: Double] {
        var out: [PitchSource: Double] = [:]
        // Cách 0 — TRỤC THÂN 3D, ra thẳng ĐỘ. Đường ưu tiên (nơi đọc duyệt theo `PitchSource.allCases`).
        if let t = measureTiltDeg(f, v) { out[.gocMay] = t }
        // Cách 1 — CHÂN so với THÂN. Mạnh, nhưng bỏ khi chân chĩa vào ống kính.
        if segmentUsable(f, v, Lm.leftHip, Lm.rightHip, Lm.leftAnkle, Lm.rightAnkle) {
            if let l = legsOverTorso(f, v) { out[.legs] = l }
        }
        return out
    }

    /// Cách 1 — dựa vào chân: `ln( (chân/thân trên ảnh) / (chân/thân ngoài đời) )`. Lớn hơn 0 = hất lên.
    private static func legsOverTorso(_ f: PoseFrame, _ v: Float) -> Double? {
        guard let neck2 = f.neck(v),
              let root2 = f.root(v),
              let ankle2 = lowestY(f, v, Lm.leftAnkle, Lm.rightAnkle) else { return nil }

        let torso2 = abs(root2.y - neck2.y)
        let legs2 = abs(ankle2 - root2.y)
        if torso2 < 1e-4 || legs2 < 1e-4 { return nil }

        guard let neckW = midWorld(f, Lm.leftShoulder, Lm.rightShoulder, v),
              let rootW = midWorld(f, Lm.leftHip, Lm.rightHip, v),
              let ankleW = [f.world(Lm.leftAnkle, v)?.y, f.world(Lm.rightAnkle, v)?.y].compactMap({ $0 }).max()
        else { return nil }

        let torso3 = abs(rootW.1 - neckW.1)
        let legs3 = abs(ankleW - rootW.1)
        if torso3 < 1e-4 || legs3 < 1e-4 { return nil }

        return log((legs2 / torso2) / (legs3 / torso3))
    }

    private static func midWorld(_ f: PoseFrame, _ a: Int, _ b: Int, _ v: Float) -> (Double, Double)? {
        guard let pa = f.world(a, v), let pb = f.world(b, v) else { return nil }
        return ((pa.x + pb.x) / 2.0, (pa.y + pb.y) / 2.0)
    }

    // MARK: - MỤC 7 — ĐỘ MẠNH PHỐI CẢNH (tách ĐỨNG GẦN khỏi ZOOM VÀO)

    /// ĐỘ MÉO PHỐI CẢNH — chỉ số không đơn vị, **miễn nhiễm với zoom** (FOOTGUNS 35, 37).
    ///
    /// `scale` sinh ra từ hai ẩn số (`s = f × S / d`), nên đi lại gần và đứng yên rồi zoom cho cùng `scale`.
    /// Phối cảnh chỉ phụ thuộc VỊ TRÍ đặt máy, không phụ thuộc tiêu cự:
    ///
    ///     P = ln[ (thân/chân) trên ảnh ÷ (thân/chân) ngoài đời ]
    ///
    /// Chia cho tỉ lệ THẬT của chính người đó để khử khác biệt cơ thể. Đo 13 ảnh: 1m ~0,25 · 2,5m ~0,2 ·
    /// 4m ~0,1 — giảm đơn điệu.
    ///
    /// ⚠️ Chỉ đo được khi thấy chân. ⚠️⚠️ Đã thử mở rộng cho nửa thân trên và thất bại (tín hiệu/nhiễu 1,54,
    /// cần ≥ 3) — ĐỪNG THỬ LẠI. PO chốt 05/09/2026: không làm.
    private static func measurePerspective(_ f: PoseFrame, _ v: Float) -> [PerspectiveSource: Double] {
        var out: [PerspectiveSource: Double] = [:]
        // Tính CẢ HAI cặp khi đo được — tầng so sánh cần cặp mà cả hai bên cùng có.
        // ⚠️ Chân chĩa vào ống kính thì BỎ HẲN, không đoán.
        if segmentUsable(f, v, Lm.leftHip, Lm.rightHip, Lm.leftAnkle, Lm.rightAnkle) {
            if let p = torsoOverLower(f, v, Lm.leftAnkle, Lm.rightAnkle) { out[.torsoAnkle] = p }
        }
        if segmentUsable(f, v, Lm.leftHip, Lm.rightHip, Lm.leftKnee, Lm.rightKnee) {
            if let p = torsoOverLower(f, v, Lm.leftKnee, Lm.rightKnee) { out[.torsoKnee] = p }
        }
        return out
    }

    /// Thân (vai→hông) so với đoạn dưới (hông→`lowerL`/`lowerR`), đã chia cho tỉ lệ thật.
    private static func torsoOverLower(_ f: PoseFrame, _ v: Float, _ lowerL: Int, _ lowerR: Int) -> Double? {
        guard let neck = f.neck(v),
              let root = f.root(v),
              let lowI = midPoint(f, lowerL, lowerR, v) else { return nil }

        let torsoImg = hypot(root.x - neck.x, root.y - neck.y)
        let lowerImg = hypot(lowI.0 - root.x, lowI.1 - root.y)
        if torsoImg < 1e-5 || lowerImg < 1e-5 { return nil }

        guard let neckW = midWorld3(f, Lm.leftShoulder, Lm.rightShoulder, v),
              let rootW = midWorld3(f, Lm.leftHip, Lm.rightHip, v),
              let lowW = midWorld3(f, lowerL, lowerR, v) else { return nil }

        let torsoW = dist3(neckW, rootW)
        let lowerW = dist3(rootW, lowW)
        if torsoW < 1e-6 || lowerW < 1e-6 { return nil }

        return log((torsoImg / lowerImg) / (torsoW / lowerW))
    }

    /// Trung điểm hai mốc TRÊN ẢNH.
    private static func midPoint(_ f: PoseFrame, _ a: Int, _ b: Int, _ v: Float) -> (Double, Double)? {
        guard let pa = f.at(a, v), let pb = f.at(b, v) else { return nil }
        return ((pa.x + pb.x) / 2.0, (pa.y + pb.y) / 2.0)
    }

    /// Trung điểm hai mốc trong KHÔNG GIAN THẬT.
    private static func midWorld3(_ f: PoseFrame, _ a: Int, _ b: Int, _ v: Float) -> (Double, Double, Double)? {
        guard let pa = f.world(a, v), let pb = f.world(b, v) else { return nil }
        return ((pa.x + pb.x) / 2, (pa.y + pb.y) / 2, (pa.z + pb.z) / 2)
    }

    private static func dist3(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        ((a.0 - b.0) * (a.0 - b.0) +
            (a.1 - b.1) * (a.1 - b.1) +
            (a.2 - b.2) * (a.2 - b.2)).squareRoot()
    }

    // MARK: - MỤC 6 — DÁNG (trọng số nhẹ nhất, không bao giờ chặn việc chụp)

    /// Cánh tay này có dùng để chấm dáng được không.
    ///
    /// ⚠️ SINH RA CHO SELFIE: tay cầm máy luôn chĩa thẳng vào ống kính — ràng buộc vật lý, không phải lựa chọn
    /// dáng. Dùng đúng phép đo và đúng ngưỡng đã dùng cho chân (`maxOutOfPlaneDeg`).
    private static func armUsable(_ f: PoseFrame, _ v: Float, left: Bool) -> Bool {
        let sh = left ? Lm.leftShoulder : Lm.rightShoulder
        let el = left ? Lm.leftElbow : Lm.rightElbow
        let wr = left ? Lm.leftWrist : Lm.rightWrist
        guard let s = f.world(sh, v), let e = f.world(el, v) else { return false }
        func tilt(_ a: P3, _ b: P3) -> Double {
            let flat = hypot(b.x - a.x, b.y - a.y)
            return flat < 1e-9 ? 90.0 : toDegrees(atan2(abs(b.z - a.z), flat))
        }
        if tilt(s, e) > maxOutOfPlaneDeg { return false }
        guard let w = f.world(wr, v) else { return true } // không thấy cổ tay thì chỉ xét cánh trên
        return tilt(e, w) <= maxOutOfPlaneDeg
    }

    /// Góc các khớp theo từng nhóm. CHỈ đo nhóm nằm trong lớp khung hình. Nhóm nào không đủ điểm thì VẮNG MẶT
    /// khỏi map, không điền 0 — vắng mặt = "không đo được", điền 0 = "đo được và bằng 0".
    private static func measurePose(_ f: PoseFrame, _ groups: Set<PoseGroup>, _ v: Float) -> [PoseGroup: [Double]] {
        var out: [PoseGroup: [Double]] = [:]

        for g in groups {
            let angles: [Double]
            switch g {
            case .spine:
                angles = [segmentAngle(f.neck(v), f.root(v))].compactMap { $0 }
            case .head:
                angles = [segmentAngle(f.neck(v), f.at(Lm.nose, v))].compactMap { $0 }
            // ⚠️ LUÔN TRẢ ĐÚNG 4 PHẦN TỬ, dùng NaN cho khớp không đo được (FOOTGUNS 50). Giữ đúng vị trí thì mỗi
            // bên tự bỏ khớp của mình, bên kia không bị vạ lây — cần cho selfie (tay cầm máy luôn phải bỏ).
            case .arms:
                angles = [
                    armUsable(f, v, left: true)
                        ? jointAngle(f, Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist, v) : nil,
                    armUsable(f, v, left: false)
                        ? jointAngle(f, Lm.rightShoulder, Lm.rightElbow, Lm.rightWrist, v) : nil,
                    armUsable(f, v, left: true)
                        ? segmentAngle(f.at(Lm.leftShoulder, v), f.at(Lm.leftElbow, v)) : nil,
                    armUsable(f, v, left: false)
                        ? segmentAngle(f.at(Lm.rightShoulder, v), f.at(Lm.rightElbow, v)) : nil,
                ].map { $0 ?? .nan }
            case .legs:
                angles = [
                    jointAngle(f, Lm.leftHip, Lm.leftKnee, Lm.leftAnkle, v),
                    jointAngle(f, Lm.rightHip, Lm.rightKnee, Lm.rightAnkle, v),
                ].compactMap { $0 }
            }
            if !angles.isEmpty { out[g] = angles }
        }
        return out
    }

    // MARK: - Mốc dùng chung

    /// Điểm mốc ĐẦU: trung điểm hai tai (hoặc mũi nếu không thấy tai). Không phải đỉnh đầu thật, và không cần
    /// phải là — ảnh mẫu và khung camera dùng chung một định nghĩa nên sai số chung triệt tiêu nhau.
    private static func headPoint(_ f: PoseFrame, _ v: Float) -> P2? {
        let le = f.at(Lm.leftEar, v)
        let re = f.at(Lm.rightEar, v)
        if let le, let re { return (le + re) / 2.0 }
        return f.at(Lm.nose, v) ?? le ?? re
    }

    /// Mức thấp nhất của cơ thể còn thấy trong khung — xem `PoseMeasurement.tamThan`.
    private static func measureTamThan(_ f: PoseFrame, _ v: Float) -> Int? {
        [
            (Lm.leftShoulder, Lm.rightShoulder),
            (Lm.leftHip, Lm.rightHip),
            (Lm.leftKnee, Lm.rightKnee),
            (Lm.leftAnkle, Lm.rightAnkle),
        ].lastIndex { l, r in f.at(l, v) != nil || f.at(r, v) != nil }
    }

    /// Khung bao phần MẶT (11 điểm đầu: mũi, mắt, tai, miệng).
    private static func faceBox(_ f: PoseFrame, _ v: Float) -> Box? {
        var minX = Double.greatestFiniteMagnitude; var maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude; var maxY = -Double.greatestFiniteMagnitude
        var found = false
        for i in Lm.nose...Lm.mouthRight {
            guard let p = f.at(i, v) else { continue }
            found = true
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        return found ? Box(left: minX, top: minY, right: maxX, bottom: maxY) : nil
    }

    /// Toạ độ y THẤP NHẤT (số lớn nhất, vì y hướng xuống) trong các điểm cho trước.
    private static func lowestY(_ f: PoseFrame, _ v: Float, _ idx: Int...) -> Double? {
        idx.compactMap { f.at($0, v)?.y }.max()
    }

    /// Góc của đoạn a→b so với phương thẳng đứng hướng xuống, ĐỘ, -180..180. 0 = b nằm ngay dưới a.
    private static func segmentAngle(_ a: P2?, _ b: P2?) -> Double? {
        guard let a, let b else { return nil }
        let dx = b.x - a.x
        let dy = b.y - a.y
        if hypot(dx, dy) < 1e-6 { return nil }
        return toDegrees(atan2(dx, dy))
    }

    /// Góc mở tại khớp giữa (ví dụ khuỷu tay), ĐỘ, 0..180. 180 = duỗi thẳng.
    private static func jointAngle(_ f: PoseFrame, _ aIdx: Int, _ bIdx: Int, _ cIdx: Int, _ v: Float) -> Double? {
        guard let a = f.at(aIdx, v), let b = f.at(bIdx, v), let c = f.at(cIdx, v) else { return nil }
        let v1x = a.x - b.x; let v1y = a.y - b.y
        let v2x = c.x - b.x; let v2y = c.y - b.y
        let n1 = hypot(v1x, v1y); let n2 = hypot(v2x, v2y)
        if n1 < 1e-6 || n2 < 1e-6 { return nil }
        let cos = min(max((v1x * v2x + v1y * v2y) / (n1 * n2), -1.0), 1.0)
        return toDegrees(acos(cos))
    }
}
