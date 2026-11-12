import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/ThoiQuenChupTest.kt` — THÓI QUEN CỦA NGƯỜI CHỤP: tự đưa máy theo ảnh mẫu trước khi được hướng dẫn,
/// mất dấu người không tính vào giờ bỏ qua bước (FOOTGUNS 93), ảnh mẫu góc gắt bỏ độ méo (FOOTGUNS 99).
struct ThoiQuenChupTest {

    private let minVis: Float = 0.5

    /// ⚠️ LỆCH BẢN KOTLIN: Kotlin dùng −40°. Ở −40° đoạn hông→cổ chân của khung live chĩa vào ống kính ĐÚNG 40°
    /// — trùng mốc `Measurer.maxOutOfPlaneDeg` (so `<=`), lệch 1 ULP của sin/cos là đổi kết quả. JVM ra hơi trên
    /// 40° (bỏ mục chân → mục ngửa/chúc không đo được → test xanh), libm của Darwin ra đúng 40,0 (giữ mục chân →
    /// mọi mục đạt → test đỏ). Dời sang −41° để test không phụ thuộc làm tròn; ý của test giữ nguyên: khung live
    /// lệch hẳn góc máy so với ảnh mẫu.
    private let gocLive = -41.0

    private func nguoi(_ gocDeg: Double) -> PoseFrame {
        let r = toRadians(-gocDeg)
        func w(_ y: Double) -> P3 { P3(0.0, y * cos(r), y * sin(r)) }
        func p(_ u: Double, _ v: Double, _ y: Double, _ x3: Double) -> (P2, Float, P3) {
            (P2(u, v), 0.99, P3(x3, w(y).y, w(y).z))
        }
        return frameOf(
            (Lm.nose, p(0.50, 0.10, -0.60, 0.0)),
            (Lm.leftEye, p(0.52, 0.09, -0.62, 0.03)),
            (Lm.rightEye, p(0.48, 0.09, -0.62, -0.03)),
            (Lm.leftShoulder, p(0.58, 0.22, -0.45, 0.18)),
            (Lm.rightShoulder, p(0.42, 0.22, -0.45, -0.18)),
            (Lm.leftHip, p(0.55, 0.52, 0.0, 0.11)),
            (Lm.rightHip, p(0.45, 0.52, 0.0, -0.11)),
            (Lm.leftKnee, p(0.55, 0.72, 0.42, 0.11)),
            (Lm.rightKnee, p(0.45, 0.72, 0.42, -0.11)),
            (Lm.leftAnkle, p(0.55, 0.92, 0.85, 0.11)),
            (Lm.rightAnkle, p(0.45, 0.92, 0.85, -0.11))
        )
    }

    private func profileCua(_ f: PoseFrame) throws -> TemplateProfile {
        TemplateProfile.from(f, try #require(FramingClass.detect(f, minVis)), minVis)
    }

    @Test("mất dấu không được tính vào sáu giây bỏ qua bước")
    func matDauKhongTinhGio() throws {
        let profile = try profileCua(nguoi(0.0))
        let engine = GuidanceEngine(profile)
        let live = Measurer.measure(nguoi(gocLive), profile.framing, minVis)
        var result = engine.update(live, 0, 0.0, allowSkip: true)
        var t: Int64 = 100
        while t <= 5_000 { result = engine.update(live, t, 0.0, allowSkip: true); t += 100 }
        #expect(result.statuses.contains { !$0.pending && !$0.skipped && $0.state != .passing },
                "Cần có bước chưa đạt để kiểm thời gian")
        let skippedBefore = result.statuses.filter(\.skipped).count
        engine.update(nil, 15_000, 0.0, allowSkip: true)
        result = engine.update(live, 15_100, 0.0, allowSkip: true)
        #expect(result.statuses.filter(\.skipped).count == skippedBefore, "Mất dấu không được làm hết giờ chờ")
    }

    @Test("không nói gì trong giây đầu, để user tự đưa máy theo template")
    func khongNoiGiayDau() throws {
        let profile = try profileCua(nguoi(0.0))
        let engine = GuidanceEngine(profile)
        let live = Measurer.measure(nguoi(gocLive), profile.framing, minVis)
        var t: Int64 = 0
        for _ in 0..<9 {
            t += 100
            let r = engine.update(live, t, 0.0)
            #expect(r.cue == nil, "t=\(t) app đã nói trong lúc user còn đang đưa máy: \(String(describing: r.cue))")
        }
    }

    @Test("qua giây đầu thì phải nói, không được câm luôn")
    func quaGiayDauPhaiNoi() throws {
        let profile = try profileCua(nguoi(0.0))
        let engine = GuidanceEngine(profile)
        let live = Measurer.measure(nguoi(gocLive), profile.framing, minVis)
        var cue: String?
        var t: Int64 = 0
        for _ in 0..<60 {
            t += 100
            cue = engine.update(live, t, 0.0).cue?.vi()
        }
        #expect(cue != nil, "Qua lúc đặt máy rồi mà app vẫn câm")
    }

    @Test("xoay thẳng máy rồi lùi và chỉnh góc trước khi zoom")
    func thuTuDayDu() {
        let thuTu = ([.pose, .pitch, .scale, .yaw, .perspective, .roll, .elevation, .center] as [Criterion])
            .sorted { (ordinal(guidanceStepOf($0)), ordinal($0)) < (ordinal(guidanceStepOf($1)), ordinal($1)) }
        #expect(thuTu == [.roll, .perspective, .elevation, .pitch, .scale, .center, .yaw, .pose])
        #expect(ordinal(guidanceStepOf(.pitch)) < ordinal(guidanceStepOf(.pose)))
    }

    private func profileCoNhan(_ goc: MediaLibrary.GocMayNhan?) throws -> TemplateProfile {
        let f = nguoi(0.0)
        return TemplateProfile.from(f, try #require(FramingClass.detect(f, minVis)), minVis, gocMayNhan: goc?.doNghieng)
    }

    @Test("ảnh mẫu ngang tầm vẫn đo độ méo để chọn chỗ đứng")
    func ngangTamVanDoMeo() throws {
        #expect(try profileCoNhan(.ngang).active.contains(.perspective))
    }

    @Test("ảnh mẫu chụp từ trên cao hoặc dưới thấp thì BỎ độ méo")
    func gocGatBoDoMeo() throws {
        for g: MediaLibrary.GocMayNhan in [.tren, .duoi] {
            let p = try profileCoNhan(g)
            #expect(!p.active.contains(.perspective), "\(g)")
            #expect(try #require(p.skipped[.perspective]).vi().contains("trên cao"), "\(g) phải nói rõ vì sao bỏ")
        }
    }

    @Test("ngưỡng góc gắt nằm GIỮA nhãn ngang và nhãn trên/dưới")
    func nguongGocGat() throws {
        let nguong = TemplateProfile.gocGatDeg
        let lech = MediaLibrary.GocMayNhan.allCases.map { abs($0.doNghieng) }
        #expect(nguong > lech.min()! + 5)
        #expect(nguong < lech.filter { $0 > 0 }.min()! - 3)
    }

    @Test("không có bước khoảng cách thì câu khung hình đưa cả hai lựa chọn")
    func khongBuocKhoangCach() throws {
        let profile = try profileCoNhan(.tren)
        let engine = GuidanceEngine(profile)
        var live = Measurer.measure(nguoi(0.0), profile.framing, minVis)
        live.scale = (live.scale ?? 0.5) * 0.6
        live.tiltDeg = -35.0
        live.pitchCue[.gocMay] = -35.0
        live.elevationDeg = Measurer.gocNhin(-35.0, live.elevationAnchorY, 65.0)
        let r = chayEngine(engine, live, den: 8_000)
        let scale = try #require(r.statuses.first { $0.criterion == .scale })
        #expect(scale.walkInsteadOfZoom)
    }
}
