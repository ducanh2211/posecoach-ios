import PoseDomain

/// Trạng thái màn chụp. Port `KT/capture/CaptureUiState.kt` — **mới phần camera** (kéo sớm để kiểm 3b trên iPhone).
/// Phần ảnh mẫu, hướng dẫn, đếm ngược, chấm điểm thêm ở bước 4c.
struct CaptureUiState {

    /// Chế độ chụp: AI cầm máy, camera nào, ảnh có lật không.
    var mode: ShootMode = .nguoiKhac

    // --- Camera ---
    var cameraReady = false
    var cameraError: UiText?
    var liveDetectionActive = true

    // --- Nhận diện thời gian thực ---
    var pose: PoseFrame = .empty
    var personDetected = false
    var inferenceMs: Int64 = 0
    /// Cỡ khung đã cắt theo tỉ lệ khung — khung xương vẽ theo cỡ này.
    var frameWidth = 0
    var frameHeight = 0

    var devicePortrait = true

    // --- Quay / chụp liên tục ---
    /// Mặc định CHỤP LIÊN TỤC (PO 08/10/2026).
    var burstMode = true
    var burstTaken = 0
    var recording = false
    var recordedMs: Int64 = 0

    /// Quay đủ tối thiểu mới cho dừng.
    var canStop: Bool { recordedMs >= Self.minRecordMs }

    static let minRecordMs: Int64 = 3_000
    static let maxRecordMs: Int64 = 30_000
}
