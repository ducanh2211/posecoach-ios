import Foundation
import Testing
@testable import PoseDomain

/// Bước 6a — đối chiếu số đo với Android. Xem `tools/so-sanh-parity/README.md`.
struct Parity6aTest {

    /// Người đứng thẳng toàn thân, quay mặt vào máy.
    private func dungThang() -> PoseFrame {
        frameOf(
            (Lm.nose, lm(0.50, 0.14, 0, -0.62)),
            (Lm.leftEye, lm(0.52, 0.12, 0.03, -0.65)), (Lm.rightEye, lm(0.48, 0.12, -0.03, -0.65)),
            (Lm.leftEar, lm(0.55, 0.13, 0.07, -0.63)), (Lm.rightEar, lm(0.45, 0.13, -0.07, -0.63)),
            (Lm.mouthLeft, lm(0.515, 0.165, 0.02, -0.58)), (Lm.mouthRight, lm(0.485, 0.165, -0.02, -0.58)),
            (Lm.leftShoulder, lm(0.60, 0.25, 0.19, -0.45)), (Lm.rightShoulder, lm(0.40, 0.25, -0.19, -0.45)),
            (Lm.leftElbow, lm(0.63, 0.40, 0.22, -0.22)), (Lm.rightElbow, lm(0.37, 0.40, -0.22, -0.22)),
            (Lm.leftWrist, lm(0.64, 0.53, 0.23, 0.0)), (Lm.rightWrist, lm(0.36, 0.53, -0.23, 0.0)),
            (Lm.leftHip, lm(0.56, 0.52, 0.1, 0)), (Lm.rightHip, lm(0.44, 0.52, -0.1, 0)),
            (Lm.leftKnee, lm(0.56, 0.71, 0.1, 0.42)), (Lm.rightKnee, lm(0.44, 0.71, -0.1, 0.42)),
            (Lm.leftAnkle, lm(0.56, 0.89, 0.1, 0.82)), (Lm.rightAnkle, lm(0.44, 0.89, -0.1, 0.82)),
            (Lm.leftHeel, lm(0.56, 0.91, 0.1, 0.86)), (Lm.rightHeel, lm(0.44, 0.91, -0.1, 0.86)),
            (Lm.leftFootIndex, lm(0.57, 0.93, 0.1, 0.88)), (Lm.rightFootIndex, lm(0.43, 0.93, -0.1, 0.88))
        )
    }

    private func thoTu(_ f: PoseFrame, file: String) -> [String: Any] {
        [
            "file": file, "w": 720, "h": 1280,
            "landmarks": zip(f.points, f.visibility).map { [$0.0.x, $0.0.y, Double($0.1)] },
            "world": f.world.map { [$0.x, $0.y, $0.z] },
            "face": ["yawDeg": 4.25, "eyesOpen": 0.93],
        ]
    }

    private func json(_ o: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys])
    }

    /// Qua JSON rồi tính lại phải ra Y HỆT tính thẳng — số thực đi qua tệp không được lệch chữ số cuối, nếu không thì so
    /// với Android sẽ thấy "lệch" do chính công cụ.
    @Test("ghi ra JSON rồi đọc lại, tính lại ra đúng từng chữ số")
    func vongJsonKhongLech() throws {
        let tho = thoTu(dungThang(), file: "ngang-test.jpg")
        let thang = Parity6a.tinhLai(Parity6a.Raw(json: tho))
        let quaTep = try JSONSerialization.jsonObject(with: try json(tho)) as! [String: Any]
        let lai = Parity6a.tinhLai(Parity6a.Raw(json: quaTep))
        #expect(try json(thang) == json(lai))

        let gate = try #require(thang["gate"] as? [String: Any])
        #expect(gate["level"] as? String != "red", "dáng đứng thẳng phải qua cổng: \(gate)")
        #expect(thang["measurement"] is [String: Any] && thang["profile"] is [String: Any])
    }

    @Test("không có landmark thì cổng đỏ, không có số đo")
    func khongLandmark() throws {
        let r = Parity6a.tinhLai(Parity6a.Raw(json: ["file": "x.jpg", "w": 10, "h": 10, "landmarks": [[Double]]()]))
        #expect((r["gate"] as? [String: Any])?["level"] as? String == "red")
        #expect(r["measurement"] is NSNull && r["profile"] is NSNull)
    }

    /// CÔNG CỤ (không phải test thường): `PARITY_6A=a.json[,b.json] swift test --filter Parity6aTest` → ghi
    /// `a.tinh-ios.json` cạnh mỗi tệp — số đo tính bằng code iOS từ landmark trong tệp đó.
    @Test("tính lại tệp xuất bằng code iOS", .enabled(if: ProcessInfo.processInfo.environment["PARITY_6A"] != nil))
    func tinhLaiTep() throws {
        let paths = (ProcessInfo.processInfo.environment["PARITY_6A"] ?? "").split(separator: ",").map(String.init)
        for p in paths {
            let url = URL(fileURLWithPath: p)
            let items = try Parity6a.doc(url).map(Parity6a.tinhLai)
            #expect(!items.isEmpty, "\(p) rỗng")
            let out = url.deletingPathExtension().appendingPathExtension("tinh-ios.json")
            try Parity6a.ghi(items, out)
            print("PARITY_6A \(items.count) mục → \(out.path)")
        }
    }
}
