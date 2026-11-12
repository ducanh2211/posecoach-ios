import PoseDomain
import SwiftUI

/// MÀN CHỜ XÁO THẺ (17/10/2026, PO duyệt) — thay vòng xoay "Đang phân tích…" của luồng đề xuất theo bối cảnh. Port
/// `KT/scene/XaoTheOverlay.kt`.
///
/// Trong lúc app THẬT SỰ đang phân tích, một dải thẻ ảnh mẫu (lấy ngẫu nhiên trong thư viện) cuộn ngang liên tục; thẻ giữa
/// to, hai bên nhỏ dần và hơi xoay. Phân tích xong thì dải chậm dần, dừng lần lượt ở hạng 1 → 2 → 3 (kết quả xếp hạng
/// THẬT, kèm % hợp bối cảnh), rồi cả lớp trượt xuống nhường chỗ cho danh sách đề xuất.
///
/// - Phân tích xong dưới `treHienMs`: không hiện gì — tránh nháy màn.
/// - Đã hiện thì cuộn tối thiểu `xaoToiThieuMs`.
/// - Có kết quả rồi thì chạm màn hình là bỏ qua phần dừng thẻ.
/// - Huỷ, lỗi, hoặc không có ảnh hợp: kết thúc ngay, danh sách tự hiện phần gõ chữ như cũ.
///
/// Chỉ là phần TRÌNH DIỄN: không đổi cách phân tích hay xếp hạng.
///
/// Khác Android: `Animatable` → `XaoTheModel.Tween` (giá trị theo thời gian, vẽ bằng `TimelineView`); coroutine chạy theo
/// `rememberUpdatedState` → model giữ giá trị mới nhất của `analyzing` / `matches`.
struct XaoTheOverlay: View {

    let analyzing: Bool
    let matches: [SceneMatch]
    let progress: UiText?
    let onCancel: () -> Void

    @State private var m = XaoTheModel()

    var body: some View {
        Group {
            if m.hien { overlay }
        }
        .task { await m.napThuVien() }
        .onChange(of: analyzing, initial: true) { m.capNhat(analyzing: analyzing, matches: matches) }
        .onChange(of: matches) { m.capNhat(analyzing: analyzing, matches: matches) }
    }

    private var overlay: some View {
        TimelineView(.animation) { ctx in
            let viTri = m.viTri.value(at: ctx.date)
            let thoat = m.thoat.value(at: ctx.date)
            GeometryReader { geo in
                let rongThe = min(geo.size.width * 0.52, 240)
                let caoThe = rongThe * 1.45
                let giua = Int(viTri.rounded(.down))
                ZStack {
                    ForEach((giua - 4)...(giua + 5), id: \.self) { i in
                        if let file = m.datThe[i] ?? m.theVong(i) {
                            the(file, hang: m.nhan[i], rong: rongThe, cao: caoThe, d: Double(i) - viTri)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay(alignment: .bottom) { chuDuoi }
                .background(Color(argb: 0xF2101114).ignoresSafeArea())
                .offset(y: thoat * geo.size.height * 0.35)
            }
            .opacity(1 - thoat)
        }
        .contentShape(Rectangle())
        // Có kết quả rồi mới bỏ qua được — đang phân tích thì chạm không làm gì.
        .onTapGesture { m.boQua() }
    }

    private func the(_ file: URL, hang: (Int, Int)?, rong: CGFloat, cao: CGFloat, d: Double) -> some View {
        let ad = abs(d)
        let s = max(1 - 0.16 * ad, 0.45)
        let shape = RoundedRectangle(cornerRadius: 18)
        return AsyncThumb(file: file)
            .frame(width: rong, height: cao)
            .clipShape(shape)
            .overlay(shape.strokeBorder(hang != nil ? Color(argb: 0xFFFFC94D) : Color(argb: 0x55FFFFFF),
                                        lineWidth: hang != nil ? 3 : 1))
            .overlay(alignment: .top) {
                if let hang {
                    Text(uiText("scene_rank_badge", .int(hang.0), .int(hang.1)))
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Color(argb: 0xFF1B1B1B))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color(argb: 0xFFFFC94D), in: Capsule())
                        .padding(.top, 10)
                }
            }
            .scaleEffect(s)
            .rotationEffect(.degrees(d * 6))
            .opacity(min(max(1 - 0.2 * ad, 0), 1))
            .offset(x: d * rong * 0.62)
            .zIndex(-ad)
    }

    private var chuDuoi: some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey(m.coKetQua ? "scene_shuffle_found" : "scene_shuffle_title"))
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            if !m.coKetQua {
                if let progress {
                    Text(progress).font(.system(size: 12)).foregroundStyle(Color(argb: 0xB3FFFFFF))
                }
                Button {
                    m.huy = true
                    onCancel()
                } label: {
                    Text(LocalizedStringKey("scene_cancel")).foregroundStyle(.white).padding(8)
                }
                .buttonStyle(.plain)
            } else {
                Text(LocalizedStringKey("scene_tap_skip"))
                    .font(.system(size: 12)).foregroundStyle(Color(argb: 0x99FFFFFF))
                    .padding(.top, 4)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Ds.pageH)
        .padding(.bottom, 28)
    }
}

