import Foundation

/// Public teaching material only. Correct answers and grading criteria remain on the server.
struct ClassroomTeachingVisual: Codable, Equatable {
    struct Item: Codable, Equatable {
        let label: String
        let detail: String
    }
    let kind: String
    let title: String
    let caption: String
    let description: String
    let parts: Int
    let whole: Double
    let unit: String
    let value: Int
    let entries: [Item]
    let expression: String
    let params: [ExplorableConfig.ExplorableParam]
    let xMin: Double
    let xMax: Double
    let yMin: Double
    let yMax: Double

    enum CodingKeys: String, CodingKey {
        case kind, title, caption, description, parts, whole, unit, value, entries, expression, params
        case xMin = "x_min", xMax = "x_max"
        case yMin = "y_min", yMax = "y_max"
    }

    var isValid: Bool {
        switch kind {
        case "fraction_bar": return (2...20).contains(parts) && (0...parts).contains(value) && whole.isFinite && whole > 0
        case "comparison", "sequence": return (2...6).contains(entries.count) && entries.indices.contains(value)
        case "graph": return !expression.isEmpty && (1...3).contains(params.count) && Set(params.map(\.name)).count == params.count && xMin.isFinite && xMax.isFinite && xMin < xMax && yMin.isFinite && yMax.isFinite && yMin < yMax && params.allSatisfy {
            $0.min.isFinite && $0.max.isFinite && $0.initial.isFinite && ($0.step ?? 1).isFinite && ($0.step ?? 1) > 0 && $0.min < $0.max && ($0.min...$0.max).contains($0.initial)
        }
        default: return false
        }
    }
}
