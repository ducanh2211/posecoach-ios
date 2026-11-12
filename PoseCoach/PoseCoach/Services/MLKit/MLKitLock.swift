import Foundation

/// KHOÁ CHUNG cho mọi lệnh chạy ML Kit (`FaceAnalyzer`, `ImageLabels`).
///
/// ⚠️ Hai bộ dò ML Kit chạy cùng lúc trên hai luồng thì SẬP (đo 12/11/2026: `EXC_BAD_ACCESS` trong `xnn_plan_memory` của
/// TFLite/XNNPACK, hai `FaceAnalyzer` khác nhau cùng gọi `results(in:)`) — kể cả khi mỗi luồng dùng một bộ dò riêng.
/// Android không gặp: ML Kit Android tự xếp hàng trong executor của nó. Khoá ở đây thay cho hàng đợi đó.
nonisolated enum MLKitLock {
    static let lock = NSLock()
}