/// Trạng thái + kịch bản chuyển động của `XaoTheOverlay`.
@Observable @MainActor private final class XaoTheModel {

    /// Phân tích xong nhanh hơn mức này thì không hiện màn xáo.
    static let treHienMs = 300
    /// Đã hiện thì xáo ít nhất chừng này, để không nháy.
    static let xaoToiThieuMs = 1_500.0
    /// Mỗi bước dịch một thẻ khi đang xáo.
    static let buocXaoMs = 110
    /// Thẻ hạng 1 được đặt cách thẻ đang giữa chừng này chỗ — đủ xa để còn thấy dải chậm dần.
    static let khoangHam = 9

    private(set) var thuVien: [URL] = []
    private(set) var hien = false
    var huy = false
    private(set) var coKetQua = false
    private(set) var viTri = Tween(0)
    private(set) var thoat = Tween(0)
    /// Thẻ được ĐẶT VÀO một chỗ trong dải (hạng 1-3); còn lại lấy vòng quanh thư viện.
    private(set) var datThe: [Int: URL] = [:]
    /// Nhãn hạng đang hiện trên thẻ: chỗ trong dải → (hạng, % hợp).
    private(set) var nhan: [Int: (Int, Int)] = [:]

    @ObservationIgnored private var dangPhanTich = false
    @ObservationIgnored private var ketQua: [SceneMatch] = []
    @ObservationIgnored private var cho: Task<Void, Never>?
    @ObservationIgnored private var viec: Task<Void, Never>?

    func napThuVien() async {
        thuVien = await Task.detached { MediaLibrary.templates().map(\.file).shuffled() }.value
        if dangPhanTich { henHien() }
    }

    func theVong(_ i: Int) -> URL? {
        if thuVien.isEmpty { return nil }
        let n = thuVien.count
        return thuVien[((i % n) + n) % n]  // Math.floorMod
    }

    func capNhat(analyzing: Bool, matches: [SceneMatch]) {
        let doi = analyzing != dangPhanTich
        dangPhanTich = analyzing
        ketQua = matches
        if doi && analyzing { henHien() }
    }

    /// Chỉ hiện khi phân tích kéo dài quá `treHienMs`.
    private func henHien() {
        guard dangPhanTich, !hien, !thuVien.isEmpty, cho == nil else { return }
        cho = Task {
            defer { cho = nil }
            try? await Task.sleep(for: .milliseconds(Self.treHienMs))
            guard !Task.isCancelled, dangPhanTich, !hien else { return }
            huy = false
            coKetQua = false
            datThe = [:]
            nhan = [:]
            viTri = Tween(0)
            thoat = Tween(0)
            hien = true
            chay()
        }
    }

