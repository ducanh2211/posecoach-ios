import Foundation
@testable import PoseDomain

/// ĐỐI CHIẾU 6a — đọc số liệu THÔ của một ảnh mẫu (landmark, mặt, cỡ ảnh) từ tệp xuất của iOS HOẶC Android, rồi tính
/// lại cổng kiểm + số đo + hồ sơ tiêu chí bằng code iOS. Định dạng: `tools/so-sanh-parity/README.md`.
///
/// Đi đúng đường của `phanTichAnhMau` + `HomeViewModel.hienKetQua` ở app: `TemplateGate.check` → `TemplateProfile.from`
/// với nhãn góc máy / kiểu chụp trên đọc từ tên file. Mặt chỉ dùng khi ảnh qua cổng (như app).
enum Parity6a {

    /// Một mục trong tệp xuất. Chỉ đọc phần thô; phần tính (`gate`, `measurement`, `profile`) bị ghi đè.
    struct Raw {
        let json: [String: Any]
        var file: String { json["file"] as? String ?? "" }

        var frame: PoseFrame? {
            guard let lm = json["landmarks"] as? [[Any]], !lm.isEmpty else { return nil }
            let points = lm.map { P2(num($0[0]), num($0[1])) }
            let vis = lm.map { Float(num($0[2])) }
            let world = (json["world"] as? [[Any]] ?? []).map { P3(num($0[0]), num($0[1]), num($0[2])) }
            return PoseFrame(points: points, visibility: vis, world: world, timestampMs: 0)
        }

        var face: FaceInfo? {
            guard let f = json["face"] as? [String: Any] else { return nil }
            return FaceInfo(yawDeg: optNum(f["yawDeg"]), eyesOpen: optNum(f["eyesOpen"]))
        }
    }

    /// Tính lại phần dẫn xuất của một mục, trả mục mới (giữ nguyên phần thô).
    static func tinhLai(_ raw: Raw) -> [String: Any] {
        var out = raw.json
        let frame = raw.frame
        let verdict = TemplateGate.check(frame)
        out["gate"] = gate(verdict)
        guard let frame, case let .accepted(a) = verdict else {
            out["measurement"] = NSNull()
            out["profile"] = NSNull()
            return out
        }
        let ten = ((raw.file as NSString).lastPathComponent as NSString).deletingPathExtension
        let p = TemplateProfile.from(frame, a.framing, TemplateGate.coreVis, face: raw.face,
                                     gocMayNhan: MediaLibrary.gocMayTheoNhan(ten),
                                     kieuChupTren: MediaLibrary.kieuChupTrenTheoNhan(ten))
        out["measurement"] = measurement(p.measurement)
        out["profile"] = profile(p)
        return out
    }

    // MARK: - Ghi

    static func gate(_ v: TemplateVerdict) -> [String: Any] {
        switch v {
        case let .rejected(r):
            return ["level": "red", "framing": NSNull(), "reason": key(r.reason), "warnings": [String]()]
        case let .accepted(a):
            return ["level": a.hasWarnings ? "yellow" : "green", "framing": ten(a.framing), "reason": NSNull(),
                    "warnings": a.warnings.map(key)]
        }
    }

    static func measurement(_ m: PoseMeasurement) -> [String: Any] {
        [
            "framing": ten(m.framing),
            "scale": j(m.scale), "centerX": j(m.centerX), "tiltDeg": j(m.tiltDeg), "elevationDeg": j(m.elevationDeg),
            "yawDeg": j(m.yawDeg), "faceYawDeg": j(m.faceYawDeg), "eyesOpen": j(m.eyesOpen),
            "anchorHeightMeters": j(m.anchorHeightMeters),
            "rollDeg": dict(m.rollDeg), "pitchCue": dict(m.pitchCue), "perspectiveIndex": dict(m.perspectiveIndex),
            "poseAngles": Dictionary(uniqueKeysWithValues: m.poseAngles.map { (ten($0.key), $0.value.map { j($0) }) }),
            "elevationAnchorY": j(m.elevationAnchorY), "faceScale": j(m.faceScale),
            "tamThan": m.tamThan.map { $0 as Any } ?? NSNull(),
        ]
    }

    static func profile(_ p: TemplateProfile) -> [String: Any] {
        [
            "framing": ten(p.framing),
            "active": p.active.map(\.key).sorted(),
            "skipped": Dictionary(uniqueKeysWithValues: p.skipped.map { ($0.key.key, key($0.value)) }),
            "poseGroups": p.poseGroups.map { ten($0) }.sorted(),
            "kieuChupTren": p.kieuChupTren.map { ten($0) as Any } ?? NSNull(),
        ]
    }

    /// Tên case enum — so với Kotlin theo quy tắc 3b (bỏ `_`, không phân biệt hoa thường) ở script so sánh.
    static func ten<T>(_ v: T) -> String { "\(v)" }

    /// Mã câu của `UiText` (không kèm tham số).
    static func key(_ t: UiText) -> String {
        switch t {
        case let .res(k, _), let .plural(k, _, _): return k
        case let .join(parts, sep): return parts.map(key).joined(separator: sep)
        case let .raw(v): return v
        }
    }

    private static func dict<K>(_ d: [K: Double]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: d.map { (ten($0.key), j($0.value)) })
    }

    /// `nil` / NaN / vô cực → `null` (JSON không có NaN).
    private static func j(_ v: Double?) -> Any {
        guard let v, v.isFinite else { return NSNull() }
        return v
    }

    private static func num(_ a: Any) -> Double { (a as? NSNumber)?.doubleValue ?? .nan }
    private static func optNum(_ a: Any?) -> Double? { (a as? NSNumber)?.doubleValue }

    // MARK: - Tệp

    static func doc(_ url: URL) throws -> [Raw] {
        let data = try Data(contentsOf: url)
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return arr.map(Raw.init)
    }

    static func ghi(_ items: [[String: Any]], _ url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }
}
