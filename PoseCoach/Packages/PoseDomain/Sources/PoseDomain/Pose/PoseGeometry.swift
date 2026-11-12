import Foundation

// ĐÂY LÀ FILE MANG BẤT BIẾN QUAN TRỌNG NHẤT CỦA DỰ ÁN. Port từ `KT/pose/PoseGeometry.kt`.
//
// Mọi nơi trong app muốn đọc toạ độ khung xương đều PHẢI đi qua đây. Không nơi nào được tự lấy
// toạ độ của MediaPipe rồi tự quy đổi (FOOTGUNS 3).
//
// Quy ước thống nhất toàn app:
//   x: 0.0 = mép TRÁI khung   →  1.0 = mép PHẢI khung
//   y: 0.0 = mép TRÊN khung   →  1.0 = mép DƯỚI khung   (y càng lớn = càng THẤP)
//
// Tức là giữ nguyên quy ước của MediaPipe, KHÔNG lật. ⚠️ Vision của iOS ngược trục y — app này
// không dùng Vision cho khung xương; nếu có chỗ nào phải dùng, đổi trục ở Services, không ở đây.
//
// Hàm dựng `PoseFrame` từ kiểu dữ liệu MediaPipe (`PoseFrame.from` bên Kotlin) nằm ở
// `Services/PoseLandmarker` (Phase 3a) — PoseDomain không import MediaPipe.

/// Một điểm trên khung hình, theo đúng quy ước đã chốt ở trên.
public struct P2: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static func + (a: P2, o: P2) -> P2 { P2(a.x + o.x, a.y + o.y) }
    public static func - (a: P2, o: P2) -> P2 { P2(a.x - o.x, a.y - o.y) }
    public static func / (a: P2, k: Double) -> P2 { P2(a.x / k, a.y / k) }
}

/// Một điểm trong không gian thật, đơn vị MÉT, gốc = trung điểm hai hông.
public struct P3: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Tên 33 điểm MediaPipe trả về, đặt theo chỉ số của thư viện.
///
/// ⚠️ Tên đặt theo GIẢI PHẪU của người mẫu, KHÔNG theo phía màn hình. Mẫu quay mặt vào máy thì
/// `leftShoulder` nằm ở bên PHẢI ảnh. Đảo thứ tự x của cặp vai chính là phép phân biệt đang thấy
/// mặt trước hay thấy lưng.
public enum Lm {
    public static let nose = 0
    public static let leftEyeInner = 1
    public static let leftEye = 2
    public static let leftEyeOuter = 3
    public static let rightEyeInner = 4
    public static let rightEye = 5
    public static let rightEyeOuter = 6
    public static let leftEar = 7
    public static let rightEar = 8
    public static let mouthLeft = 9
    public static let mouthRight = 10
    public static let leftShoulder = 11
    public static let rightShoulder = 12
    public static let leftElbow = 13
    public static let rightElbow = 14
    public static let leftWrist = 15
    public static let rightWrist = 16
    public static let leftPinky = 17
    public static let rightPinky = 18
    public static let leftIndex = 19
    public static let rightIndex = 20
    public static let leftThumb = 21
    public static let rightThumb = 22
    public static let leftHip = 23
    public static let rightHip = 24
    public static let leftKnee = 25
    public static let rightKnee = 26
    public static let leftAnkle = 27
    public static let rightAnkle = 28
    public static let leftHeel = 29
    public static let rightHeel = 30
    public static let leftFootIndex = 31
    public static let rightFootIndex = 32

    public static let count = 33

    /// Chỉ số khớp ĐỐI XỨNG qua trục dọc cơ thể. Dùng khi lật ảnh gương.
    ///
    /// Danh sách của MediaPipe xếp thành từng cặp trái-phải liền nhau: mũi đứng một mình ở 0, rồi
    /// 1↔4, 2↔5, 3↔6 (ba điểm quanh mắt), 7↔8 (tai), 9↔10 (khoé miệng), và từ 11 trở đi là các cặp
    /// lẻ-chẵn liền kề.
    public static func mirrorIndex(_ i: Int) -> Int {
        switch i {
        case nose: return nose
        case leftEyeInner...leftEyeOuter: return i + 3
        case rightEyeInner...rightEyeOuter: return i - 3
        case leftEar...rightFootIndex: return i % 2 == 1 ? i + 1 : i - 1
        default: return i
        }
    }

