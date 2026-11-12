import Foundation
import Testing
@testable import PoseDomain

/// Port từ `KTT/SceneMatchingTest.kt`.
struct SceneMatchingTest {

    private func tag(_ id: String, _ confidence: Float = 0.9) -> SceneTag { SceneMatching.tag(id, confidence)! }

    private func template(_ name: String, _ tags: String...) -> SceneTemplate {
        SceneTemplate(URL(fileURLWithPath: name), name, tags.map { tag($0) })
    }

    @Test("person and weak guesses do not drive background suggestions")
    func personAndWeakGuesses() {
        #expect(SceneMatching.tag("Person", 0.99) == nil)
        #expect(SceneMatching.tag("Flower", 0.3) == nil)
        #expect(SceneMatching.tag("Flower", .nan) == nil)
    }

    @Test("templates without shared elements are not returned")
    func withoutShared() {
        let matches = SceneMatching.rank(
            [SceneFrame(0, [tag("Flower")])], [template("beach", "Beach")], ["Flower"]
        )
        #expect(matches.isEmpty)
    }

    @Test("removing a mistaken label removes its suggestions")
    func removingMistakenLabel() {
        let frames = [SceneFrame(0, [tag("Flower"), tag("Beach")])]
        let matches = SceneMatching.rank(frames, [template("flowers", "Flower"), template("beach", "Beach")], ["Beach"])
        #expect(matches.map(\.template.name) == ["beach"])
    }

    @Test("different video angles cannot add up to a fictitious scene")
    func differentAngles() throws {
        let frames = [SceneFrame(0, [tag("Flower")]), SceneFrame(1000, [tag("Bench")])]
        let result = SceneMatching.rank(frames, [template("both", "Flower", "Bench")], ["Flower", "Bench"])
        #expect(result.count == 1)
        let r = try #require(result.first)
        #expect(r.shared.count == 1)
        #expect(abs(r.score - 0.81) <= 0.001)
    }

    @Test("repeated frames do not increase ranking score")
    func repeatedFrames() {
        let frame = SceneFrame(0, [tag("Flower")])
        let templates = [template("flowers", "Flower")]
        #expect(
            SceneMatching.rank([frame], templates, ["Flower"])
                == SceneMatching.rank(Array(repeating: frame, count: 12), templates, ["Flower"])
        )
    }

    @Test("video samples cover the clip and stay below its duration")
    func videoSamples() {
        #expect(SceneMatching.sampleTimes(1) == [0])
        let times = SceneMatching.sampleTimes(60_000)
        #expect(times.count == 12)
        #expect(Set(times).count == times.count)
        #expect(times.last == 55_000)
        #expect(times.allSatisfy { (0..<60_000).contains($0) })
    }

    @Test("phần trăm hợp bằng phần yếu tố cảnh mà ảnh mẫu cũng có")
    func phanTramHop() {
        let bien = SceneTag("Beach", "", 1)
        let troi = SceneTag("Sky", "", 1)
        let f = URL(fileURLWithPath: "x.jpg")
        let m = SceneMatch(SceneTemplate(f, "x", [bien]), shared: [bien], score: 1, missing: [troi])
        #expect(m.phanTramHop == 50)
        #expect(SceneMatch(SceneTemplate(f, "x", []), shared: [], score: 0).phanTramHop == 0)
    }
}
