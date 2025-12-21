import Foundation

// MARK: - Discover Item Type

enum DiscoverItemType: String, Codable, CaseIterable {
    case courseSuggestion
    case videoSnippet
    case pathSuggestion
    case eventSuggestion
    
    var displayName: String {
        switch self {
        case .courseSuggestion: return "Course"
        case .videoSnippet: return "Video"
        case .pathSuggestion: return "Path"
        case .eventSuggestion: return "Event"
        }
    }
    
    var icon: String {
        switch self {
        case .courseSuggestion: return "book.fill"
        case .videoSnippet: return "play.rectangle.fill"
        case .pathSuggestion: return "map.fill"
        case .eventSuggestion: return "calendar"
        }
    }
}

// MARK: - Learning Context

enum LearningLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "yellow"
        case .advanced: return "red"
        }
    }
}

struct QuizMoment: Codable, Identifiable {
    var id: String = UUID().uuidString
    let timestamp: TimeInterval // When to pause video
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - Discover Item

struct DiscoverItem: Identifiable, Codable {
    let id: String
    let type: DiscoverItemType
    
    // Core Learning Context
    let subject: String? // e.g. "Math"
    let topic: String? // e.g. "Algebra" (Mapped to title? or separate?)
    let level: LearningLevel
    let xpReward: Int
    
    let title: String
    let subtitle: String?
    let tag: String?
    let estimatedMinutes: Int? // "Time to learn"
    
    let courseId: String?
    let lessonId: String?
    
    let thumbnailURL: URL?
    let videoURL: URL?
    let aiInsight: String? // Dynamic context
    
    // Auto-Generated Lyo Content
    let keyPoints: [String] // "3 Key Points"
    let generatedSummary: String?
    
    // Connections
    let linkedGoalId: String? // "Pass 8th Grade Math"
    let relatedGroupId: String? // "NYC Study Group"
    
    // Interactivity
    let quizMoments: [QuizMoment]
    
    // Social Stats
    var isLiked: Bool
    var likeCount: Int
    var viewCount: Int
    var shareCount: Int
    var isSaved: Bool
    let authorName: String?
    let authorAvatarURL: URL?
    
    init(
        id: String = UUID().uuidString,
        type: DiscoverItemType,
        title: String,
        subtitle: String? = nil,
        tag: String? = nil,
        estimatedMinutes: Int? = 1,
        courseId: String? = nil,
        lessonId: String? = nil,
        thumbnailURL: URL? = nil,
        videoURL: URL? = nil,
        aiInsight: String? = nil,
        
        // Learning Context
        subject: String? = "General",
        topic: String? = nil,
        level: LearningLevel = .beginner,
        xpReward: Int = 10,
        keyPoints: [String] = [],
        generatedSummary: String? = nil,
        linkedGoalId: String? = nil,
        relatedGroupId: String? = nil,
        quizMoments: [QuizMoment] = [],
        
        // Social Stats
        isLiked: Bool = false,
        likeCount: Int = 0,
        viewCount: Int = 0,
        shareCount: Int = 0,
        isSaved: Bool = false,
        authorName: String? = nil,
        authorAvatarURL: URL? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.tag = tag
        self.estimatedMinutes = estimatedMinutes
        self.courseId = courseId
        self.lessonId = lessonId
        self.thumbnailURL = thumbnailURL
        self.videoURL = videoURL
        self.aiInsight = aiInsight
        
        self.subject = subject
        self.topic = topic
        self.level = level
        self.xpReward = xpReward
        self.keyPoints = keyPoints
        self.generatedSummary = generatedSummary
        self.linkedGoalId = linkedGoalId
        self.relatedGroupId = relatedGroupId
        self.quizMoments = quizMoments
        
        self.isLiked = isLiked
        self.likeCount = likeCount
        self.viewCount = viewCount
        self.shareCount = shareCount
        self.isSaved = isSaved
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
    }
}
