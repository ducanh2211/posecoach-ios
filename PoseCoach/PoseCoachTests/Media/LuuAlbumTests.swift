import Foundation
import Testing
@testable import PoseCoach

/// Lưu một lần chụp KÈM ẢNH MẪU, giống mẫu nhất đứng đầu, có điểm (17/10/2026). Port `KTT/LuuAlbumTest.kt`.
struct LuuAlbumTests {

    private let tmp: URL = {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("LuuAlbum-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private func anh(_ ten: String) throws -> URL {
        let f = tmp.appendingPathComponent(ten)
        try ten.write(to: f, atomically: true, encoding: .utf8)
        return f
    }

    private func doc(_ f: URL) throws -> String { try String(contentsOf: f, encoding: .utf8) }

    @Test func ghiAnhMauAnhTheoThuTuVaDiem() throws {
        let mau = try anh("mau-goc.jpg")
        let tot = try anh("1.jpg")
        let kem = try anh("2.jpg")
        let album = tmp.appendingPathComponent("buoi-1")
        #expect(ResultLibrary.ghiAlbum(album, mau, [(tot, 82), (kem, 61)]))
        #expect(try doc(album.appendingPathComponent("_mau.jpg")) == "mau-goc.jpg")
        #expect(try doc(album.appendingPathComponent("anh-01.jpg")) == "1.jpg")
        #expect(try doc(album.appendingPathComponent("anh-02.jpg")) == "2.jpg")
        let diem = try doc(album.appendingPathComponent("_diem.txt")).components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(diem == ["anh-01.jpg=82", "anh-02.jpg=61"])
    }

    @Test func chepHongThiKhongDeAlbumDoDang() {
        let album = tmp.appendingPathComponent("buoi-2")
        #expect(!ResultLibrary.ghiAlbum(album, nil, [(tmp.appendingPathComponent("khong-co.jpg"), 50)]))
        #expect(!FileManager.default.fileExists(atPath: album.path))
    }
}
