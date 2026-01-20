//
//  ClipModels.swift
//  Lyo
//
//  Models for Clips - short educational videos created by users
//

import Foundation

// MARK: - Clip Model

/// A short educational video clip created by a user
struct Clip: Identifiable, Codable, Hashable {
    let id: String
    let userId: Int
    var title: String
    var description: String?
    let videoURL: URL
    let thumbnailURL: URL?
    let durationSeconds: Double
    
    // AI-extractable metadata for course generation
    var metadata: ClipMetadata
    
    // Social stats
    var viewCount: Int
    var likeCount: Int
    var shareCount: Int
    var isLiked: Bool
    var isSaved: Bool
    
    // Author info
    let authorName: String?
    let authorAvatarURL: URL?
    
    // Flags
    let isPublic: Bool
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: Int,
        title: String,
        description: String? = nil,
        videoURL: URL,
        thumbnailURL: URL? = nil,
        durationSeconds: Double = 0,
        metadata: ClipMetadata = ClipMetadata(),
        viewCount: Int = 0,
        likeCount: Int = 0,
        shareCount: Int = 0,
        isLiked: Bool = false,
        isSaved: Bool = false,
        authorName: String? = nil,
        authorAvatarURL: URL? = nil,
        isPublic: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.durationSeconds = durationSeconds
        self.metadata = metadata
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.shareCount = shareCount
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.isPublic = isPublic
        self.createdAt = createdAt
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Clip, rhs: Clip) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Clip Metadata

/// AI-extractable metadata for course generation from clips
struct ClipMetadata: Codable, Hashable {
    var subject: String?          // e.g., "Mathematics", "Science"
    var topic: String?            // e.g., "Algebra", "Chemistry"
    var level: LearningLevel      // beginner, intermediate, advanced
    var keyPoints: [String]       // User-defined or AI-extracted key points
    var transcript: String?       // Auto-generated transcript (for AI)
    var tags: [String]            // Searchable tags
    var enableCourseGeneration: Bool  // Flag for AI course gen
    
    init(
        subject: String? = nil,
        topic: String? = nil,
        level: LearningLevel = .beginner,
        keyPoints: [String] = [],
        transcript: String? = nil,
        tags: [String] = [],
        enableCourseGeneration: Bool = true
    ) {
        self.subject = subject
        self.topic = topic
        self.level = level
        self.keyPoints = keyPoints
        self.transcript = transcript
        self.tags = tags
        self.enableCourseGeneration = enableCourseGeneration
    }
}

// MARK: - Clip Create Request

/// Request model for creating a new clip
struct ClipCreateRequest: Codable {
    let title: String
    let description: String?
    let videoUrl: String          // URL after upload to storage
    let thumbnailUrl: String?
    let durationSeconds: Double
    let subject: String?
    let topic: String?
    let level: String
    let keyPoints: [String]
    let tags: [String]
    let isPublic: Bool
    let enableCourseGeneration: Bool
    
    init(
        title: String,
        description: String? = nil,
        videoUrl: String,
        thumbnailUrl: String? = nil,
        durationSeconds: Double = 0,
        subject: String? = nil,
        topic: String? = nil,
        level: LearningLevel = .beginner,
        keyPoints: [String] = [],
        tags: [String] = [],
        isPublic: Bool = true,
        enableCourseGeneration: Bool = true
    ) {
        self.title = title
        self.description = description
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.durationSeconds = durationSeconds
        self.subject = subject
        self.topic = topic
        self.level = level.rawValue
        self.keyPoints = keyPoints
        self.tags = tags
        self.isPublic = isPublic
        self.enableCourseGeneration = enableCourseGeneration
    }
}

// MARK: - Clip Response

/// API response for clip operations
struct ClipResponse: Codable {
    let success: Bool
    let clip: Clip?
    let message: String?
    let error: String?
}

/// API response for listing clips
struct ClipsListResponse: Codable {
    let success: Bool
    let clips: [Clip]
    let total: Int
    let page: Int
    let perPage: Int
}

// MARK: - Clip Update Request

/// Request model for updating clip metadata
struct ClipUpdateRequest: Codable {
    let title: String?
    let description: String?
    let subject: String?
    let topic: String?
    let level: String?
    let keyPoints: [String]?
    let tags: [String]?
    let isPublic: Bool?
}

// MARK: - Clip Subjects

/// Predefined subjects for clips
enum ClipSubject: String, CaseIterable, Identifiable {
    case mathematics = "Mathematics"
    case science = "Science"
    case english = "English"
    case history = "History"
    case languages = "Languages"
    case arts = "Arts"
    case music = "Music"
    case technology = "Technology"
    case business = "Business"
    case health = "Health"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .mathematics: return "function"
        case .science: return "atom"
        case .english: return "textformat"
        case .history: return "clock.arrow.circlepath"
        case .languages: return "globe"
        case .arts: return "paintpalette"
        case .music: return "music.note"
        case .technology: return "laptopcomputer"
        case .business: return "chart.line.uptrend.xyaxis"
        case .health: return "heart.fill"
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Generate Course from Clip

/// Request to generate a course from a clip
struct GenerateCourseFromClipRequest: Codable {
    let clipId: String
    let courseTitle: String?
    let targetLevel: String?
    let additionalContext: String?
}

/// Response from course generation
struct GenerateCourseFromClipResponse: Codable {
    let success: Bool
    let courseId: String?
    let message: String?
    let error: String?
}