    /// Các cặp điểm nối thành xương, dùng để vẽ khung xương lên màn hình.
    public static let bones: [(Int, Int)] = [
        // Thân
        (leftShoulder, rightShoulder),
        (leftShoulder, leftHip),
        (rightShoulder, rightHip),
        (leftHip, rightHip),
        // Tay
        (leftShoulder, leftElbow), (leftElbow, leftWrist),
        (rightShoulder, rightElbow), (rightElbow, rightWrist),
        // Chân
        (leftHip, leftKnee), (leftKnee, leftAnkle), (leftAnkle, leftHeel),
        (leftHeel, leftFootIndex),
        (rightHip, rightKnee), (rightKnee, rightAnkle), (rightAnkle, rightHeel),
        (rightHeel, rightFootIndex),
        // Mặt
        (nose, leftEye), (leftEye, leftEar),
        (nose, rightEye), (rightEye, rightEar),
        (mouthLeft, mouthRight),
    ]
}

/// Một khung hình đã được đo. Đây là thứ DUY NHẤT các tầng trên được phép dùng — không tầng nào
/// được chạm thẳng vào kiểu dữ liệu của MediaPipe.
public struct PoseFrame: Equatable, Sendable {
    /// 33 điểm trên khung hình, theo quy ước đã chốt (y hướng XUỐNG).
    public let points: [P2]
    /// Độ tin cậy từng điểm, 0..1. Điểm nằm ngoài khung vẫn được trả về nhưng tin cậy thấp.
    public let visibility: [Float]
    /// 33 điểm trong không gian thật (mét), gốc = trung điểm hai hông. Rỗng nếu không có.
    public let world: [P3]
    /// Thời điểm khung hình được chụp, mili-giây.
    public let timestampMs: Int64

    public init(points: [P2], visibility: [Float], world: [P3], timestampMs: Int64) {
        self.points = points
        self.visibility = visibility
        self.world = world
        self.timestampMs = timestampMs
    }

    public static let empty = PoseFrame(points: [], visibility: [], world: [], timestampMs: 0)

    public var isEmpty: Bool { points.isEmpty }

    /// Lấy điểm nếu độ tin cậy đủ cao VÀ toạ độ còn nằm trong khung, ngược lại trả nil.
    public func at(_ index: Int, _ minVisibility: Float) -> P2? {
        guard points.indices.contains(index) else { return nil }
        if visibility[index] < minVisibility { return nil }
        let p = points[index]
        // MediaPipe vẫn trả về điểm NGOÀI khung bằng ngoại suy. Chỉ kiểm độ tin cậy là chưa đủ — phải
        // kiểm cả toạ độ, nếu không ảnh chân dung sẽ bị nhận nhầm thành ảnh toàn thân.
        if p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 { return nil }
        return p
    }

