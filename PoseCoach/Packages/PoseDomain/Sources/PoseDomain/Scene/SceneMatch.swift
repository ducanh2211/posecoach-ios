import Foundation

/// Port từ `KT/scene/SceneMatch.kt` — gợi ý ảnh mẫu theo BỐI CẢNH (09/10/2026).
///
/// - `titleRes`: key String Catalog (xem `UiText`).
public struct SceneTag: Equatable, Sendable {
    public let id: String
    public let titleRes: String
    public let confidence: Float

    public init(_ id: String, _ titleRes: String, _ confidence: Float) {
        self.id = id
        self.titleRes = titleRes
        self.confidence = confidence
    }
}

public struct SceneFrame: Equatable, Sendable {
    public let timeMs: Int64
    public let tags: [SceneTag]

    public init(_ timeMs: Int64, _ tags: [SceneTag]) {
        self.timeMs = timeMs
        self.tags = tags
    }
}

public struct SceneTemplate: Equatable, Sendable {
    public let file: URL
    public let name: String
    public let tags: [SceneTag]

    public init(_ file: URL, _ name: String, _ tags: [SceneTag]) {
        self.file = file
        self.name = name
        self.tags = tags
    }
}

/// - `missing`: yếu tố người dùng đang tìm mà ảnh mẫu này KHÔNG có. PO chốt 09/10/2026: ảnh khớp một phần vẫn hiện,
///   nhưng phải ghi rõ thiếu gì.
public struct SceneMatch: Equatable, Sendable {
    public let template: SceneTemplate
    public let shared: [SceneTag]
    public let score: Float
    public let missing: [SceneTag]

    public init(_ template: SceneTemplate, shared: [SceneTag], score: Float, missing: [SceneTag] = []) {
        self.template = template
        self.shared = shared
        self.score = score
        self.missing = missing
    }

    /// Mức hợp bối cảnh 0..100 — phần yếu tố của cảnh (theo độ tin) mà ảnh mẫu này cũng có. Chỉ để HIỂN THỊ; xếp hạng
    /// vẫn theo `score`.
    public var phanTramHop: Int {
        let tong = (shared + missing).reduce(0.0) { $0 + Double($1.confidence) }
        if tong <= 0.0 { return 0 }
        // `roundToInt` của Kotlin làm tròn nửa lên.
        let r = Int((Double(score) / tong * 100 + 0.5).rounded(.down))
        return min(max(r, 0), 100)
    }
}

/// Chỉ giữ yếu tố bối cảnh; người/quần áo/selfie không được lấn át cảnh.
public enum SceneMatching {

    /// Nhãn ML Kit → key String Catalog.
    private static let names: [String: String] = [
        "Flower": "scene_flower", "Flowerpot": "scene_flowerpot", "Plant": "scene_plant",
        "Garden": "scene_garden", "Tree": "scene_tree", "Forest": "scene_forest",
        "Beach": "scene_beach", "Sand": "scene_sand", "Sea": "scene_sea",
        "Water": "scene_water", "Lake": "scene_lake", "River": "scene_river",
        "Waterfall": "scene_waterfall", "Mountain": "scene_mountain", "Field": "scene_field",
        "Sky": "scene_sky", "Cloud": "scene_cloud", "Sunset": "scene_sunset",
        "Snow": "scene_snow", "Rock": "scene_rock", "Room": "scene_room",
        "Wall": "scene_wall", "Window": "scene_window", "Door": "scene_door",
        "Bench": "scene_bench", "Chair": "scene_chair", "Table": "scene_table",
        "Couch": "scene_couch", "Loveseat": "scene_loveseat", "Shelf": "scene_shelf",
        "Curtain": "scene_curtain", "Kitchen": "scene_kitchen", "Countertop": "scene_countertop",
        "Building": "scene_building", "Skyscraper": "scene_skyscraper", "Bridge": "scene_bridge",
        "Road": "scene_road", "Street": "scene_street", "Temple": "scene_temple",
        "Castle": "scene_castle", "Museum": "scene_museum", "Handrail": "scene_handrail",
        "Bicycle": "scene_bicycle", "Car": "scene_car", "Boat": "scene_boat",
        "Cup": "scene_cup", "Coffee": "scene_coffee", "Cappuccino": "scene_cappuccino",
        "Umbrella": "scene_umbrella", "Balloon": "scene_balloon",
    ]

    public static func tag(_ label: String, _ confidence: Float) -> SceneTag? {
        guard let res = names[label] else { return nil }
        return confidence.isFinite && confidence >= 0.6 ? SceneTag(label, res, confidence) : nil
    }

    /// Nhãn hiểu được từ chữ gõ — coi như chắc chắn (độ tin cậy 1). `nil` = nhãn không hỗ trợ.
    public static func typedTag(_ label: String) -> SceneTag? {
        names[label].map { SceneTag(label, $0, 1) }
    }

    /// Mỗi nhãn lấy lần có độ tin cao nhất, sắp giảm dần theo độ tin.
    public static func tags(_ frames: [SceneFrame]) -> [SceneTag] {
        // `groupBy` giữ thứ tự xuất hiện đầu tiên; `maxBy` lấy phần tử lớn nhất ĐẦU TIÊN.
        var order: [String] = []
        var best: [String: SceneTag] = [:]
        for t in frames.flatMap(\.tags) {
            if let cur = best[t.id] {
                if t.confidence > cur.confidence { best[t.id] = t }
            } else {
                order.append(t.id)
                best[t.id] = t
            }
        }
        return stableSorted(order.map { best[$0]! }) { $0.confidence > $1.confidence }
    }

    /// So từng góc riêng: không cộng các đồ vật ở hai đầu video thành một cảnh.
    public static func rank(_ frames: [SceneFrame], _ templates: [SceneTemplate], _ selected: Set<String>) -> [SceneMatch] {
        let matches = templates.compactMap { template -> SceneMatch? in
            var templateTags: [String: SceneTag] = [:]
            // `associateBy`: trùng khoá thì phần tử SAU thắng.
            for t in template.tags { templateTags[t.id] = t }
            var best: SceneMatch?
            for frame in frames {
                var seen = Set<String>()
                let wanted = frame.tags.filter { selected.contains($0.id) && seen.insert($0.id).inserted }
                let shared = wanted.filter { templateTags[$0.id] != nil }
                if shared.isEmpty { continue }
                let score = Float(shared.reduce(0.0) { $0 + Double($1.confidence * templateTags[$1.id]!.confidence) })
                let m = SceneMatch(
                    template, shared: shared, score: score,
                    missing: wanted.filter { templateTags[$0.id] == nil }
                )
                // `maxByOrNull`: lấy phần tử lớn nhất ĐẦU TIÊN.
                if best == nil || m.score > best!.score { best = m }
            }
            return best
        }
        return stableSorted(matches) { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.template.file.lastPathComponent < b.template.file.lastPathComponent
        }
    }

    public static func sampleTimes(_ durationMs: Int64) -> [Int64] {
        precondition(durationMs > 0)
        let count = min(12, (durationMs - 1) / 1000 + 1)
        return (0..<count).map { i in durationMs * i / count }
    }

    /// Sắp ổn định như `sortedWith` của Kotlin — `sort` của Swift không hứa giữ thứ tự khi hoà.
    private static func stableSorted<T>(_ xs: [T], _ before: (T, T) -> Bool) -> [T] {
        xs.indices.sorted { i, j in
            before(xs[i], xs[j]) || (!before(xs[j], xs[i]) && i < j)
        }.map { xs[$0] }
    }
}
