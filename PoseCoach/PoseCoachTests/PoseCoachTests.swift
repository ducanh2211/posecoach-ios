import Testing
import Foundation
import MachO
import ObjectiveC
@testable import PoseCoach
import MediaPipeTasksVision
import MLKitFaceDetection
import MLKitImageLabeling
import onnxruntime_objc

struct PoseCoachPhase0Tests {

    private func findBundleFile(named name: String, withExtension ext: String?) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }
        // Fallback: search recursively in bundle directory
        let bundleURL = bundle.bundleURL
        if let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.deletingPathExtension().lastPathComponent == name {
                    if let ext = ext {
                        if fileURL.pathExtension.lowercased() == ext.lowercased() {
                            return fileURL
                        }
                    } else {
                        return fileURL
                    }
                }
            }
        }
        return nil
    }

    @Test("Tài nguyên Bundle: pose_landmarker_full.task, geocalib onnx, và đủ 114 ảnh mẫu")
    func testBundleResources() throws {
        // 1. Kiểm tra pose_landmarker_full.task
        let modelURL = findBundleFile(named: "pose_landmarker_full", withExtension: "task")
        #expect(modelURL != nil, "Không tìm thấy pose_landmarker_full.task trong bundle")
        if let modelURL = modelURL {
            let attrs = try FileManager.default.attributesOfItem(atPath: modelURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            #expect(size > 5_000_000, "pose_landmarker_full.task kích thước quá nhỏ: \(size) bytes")
        }

        // 2. Kiểm tra geocalib-mang-int8.onnx
        let onnxURL = findBundleFile(named: "geocalib-mang-int8", withExtension: "onnx")
        #expect(onnxURL != nil, "Không tìm thấy geocalib-mang-int8.onnx trong bundle")
        if let onnxURL = onnxURL {
            let attrs = try FileManager.default.attributesOfItem(atPath: onnxURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            #expect(size > 20_000_000, "geocalib-mang-int8.onnx kích thước quá nhỏ: \(size) bytes")
        }

        // 3. Quét đệ quy 114 ảnh mẫu
        let bundleURL = Bundle.main.bundleURL
        let templatesURL = bundleURL.appendingPathComponent("templates")
        #expect(FileManager.default.fileExists(atPath: templatesURL.path), "Thư mục templates không tồn tại trong bundle")

        var imageFiles: [URL] = []
        let allowedExts = Set(["jpg", "jpeg", "png"])
        if let enumerator = FileManager.default.enumerator(at: templatesURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if allowedExts.contains(fileURL.pathExtension.lowercased()) {
                    imageFiles.append(fileURL)
                }
            }
        }
        #expect(imageFiles.count == 114, "Số ảnh mẫu tìm được là \(imageFiles.count), kỳ vọng đúng 114 ảnh")
    }

    @Test("Khởi tạo đồng thời: PoseLandmarker, FaceDetector, ImageLabeler, ORTSession")
    func testFrameworkInitializationAndNoSymbolCollision() throws {
        // 1. MediaPipe PoseLandmarker
        guard let modelURL = findBundleFile(named: "pose_landmarker_full", withExtension: "task") else {
            Issue.record("Thiếu model pose_landmarker_full.task")
            return
        }
        let poseOptions = PoseLandmarkerOptions()
        poseOptions.baseOptions.modelAssetPath = modelURL.path
        poseOptions.runningMode = .image
        poseOptions.numPoses = 1
        poseOptions.minPoseDetectionConfidence = 0.5
        poseOptions.minPosePresenceConfidence = 0.5
        poseOptions.minTrackingConfidence = 0.5

        _ = try PoseLandmarker(options: poseOptions)

        // 2. ML Kit FaceDetector (dùng MLKitFaceDetection để tránh xung đột với MediaPipe)
        let faceOptions = MLKitFaceDetection.FaceDetectorOptions()
        faceOptions.performanceMode = .fast
        _ = MLKitFaceDetection.FaceDetector.faceDetector(options: faceOptions)

        // 3. ML Kit ImageLabeler
        let labelerOptions = MLKitImageLabeling.ImageLabelerOptions()
        labelerOptions.confidenceThreshold = 0.2
        _ = MLKitImageLabeling.ImageLabeler.imageLabeler(options: labelerOptions)

        // 4. ONNX Runtime ORTSession
        guard let onnxURL = findBundleFile(named: "geocalib-mang-int8", withExtension: "onnx") else {
            Issue.record("Thiếu model geocalib-mang-int8.onnx")
            return
        }
        let ortEnv = try ORTEnv(loggingLevel: .warning)
        let sessionOptions = try ORTSessionOptions()
        _ = try ORTSession(env: ortEnv, modelPath: onnxURL.path, sessionOptions: sessionOptions)
    }

    /// Trùng đã biết, chấp nhận: MediaPipe 1.0.0 nhúng sẵn GTM trong `libMediaPipeTasksCommon_*_graph.a`
    /// (bị `-force_load`), ML Kit 8.0.0 lại kéo pod `GoogleToolboxForMac` + `GTMSessionFetcher`.
    /// Liên kết tĩnh thì link lỗi (1181 duplicate symbols). Rủi ro thấp: GTMLogger chỉ ghi log,
    /// GTMSessionFetcher dùng tải model qua mạng — model ML Kit của app đóng sẵn trong bundle.
    /// Thêm tên vào đây phải hỏi người dùng trước (xem AGENTS.md, mục Build & test).
    private static let knownGTMDuplicates: Set<String> = [
        "GTMLogger", "GTMLogBasicFormatter", "GTMLogStandardFormatter", "GTMLogLevelFilter",
        "GTMLogNoFilter", "GTMLogAllowedLevelFilter", "GTMLogMininumLevelFilter", "GTMLogMaximumLevelFilter",
        "GTMSessionFetcher", "GTMSessionCookieStorage", "GTMUserAgentStringProvider",
        "GTMStandardUserAgentProvider", "GTMSessionFetcherService",
        "GTMSessionFetcherSessionDelegateDispatcher", "GTMSessionUploadFetcher",
    ]

    /// Tương đương cảnh báo runtime `Class X is implemented in both A and B`:
    /// tên class ObjC xuất hiện ở ≥ 2 image đã nạp, trong đó ít nhất một image nằm trong app bundle.
    ///
    /// Bỏ qua chính test bundle (`PlugIns/*.xctest`): `onnxruntime_objc` là framework TĨNH với symbol ẩn
    /// (`nm`: `s _OBJC_CLASS_$_ORTEnv`), nên test gọi `ORTSession` thì buộc phải link bản riêng — trùng đó
    /// chỉ có khi chạy test, app thật chỉ có một bản. Test này kiểm cái app phát hành.
    @Test("Không có class ObjC trùng giữa MediaPipe / ML Kit / ONNX Runtime / app (trừ GTM đã biết)")
    func testNoDuplicateObjCClasses() {
        let bundlePath = Bundle.main.bundlePath
        let testBundlesPath = Bundle.main.builtInPlugInsPath ?? bundlePath + "/PlugIns"
        var owner: [String: String] = [:]
        var duplicates: [String] = []

        for i in 0..<_dyld_image_count() {
            guard let cImage = _dyld_get_image_name(i) else { continue }
            let image = String(cString: cImage)
            if image.hasPrefix(testBundlesPath) { continue }
            var count: UInt32 = 0
            guard let names = objc_copyClassNamesForImage(cImage, &count) else { continue }
            defer { free(UnsafeMutableRawPointer(mutating: names)) }

            for j in 0..<Int(count) {
                let name = String(cString: names[j])
                if Self.knownGTMDuplicates.contains(name) { continue }
                if let previous = owner[name], previous != image {
                    if previous.hasPrefix(bundlePath) || image.hasPrefix(bundlePath) {
                        duplicates.append("\(name): \(previous) ↔ \(image)")
                    }
                } else {
                    owner[name] = image
                }
            }
        }

        #expect(duplicates.isEmpty, "Class ObjC trùng:\n\(duplicates.joined(separator: "\n"))")
    }

    /// Kiểm bản ĐÃ BIÊN DỊCH trong bundle (`<lang>.lproj/Localizable.strings` + `.stringsdict`),
    /// không đọc `.xcstrings` nguồn: app chạy trong sandbox không đọc được thư mục repo, và cái người dùng
    /// nhận là bản biên dịch.
    @Test("String Catalog: đủ 477 chuỗi + 3 plurals, en và vi khớp key")
    func testStringCatalogParity() throws {
        func keys(_ lang: String, _ type: String) -> Set<String> {
            guard let path = Bundle.main.path(forResource: "Localizable", ofType: type, inDirectory: nil, forLocalization: lang),
                  let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
                Issue.record("Thiếu hoặc không đọc được \(lang).lproj/Localizable.\(type)")
                return []
            }
            return Set(dict.keys)
        }

        let enStrings = keys("en", "strings"), viStrings = keys("vi", "strings")
        let enPlurals = keys("en", "stringsdict"), viPlurals = keys("vi", "stringsdict")

        #expect(enStrings.count == 477, "en: \(enStrings.count) chuỗi, kỳ vọng 477")
        #expect(enPlurals.count == 3, "en: \(enPlurals.count) plural, kỳ vọng 3")
        #expect(enStrings == viStrings, "Lệch key chuỗi — thiếu vi: \(enStrings.subtracting(viStrings).sorted()), thiếu en: \(viStrings.subtracting(enStrings).sorted())")
        #expect(enPlurals == viPlurals, "Lệch key plural — thiếu vi: \(enPlurals.subtracting(viPlurals).sorted()), thiếu en: \(viPlurals.subtracting(enPlurals).sorted())")
    }
}
