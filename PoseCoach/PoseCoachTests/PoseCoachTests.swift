import Testing
import Foundation
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

        let landmarker = try PoseLandmarker(options: poseOptions)
        #expect(landmarker != nil)

        // 2. ML Kit FaceDetector (dùng MLKitFaceDetection để tránh xung đột với MediaPipe)
        let faceOptions = MLKitFaceDetection.FaceDetectorOptions()
        faceOptions.performanceMode = .fast
        let faceDetector = MLKitFaceDetection.FaceDetector.faceDetector(options: faceOptions)
        #expect(faceDetector != nil)

        // 3. ML Kit ImageLabeler
        let labelerOptions = MLKitImageLabeling.ImageLabelerOptions()
        labelerOptions.confidenceThreshold = 0.2
        let imageLabeler = MLKitImageLabeling.ImageLabeler.imageLabeler(options: labelerOptions)
        #expect(imageLabeler != nil)

        // 4. ONNX Runtime ORTSession
        guard let onnxURL = findBundleFile(named: "geocalib-mang-int8", withExtension: "onnx") else {
            Issue.record("Thiếu model geocalib-mang-int8.onnx")
            return
        }
        let ortEnv = try ORTEnv(loggingLevel: .warning)
        let sessionOptions = try ORTSessionOptions()
        let session = try ORTSession(env: ortEnv, modelPath: onnxURL.path, sessionOptions: sessionOptions)
        #expect(session != nil)
    }

    @Test("String Catalog: Đủ 477 chuỗi + 3 plurals, mỗi key đủ en và vi")
    func testStringCatalogParity() throws {
        // Đọc Localizable.xcstrings từ bundle hoặc fallback từ repo
        var catalogURL = findBundleFile(named: "Localizable", withExtension: "xcstrings")
        if catalogURL == nil {
            let sourceURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("PoseCoach/Resources/Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                catalogURL = sourceURL
            }
        }

        guard let catalogURL = catalogURL, FileManager.default.fileExists(atPath: catalogURL.path) else {
            Issue.record("Không tìm thấy Localizable.xcstrings")
            return
        }

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let strings = json?["strings"] as? [String: [String: Any]] else {
            Issue.record("Định dạng Localizable.xcstrings không hợp lệ")
            return
        }

        #expect(strings.count == 480, "Tổng số key là \(strings.count), kỳ vọng đúng 480 (477 chuỗi + 3 plurals)")

        var missingEn: [String] = []
        var missingVi: [String] = []

        for (key, content) in strings {
            guard let locs = content["localizations"] as? [String: Any] else {
                missingEn.append(key)
                missingVi.append(key)
                continue
            }
            if locs["en"] == nil { missingEn.append(key) }
            if locs["vi"] == nil { missingVi.append(key) }
        }

        #expect(missingEn.isEmpty, "Các key thiếu tiếng Anh: \(missingEn)")
        #expect(missingVi.isEmpty, "Các key thiếu tiếng Việt: \(missingVi)")
    }
}
