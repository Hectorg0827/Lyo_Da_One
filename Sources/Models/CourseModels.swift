//
//  CourseModels.swift
//  Lyo
//
//  Shared course creation and A2UI content models used across the app.
//

import Foundation

// MARK: - Course Creation Data (A2UI Protocol)
/// Data structure for AI-generated course proposals that can be displayed in chat
struct CourseCreationData: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let topic: String
    let level: String
    let modules: [CourseModuleData]
    let difficultyLevel: String
    let instructorId: String

    init(
        id: String = UUID().uuidString, title: String, topic: String, level: String,
        modules: [CourseModuleData], difficultyLevel: String, instructorId: String
    ) {
        self.id = id
        self.title = title
        self.topic = topic
        self.level = level
        self.modules = modules
        self.difficultyLevel = difficultyLevel
        self.instructorId = instructorId
    }
}

struct CourseModuleData: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let lessons: [CourseLessonData]

    init(
        id: String = UUID().uuidString, title: String, description: String,
        lessons: [CourseLessonData] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.lessons = lessons
    }
}

struct CourseLessonData: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let duration: String

    init(id: String = UUID().uuidString, title: String, duration: String = "10 min") {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

// NOTE: CardAction and TopicOption are defined in MultimodalMessage.swift
// Do not duplicate them here to avoid ambiguous type errors

// MARK: - OPEN_CLASSROOM Command (A2UI Protocol)
/// JSON command structure for triggering classroom navigation from AI responses
struct OpenClassroomCommand: Codable {
    let type: String
    let payload: OpenClassroomPayload

    /// Convenience accessor for course data
    var course: CoursePayload { payload.course }
    /// Convenience accessor for stack item data (optional)
    var stackItem: StackItemPayload? { payload.stackItem }

    struct OpenClassroomPayload: Codable {
        let stackItem: StackItemPayload?  // Optional - backend may not include it
        let course: CoursePayload
        // New: A2UI components for rich UI (renamed to avoid collision with renderer type)
        var components: [OpenClassroomComponent]? = nil

        enum CodingKeys: String, CodingKey {
            case stackItem = "stack_item"
            case course
            case components
        }
    }

    // MARK: - A2UI Components
    enum OpenClassroomComponent: Codable {
        case text(TextComponent)
        case image(ImageComponent)
        case media(InlineMediaComponent)
        case chart(ChartComponent)
        case quiz(QuizComponent)
        case roadmap(RoadmapComponent)
        case rawPayload([String: AnyCodable])

        private enum CodingKeys: String, CodingKey { case type, payload }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "text": self = .text(try container.decode(TextComponent.self, forKey: .payload))
            case "image": self = .image(try container.decode(ImageComponent.self, forKey: .payload))
            case "media":
                self = .media(try container.decode(InlineMediaComponent.self, forKey: .payload))
            case "chart": self = .chart(try container.decode(ChartComponent.self, forKey: .payload))
            case "quiz": self = .quiz(try container.decode(QuizComponent.self, forKey: .payload))
            case "roadmap":
                self = .roadmap(try container.decode(RoadmapComponent.self, forKey: .payload))
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

    struct TextComponent: Codable {
        let id: String?
        let text: String
        let style: [String: AnyCodable]?
    }

    struct ImageComponent: Codable {
        let id: String?
        let url: URL
        let alt: String?
        let caption: String?
        let layout: ImageLayout?
        let aspectRatio: Double?
        let blurHash: String?
        let focalPoint: Point?
    }

    enum ImageLayout: String, Codable { case inline, full, cover }

    struct Point: Codable {
        let x: Double
        let y: Double
    }

    struct InlineMediaComponent: Codable {
        let id: String?
        let url: URL
        let type: MediaType
        let posterURL: URL?
        let provider: String?
        let autoplay: Bool?
        let controls: Bool?
    }

    enum MediaType: String, Codable { case video, gif }

    struct ChartComponent: Codable {
        let id: String?
        let chartType: String
        let data: [String: AnyCodable]
        let options: [String: AnyCodable]?
    }

    struct QuizComponent: Codable {
        let id: String?
        let title: String?
        let description: String?
        let questionPool: [Question]
        let shuffle: Bool?
        let maxQuestions: Int?
        let scoring: Scoring?
    }

    struct Question: Codable {
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

    struct RoadmapComponent: Codable {
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

    struct StackItemPayload: Codable {
        let category: String
        let title: String
        let subtitle: String
        let status: String
    }

    struct CoursePayload: Codable {
        let title: String
        let topic: String
        let level: String
        let language: String?
        let duration: String?
        let objectives: [String]
        let thumbnail: String?
        let difficultyLevel: String?
        let instructorId: String?
    }

    /// Convert to CourseCreationData for display
    func toCourseCreationData() -> CourseCreationData {
        CourseCreationData(
            title: payload.course.title,
            topic: payload.course.topic,
            level: payload.course.level,
            modules: payload.course.objectives.enumerated().map { index, objective in
                CourseModuleData(
                    id: "mod_\(index + 1)",
                    title: "Module \(index + 1)",
                    description: objective
                )
            },
            difficultyLevel: payload.course.difficultyLevel ?? "beginner",
            instructorId: payload.course.instructorId ?? "default"
        )
    }
}
