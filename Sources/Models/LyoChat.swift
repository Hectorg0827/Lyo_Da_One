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

struct LyoMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    var attachments: [MessageAttachment]?
    var actions: [MessageAction]?
    var status: MessageStatus?
    
    // New fields for Mentor Mode
    var responseMode: ResponseMode?
    var quickExplainer: QuickExplainerData?
    var courseProposal: CourseProposalData?
    
    enum MessageStatus: String, Codable {
        case sending
        case sent
        case failed
    }
}

struct MessageAttachment: Identifiable, Codable {
    let id: String
    let type: AttachmentType
    let url: String
    var filename: String?
    var size: Int?
    var mimeType: String?
}

struct MessageAction: Identifiable, Codable {
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

// MARK: - Open Classroom Payload
// Note: StackItemPayload and CoursePayload are defined in AICommandResponse.swift

struct OpenClassroomPayload: Codable {
    let stackItem: StackItemPayload
    let course: CoursePayload
    
    enum CodingKeys: String, CodingKey {
        case stackItem = "stack_item"
        case course
    }
}