    /// LẬT NGANG khung xương — dùng cho ẢNH CHỤP QUA GƯƠNG.
    ///
    /// Ảnh gương là ảnh của một người bị lật ngang. Bộ nhận diện đặt tên khớp theo GIẢI PHẪU, nên với
    /// ảnh gương nó gọi tay PHẢI thật của người đó là `leftWrist`. Hàm này đưa mọi thứ về không gian
    /// chuẩn — cảnh sẽ trông thế nào nếu không có gương. Ảnh mẫu và khung camera mỗi bên tự quy về đó,
    /// rồi mới so.
    ///
    /// Ba việc phải làm cùng lúc:
    /// 1. Toạ độ ảnh: `x → 1 - x`
    /// 2. Toạ độ thật: `x → -x`
    /// 3. **Hoán đổi nhãn TRÁI ↔ PHẢI của mọi khớp** — thiếu bước này là góc xoay thân đảo dấu và mọi câu
    ///    về tay chân chỉ nhầm bên, không có gì báo.
    ///
    /// ⚠️ Việc lật này làm ĐẢO CHIỀU hai câu nhắc: lệch trái/phải và nghiêng ngang. Xem `CuePresenter`.
    public func mirrored() -> PoseFrame {
        if isEmpty { return self }
        var p = Array(repeating: P2(0.0, 0.0), count: points.count)
        var v = Array(repeating: Float(0), count: visibility.count)
        var w = Array(repeating: P3(0.0, 0.0, 0.0), count: world.count)
        for i in points.indices {
            let j = Lm.mirrorIndex(i)
            p[j] = P2(1.0 - points[i].x, points[i].y)
            v[j] = visibility[i]
            if world.indices.contains(i) {
                let it = world[i]
                w[j] = P3(-it.x, it.y, it.z)
            }
        }
        return PoseFrame(points: p, visibility: v, world: w, timestampMs: timestampMs)
    }

    /// CẮT KHUNG VỀ ĐÚNG TỈ LỆ CỦA ẢNH MẪU, rồi quy toạ độ theo khung đã cắt.
    ///
    /// Toạ độ khớp là tỉ lệ so với khung hình chứa nó. Không đưa ảnh mẫu và camera về chung một tỉ lệ
    /// thì mục lệch trái/phải và máy cao/thấp đang so hai thứ không so được.
    ///
    /// Cắt phần GIỮA khung sao cho tỉ lệ còn lại đúng bằng `targetAspect`, rồi quy toạ độ về khung mới.
    /// Điểm rơi ra ngoài phần cắt có toạ độ ngoài `0..1` và bị `at` loại — đúng như khi nó nằm ngoài
    /// khung ảnh thật. Toạ độ THẬT (`world`) không đụng tới: tính bằng mét, không phụ thuộc khung.
    ///
    /// - Parameters:
    ///   - targetAspect: tỉ lệ ngang/dọc của ẢNH MẪU
    ///   - frameAspect: tỉ lệ ngang/dọc của KHUNG HÌNH hiện tại
    public func croppedToAspect(_ targetAspect: Double, _ frameAspect: Double) -> PoseFrame {
        if isEmpty { return self }
        if targetAspect <= 0 || frameAspect <= 0 { return self }
        // Lệch dưới 1% thì cắt cũng như không — bỏ qua cho đỡ tính thừa.
        if abs(targetAspect - frameAspect) / frameAspect < 0.01 { return self }

        var pts: [P2] = []
        pts.reserveCapacity(points.count)
        if targetAspect < frameAspect {
            // Ảnh mẫu HẸP hơn khung → cắt hai bên.
            let f = targetAspect / frameAspect
            let edge = (1.0 - f) / 2.0
            for p in points { pts.append(P2((p.x - edge) / f, p.y)) }
        } else {
            // Ảnh mẫu RỘNG hơn khung → cắt trên dưới.
            let f = frameAspect / targetAspect
            let edge = (1.0 - f) / 2.0
            for p in points { pts.append(P2(p.x, (p.y - edge) / f)) }
        }
        return PoseFrame(points: pts, visibility: visibility, world: world, timestampMs: timestampMs)
    }

    public func world(_ index: Int, _ minVisibility: Float) -> P3? {
        guard world.indices.contains(index) else { return nil }
        if visibility[index] < minVisibility { return nil }
        return world[index]
    }

    /// Điểm CỔ — MediaPipe không có sẵn, phải suy ra từ trung điểm hai vai (FOOTGUNS 4).
    public func neck(_ minVisibility: Float) -> P2? {
        guard let l = at(Lm.leftShoulder, minVisibility),
              let r = at(Lm.rightShoulder, minVisibility) else { return nil }
        return (l + r) / 2.0
    }

    /// Điểm GỐC THÂN (giữa hai hông) — cũng phải suy ra, cùng lý do như `neck`.
    public func root(_ minVisibility: Float) -> P2? {
        guard let l = at(Lm.leftHip, minVisibility),
              let r = at(Lm.rightHip, minVisibility) else { return nil }
        return (l + r) / 2.0
    }

