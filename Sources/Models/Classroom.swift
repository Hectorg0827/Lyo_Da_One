import Foundation

// MARK: - Classroom Models

struct LessonModule: Identifiable, Codable {
    let id: String
    let title: String
    let coverImageURL: String?
    let slides: [Slide]
    let estimatedDuration: Int // in seconds
    let concepts: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case coverImageURL = "cover_image_url"
        case slides
        case estimatedDuration = "estimated_duration"
        case concepts
    }
}

struct Slide: Identifiable, Codable {
    let id: String
    let type: SlideType
    let content: SlideContent
    let narration: String
    let estimatedReadTime: Int // in seconds
    
    enum SlideType: String, Codable {
        case concept
        case diagram
        case example
        case practice
        case summary
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, content, narration
        case estimatedReadTime = "estimated_read_time"
    }
}

struct SlideContent: Codable {
    let title: String
    let body: String
    let diagram: DiagramData?
    let codeSnippet: String?
    let bulletPoints: [String]?
    let mediaURL: String?
    
    enum CodingKeys: String, CodingKey {
        case title, body, diagram
        case codeSnippet = "code_snippet"
        case bulletPoints = "bullet_points"
        case mediaURL = "media_url"
    }
}

struct DiagramData: Codable {
    let imageURL: String?
    let svgData: String?
    let labels: [String]?
    
    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case svgData = "svg_data"
        case labels
    }
}

// MARK: - Quick Check Models

struct QuickCheck: Identifiable, Codable {
    let id: String
    let type: CheckType
    let question: String
    let options: [String]?
    let correctAnswer: String
    let explanation: String
    let reteachContent: ReteachContent?
    let timeLimit: Int? // in seconds, nil = no limit
    
    enum CheckType: String, Codable {
        case multipleChoice = "multiple_choice"
        case tapToOrder = "tap_to_order"
        case labelDiagram = "label_diagram"
        case flashDecision = "flash_decision"
        case trueFalse = "true_false"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, question, options
        case correctAnswer = "correct_answer"
        case explanation
        case reteachContent = "reteach_content"
        case timeLimit = "time_limit"
    }
}

struct ReteachContent: Codable {
    let explanation: String
    let analogy: String?
    let diagram: DiagramData?
    let alternativeApproach: String?
    
    enum CodingKeys: String, CodingKey {
        case explanation, analogy, diagram
        case alternativeApproach = "alternative_approach"
    }
}

// MARK: - Classroom State

enum ClassroomState {
    case loading
    case ready
    case playing
    case paused
    case quickCheck
    case reteach
    case complete
    case error
}

// MARK: - Settings

struct ClassroomSettings: Codable {
    var autoplayNarration: Bool = true
    var autoAdvanceAfterNarration: Bool = false
    var playbackSpeed: Float = 1.0 // 0.75, 1.0, 1.25, 1.5
    var captionsEnabled: Bool = true
    var checkFrequency: CheckFrequency = .standard
    var textSize: TextSize = .medium
    
    enum CheckFrequency: String, Codable {
        case fewer
        case standard
        case more
    }
    
    enum TextSize: String, Codable {
        case small
        case medium
        case large
        case extraLarge
    }
}

// MARK: - Progress Tracking

struct ModuleProgress: Codable {
    let moduleId: String
    var currentSlideIndex: Int
    var completedSlides: Set<String>
    var checkResults: [String: Bool] // checkId -> passed
    var narrationPosition: Double // seconds into current slide
    var confidenceLevels: [String: Int] // conceptId -> 1-3
    var lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case moduleId = "module_id"
        case currentSlideIndex = "current_slide_index"
        case completedSlides = "completed_slides"
        case checkResults = "check_results"
        case narrationPosition = "narration_position"
        case confidenceLevels = "confidence_levels"
        case lastUpdated = "last_updated"
    }
}

struct LessonProgress: Codable {
    let lessonId: String
    var moduleProgress: [String: ModuleProgress]
    var overallProgress: Double // 0.0 - 1.0
    var startedAt: Date
    var lastAccessedAt: Date
    var completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case moduleProgress = "module_progress"
        case overallProgress = "overall_progress"
        case startedAt = "started_at"
        case lastAccessedAt = "last_accessed_at"
        case completedAt = "completed_at"
    }
}

// MARK: - Classroom Session

struct ClassroomSession: Codable {
    let id: String
    let lessonId: String
    let modules: [LessonModule]
    var settings: ClassroomSettings
    var progress: LessonProgress
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case modules, settings, progress
        case createdAt = "created_at"
    }
}

// MARK: - Analytics Events

struct ClassroomAnalytics {
    enum Event {
        case startModule(moduleId: String)
        case slideViewed(slideId: String, timeSpent: Double)
        case ttsAutoplay(slideId: String)
        case speedChanged(from: Float, to: Float)
        case checkShown(checkId: String)
        case checkPassed(checkId: String, attempts: Int)
        case checkFailed(checkId: String, attempts: Int)
        case reteachStarted(checkId: String)
        case moduleCompleted(moduleId: String, duration: Double)
        case notesSaved(slideId: String)
        case confidenceReported(slideId: String, level: Int)
        case breakTaken(duration: Double)
    }
}
