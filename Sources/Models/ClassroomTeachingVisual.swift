import Foundation

/// Public teaching material only. Correct answers and grading criteria remain on the server.
struct ClassroomTeachingVisual: Codable, Equatable {
    struct Item: Codable, Equatable {
        let label: String
        let detail: String
        let position: Double?
        let x: Double?
        let y: Double?

        init(label: String, detail: String, position: Double? = nil, x: Double? = nil, y: Double? = nil) {
            self.label = label
            self.detail = detail
            self.position = position
            self.x = x
            self.y = y
        }
    }

    let visualId: String?
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
    let imageQuery: String?
    let imageUrl: String?
    let sourceUrl: String?
    let attribution: String?

    enum CodingKeys: String, CodingKey {
        case kind, title, caption, description, parts, whole, unit, value, entries, expression, params
        case visualId = "visual_id"
        case xMin = "x_min", xMax = "x_max"
        case yMin = "y_min", yMax = "y_max"
        case imageQuery = "image_query"
        case imageUrl = "image_url"
        case sourceUrl = "source_url"
        case attribution
    }

    private func isTrustedImage(_ raw: String?) -> Bool {
        guard let raw, let url = URL(string: raw), url.scheme == "https" else { return raw == nil }
        return url.host == "upload.wikimedia.org" || url.host == "commons.wikimedia.org"
    }

    var isValid: Bool {
        switch kind {
        case "fraction_bar", "fraction_pie":
            return ((kind == "fraction_pie" ? 1 : 2)...20).contains(parts) && (0...parts).contains(value) && whole.isFinite && whole > 0
        case "comparison", "sequence", "process_flow", "timeline":
            return (2...8).contains(entries.count) && entries.indices.contains(value)
        case "number_line":
            return (2...8).contains(entries.count)
                && entries.indices.contains(value)
                && xMin.isFinite && xMax.isFinite && xMin < xMax
                && entries.allSatisfy { item in
                    guard let position = item.position else { return false }
                    return position.isFinite && position >= xMin && position <= xMax
                }
        case "annotated_image":
            return !(imageQuery ?? "").isEmpty
                && isTrustedImage(imageUrl)
                && isTrustedImage(sourceUrl)
                && entries.allSatisfy { item in
                    if item.x == nil && item.y == nil { return true }
                    guard let x = item.x, let y = item.y else { return false }
                    return x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
                }
        case "graph":
            return !expression.isEmpty && (1...3).contains(params.count)
                && Set(params.map(\.name)).count == params.count
                && xMin.isFinite && xMax.isFinite && xMin < xMax
                && yMin.isFinite && yMax.isFinite && yMin < yMax
                && params.allSatisfy {
                    $0.min.isFinite && $0.max.isFinite && $0.initial.isFinite
                        && ($0.step ?? 1).isFinite && ($0.step ?? 1) > 0
                        && $0.min < $0.max && ($0.min...$0.max).contains($0.initial)
                }
        default:
            return false
        }
    }
}
