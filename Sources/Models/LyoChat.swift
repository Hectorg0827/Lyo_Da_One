import Foundation

// MARK: - Message Models

enum AttachmentType: String, Codable {
    case file
    case image
    case video
    case audio
    case link
    case document
}

struct LyoMessage: Identifiable, Codable, Equatable {
    let id: String
    // Added session ID for isolating chat contexts
    var sessionId: String?
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    var attachments: [MessageAttachment]?
    var actions: [MessageAction]?
    var status: MessageStatus?

    // A2UI Widget Content Types (parsed from backend)
    var contentTypes: [MessageContentType]? = nil

    // New fields for Mentor Mode
    var responseMode: ResponseMode?
    var quickExplainer: QuickExplainerData?
    var courseProposal: CourseProposalData?

    // MARK: - Lyo Protocol Animation State
    /// When true, ChatBubbleView will run the typewriter animation on appear,
    /// then flip this to false so scrolling back never re-triggers it.
    var shouldAnimate: Bool = false
    /// When false, the message view is hidden; flipping to true triggers a spring reveal.
    /// Used by buffer-and-reveal for artifact cards (quiz, flashcards, study plans, etc.).
    var isRevealed: Bool = true
    /// When true, content is still being streamed from the backend (SSE).
    /// Used by MessageBubbleView to show a blinking cursor and trigger haptics.
    var isStreaming: Bool = false

    // Exclude ephemeral animation state from Codable
    enum CodingKeys: String, CodingKey {
        case id, sessionId, content, isFromUser, timestamp
        case attachments, actions, status, contentTypes
        case responseMode, quickExplainer, courseProposal
    }

    enum MessageStatus: String, Codable {
        case sending
        case sent
        case failed
    }

    // Manual Equatable: compare by id + content + status + reveal state
    // (avoids requiring deep Equatable conformance on every nested A2UI / mentor type).
    static func == (lhs: LyoMessage, rhs: LyoMessage) -> Bool {
        lhs.id == rhs.id
            && lhs.content == rhs.content
            && lhs.status == rhs.status
            && lhs.isFromUser == rhs.isFromUser
            && lhs.isRevealed == rhs.isRevealed
            && lhs.shouldAnimate == rhs.shouldAnimate
            && lhs.isStreaming == rhs.isStreaming
    }
}

struct MessageAttachment: Identifiable, Codable, Equatable {
    let id: String
    let type: AttachmentType
    let url: String
    var filename: String?
    var size: Int?
    var mimeType: String?
}

struct MessageAction: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let actionType: ActionType
    var data: [String: String]?

    enum ActionType: String, Codable {
        case createCourse = "create_course"
        case createCourseA2A = "create_course_a2a"  // A2A multi-agent generation
        case quizMe = "quiz_me"
        case addToLibrary = "add_to_library"
        case openDrawer = "open_drawer"
        case generateSyllabus = "generate_syllabus"
        case quickExplainer = "quick_explainer"
        case makeFlashcards = "make_flashcards"
        case extractKeyPoints = "extract_key_points"
        case openClassroom = "open_classroom"
    }
}

// MARK: - Suggestion Models

struct SuggestionChip: Identifiable, Codable {
    let id: String
    let text: String
    var icon: String?
    var actionType: String?
    var context: [String: String]?
}

// MARK: - Course Models

struct CourseCard: Identifiable, Codable {
    let id: String
    let title: String
    var description: String?
    var coverURL: String?
    var progress: Double?
    var timeLeft: String?
    var lastOpened: Date?
    var tags: [String]?
    var status: CourseStatus

    enum CourseStatus: String, Codable {
        case `continue` = "continue"
        case started = "started"
        case suggested = "suggested"
        case completed = "completed"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case coverURL = "cover_url"
        case progress
        case timeLeft = "time_left"
        case lastOpened = "last_opened"
        case tags
        case status
    }
}

// MARK: - API Request/Response

struct LyoChatRequest: Codable {
    let message: String
    var context: ChatContext?
    var attachments: [String]?
}

struct ChatContext: Codable {
    var courseId: String?
    var lessonId: String?
    var currentTime: String?
    var recentActivity: [String]?

    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case lessonId = "lesson_id"
        case currentTime = "current_time"
        case recentActivity = "recent_activity"
    }
}

struct LyoChatResponse: Codable {
    let message: LyoMessage
    var suggestions: [SuggestionChip]?
    var systemStatus: String?
    var uiComponent: A2UIEnvelope?  // NEW: Backend A2UI payload

    enum CodingKeys: String, CodingKey {
        case message
        case suggestions
        case systemStatus = "system_status"
        case uiComponent = "ui_component"
    }
}

// MARK: - Legacy Chat Models (Preserved for Proactive Greetings)

struct LioGreetingResponse: Codable {
    let greeting: String
    let contextUsed: Bool
    let suggestions: [String]?

    enum CodingKeys: String, CodingKey {
        case greeting
        case contextUsed = "context_used"
        case suggestions
    }
}

// MARK: - A2UI Envelope (Backend Protocol)
/// Envelope structure sent by backend for rendering UI components
struct A2UIEnvelope: Codable {
    let type: A2UIComponentType
    let props: LegacyA2UIProps

    enum A2UIComponentType: String, Codable {
        case visualGallery = "visual_gallery"
        case courseRoadmap = "course_roadmap"
        case quizCard = "quiz_card"
        case flashcards
        case notes  // Structured notes/cheat sheets
        case topicSelection = "topic_selection"
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            self = A2UIComponentType(rawValue: value) ?? .unknown
        }
    }
}

/// Props container for A2UI components (flexible dictionary)
struct LegacyA2UIProps: Codable {
    private let storage: [String: Any]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: ChatAnyCodableValue].self)
        self.storage = dict.mapValues { $0.value }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage.mapValues { ChatAnyCodableValue($0) })
    }

    subscript(key: String) -> Any? {
        return storage[key]
    }

    func get<T>(_ key: String, as type: T.Type) -> T? {
        return storage[key] as? T
    }
}

/// Helper for encoding/decoding Any values
private struct ChatAnyCodableValue: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([ChatAnyCodableValue].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: ChatAnyCodableValue].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { ChatAnyCodableValue($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { ChatAnyCodableValue($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Open Classroom Payload
// Note: StackItemPayload and CoursePayload are defined in AICommandResponse.swift

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

// MARK: - A2UI Components (same as CourseModels)
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
    let questionPool: [LyoChatQuestion]
    let shuffle: Bool?
    let maxQuestions: Int?
    let scoring: Scoring?
}

struct LyoChatQuestion: Codable {
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
