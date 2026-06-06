import Foundation

// MARK: - Open Classroom Shared Models
// Consolidated from CourseModels.swift and LyoChat.swift to avoid ambiguous type errors.

struct OpenClassroomPayload: Codable {
    let stackItem: StackItemPayload?
    let course: CoursePayload
    var components: [OpenClassroomComponent]? = nil

    enum CodingKeys: String, CodingKey {
        case stackItem = "stack_item"
        case course
        case components
    }
}

enum OpenClassroomComponent: Codable {
    case text(OpenClassroomTextComponent)
    case image(OpenClassroomImageComponent)
    case media(OpenClassroomMediaComponent)
    case chart(OpenClassroomChartComponent)
    case quiz(OpenClassroomQuizComponent)
    case roadmap(OpenClassroomRoadmapComponent)
    case rawPayload([String: AnyCodable])

    private enum CodingKeys: String, CodingKey { case type, payload }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text": self = .text(try container.decode(OpenClassroomTextComponent.self, forKey: .payload))
        case "image": self = .image(try container.decode(OpenClassroomImageComponent.self, forKey: .payload))
        case "media": self = .media(try container.decode(OpenClassroomMediaComponent.self, forKey: .payload))
        case "chart": self = .chart(try container.decode(OpenClassroomChartComponent.self, forKey: .payload))
        case "quiz": self = .quiz(try container.decode(OpenClassroomQuizComponent.self, forKey: .payload))
        case "roadmap": self = .roadmap(try container.decode(OpenClassroomRoadmapComponent.self, forKey: .payload))
        default:
            let raw = try container.decode([String: AnyCodable].self, forKey: .payload)
            self = .rawPayload(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let v):
            try container.encode("text", forKey: .type)
            try container.encode(v, forKey: .payload)
        case .image(let v):
            try container.encode("image", forKey: .type)
            try container.encode(v, forKey: .payload)
        case .media(let v):
            try container.encode("media", forKey: .type)
            try container.encode(v, forKey: .payload)
        case .chart(let v):
            try container.encode("chart", forKey: .type)
            try container.encode(v, forKey: .payload)
        case .quiz(let v):
            try container.encode("quiz", forKey: .type)
            try container.encode(v, forKey: .payload)
        case .roadmap(let v):
            try container.encode("roadmap", forKey: .type)
            try container.encode(v, forKey: .payload)
        case .rawPayload(let v):
            try container.encode("raw", forKey: .type)
            try container.encode(v, forKey: .payload)
        }
    }
}

struct OpenClassroomTextComponent: Codable {
    let id: String?
    let text: String
    let style: [String: AnyCodable]?
}

struct OpenClassroomImageComponent: Codable {

    let id: String?
    let url: URL
    let alt: String?
    let caption: String?
    let layout: ImageLayout?
    let aspectRatio: Double?
    let blurHash: String?
    let focalPoint: Point?
}


struct OpenClassroomMediaComponent: Codable {
    let id: String?
    let url: URL
    let type: MediaType
    let posterURL: URL?
    let provider: String?
    let autoplay: Bool?
    let controls: Bool?
}

enum MediaType: String, Codable { case video, gif }

struct OpenClassroomChartComponent: Codable {
    let id: String?
    let chartType: String
    let data: [String: AnyCodable]
    let options: [String: AnyCodable]?
}

struct OpenClassroomQuizComponent: Codable {
    let id: String?
    let title: String?
    let description: String?
    let questionPool: [DetailedQuestion]
    let shuffle: Bool?
    let maxQuestions: Int?
    let scoring: Scoring?
}

struct DetailedQuestion: Codable {
    let id: String
    let type: QuestionType
    let prompt: String
    let choices: [Choice]?
    let answer: AnswerRepresentation?
    let explanation: String?
    let difficulty: String?
    let tags: [String]?
    let metadata: [String: AnyCodable]?
}

enum QuestionType: String, Codable { case mcq, tf, fib, code, match, short }

struct Choice: Codable {
    let id: String
    let text: String
    let metadata: [String: AnyCodable]?
}

struct AnswerRepresentation: Codable {
    let correctChoiceIds: [String]?
    let textAnswer: String?
    let regex: String?
    let rubric: [RubricItem]?
}

struct RubricItem: Codable {
    let criterion: String
    let points: Double?
}

struct Scoring: Codable {
    let pointsPerQuestion: Double?
    let partialCredit: Bool?
}

struct OpenClassroomRoadmapComponent: Codable {
    let id: String?
    let title: String?
    let milestones: [Milestone]
    let etaSeconds: Int?
    let percent: Double?
}

struct Milestone: Codable {
    let id: String
    let title: String
    let description: String?
    let percent: Double?
}

