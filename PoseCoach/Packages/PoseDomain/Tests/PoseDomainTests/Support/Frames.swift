@testable import PoseDomain

/// Dựng `PoseFrame` 33 điểm; mốc không truyền vào để tin cậy 0 nên bị bỏ qua.
/// Tương đương hàm `frameOf` mà mỗi file test Kotlin tự chép lại.
func frameOf(_ entries: (Int, (P2, Float, P3))...) -> PoseFrame {
    var pts = Array(repeating: P2(0, 0), count: 33)
    var vis = Array(repeating: Float(0), count: 33)
    var wld = Array(repeating: P3(0, 0, 0), count: 33)
    for (i, t) in entries { pts[i] = t.0; vis[i] = t.1; wld[i] = t.2 }
    return PoseFrame(points: pts, visibility: vis, world: wld, timestampMs: 0)
}

/// Mốc tin cậy 0,99, toạ độ thật chỉ có x/y (z = 0) — dạng `lm(u, v, wx, wy)` của nhiều file test Kotlin.
func lm(_ u: Double, _ v: Double, _ wx: Double = 0, _ wy: Double = 0) -> (P2, Float, P3) {
    (P2(u, v), 0.99, P3(wx, wy, 0.0))
}

/// Chạy engine đủ lâu với cùng một số đo, trả kết quả cuối.
@discardableResult
func chayEngine(
    _ engine: GuidanceEngine, _ live: PoseMeasurement?, tu: Int64 = 0, den: Int64, buoc: Int64 = 100
) -> GuidanceResult {
    var r = engine.update(live, tu, 0.0)
    var t = tu
    while t + buoc <= den {
        t += buoc
        r = engine.update(live, t, 0.0)
    }
    return r
}
