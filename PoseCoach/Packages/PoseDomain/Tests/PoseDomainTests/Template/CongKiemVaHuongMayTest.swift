import Testing
@testable import PoseDomain

/// Port từ `KTT/CongKiemVaHuongMayTest.kt` — hai lỗi PO báo 12/09/2026:
/// 1. Cổng kiểm từ chối oan ảnh khuất vai nhưng rõ mặt (FOOTGUNS 68).
/// 2. Hướng máy dọc/ngang nhảy loạn khi chúc máy.
///
/// ⚠️ Phần 2 của bản Kotlin kiểm một BẢN CHÉP bộ chống rung hướng máy (hàm `chay` riêng trong test, giữ 400ms) —
/// port nguyên như vậy. Bộ chống rung thật nằm ở tầng camera (Phase 3).
struct CongKiemVaHuongMayTest {

    private func roMat() -> PoseFrame {
        frameOf(
            (Lm.nose, lm(0.50, 0.46)),
            (Lm.leftEye, lm(0.60, 0.30)),
            (Lm.rightEye, lm(0.40, 0.30)),
            (Lm.leftEar, lm(0.72, 0.34)),
            (Lm.rightEar, lm(0.28, 0.34)),
            (Lm.mouthLeft, lm(0.57, 0.66)),
            (Lm.mouthRight, lm(0.43, 0.66))
        )
    }

    @Test("ảnh khuất vai nhưng RÕ MẶT thì phải NHẬN, không được từ chối")
    func khuatVaiRoMatNhan() {
        let v = TemplateGate.check(roMat())
        guard case .accepted = v else {
            Issue.record("Ảnh rõ mặt mà bị từ chối — đúng lỗi PO báo. Nhận được: \(v)")
            return
        }
    }

    @Test("ảnh khuất vai phải kèm CẢNH BÁO nói rõ bỏ qua mục nào")
    func khuatVaiCanhBao() throws {
        guard case let .accepted(v) = TemplateGate.check(roMat()) else {
            Issue.record("Phải nhận")
            return
        }
        #expect(v.hasWarnings, "Phải có cảnh báo, nhận được \(v.warnings)")
        #expect(v.warnings.contains { $0.vi().localizedCaseInsensitiveContains("vai") }, "Cảnh báo phải nhắc tới vai")
    }

    @Test("không thấy CẢ vai LẪN mặt thì mới từ chối")
    func khongThayVaiLanMat() {
        let chiCoChan = frameOf(
            (Lm.leftKnee, lm(0.55, 0.60)),
            (Lm.rightKnee, lm(0.45, 0.60)),
            (Lm.leftAnkle, lm(0.55, 0.90)),
            (Lm.rightAnkle, lm(0.45, 0.90))
        )
        guard case .rejected = TemplateGate.check(chiCoChan) else {
            Issue.record("Phải từ chối")
            return
        }
    }

    @Test("ảnh thấy rõ vai vẫn nhận bình thường, không sinh cảnh báo thừa")
    func thayVaiNhanBinhThuong() {
        let toanThan = frameOf(
            (Lm.nose, lm(0.50, 0.10)),
            (Lm.leftEye, lm(0.52, 0.09)),
            (Lm.rightEye, lm(0.48, 0.09)),
            (Lm.leftShoulder, lm(0.58, 0.22, 0.18, -0.45)),
            (Lm.rightShoulder, lm(0.42, 0.22, -0.18, -0.45)),
            (Lm.leftHip, lm(0.55, 0.52, 0.11, 0.0)),
            (Lm.rightHip, lm(0.45, 0.52, -0.11, 0.0)),
            (Lm.leftKnee, lm(0.55, 0.72, 0.11, 0.42)),
            (Lm.rightKnee, lm(0.45, 0.72, -0.11, 0.42)),
            (Lm.leftAnkle, lm(0.55, 0.92, 0.11, 0.85)),
            (Lm.rightAnkle, lm(0.45, 0.92, -0.11, 0.85))
        )
        guard case let .accepted(v) = TemplateGate.check(toanThan) else {
            Issue.record("Phải nhận")
            return
        }
        #expect(v.framing == .full)
        #expect(!v.warnings.contains { $0.vi().localizedCaseInsensitiveContains("hai vai") }, "Ảnh đủ vai mà vẫn cảnh báo về vai: \(v.warnings)")
    }

    // MARK: - Chống rung hướng máy (bản chép của test Kotlin)

    private let giuMs: Int64 = 400

    private func chay(_ hienTai: String, _ mau: [(Int64, String)]) -> String {
        var cur = hienTai
        var cho: String?
        var choTu: Int64 = 0
        for (t, doc) in mau {
            if doc == cur { cho = nil; continue }
            if doc != cho { cho = doc; choTu = t; continue }
            if t - choTu < giuMs { continue }
            cho = nil
            cur = doc
        }
        return cur
    }

    @Test("nhiễu chớp nhoáng khi chúc máy KHÔNG được đổi hướng")
    func nhieuChopNhoang() {
        let mau: [(Int64, String)] = (0..<40).map { i in
            let nhieu = i % 7 == 3 || i % 7 == 4
            return (Int64(i) * 50, nhieu ? "ngang" : "doc")
        }
        #expect(chay("doc", mau) == "doc", "Rung do chúc máy không được làm đổi hướng — đúng lỗi PO báo")
    }

    @Test("xoay máy THẬT thì vẫn phải đổi hướng")
    func xoayMayThat() {
        let mau: [(Int64, String)] = (0..<40).map { i in (Int64(i) * 50, i < 4 ? "doc" : "ngang") }
        #expect(chay("doc", mau) == "ngang")
    }

    @Test("đổi hướng chậm nhất sau 400ms, không lâu hơn")
    func doiHuongSau400ms() {
        #expect(chay("doc", (0..<40).map { (Int64($0) * 50, "ngang") }) == "ngang")
        #expect(chay("doc", (0..<7).map { (Int64($0) * 50, "ngang") }) == "doc")
    }
}
