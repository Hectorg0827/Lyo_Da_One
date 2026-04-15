import Foundation

// MARK: - Progressive Course Generation Models

/// Explicit state for every module — eliminates "0 lessons" ambiguity forever
enum ModuleState: String, Codable {
    case locked    // Not started yet
    case building  // Backend is generating this module right now
    case ready     // Content is available, tappable
    case failed    // Something went wrong, show retry
}

/// The fast payload returned by POST /course/generate in under 3 seconds
struct InstantCourseResponse: Codable {
    let jobId: String
    let schemaVersion: String?
    let instant: InstantPayload
    
    struct InstantPayload: Codable {
        let courseId: String
        let title: String
        let objective: String?
        let level: String?
        let syllabus: [String]
        let modulePreview: ModulePreview?
    }
    
    struct ModulePreview: Codable {
        let moduleIndex: Int
        let moduleTitle: String
        let lessonPreview: LessonPreview?
    }
    
    struct LessonPreview: Codable {
        let title: String?
        let summary: String?
        let miniPractice: [String]?
    }
}

/// Response from GET /course/generate/status — lightweight, instant
struct CourseStatus: Codable {
    let state: String // "generating", "partial", "complete", "failed"
    let progress: Double?
    let modules: [ModuleStatus]
    let courseId: String?
    let schemaVersion: String?
    let etaSeconds: Int?
    
    struct ModuleStatus: Codable {
        let index: Int
        let state: ModuleState
        /// Title sent by backend in status payload — used to keep card titles
        /// accurate while modules transition from locked → building → ready.
        let title: String?
    }
}

struct GeneratedCourse: Codable, Identifiable {
    let id: String
    let jobId: String?
    let title: String
    let objective: String?
    let syllabus: [String]?
    var modules: [ProgressiveModule]
    let schemaVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, objective, syllabus, modules
        case jobId, schemaVersion
    }
    
    /// Tolerant decoder — never crashes on missing optional fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.jobId = try container.decodeIfPresent(String.self, forKey: .jobId)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Course"
        self.objective = try container.decodeIfPresent(String.self, forKey: .objective)
        self.syllabus = try container.decodeIfPresent([String].self, forKey: .syllabus) ?? []
        self.modules = try container.decodeIfPresent([ProgressiveModule].self, forKey: .modules) ?? []
        self.schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
    }
    
    /// Manual init for building from InstantCourseResponse
    init(id: String, jobId: String?, title: String, objective: String?, syllabus: [String], modules: [ProgressiveModule], schemaVersion: String?) {
        self.id = id
        self.jobId = jobId
        self.title = title
        self.objective = objective
        self.syllabus = syllabus
        self.modules = modules
        self.schemaVersion = schemaVersion
    }
}

struct ProgressiveModule: Codable, Identifiable, Equatable {
    let id: String
    let index: Int
    var state: ModuleState
    let title: String
    var lessons: [ProgressiveLesson]?
    var summary: String?
    var hook: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.index = try container.decode(Int.self, forKey: .index)
        self.state = try container.decodeIfPresent(ModuleState.self, forKey: .state) ?? .locked
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Module \(index)"
        self.lessons = try container.decodeIfPresent([ProgressiveLesson].self, forKey: .lessons)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.hook = try container.decodeIfPresent(String.self, forKey: .hook)
    }
    
    init(id: String, index: Int, state: ModuleState, title: String, lessons: [ProgressiveLesson]? = nil, summary: String? = nil, hook: String? = nil) {
        self.id = id
        self.index = index
        self.state = state
        self.title = title
        self.lessons = lessons
        self.summary = summary
        self.hook = hook
    }
    
    static func == (lhs: ProgressiveModule, rhs: ProgressiveModule) -> Bool {
        return lhs.id == rhs.id && lhs.index == rhs.index && lhs.state == rhs.state && lhs.title == rhs.title
    }
}

struct ProgressiveLesson: Codable, Identifiable, Equatable {
    let id: String
    let title: String?
    let content: String?
    let summary: String?
    let miniPractice: [String]?
    let quiz: LessonQuiz?
    
    struct LessonQuiz: Codable, Equatable {
        let question: String
        let options: [String]
        let correctIndex: Int
        let explanation: String?
        
        enum CodingKeys: String, CodingKey {
            case question, options, explanation
            case correctIndex = "correct_index"
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.miniPractice = try container.decodeIfPresent([String].self, forKey: .miniPractice)
        self.quiz = try container.decodeIfPresent(LessonQuiz.self, forKey: .quiz)
    }
    
    init(id: String, title: String?, content: String?, summary: String?, miniPractice: [String]?, quiz: LessonQuiz? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.summary = summary
        self.miniPractice = miniPractice
        self.quiz = quiz
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, summary, miniPractice, quiz
    }
}

// MARK: - Chat-UI Course Module (used by CourseRoadmapBubbleView, EnhancedMessageBubble)

struct CourseModule: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let duration: String?
    let isCompleted: Bool
    let isLocked: Bool
    let description: String?
    let lessons: [ModuleLessonData]?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        duration: String? = nil,
        isCompleted: Bool = false,
        isLocked: Bool = false,
        description: String? = nil,
        lessons: [ModuleLessonData]? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.isCompleted = isCompleted
        self.isLocked = isLocked
        self.description = description
        self.lessons = lessons
    }
}

// MARK: - Backward Compatibility Extensions

extension GeneratedCourse {
    /// Legacy alias — old code uses `.courseId` instead of `.id`
    var courseId: String { id }
    /// Legacy alias — maps objective to description
    var description: String { objective ?? "" }
    /// Estimated total duration in minutes (15 min per module)
    var estimatedDuration: Int { modules.count * 15 }
}

extension ProgressiveModule {
    /// Legacy alias — maps summary to description
    var description: String { summary ?? "" }
}

extension ProgressiveLesson {
    /// Legacy ordering accessor — progressive lessons don't store order
    var order: Int { 0 }
}

// MARK: - Course Generation Errors

enum CourseGenerationError: LocalizedError {
    case generationFailed(String)
    case timeout
    case invalidResponse
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .generationFailed(let msg): return "Generation failed: \(msg)"
        case .timeout: return "Course generation timed out"
        case .invalidResponse: return "Invalid response from server"
        case .noContent: return "No content available"
        }
    }
}
