import CoreGraphics
import CoreTransferable
import Foundation
import os
import PhotosUI
import PoseDomain
import SwiftUI
import UniformTypeIdentifiers

/// Lỗi có câu giải thích cho người dùng — màn hình hiện nguyên câu này.
struct SceneError: Error {
    let text: UiText
}

/// NHẬN DIỆN BỐI CẢNH — hoàn toàn trên máy. Nguồn ảnh mẫu là thư viện của app. Port `KT/core/data/SceneRepository.kt`.
///
/// Mỗi đầu vào (một ảnh, một video) phân tích RIÊNG thành các khung hình có nhãn; màn đề xuất gộp lại. Nhờ vậy thêm một
/// ảnh thì chỉ phân tích đúng ảnh đó.
///
/// Khác Android: nằm ở `Features/Scene` (chỉ màn này dùng, AGENTS quy tắc 5); ML Kit gọi qua `ImageLabels.raw`
/// (ngưỡng 0,5 = `DEFAULT_OPTIONS`), khung video qua `VideoFrameSource`, ảnh qua `UprightImage`. Hàm `@concurrent` chạy
/// ngoài luồng chính và nhận lệnh huỷ của Task gọi nó (= `ensureActive`).
nonisolated final class SceneRepository: Sendable {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "SceneRepository")

    /// Video bối cảnh dài nhất nhận phân tích. Màn camera tự dừng ở mốc này.
    static let maxVideoMs: Int64 = 60_000

    /// Ngưỡng tin cậy của nhãn ML Kit — `ImageLabelerOptions.DEFAULT_OPTIONS`.
    private static let labelThreshold = 0.5

    /// Video hay ảnh — theo đuôi file (mọi đầu vào đều là file tạm của app).
    static func isVideo(_ file: URL) -> Bool {
        UTType(filenameExtension: file.pathExtension)?.conforms(to: .movie) ?? false
    }

    /// Thư mục tạm cho ảnh/video bối cảnh. Xoá sạch khi rời luồng đề xuất.
    private static var captureDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("scene-capture")
    }

    static func newCaptureFile(_ ext: String) -> URL {
        try? FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)
        return captureDir.appendingPathComponent("scene-\(Int64(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(4)).\(ext)")
    }

    /// Ảnh/video bối cảnh chỉ để nhận diện — không giữ lại, tránh rác máy.
    static func clearCaptures() {
        try? FileManager.default.removeItem(at: captureDir)
    }

    /// Chép một mục chọn từ Photo Picker vào thư mục tạm. `nil` = không đọc được.
    @concurrent static func copyPicked(_ item: PhotosPickerItem) async -> URL? {
        do {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                return try await item.loadTransferable(type: PickedMovie.self)?.file
            }
            guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
            let f = newCaptureFile("jpg")
            try data.write(to: f)
            return f
        } catch {
            log.warning("Không chép được mục đã chọn: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Các khung hình có nhãn của MỘT đầu vào. Video lấy tối đa 12 khung rải đều.
    @concurrent func framesOf(
        _ file: URL, video: Bool, progress: @escaping @Sendable (UiText) async -> Void
    ) async throws -> [SceneFrame] {
        if video {
            // Khung thu vào ô 640×640 như `getScaledFrameAtTime(…, 640, 640)`: mở một lần để biết cỡ, rồi mở đúng cỡ.
            let probe = await VideoFrameSource.open(file, targetShortSide: 640)
            guard probe.isValid else { throw SceneError(text: uiText("scene_err_duration")) }
            let duration = probe.durationMs
            if !(1...Self.maxVideoMs).contains(duration) { throw SceneError(text: uiText("scene_err_too_long")) }
            let w = probe.displayWidth, h = probe.displayHeight
            probe.close()
            let reader = await VideoFrameSource.open(file, targetShortSide: max(1, 640 * min(w, h) / max(w, h, 1)))
            defer { reader.close() }
            let times = SceneMatching.sampleTimes(duration)
            var frames: [SceneFrame] = []
            for (index, time) in times.enumerated() {
                try Task.checkCancellation()
                await progress(uiText("scene_progress_angle", .int(index + 1), .int(times.count)))
                guard let bitmap = await reader.frameAt(time, exact: true) else { continue }
                frames.append(SceneFrame(time, Self.toTags(try label(bitmap))))
            }
            if frames.isEmpty { throw SceneError(text: uiText("scene_err_no_frames")) }
            return frames
        } else {
            await progress(uiText("scene_progress_labeling"))
            // Áp EXIF và giới hạn cạnh dài trước khi cấp phát ảnh.
            guard let bitmap = UprightImage.decode(file, maxLongSide: 640) else {
                throw SceneError(text: uiText("scene_err_type"))
            }
            return [SceneFrame(0, Self.toTags(try label(bitmap)))]
        }
    }

    /// Nhãn bối cảnh của cả thư viện ảnh mẫu — dùng cho đường GÕ CHỮ, không cần ảnh/video.
    ///
    /// ⚠️ NHÃN ẢNH MẪU ĐƯỢC LƯU LẠI (09/10/2026). Chỉ ảnh mới hoặc đã đổi (khác thời điểm sửa hoặc kích thước file) mới
    /// phải chạy ML Kit. Lưu nhãn THÔ (mọi nhãn ≥ 0,5), chưa lọc — đổi bộ nhãn bối cảnh hay ngưỡng trong `SceneMatching`
    /// thì không phải gắn lại (FOOTGUNS 107.4).
    ///
    /// - Returns: ảnh mẫu kèm nhãn, và số ảnh không đọc được.
    @concurrent func library(progress: @escaping @Sendable (UiText) async -> Void) async throws -> ([SceneTemplate], Int) {
        let library = MediaLibrary.templates()
        let cache = Self.readCache()
        var fresh: [String: CachedLabels] = [:]
        var unreadable = 0
        var templates: [SceneTemplate] = []
        for (index, template) in library.enumerated() {
            try Task.checkCancellation()
            let file = template.file
            let (modified, size) = Self.stat(file)
            var raw: [(String, Float)]?
            if let c = cache[file.lastPathComponent], c.modified == modified, c.size == size {
                raw = c.labels
            } else {
                await progress(uiText("scene_progress_templates", .int(index + 1), .int(library.count)))
                if let bitmap = UprightImage.decode(file, shortSide: 320) { raw = try label(bitmap) }
            }
            guard let raw else {
                unreadable += 1
                continue
            }
            fresh[file.lastPathComponent] = CachedLabels(modified: modified, size: size, labels: raw)
            templates.append(SceneTemplate(file, template.displayName, Self.toTags(raw)))
        }
        // Ghi lại toàn bộ: ảnh đã xoá khỏi thư viện cũng rơi khỏi tệp lưu.
        Self.writeCache(fresh)
        return (templates, unreadable)
    }

    // MARK: - Tệp lưu nhãn

    private struct CachedLabels {
        let modified: Int64
        let size: Int64
        let labels: [(String, Float)]
    }

    /// Như `files/scene-tags-v1.json` của Android — ở `Application Support/`.
    private static var cacheFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("scene-tags-v1.json")
    }

    /// Như `File.lastModified()` (ms) + `File.length()`.
    private static func stat(_ file: URL) -> (Int64, Int64) {
        let a = try? FileManager.default.attributesOfItem(atPath: file.path)
        let date = a?[.modificationDate] as? Date
        let size = (a?[.size] as? NSNumber)?.int64Value ?? 0
        return (Int64((date?.timeIntervalSince1970 ?? 0) * 1000), size)
    }

    /// Tệp hỏng hay chưa có thì coi như trống — chỉ mất công gắn nhãn lại, không mất gì khác.
    private static func readCache() -> [String: CachedLabels] {
        guard let data = try? Data(contentsOf: cacheFile),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: CachedLabels] = [:]
        for (name, value) in root {
            guard let o = value as? [String: Any],
                  let modified = (o["modified"] as? NSNumber)?.int64Value,
                  let size = (o["size"] as? NSNumber)?.int64Value,
                  let arr = o["labels"] as? [[Any]] else { return [:] }
            var labels: [(String, Float)] = []
            for l in arr {
                guard l.count == 2, let text = l[0] as? String, let conf = (l[1] as? NSNumber)?.doubleValue else { return [:] }
                labels.append((text, Float(conf)))
            }
            out[name] = CachedLabels(modified: modified, size: size, labels: labels)
        }
        return out
    }

    private static func writeCache(_ entries: [String: CachedLabels]) {
        var root: [String: Any] = [:]
        for (name, c) in entries {
            root[name] = [
                "modified": c.modified, "size": c.size,
                "labels": c.labels.map { [$0.0, Double($0.1)] as [Any] },
            ] as [String: Any]
        }
        do {
            try JSONSerialization.data(withJSONObject: root).write(to: cacheFile, options: .atomic)
        } catch {
            log.warning("Không ghi được tệp nhãn ảnh mẫu: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Gắn nhãn

    private static func toTags(_ raw: [(String, Float)]) -> [SceneTag] {
        raw.compactMap { SceneMatching.tag($0.0, $0.1) }
    }

    /// Nhãn THÔ của ML Kit (tên tiếng Anh, độ tin cậy). Lọc bằng `toTags`.
    private func label(_ bitmap: CGImage) throws -> [(String, Float)] {
        try Task.checkCancellation()
        let tags = try ImageLabels.raw(bitmap, threshold: Self.labelThreshold).map { ($0.text, $0.confidence) }
        try Task.checkCancellation()
        return tags
    }
}

/// Video chọn từ Photo Picker — chép ra thư mục tạm của luồng bối cảnh.
private struct PickedMovie: Transferable {
    let file: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = SceneRepository.newCaptureFile(ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(file: dest)
        }
    }
}
