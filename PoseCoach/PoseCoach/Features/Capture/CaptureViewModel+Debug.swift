#if DEBUG
import Foundation
import PoseDomain

/// SỐ ĐO THÔ HIỆN LÊN MÀN CHỤP — chỉ có ở bản Debug, để đối chiếu iOS ↔ Android trên máy thật (13/11/2026).
///
/// Hai dòng đầu chép ĐÚNG định dạng `debugGocMay` / `debugDo` của Android (`CaptureViewModel.kt:388–410`) để đặt hai
/// máy cạnh nhau so từng số. Khác: iOS không chạy GeoCalib trên màn chụp (D7) nên phần đó luôn `n/a`. Số thực in theo
/// POSIX (dấu chấm); Android in theo ngôn ngữ máy (máy tiếng Việt ra dấu phẩy).
///
/// Dòng thứ ba chỉ iOS có — khung đưa vào nhận diện, zoom, độ lệch từng tiêu chí.
extension CaptureViewModel {

    /// `CAM ANGLE   sensor …   ·   GeoCalib …` — `camBien` đã đảo dấu cho camera trước.
    static func debugGocMay(_ camBien: Double?) -> String {
        "CAM ANGLE   sensor " + dau(camBien) + "   ·   GeoCalib n/a"
    }

    /// `m3 ảnh mẫu/live  m4 …  size …  vFOV …` — y như Android.
    static func debugDo(_ t: PoseMeasurement?, _ l: PoseMeasurement?, _ vFovDeg: Double?) -> String? {
        guard let t, let l else { return nil }
        // m4: số sau là CẢM BIẾN. cỡ: có chữ "f" là đang so bằng khung mặt.
        let coM = t.scale == nil && t.faceScale != nil
        return "m3 " + dau(t.elevationDeg) + "/" + dau(l.elevationDeg) +
            "  m4 " + dau(t.tiltDeg) + "/" + dau(l.tiltDeg) +
            "  size" + (coM ? "f " : " ") +
            (coM ? hai(t.faceScale) + "/" + hai(l.faceScale) : hai(t.scale) + "/" + hai(l.scale)) +
            "  vFOV " + (vFovDeg.map { String(format: "%.0f", $0) } ?? "65?")
    }

    /// Dòng riêng iOS. Ký hiệu tiêu chí: ✓ đạt · ~ vùng xám · ✗ trượt · ? chưa đo; số là `độ lệch/accept`.
    static func debugChiTiet(
        inW: Int, inH: Int, cropW: Int, cropH: Int, zoom: Float, visible: Int, ms: Int64, deviceRoll: Double?,
        t: PoseMeasurement?, l: PoseMeasurement?, statuses: [CriterionStatus]
    ) -> String {
        var dong1 = "in \(inW)×\(inH) → \(cropW)×\(cropH)  zoom " + String(format: "%.2f", zoom) +
            "  vis \(visible)/33  \(ms)ms  devRoll " + dau(deviceRoll)
        if let t, let l {
            dong1 += "\nyaw " + dau(t.yawDeg) + "/" + dau(l.yawDeg) +
                "  face " + dau(t.faceYawDeg) + "/" + dau(l.faceYawDeg) +
                "  cx " + hai(t.centerX) + "/" + hai(l.centerX)
            // Nguồn đo: cái ĐẦU TIÊN cả hai bên cùng có — đúng thứ tự `ShotScorer.deviation` chọn để so.
            let persp = PerspectiveSource.allCases.first { t.perspectiveIndex[$0] != nil && l.perspectiveIndex[$0] != nil }
            let roll = RollSource.allCases.first { t.rollDeg[$0] != nil && l.rollDeg[$0] != nil }
            dong1 += "\npersp" + (persp.map { "[\($0)] " + hai(t.perspectiveIndex[$0]) + "/" + hai(l.perspectiveIndex[$0]) }
                ?? " -- (mẫu " + nguon(t.perspectiveIndex) + " · live " + nguon(l.perspectiveIndex) + ")") +
                "  roll" + (roll.map { "[\($0)] " + dau(t.rollDeg[$0]) + "/" + dau(l.rollDeg[$0]) }
                ?? " -- (mẫu " + nguon(t.rollDeg) + " · live " + nguon(l.rollDeg) + ")") +
                "  poseΔ " + dau(ShotScorer.deviation(t, l).poseDeg).replacingOccurrences(of: "+", with: "") + "°"
        }
        let tieuChi = statuses.map { s -> String in
            let kyHieu = switch s.state {
            case .passing: "✓"
            case .grey: "~"
            case .failing: "✗"
            case .unmeasured: "?"
            }
            return "\(s.criterion) \(kyHieu)" + hai(s.deviation) + "/" + hai(s.band?.accept)
        }
        return tieuChi.isEmpty ? dong1 : dong1 + "\n" + tieuChi.joined(separator: "  ")
    }

    /// Các nguồn đo một bên có — để thấy vì sao hai bên không có nguồn chung.
    private static func nguon<K>(_ d: [K: Double]) -> String {
        d.isEmpty ? "∅" : d.keys.map { "\($0)" }.sorted().joined(separator: ",")
    }

    private static func dau(_ v: Double?) -> String { v.map { String(format: "%+.0f", $0) } ?? "--" }
    private static func hai(_ v: Double?) -> String { v.map { String(format: "%.2f", $0) } ?? "--" }
}
#endif
