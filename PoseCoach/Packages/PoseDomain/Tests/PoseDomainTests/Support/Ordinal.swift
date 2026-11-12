/// Thứ tự khai báo trong enum — tương đương `ordinal` của Kotlin.
func ordinal<T: CaseIterable & Equatable>(_ x: T) -> Int {
    T.allCases.distance(from: T.allCases.startIndex, to: T.allCases.firstIndex(of: x)!)
}
