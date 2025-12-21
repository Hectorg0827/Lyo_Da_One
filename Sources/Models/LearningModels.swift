import Foundation

// MARK: - Learning Models

struct Course: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let shortDescription: String?
    let instructorId: Int?
    let difficultyLevel: String?
    let category: String?
    let tags: [String]?
    let thumbnailURL: String?
    let isPublished: Bool?
    let isFeatured: Bool?
    let lessonCount: Int?
    let enrollmentCount: Int?
    let estimatedDurationHours: Int?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Computed property for backward compatibility
    var level: SkillLevel? {
        guard let difficulty = difficultyLevel else { return nil }
        return SkillLevel(rawValue: difficulty)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, category, tags
        case shortDescription = "short_description"
        case instructorId = "instructor_id"
        case difficultyLevel = "difficulty_level"
        case thumbnailURL = "thumbnail_url"
        case isPublished = "is_published"
        case isFeatured = "is_featured"
        case lessonCount = "lesson_count"
        case enrollmentCount = "enrollment_count"
        case estimatedDurationHours = "estimated_duration_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: String, title: String, description: String, shortDescription: String? = nil, instructorId: Int? = nil, difficultyLevel: String? = nil, category: String? = nil, tags: [String]? = nil, thumbnailURL: String? = nil, isPublished: Bool? = nil, isFeatured: Bool? = nil, lessonCount: Int? = nil, enrollmentCount: Int? = nil, estimatedDurationHours: Int? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.shortDescription = shortDescription
        self.instructorId = instructorId
        self.difficultyLevel = difficultyLevel
        self.category = category
        self.tags = tags
        self.thumbnailURL = thumbnailURL
        self.isPublished = isPublished
        self.isFeatured = isFeatured
        self.lessonCount = lessonCount
        self.enrollmentCount = enrollmentCount
        self.estimatedDurationHours = estimatedDurationHours
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID (String or Int)
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        shortDescription = try? container.decodeIfPresent(String.self, forKey: .shortDescription)
        instructorId = try? container.decodeIfPresent(Int.self, forKey: .instructorId)
        difficultyLevel = try? container.decodeIfPresent(String.self, forKey: .difficultyLevel)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        tags = try? container.decodeIfPresent([String].self, forKey: .tags)
        thumbnailURL = try? container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        isPublished = try? container.decodeIfPresent(Bool.self, forKey: .isPublished)
        isFeatured = try? container.decodeIfPresent(Bool.self, forKey: .isFeatured)
        lessonCount = try? container.decodeIfPresent(Int.self, forKey: .lessonCount)
        enrollmentCount = try? container.decodeIfPresent(Int.self, forKey: .enrollmentCount)
        estimatedDurationHours = try? container.decodeIfPresent(Int.self, forKey: .estimatedDurationHours)
        
        // Handle dates with flexible parsing
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? parseFlexibleDate(dateString)
        } else {
            createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        }
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: dateString) ?? parseFlexibleDate(dateString)
        } else {
            updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
        }
    }
}

// Helper function to parse flexible date formats
private func parseFlexibleDate(_ dateString: String) -> Date? {
    let formatters = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd"
    ]
    
    for format in formatters {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = formatter.date(from: dateString) {
            return date
        }
    }
    return nil
}

// MARK: - Enrollment & Progress

struct EnrollmentResponse: Codable {
    let id: String
    let userId: String
    let courseId: String
    let enrolledAt: Date
    let status: EnrollmentStatus
    
    enum EnrollmentStatus: String, Codable {
        case active
        case completed
        case paused
        case cancelled
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case courseId = "course_id"
        case enrolledAt = "enrolled_at"
        case status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        
        // Handle User ID
        if let userIdInt = try? container.decode(Int.self, forKey: .userId) {
            userId = String(userIdInt)
        } else {
            userId = try container.decode(String.self, forKey: .userId)
        }
        
        // Handle Course ID
        if let courseIdInt = try? container.decode(Int.self, forKey: .courseId) {
            courseId = String(courseIdInt)
        } else {
            courseId = try container.decode(String.self, forKey: .courseId)
        }
        
        enrolledAt = try container.decode(Date.self, forKey: .enrolledAt)
        status = try container.decode(EnrollmentStatus.self, forKey: .status)
    }
}

struct CompletionResponse: Codable {
    let id: String
    let lessonId: String
    let completedAt: Date
    let score: Int?
    let xpAwarded: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case completedAt = "completed_at"
        case score
        case xpAwarded = "xp_awarded"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        
        // Handle Lesson ID
        if let lessonIdInt = try? container.decode(Int.self, forKey: .lessonId) {
            lessonId = String(lessonIdInt)
        } else {
            lessonId = try container.decode(String.self, forKey: .lessonId)
        }
        
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        xpAwarded = try container.decode(Int.self, forKey: .xpAwarded)
    }
}

struct CourseProgress: Codable {
    let courseId: String
    let userId: String
    let totalLessons: Int
    let completedLessons: Int
    let progressPercent: Double
    let currentLessonId: String?
    let lastAccessedAt: Date?
    let estimatedTimeRemaining: Int? // in minutes
    
    var isCompleted: Bool {
        completedLessons >= totalLessons
    }
    
    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case userId = "user_id"
        case totalLessons = "total_lessons"
        case completedLessons = "completed_lessons"
        case progressPercent = "progress_percent"
        case currentLessonId = "current_lesson_id"
        case lastAccessedAt = "last_accessed_at"
        case estimatedTimeRemaining = "estimated_time_remaining"
    }
}


