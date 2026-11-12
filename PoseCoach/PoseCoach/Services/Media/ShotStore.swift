import CoreGraphics
import Foundation
import ImageIO
import os
import PoseDomain
import UniformTypeIdentifiers

/// KHO ẢNH TẠM của một lần quay. Port từ `KT/capture/ShotStore.kt`.
///
/// Yêu cầu sản phẩm: *"video hay ảnh thừa đã lọc ra thì xoá luôn tránh rác máy"*. Bốn lớp, cố ý chồng lên nhau:
///  1. **Không bao giờ lưu quá `capacity` file** — `BestShotBuffer` đá khung yếu ra là `delete` file luôn.
///  2. **Chọn xong thì xoá phần thừa.**
///  3. **Thoát giữa chừng thì xoá cả phiên.**
///  4. **`sweepOrphans` lúc mở app** — vớt nốt khi app bị tắt đột ngột.
///
/// Khác Android: thư mục tạm nằm trong `Library/Caches/` (Android: `getExternalFilesDir`) — hệ thống không sao lưu,
/// và chỉ dọn khi app không chạy.
nonisolated final class ShotStore {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "ShotStore")
    private static let jpegQuality = 0.95
    private static let indexName = "index.csv"
    private static let root = "shots"
    private static let recordings = "recordings"
    /// Ảnh gốc của loạt chụp liên tục, trước khi chấm điểm.
    private static let burst = "burst"

    /// Thứ tự cột điểm từng mục trong bảng kê. Lấy thẳng từ `Criterion` — gõ cứng thì thêm tiêu chí mà quên sửa là lệch
    /// cột, điểm mục này hiện dưới tên mục khác.
    static let partKeys: [String] = Criterion.allCases.map(\.key)

    let sessionDir: URL

    private init(_ sessionDir: URL) {
        self.sessionDir = sessionDir
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
    }

    func file(_ id: Int64) -> URL { sessionDir.appendingPathComponent("\(id).jpg") }

    /// CẮT ẢNH VỀ TỈ LỆ KHUNG người dùng chọn (phần GIỮA), trước khi ghi. `nil` = giữ nguyên.
    func cropToAspect(_ image: CGImage, _ targetAspect: Double?) -> CGImage {
        guard let targetAspect, targetAspect > 0.0 else { return image }
        let w = image.width
        let h = image.height
        if w <= 0 || h <= 0 { return image }
        let cur = Double(w) / Double(h)
        if abs(cur - targetAspect) / cur < 0.01 { return image }
        let rect: CGRect
        if targetAspect < cur {
            let nw = min(max(Int(Double(h) * targetAspect), 1), w)
            rect = CGRect(x: (w - nw) / 2, y: 0, width: nw, height: h)
        } else {
            let nh = min(max(Int(Double(w) / targetAspect), 1), h)
            rect = CGRect(x: 0, y: (h - nh) / 2, width: w, height: nh)
        }
        return image.cropping(to: rect) ?? image
    }

    /// Lưu một khung. `false` nếu ghi hỏng — khi đó đừng đưa nó vào bộ giữ.
    func save(_ id: Int64, _ image: CGImage) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(file(id) as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            Self.log.warning("Không lưu được khung \(id)")
            return false
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: Self.jpegQuality] as CFDictionary)
        let ok = CGImageDestinationFinalize(dest)
        if !ok { Self.log.warning("Không lưu được khung \(id)") }
        return ok
    }

    func delete(_ id: Int64) {
        try? FileManager.default.removeItem(at: file(id))
    }

    func delete<S: Sequence>(_ ids: S) where S.Element == Int64 {
        ids.forEach { delete($0) }
    }

    /// Xoá sạch cả phiên, kể cả bảng kê.
    func deleteSession() {
        try? FileManager.default.removeItem(at: sessionDir)
    }

    // MARK: - Bảng kê — để màn kết quả đọc lại được mà không cần ViewModel màn chụp còn sống

    /// Ghi bảng kê khi quay xong. Ra file thay vì truyền qua bộ nhớ: màn kết quả là màn RIÊNG.
    func writeIndex(_ entries: [ShotCandidate]) {
        var s = "id,time_ms,score,trustworthy,\(Self.partKeys.joined(separator: ","))\n"
        for e in entries {
            s += "\(e.id),\(e.timeMs),\(Self.num(e.score)),\(e.trustworthy)"
            // Mục KHÔNG đo được để trống, không ghi 0. Trống = "không biết"; 0 = "biết, và sai hoàn toàn".
            for k in Self.partKeys {
                s += ","
                if let v = e.parts[k] { s += Self.num(v) }
            }
            s += "\n"
        }
        do {
            try s.write(to: sessionDir.appendingPathComponent(Self.indexName), atomically: true, encoding: .utf8)
        } catch {
            Self.log.warning("Không ghi được bảng kê: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Đọc bảng kê. Rỗng nếu chưa có hoặc file hỏng.
    func readIndex() -> [ShotCandidate] {
        let f = sessionDir.appendingPathComponent(Self.indexName)
        guard let text = try? String(contentsOf: f, encoding: .utf8) else { return [] }
        return Self.lines(text).dropFirst().compactMap { line -> ShotCandidate? in
            let c = line.components(separatedBy: ",")
            if c.count < 4 { return nil }
            guard let id = Int64(c[0]) else { return nil }
            // Bỏ dòng trỏ tới file đã không còn — tránh ô ảnh trống trên màn kết quả mà không có lời giải thích.
            if !FileManager.default.fileExists(atPath: file(id).path) { return nil }
            var parts: [String: Double] = [:]
            for (i, key) in Self.partKeys.enumerated() {
                let idx = 4 + i
                if idx < c.count, let v = Double(c[idx].trimmingCharacters(in: .whitespaces)) { parts[key] = v }
            }
            return ShotCandidate(
                id: id,
                timeMs: Int64(c[1]) ?? 0,
                score: Double(c[2]) ?? 0.0,
                trustworthy: c[3].trimmingCharacters(in: .whitespaces).lowercased() == "true",
                parts: parts
            )
        }
    }

    /// Như `File.readLines()`: tách theo xuống dòng, không giữ dòng rỗng cuối file.
    private static func lines(_ text: String) -> [String] {
        var l = text.components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        if l.last == "" { l.removeLast() }
        return l
    }

    /// SỐ GHI RA FILE — **BẮT BUỘC** `en_US_POSIX`.
    ///
    /// ⚠️ Lỗi đã xảy ra thật (06/09/2026, máy tiếng Việt): định dạng theo ngôn ngữ máy ra `0,899` — mà bảng kê là CSV
    /// ngăn bằng dấu phẩy → một giá trị thành HAI cột, mọi cột sau trượt một ô (`LocaleCsvTests`).
    static func num(_ v: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), v)
    }

    // MARK: - Thư mục + dọn rác

    private static var baseDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    static func rootDir() -> URL {
        let d = baseDir.appendingPathComponent(root)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Nơi để video thô trong lúc chấm điểm. Xoá ngay sau khi cắt xong 5 ảnh.
    static func recordingsDir() -> URL {
        let d = baseDir.appendingPathComponent(recordings)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Nơi để ảnh gốc của loạt chụp liên tục.
    static func burstDir() -> URL {
        baseDir.appendingPathComponent(burst)
    }

    /// Dọn video thô bỏ lại — rác NẶNG NHẤT (30 giây Full HD 60-100 MB). Gọi lúc MỞ app.
    static func sweepRecordings() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: recordingsDir(), includingPropertiesForKeys: [.fileSizeKey]) else {
            return
        }
        for f in files {
            let mb = ((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) / 1024 / 1024
            log.info("Dọn video bỏ lại: \(f.lastPathComponent, privacy: .public) (\(mb) MB)")
            do { try fm.removeItem(at: f) } catch {
                log.warning("Dọn video bỏ lại không xong: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Dọn ảnh gốc của loạt chụp liên tục bỏ lại.
    static func sweepBurst() {
        let d = burstDir()
        guard FileManager.default.fileExists(atPath: d.path) else { return }
        do { try FileManager.default.removeItem(at: d) } catch {
            log.warning("Dọn ảnh chụp liên tục bỏ lại không xong: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Mở một phiên mới. Tên thư mục theo thời điểm nên xếp được theo thứ tự.
    static func createSession() -> ShotStore {
        ShotStore(rootDir().appendingPathComponent("s\(Int64(Date().timeIntervalSince1970 * 1000))"))
    }

    static func openSession(_ dir: URL) -> ShotStore { ShotStore(dir) }

    /// Dọn các phiên bỏ lại từ lần chạy trước.
    ///
    /// ⚠️ Gọi lúc MỞ APP, không phải lúc đóng — lúc đóng thì app đã bị hệ điều hành giết, code dọn không chạy tới.
    ///
    /// - Parameter keep: phiên đang dùng, không được xoá. `nil` = xoá hết.
    static func sweepOrphans(keep: URL? = nil) {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: rootDir(), includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        for dir in dirs {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir, dir.standardizedFileURL.path != keep?.standardizedFileURL.path else { continue }
            log.info("Dọn phiên bỏ lại: \(dir.lastPathComponent, privacy: .public)")
            do { try fm.removeItem(at: dir) } catch {
                log.warning("Dọn phiên bỏ lại không xong: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
