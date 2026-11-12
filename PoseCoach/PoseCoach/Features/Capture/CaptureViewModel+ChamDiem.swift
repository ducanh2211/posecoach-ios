import CoreGraphics
import Foundation
import PoseDomain

/// CHẤM ĐIỂM SAU KHI CHỤP / QUAY. Port `processRecording` + `processBurst` trong `KT/capture/CaptureScreen.kt`.
///
/// ⚠️ Vì sao quay rồi mới chấm, thay vì chấm ngay lúc quay: khung đưa vào nhận diện chỉ ~640 px (cố ý, cho nhanh); lấy
/// chính nó làm ảnh cuối thì ảnh xấu. Quay Full HD / chụp đủ độ phân giải rồi cắt ra mới đúng thiết kế sản phẩm.
///
/// Khác Android: không có nhánh `catch (Throwable)` — các hàm Swift ở đây không ném lỗi; mọi nhánh hỏng đã có câu báo
/// riêng (luật số 7).
extension CaptureViewModel {

    /// Bước nhảy khi quét video để chấm. ⚠️ Đi cùng chế độ lấy KHUNG KHOÁ của `VideoFrameSource` — video điện thoại 1-2
    /// giây mới có một khung khoá, quét dày hơn chỉ lấy lại cùng một khung (FOOTGUNS 31).
    nonisolated static let scoreStepMs: Int64 = 500
    /// Cạnh ngắn khi CHẤM ĐIỂM — nhỏ cho nhanh, ảnh này không dùng làm ảnh cuối.
    nonisolated static let scoringShortSide = 480
    /// Cạnh ngắn khi CẮT ẢNH CUỐI từ video — chỉ làm với ≤ 12 khung chung kết nên chậm cũng không sao.
    nonisolated static let finalShortSide = 1440
    /// Cạnh ngắn ẢNH CUỐI khi CHỤP LIÊN TỤC — gần bằng cảm biến 12 MP. Không mở nguyên cỡ (máy 50 MP ~200 MB một tấm).
    nonisolated static let burstFinalShortSide = 3024

    /// Báo tiến độ / kết quả từ luồng nền về ViewModel.
    private struct BaoVe: Sendable {
        let vm: CaptureViewModel

        func tienDo(_ p: Float, _ note: UiText) { vm.onProcessing(p, note) }
        func hong(_ m: UiText) { vm.onProcessingFailed(m) }
        func xong(_ dir: URL) { vm.onFinished(dir) }
    }

    /// Chấm từng khung của video vừa quay, giữ 5 khung khớp ảnh mẫu nhất, rồi XOÁ video thô.
    func processRecording(_ video: URL) {
        guard let profile = templateProfile else {
            onProcessingFailed(uiText("process_err_no_profile"))
            try? FileManager.default.removeItem(at: video)
            return
        }
        onProcessing(0, uiText("process_opening_video"))
        let bao = BaoVe(vm: self)
        let tiLe = tiLeKhung
        Task.detached {
            let small = await VideoFrameSource.open(video, targetShortSide: Self.scoringShortSide)
            defer { small.close() }
            if !small.isValid || small.durationMs <= 0 {
                await bao.hong(uiText("process_err_read_video"))
                return
            }
            let an = VideoPoseAnalyzer()
            defer { an.close() }
            if !an.isReady {
                await bao.hong(uiText("process_err_model"))
                return
            }

            let store = ShotStore.createSession()
            let session = ShotSession(store, profile, Self.minVis, faceAnalyzer: FaceAnalyzer(), tiLeKhung: tiLe)

            var pos: Int64 = 0
            var seen = 0
            while pos <= small.durationMs {
                if let bmp = await small.frameAt(pos), let pose = an.analyze(bmp, pos), !pose.isEmpty {
                    session.offer(bmp, pose, pos)
                    seen += 1
                }
                pos += Self.scoreStepMs
                await bao.tienDo(
                    Float(pos) / Float(small.durationMs),
                    uiText("process_scoring_seconds",
                           .int(Int((Double(pos) / 1000).rounded())),
                           .int(Int((Double(small.durationMs) / 1000).rounded())))
                )
            }

            if seen == 0 {
                // Không "thất bại im lặng" (luật số 7): nói rõ chuyện gì đã xảy ra.
                await bao.hong(uiText("process_err_no_person_video"))
                store.deleteSession()
                return
            }

            await bao.tienDo(1, uiText("process_extracting"))

            // Cắt lại ở độ phân giải cao NGAY TRONG bước chốt: mắt nhắm và độ nét chấm trên đúng tấm ảnh sẽ giao.
            let big = await VideoFrameSource.open(video, targetShortSide: Self.finalShortSide)
            defer { big.close() }
            await session.finish(keepCount: 5, highRes: big.isValid ? { t in await big.frameAt(t) } : nil)

            // Xoá video thô — rác nặng nhất của app (30 giây Full HD ~60-100 MB).
            try? FileManager.default.removeItem(at: video)

            await bao.xong(store.sessionDir)
        }
    }

    /// CHẤM ĐIỂM MỘT LOẠT ẢNH CHỤP LIÊN TỤC. Khác đường video đúng ở chỗ lấy ảnh từ đâu: mỗi tấm đã là ảnh chụp thật.
    /// Mọi bước phía sau — đo, chấm, giữ 5 tấm, xoá phần còn lại — dùng chung `ShotSession`.
    func processBurst(_ photos: [URL]) {
        guard let profile = templateProfile else {
            onProcessingFailed(uiText("process_err_no_profile"))
            photos.forEach { try? FileManager.default.removeItem(at: $0) }
            return
        }
        if photos.isEmpty {
            onProcessingFailed(uiText("process_err_no_photos"))
            return
        }
        onProcessing(0, uiText("process_reviewing_burst"))
        let bao = BaoVe(vm: self)
        let tiLe = tiLeKhung
        Task.detached {
            let store = ShotStore.createSession()
            let session = ShotSession(store, profile, Self.minVis, faceAnalyzer: FaceAnalyzer(), tiLeKhung: tiLe)

            // Mốc thời gian theo đúng nhịp đã chụp, để bộ giữ khung áp được luật "hai tấm giữ lại phải cách nhau".
            let stamps = photos.indices.map { Int64($0 * Self.burstIntervalMs) }
            var seen = 0

            for (i, file) in photos.enumerated() {
                if let bmp = UprightImage.decode(file, shortSide: Self.finalShortSide),
                   let pose = StillPoseAnalyzer.analyze(bmp), !pose.isEmpty {
                    session.offer(bmp, pose, stamps[i])
                    seen += 1
                }
                await bao.tienDo(Float(i + 1) / Float(photos.count),
                                 uiText("process_scoring_photos", .int(i + 1), .int(photos.count)))
            }

            if seen == 0 {
                await bao.hong(uiText("process_err_no_person_burst"))
                store.deleteSession()
                photos.forEach { try? FileManager.default.removeItem(at: $0) }
                return
            }

            // Ảnh gốc vẫn còn trên đĩa nên lấy lại được theo mốc thời gian.
            let kept = await session.finish(keepCount: 5) { t in
                guard let idx = stamps.firstIndex(of: t), photos.indices.contains(idx) else { return nil }
                return UprightImage.decode(photos[idx], shortSide: Self.burstFinalShortSide)
            }
            if kept.isEmpty {
                await bao.hong(uiText("process_err_none_kept"))
                store.deleteSession()
            } else {
                await bao.xong(store.sessionDir)
            }

            // Ảnh gốc của loạt là rác sau khi đã cắt xong — xoá ngay, cùng nguyên tắc với video thô.
            photos.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }
}