    private func chay() {
        viec = Task {
            let batDau = Date()
            // --- Xáo: chạy suốt thời gian phân tích, tối thiểu `xaoToiThieuMs` ---
            while !huy && (dangPhanTich || Date().timeIntervalSince(batDau) * 1000 < Self.xaoToiThieuMs) {
                if !(await animate(\.viTri, viTri.to + 1, Self.buocXaoMs, .linear)) { return }
            }
            let top = Array(ketQua.prefix(3))
            if huy || top.isEmpty { await ketThuc(nhanh: true); return }
            // --- Dừng lần lượt ở hạng 1 → 3 ---
            coKetQua = true
            let hienTai = viTri.value(at: Date())
            let dich = Int((hienTai + 0.5).rounded(.down)) + Self.khoangHam  // roundToInt
            datThe = Dictionary(uniqueKeysWithValues: top.enumerated().map { (dich + $0.offset, $0.element.template.file) })
            if !(await animate(\.viTri, Double(dich), 1_300, .fastOutSlowIn)) { return }
            for (k, match) in top.enumerated() {
                if k > 0, !(await animate(\.viTri, Double(dich + k), 450, .fastOutSlowIn)) { return }
                nhan[dich + k] = (k + 1, match.phanTramHop)
                guard (try? await Task.sleep(for: .milliseconds(k == 0 ? 650 : 450))) != nil else { return }
            }
            guard (try? await Task.sleep(for: .milliseconds(350))) != nil else { return }
            await ketThuc(nhanh: false)
        }
    }

    func boQua() {
        guard coKetQua else { return }
        viec?.cancel()
        Task { await ketThuc(nhanh: true) }
    }

    private func ketThuc(nhanh: Bool) async {
        _ = await animate(\.thoat, 1, nhanh ? 250 : 450, .fastOutSlowIn)
        hien = false
    }

    /// Như `Animatable.animateTo(target, tween(ms, easing))`: chạy từ giá trị hiện tại tới `target`, chờ xong. `false` =
    /// bị huỷ giữa chừng.
    private func animate(_ key: ReferenceWritableKeyPath<XaoTheModel, Tween>, _ target: Double, _ ms: Int,
                         _ easing: Tween.Easing) async -> Bool {
        let now = Date()
        self[keyPath: key] = Tween(from: self[keyPath: key].value(at: now), to: target, start: now,
                                   duration: Double(ms) / 1000, easing: easing)
        return (try? await Task.sleep(for: .milliseconds(ms))) != nil
    }

    /// Một giá trị chạy từ `from` tới `to` trong `duration` giây kể từ `start`.
    struct Tween {
        enum Easing { case linear, fastOutSlowIn }

        var from: Double
        var to: Double
        var start: Date
        var duration: Double
        var easing: Easing

        init(_ v: Double) {
            self.init(from: v, to: v, start: .distantPast, duration: 0, easing: .linear)
        }

        init(from: Double, to: Double, start: Date, duration: Double, easing: Easing) {
            self.from = from
            self.to = to
            self.start = start
            self.duration = duration
            self.easing = easing
        }

        func value(at t: Date) -> Double {
            if duration <= 0 { return to }
            let p = min(max(t.timeIntervalSince(start) / duration, 0), 1)
            let e = easing == .linear ? p : Self.cubicBezier(0.4, 0, 0.2, 1, p)
            return from + (to - from) * e
        }

        /// `CubicBezierEasing(x1, y1, x2, y2)` — `FastOutSlowInEasing` = (0,4; 0; 0,2; 1).
        private static func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
            func bez(_ a: Double, _ b: Double, _ t: Double) -> Double {
                3 * a * t * (1 - t) * (1 - t) + 3 * b * t * t * (1 - t) + t * t * t
            }
            var lo = 0.0, hi = 1.0
            for _ in 0..<30 {
                let mid = (lo + hi) / 2
                if bez(x1, x2, mid) < x { lo = mid } else { hi = mid }
            }
            return bez(y1, y2, (lo + hi) / 2)
        }
    }
}
