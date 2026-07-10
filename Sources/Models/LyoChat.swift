
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

    // Widget Content Types (parsed from backend)
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
    
    /// v2 unified block format — decoded from the backend's `smart_blocks` SSE event.
    var smartBlocks: [SmartBlock]?

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
    // (avoids requiring deep Equatable conformance on every nested mentor type).
    static func == (lhs: LyoMessage, rhs: LyoMessage) -> Bool {
        lhs.id == rhs.id
            && lhs.content == rhs.content
            && lhs.status == rhs.status
            && lhs.isFromUser == rhs.isFromUser
            && lhs.isRevealed == rhs.isRevealed
            && lhs.shouldAnimate == rhs.shouldAnimate
            && lhs.isStreaming == rhs.isStreaming
            && lhs.smartBlocks?.count == rhs.smartBlocks?.count
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

    enum CodingKeys: String, CodingKey {
        case message
        case suggestions
        case systemStatus = "system_status"
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

// If you reference RoadmapComponent elsewhere, replace with OpenClassroomRoadmapComponent

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








// MARK: - Test Prep Content

struct TestPrepContent: Codable, Equatable {
    let subject: String
    let topic: String?
    let testDate: String?
    let studyPlan: StudyPlan?
    
    init(subject: String, topic: String? = nil, testDate: String? = nil, studyPlan: StudyPlan? = nil) {
        self.subject = subject
        self.topic = topic
        self.testDate = testDate
        self.studyPlan = studyPlan
    }
}

