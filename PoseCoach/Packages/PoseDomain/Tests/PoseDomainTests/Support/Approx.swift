/// Tương đương `assertEquals(expected, actual, delta)` của JUnit: |actual − expected| ≤ delta.
func isClose(_ actual: Double, _ expected: Double, _ delta: Double) -> Bool {
    abs(actual - expected) <= delta
}