    /// Góc xoay thân quanh trục đứng, ĐỘ. 0 = mẫu quay thẳng mặt vào máy.
    ///
    /// Dùng toạ độ 3 chiều thật nên `atan2` ổn định ở MỌI góc — không có điểm kỳ dị.
    ///
    /// ⚠️ CHƯA KIỂM CHỨNG TRÊN MÁY THẬT. `world` là kết quả model ƯỚC LƯỢNG, không phải đo đạc.
    public func bodyYawDeg(_ minVisibility: Float) -> Double? {
        guard let l = world(Lm.leftShoulder, minVisibility),
              let r = world(Lm.rightShoulder, minVisibility) else { return nil }

        // THỨ TỰ HAI VAI QUYẾT ĐỊNH GỐC 0° (FOOTGUNS 13). Đảo thứ tự là lệch đúng 180°.
        //
        // Mẫu nhìn thẳng vào máy thì vai-TRÁI-giải-phẫu nằm ở bên PHẢI ảnh (x lớn hơn), hai vai cùng độ
        // sâu z. Vậy atan2(l.z − r.z, l.x − r.x) = atan2(0, số dương) = 0°. Viết ngược thành (r − l) ra
        // 180° — mẫu nhìn thẳng vào máy mà máy báo "đang quay lưng".
        //
        // ⚠️ CÒN PHẢI KIỂM DẤU trái/phải trên máy thật: gốc 0° đã đúng, nhưng nghiêng sang trái ra số âm
        // hay dương thì chưa xác nhận.
        return toDegrees(atan2(l.z - r.z, l.x - r.x))
    }

    /// Bề rộng vai biểu kiến trên khung hình — dùng để theo dõi độ ổn định phép đo.
    public func shoulderSpanNormalized(_ minVisibility: Float) -> Double? {
        guard let l = at(Lm.leftShoulder, minVisibility),
              let r = at(Lm.rightShoulder, minVisibility) else { return nil }
        return hypot(r.x - l.x, r.y - l.y)
    }

    /// Chiều cao mẫu ước lượng theo MÉT, suy từ toạ độ thật.
    public func bodyHeightMeters(_ minVisibility: Float) -> Double? {
        guard let nose = world(Lm.nose, minVisibility) else { return nil }
        let la = world(Lm.leftAnkle, minVisibility)
        let ra = world(Lm.rightAnkle, minVisibility)
        guard let ankleY = [la?.y, ra?.y].compactMap({ $0 }).max() else { return nil }
        // Gốc toạ độ ở hông; y hướng xuống. Bù thêm phần đỉnh đầu phía trên mũi.
        return (ankleY - nose.y) * 1.08
    }

    /// Khung bao chủ thể (chỉ tính điểm còn trong khung), dùng để suy lớp khung hình.
    public func subjectBox(_ minVisibility: Float) -> Box? {
        var minX = Double.greatestFiniteMagnitude; var maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude; var maxY = -Double.greatestFiniteMagnitude
        var found = false
        for i in points.indices {
            guard let p = at(i, minVisibility) else { continue }
            found = true
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        return found ? Box(left: minX, top: minY, right: maxX, bottom: maxY) : nil
    }
}

/// Khung bao, theo quy ước toạ độ đã chốt (y hướng xuống).
public struct Box: Equatable, Sendable {
    public let left: Double
    public let top: Double
    public let right: Double
    public let bottom: Double

    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    public var width: Double { right - left }
    public var height: Double { bottom - top }
}

/// Tương đương `Math.toDegrees` của Java: `angrad * RADIANS_TO_DEGREES` với hằng số tính sẵn 180/π.
/// ⚠️ Không viết `x * 180 / .pi` — thứ tự phép tính khác, có thể lệch ở chữ số cuối.
func toDegrees(_ angrad: Double) -> Double {
    angrad * (180.0 / Double.pi)
}
