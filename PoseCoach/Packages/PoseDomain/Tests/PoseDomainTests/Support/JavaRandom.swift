/// Bản chép `java.util.Random` (LCG 48 bit) — test Kotlin dùng `Random(seed)` để sinh dữ liệu lặp lại được, chép
/// đúng thuật toán để dãy số giống hệt bên Android.
struct JavaRandom {
    private static let multiplier: UInt64 = 0x5DEECE66D
    private static let mask: UInt64 = (1 << 48) - 1

    private var seed: UInt64

    init(_ seed: Int64) {
        self.seed = (UInt64(bitPattern: seed) ^ Self.multiplier) & Self.mask
    }

    private mutating func next(_ bits: Int) -> Int64 {
        seed = (seed &* Self.multiplier &+ 0xB) & Self.mask
        return Int64(Int32(truncatingIfNeeded: seed >> UInt64(48 - bits)))
    }

    mutating func nextDouble() -> Double {
        Double((next(26) << 27) + next(27)) * 0x1.0p-53
    }
}
