import CoreMotion
import Foundation

/// Đọc độ nghiêng của máy từ cảm biến. Port từ `KT/sensors/DeviceTilt.kt`.
///
/// Nuôi hai thứ:
///   - Mục 4 (máy ngửa/chúc) — tiêu chí DUY NHẤT được siết tới 5°, vì cảm biến chính xác dưới 1°.
///   - Tốc độ góc — cổng chống chụp lúc tay đang đưa (15°/s), đóng băng hướng dẫn khi lắc mạnh (45°/s), loại khung rung.
///
/// ⚠️ Lấy từ VECTOR TRỌNG LỰC, không lấy từ `attitude`: `attitude.pitch` bị "khoá gimbal" khi cầm máy dựng đứng — đúng
/// tư thế chụp ảnh dọc mà app này dùng nhiều nhất.
///
/// Khác Android: `CMDeviceMotion.gravity` hướng XUỐNG (đặt máy nằm ngửa đọc được `(0, 0, -1)`), còn `TYPE_GRAVITY` của
/// Android hướng LÊN (`(0, 0, +9,81)`). Hai hệ trục giống nhau (x sang phải · y lên đỉnh máy · z ra phía người dùng), nên
/// vector Android = −vector CoreMotion; công thức dưới đã đổi dấu theo đó, kết quả giữ đúng quy ước Android.
nonisolated final class DeviceTilt {

    struct Reading {
        /// Góc ngẩng của trục ống kính so với MẶT PHẲNG NGANG, độ. Dương = máy ngửa lên trời. Âm = chúc xuống đất.
        var cameraPitchDeg: Double = 0.0
        /// Độ vẹo chân trời, độ. Chỉ đọc để tự nắn ảnh, KHÔNG dùng để hướng dẫn.
        var rollDeg: Double = 0.0
        /// Tốc độ quay của máy, độ/giây. Càng lớn = tay càng đang di chuyển.
        var angularSpeedDegPerSec: Double = 0.0
        var hasData: Bool = false
    }

    private let manager = CMMotionManager.shared
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "DeviceTilt"
        q.maxConcurrentOperationCount = 1
        return q
    }()
    private let lock = NSLock()
    private var _state = Reading()

    /// Máy này có đủ cảm biến không. Thiếu con quay hồi chuyển là hỏng 4 thứ (FOOTGUNS mục 2).
    /// iOS gộp gravity vào `deviceMotion` — có `deviceMotion` là có vector trọng lực.
    var hasGravity: Bool { manager.isDeviceMotionAvailable }
    var hasGyroscope: Bool { manager.isGyroAvailable }

    /// Số đọc mới nhất. Đọc được từ mọi luồng.
    var state: Reading {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        // ~50 Hz, tương đương `SENSOR_DELAY_GAME` (20 ms).
        manager.deviceMotionUpdateInterval = 0.02
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.onMotion(motion)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func onMotion(_ motion: CMDeviceMotion) {
        var next = state

        // --- TYPE_GRAVITY ---
        // Đổi sang quy ước Android (vector HƯỚNG LÊN): g_android = −g_coremotion.
        let gx = -motion.gravity.x
        let gy = -motion.gravity.y
        let gz = -motion.gravity.z
        let mag = (gx * gx + gy * gy + gz * gz).squareRoot()
        if mag >= 1e-6 {
            // sin(góc ngẩng) = trục ống kính sau (0, 0, −1) · hướng lên (gx, gy, gz)/|g| = −gz/|g|
            //   nằm ngửa trên bàn (camera chúc xuống đất): −90° · cầm dọc: 0° · nằm sấp (camera nhìn trời): +90°
            let sinPitch = min(max(-gz / mag, -1.0), 1.0)
            next.cameraPitchDeg = toDegrees(asin(sinPitch))
            // Độ vẹo. Dấu cần kiểm lại trên máy thật, nhưng không gấp: không hướng dẫn nắn vẹo, chỉ tự nắn ảnh dưới 3°.
            next.rollDeg = toDegrees(atan2(-gx, gy))
            next.hasData = true
        }

        // --- TYPE_GYROSCOPE --- radian/giây quanh 3 trục, lấy độ lớn tổng hợp.
        let wx = motion.rotationRate.x
        let wy = motion.rotationRate.y
        let wz = motion.rotationRate.z
        next.angularSpeedDegPerSec = toDegrees((wx * wx + wy * wy + wz * wz).squareRoot())

        lock.lock()
        _state = next
        lock.unlock()
    }

    private func toDegrees(_ rad: Double) -> Double { rad * 180.0 / .pi }
}
