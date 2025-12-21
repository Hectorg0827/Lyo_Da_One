import Foundation

// MARK: - Lesson Block Type

/// Types of content blocks in a live lesson
enum LessonBlockType: String, Codable, CaseIterable {
    case explain    // Explanatory text
    case image      // Image or diagram
    case example    // Worked example
    case quizMcq    // Multiple-choice quiz
    case summary    // Recap/summary
    
    var icon: String {
        switch self {
        case .explain: return "text.book.closed"
        case .image: return "photo"
        case .example: return "lightbulb"
        case .quizMcq: return "questionmark.circle"
        case .summary: return "list.bullet.clipboard"
        }
    }
    
    var displayName: String {
        switch self {
        case .explain: return "Explanation"
        case .image: return "Visual"
        case .example: return "Example"
        case .quizMcq: return "Quick Check"
        case .summary: return "Summary"
        }
    }
}

// MARK: - Lesson Block

/// A single content block within a live lesson
struct LessonBlock: Identifiable, Codable {
    let id: String
    let type: LessonBlockType
    let title: String?
    let body: String?
    let assetURL: URL?
    
    // Quiz-specific properties
    let options: [String]?
    let correctIndex: Int?
    let explanation: String?
    
    init(
        id: String = UUID().uuidString,
        type: LessonBlockType,
        title: String? = nil,
        body: String? = nil,
        assetURL: URL? = nil,
        options: [String]? = nil,
        correctIndex: Int? = nil,
        explanation: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.assetURL = assetURL
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
    }
}

// MARK: - Live Lesson

/// A complete live lesson with multiple blocks
struct LiveLesson: Codable {
    let courseId: String
    let lessonId: String
    let title: String
    let subtitle: String?
    let blocks: [LessonBlock]
    let estimatedDuration: Int? // in minutes
    
    init(
        courseId: String,
        lessonId: String,
        title: String,
        subtitle: String? = nil,
        blocks: [LessonBlock],
        estimatedDuration: Int? = nil
    ) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.title = title
        self.subtitle = subtitle
        self.blocks = blocks
        self.estimatedDuration = estimatedDuration
    }
    
    var totalBlocks: Int {
        blocks.count
    }
    
    var quizCount: Int {
        blocks.filter { $0.type == .quizMcq }.count
    }
}

// MARK: - Chat Turn

/// A single turn in the lesson transcript
struct ChatTurn: Identifiable {
    let id: UUID
    let isUser: Bool
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), isUser: Bool, text: String, timestamp: Date = Date()) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Sentiment Signal

/// User feedback signals during the lesson
enum SentimentSignal: String, CaseIterable {
    case confused = "confused"
    case slower = "slower"
    case tooEasy = "too_easy"
    case quizMe = "quiz_me"
    
    var displayLabel: String {
        switch self {
        case .confused: return "I'm confused"
        case .slower: return "Slower"
        case .tooEasy: return "Too easy"
        case .quizMe: return "Quiz me"
        }
    }
    
    var icon: String {
        switch self {
        case .confused: return "questionmark.bubble"
        case .slower: return "tortoise"
        case .tooEasy: return "hare"
        case .quizMe: return "checkmark.circle"
        }
    }
}

// MARK: - Quiz Result

/// Result of a quiz attempt
struct QuizResult {
    let blockId: String
    let selectedIndex: Int
    let isCorrect: Bool
    let timestamp: Date
}

// MARK: - Lesson Progress

/// Progress tracking for a live lesson
struct LiveLessonProgress: Codable {
    let courseId: String
    let lessonId: String
    var currentBlockIndex: Int
    var completedBlocks: Set<String>
    var quizResults: [String: Bool] // blockId -> passed
    var lastAccessedAt: Date
    
    var isComplete: Bool {
        // Consider complete when on last block
        return false // Will be determined by ViewModel
    }
    
    init(courseId: String, lessonId: String) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.currentBlockIndex = 0
        self.completedBlocks = []
        self.quizResults = [:]
        self.lastAccessedAt = Date()
    }
}
