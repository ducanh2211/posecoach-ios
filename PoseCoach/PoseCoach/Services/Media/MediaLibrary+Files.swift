import Foundation
import os
import PoseDomain

/// Phần ĐỌC / GHI FILE của `KT/media/MediaLibrary.kt`. Phần đọc tên file (nhóm, nhãn góc, `ganNhan` tính tên) nằm ở
/// `PoseDomain.MediaLibrary`; file này là extension của chính enum đó để mọi chỗ gọi cùng một tên như Kotlin.
///
/// Khác Android: thư mục làm việc ở `Application Support/templates/` (Android: `getExternalFilesDir`). Ảnh soạn sẵn
/// đọc từ thư mục `templates/` trong bundle (Android: `assets/templates/`).
nonisolated extension MediaLibrary {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "MediaLibrary")
    private static let templatesDirName = "templates"
    /// Thư mục ảnh mẫu soạn sẵn, ĐÓNG GÓI TRONG APP.
    private static let bundleTemplates = "templates"

    /// Dấu vết "đã nạp ảnh mẫu soạn sẵn một lần rồi" — thiếu thì ảnh mẫu người dùng **xoá đi sẽ tự mọc lại** ở lần mở
    /// app kế tiếp (FOOTGUNS 32).
    ///
    /// ⚠️ CÓ SỐ PHIÊN BẢN. Đổi số này là lần mở app kế tiếp **xoá bộ ảnh mẫu cũ do app cài sẵn** rồi chép bộ mới. Chỉ
    /// xoá ảnh do app cài — danh sách ghi trong chính file đánh dấu; ảnh người dùng tự chọn KHÔNG bị đụng tới.
    private static let seedMarker = ".da-nap-anh-mau-v10"
    private static let imageExt: Set<String> = ["jpg", "jpeg", "png", "webp", "jfif"]
    private static let seedLock = NSLock()

    static func templatesDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent(templatesDirName)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// CHÉP THƯ VIỆN ẢNH MẪU SOẠN SẴN TỪ TRONG APP RA THƯ MỤC LÀM VIỆC.
    ///
    /// Chép ra thay vì đọc thẳng từ bundle: mọi đường phía sau (cổng kiểm, phân tích, màn chụp, xoá) làm việc với file
    /// thật trong một thư mục — và ảnh soạn sẵn người dùng xoá được.
    ///
    /// Đọc cả THƯ MỤC CON (`mirror/`, `selfie/`, `photographer/`), ra thư mục làm việc thì trải phẳng — nhóm đã nằm ngay
    /// trong tên file. Gọi ở luồng nền khi mở tab Ảnh mẫu. Chạy đúng MỘT lần nhờ `seedMarker`.
    static func seedBuiltInTemplates() {
        seedLock.lock()
        defer { seedLock.unlock() }
        let fm = FileManager.default
        let dir = templatesDir()
        let marker = dir.appendingPathComponent(seedMarker)
        if fm.fileExists(atPath: marker.path) { return }

        do {
            // Dọn bộ CŨ trước theo danh sách trong file đánh dấu của phiên bản trước.
            for old in (try fm.contentsOfDirectory(atPath: dir.path)) where old.hasPrefix(".da-nap-anh-mau") {
                let oldURL = dir.appendingPathComponent(old)
                let text = (try? String(contentsOf: oldURL, encoding: .utf8)) ?? ""
                for line in text.components(separatedBy: .newlines) {
                    let name = line.trimmingCharacters(in: .whitespaces)
                    let f = dir.appendingPathComponent(name)
                    if !name.isEmpty, fm.fileExists(atPath: f.path) { try? fm.removeItem(at: f) }
                }
                try? fm.removeItem(at: oldURL)
            }

            guard let src = Bundle.main.url(forResource: bundleTemplates, withExtension: nil) else {
                log.error("Không tìm thấy thư mục \(bundleTemplates, privacy: .public)/ trong bundle")
                return
            }
            let files = anhTrongBundle(src)
            for f in files {
                let dest = dir.appendingPathComponent(f.lastPathComponent)
                try? fm.removeItem(at: dest)
                try fm.copyItem(at: f, to: dest)
            }
            // Ghi lại đúng những gì vừa chép, để lần sau dọn được sạch.
            try files.map(\.lastPathComponent).joined(separator: "\n").write(to: marker, atomically: true, encoding: .utf8)
        } catch {
            log.error("Chép ảnh mẫu soạn sẵn không xong: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Mọi file ảnh dưới `root`, kể cả thư mục con (thư mục `templates` là symlink vào `shared/` — đi theo nó).
    private static func anhTrongBundle(_ root: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: root.resolvingSymlinksInPath(), includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }
        return e.compactMap { $0 as? URL }
            .filter { imageExt.contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }
    }

    /// Danh sách ảnh mẫu, xếp theo tên (không phân biệt hoa thường) cho ổn định thứ tự giữa các lần mở.
    static func templates() -> [Template] {
        let dir = templatesDir()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isRegularFileKey]
        )) ?? []
        return files
            .filter { imageExt.contains($0.pathExtension.lowercased()) }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
            .map { Template($0) }
    }

    /// GÁN KIỂU CHỤP VÀ GÓC MÁY cho ảnh tự nhập — ĐỔI TÊN file theo `ganNhan(_:_:_:_:)` của PoseDomain.
    ///
    /// - Returns: file sau khi đổi tên; đổi tên thất bại thì trả lại file cũ.
    static func ganNhan(_ file: URL, _ kind: TemplateKind, _ goc: GocMayNhan?, _ kieuTren: KieuChupTren? = nil) -> URL {
        let tenMoi = ganNhan(file.lastPathComponent, kind, goc, kieuTren)
        if tenMoi == file.lastPathComponent { return file }
        let dich = file.deletingLastPathComponent().appendingPathComponent(tenMoi)
        do {
            try FileManager.default.moveItem(at: file, to: dich)
            return dich
        } catch {
            log.warning("Không đổi tên được ảnh nhập: \(error.localizedDescription, privacy: .public)")
            return file
        }
    }
}
