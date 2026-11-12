import Foundation
import os
import PoseDomain

/// THƯ VIỆN ẢNH ĐÃ LỌC — kết quả cuối, xem lại bất cứ lúc nào. Port từ `KT/media/ResultLibrary.kt`.
///
/// Tách khỏi `ShotStore`: kho tạm có bốn lớp dọn rác, thư viện thì **cố ý giữ lại** tới khi người dùng tự xoá. Trộn hai
/// thứ là hỏng theo cả hai chiều — dọn nhầm ảnh người ta muốn giữ, hoặc để rác tạm nằm lại mãi.
///
/// ⚠️ Luật cứng: **XOÁ NGUỒN GỐC sau khi lọc** — video thô 60-100 MB, loạt ảnh vài chục MB (xem `saveSession`).
///
/// Khác Android: nằm ở `Application Support/thu-vien/` (Android: `getExternalFilesDir`).
nonisolated enum ResultLibrary {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "ResultLibrary")
    private static let dirName = "thu-vien"
    private static let templateName = "_mau.jpg"
    private static let scoresName = "_diem.txt"
    /// Thứ tự như `setOf(...)` của Kotlin (giữ thứ tự thêm vào) — `timMauCu` thử đuôi theo thứ tự này.
    private static let imageExtOrder = ["jpg", "jpeg", "png"]
    private static let imageExt = Set(imageExtOrder)

    /// Thư mục thư viện. Tự tạo nếu chưa có.
    static func dir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent(dirName)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// MỘT LẦN CHỤP đã lọc xong: một thư mục con chứa các ảnh kết quả.
    struct Album: Equatable {
        let dir: URL
        /// Ảnh mẫu đã dùng, chép vào để xem lại đối chiếu. `nil` = không còn.
        let templateThumb: URL?
        /// Ảnh đã lưu, GIỐNG MẪU NHẤT đứng đầu.
        let photos: [URL]
        /// Điểm giống mẫu (0-100) theo tên file ảnh. Album cũ không có thì rỗng.
        var scores: [String: Int] = [:]

        func scoreOf(_ photo: URL) -> Int? { scores[photo.lastPathComponent] }

        var createdAtMs: Int64 { ResultLibrary.modifiedMs(dir) }
        var count: Int { photos.count }
    }

    /// Mọi lần chụp đã lưu, mới nhất đứng đầu.
    static func albums() -> [Album] {
        let fm = FileManager.default
        let mau = MediaLibrary.templatesDir()
        let dirs = ((try? fm.contentsOfDirectory(at: dir(), includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey])) ?? [])
            .filter { isDirectory($0) }
        return stableSorted(dirs) { modifiedMs($0) > modifiedMs($1) }
            .map { d -> Album in
                let files = ((try? fm.contentsOfDirectory(at: d, includingPropertiesForKeys: [.isRegularFileKey])) ?? [])
                    .filter { !isDirectory($0) }
                let photos = files
                    .filter { $0.lastPathComponent != templateName && imageExt.contains($0.pathExtension.lowercased()) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                return Album(
                    dir: d,
                    templateThumb: files.first { $0.lastPathComponent == templateName } ?? timMauCu(mau, photos),
                    photos: photos,
                    scores: docDiem(d.appendingPathComponent(scoresName))
                )
            }
            .filter { !$0.photos.isEmpty }
    }

    /// GHI MỘT LẦN CHỤP VÀO THƯ VIỆN (17/10/2026): ảnh mẫu + các ảnh đã chọn, xếp theo điểm (`anh-01` giống mẫu nhất),
    /// kèm điểm từng ảnh. Chép hỏng thì xoá album dở, trả `false`.
    ///
    /// - Parameter photos: ảnh và điểm (0-100), ĐÃ xếp giống mẫu nhất đứng đầu.
    static func ghiAlbum(_ album: URL, _ template: URL?, _ photos: [(URL, Int)]) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: album, withIntermediateDirectories: true)
            if let template, isRegularFile(template) {
                try copyOverwrite(template, album.appendingPathComponent(templateName))
            }
            var diem = ""
            for (i, (f, d)) in photos.enumerated() {
                let ten = String(format: "anh-%02d.jpg", i + 1)
                try copyOverwrite(f, album.appendingPathComponent(ten))
                diem += "\(ten)=\(d)\n"
            }
            try diem.write(to: album.appendingPathComponent(scoresName), atomically: true, encoding: .utf8)
            return true
        } catch {
            log.error("Ghi album không xong: \(error.localizedDescription, privacy: .public)")
            try? fm.removeItem(at: album)
            return false
        }
    }

    private static func docDiem(_ f: URL) -> [String: Int] {
        guard let text = try? String(contentsOf: f, encoding: .utf8) else { return [:] }
        var out: [String: Int] = [:]
        for dong in text.components(separatedBy: "\n") {
            let p = dong.components(separatedBy: "=")
            guard p.count == 2, let d = Int(p[1].trimmingCharacters(in: .whitespaces)) else { continue }
            out[p[0].trimmingCharacters(in: .whitespaces)] = d
        }
        return out
    }

    /// Album lưu TRƯỚC 17/10/2026 không chép ảnh mẫu. Ảnh lưu bằng nút "Giữ ảnh này" cũ có tên
    /// `<tên ảnh mẫu>-<số>.jpg` — tìm lại ảnh mẫu đó trong thư viện mẫu nếu còn.
    private static func timMauCu(_ mau: URL, _ photos: [URL]) -> URL? {
        let re = try! NSRegularExpression(pattern: #"^(.+)-\d+$"#)
        let ten = photos.lazy.compactMap { p -> String? in
            let n = p.deletingPathExtension().lastPathComponent
            guard let m = re.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)),
                  let r = Range(m.range(at: 1), in: n) else { return nil }
            return String(n[r])
        }.first
        guard let ten else { return nil }
        return imageExtOrder.map { mau.appendingPathComponent("\(ten).\($0)") }.first { isRegularFile($0) }
    }

    /// Chuyển kết quả một lần quay vào thư viện, rồi **XOÁ SẠCH nguồn**.
    ///
    /// - Parameters:
    ///   - sessionDir: thư mục tạm của `ShotStore`.
    ///   - templateFile: ảnh mẫu đã dùng, chép vào album để sau còn đối chiếu.
    ///   - sources: video thô hoặc loạt ảnh gốc — **bị xoá sau khi chép xong**.
    /// - Returns: thư mục album mới, `nil` nếu không có ảnh nào để lưu.
    static func saveSession(_ sessionDir: URL, _ templateFile: URL?, _ sources: [URL]) -> URL? {
        let fm = FileManager.default
        let photos = ((try? fm.contentsOfDirectory(at: sessionDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { isRegularFile($0) && imageExt.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if photos.isEmpty {
            log.warning("Phiên không có ảnh nào, không lưu vào thư viện")
            return nil
        }

        let album = dir().appendingPathComponent("buoi-\(Int64(Date().timeIntervalSince1970 * 1000))")
        do {
            try fm.createDirectory(at: album, withIntermediateDirectories: true)
            for (i, f) in photos.enumerated() {
                try copyOverwrite(f, album.appendingPathComponent(String(format: "anh-%02d.jpg", i + 1)))
            }
            if let templateFile { try copyOverwrite(templateFile, album.appendingPathComponent(templateName)) }
        } catch {
            log.error("Chép vào thư viện không xong: \(error.localizedDescription, privacy: .public)")
            try? fm.removeItem(at: album)
            return nil
        }

        // ⚠️ XOÁ NGUỒN NGAY — luật cứng, không phải dọn cho gọn: quên vài lần là máy người dùng đầy, mà họ không hiểu vì sao.
        sources.forEach { try? fm.removeItem(at: $0) }
        try? fm.removeItem(at: sessionDir)

        log.info("Đã lưu \(photos.count) ảnh vào \(album.lastPathComponent, privacy: .public), đã xoá nguồn")
        return album
    }

    /// Xoá hẳn một album. Không hỏi lại — bên gọi phải xác nhận trước.
    static func delete(_ album: Album) {
        try? FileManager.default.removeItem(at: album.dir)
    }

    // MARK: - Tiện ích file

    /// Như `File.copyTo(…, overwrite = true)`.
    private static func copyOverwrite(_ src: URL, _ dest: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: src, to: dest)
    }

    private static func isDirectory(_ u: URL) -> Bool {
        var d: ObjCBool = false
        return FileManager.default.fileExists(atPath: u.path, isDirectory: &d) && d.boolValue
    }

    private static func isRegularFile(_ u: URL) -> Bool {
        var d: ObjCBool = false
        return FileManager.default.fileExists(atPath: u.path, isDirectory: &d) && !d.boolValue
    }

    fileprivate static func modifiedMs(_ u: URL) -> Int64 {
        let date = (try? FileManager.default.attributesOfItem(atPath: u.path)[.modificationDate]) as? Date
        return Int64((date?.timeIntervalSince1970 ?? 0) * 1000)
    }

    /// `sortedByDescending` của Kotlin là sắp xếp ỔN ĐỊNH; `sort` của Swift thì không bảo đảm.
    private static func stableSorted<T>(_ a: [T], by less: (T, T) -> Bool) -> [T] {
        a.enumerated().sorted { less($0.element, $1.element) || (!less($1.element, $0.element) && $0.offset < $1.offset) }
            .map(\.element)
    }
}
