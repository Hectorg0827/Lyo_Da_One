import Foundation

// MARK: - Notification Settings Request
struct NotificationSettingsRequest: Codable {
    var pushEnabled: Bool
    var emailEnabled: Bool
    var learningReminders: Bool
    var socialNotifications: Bool
    var achievementNotifications: Bool
    var communityUpdates: Bool
    var quietHoursStart: Int?
    var quietHoursEnd: Int?
    
    enum CodingKeys: String, CodingKey {
        case pushEnabled = "push_enabled"
        case emailEnabled = "email_enabled"
        case learningReminders = "learning_reminders"
        case socialNotifications = "social_notifications"
        case achievementNotifications = "achievement_notifications"
        case communityUpdates = "community_updates"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
    }
}

// MARK: - Push Device
struct PushDevice: Codable, Identifiable {
    let id: String
    let deviceToken: String
    let deviceType: String
    let isActive: Bool
    let createdAt: Date
    let lastUsed: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case deviceToken = "device_token"
        case deviceType = "device_type"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastUsed = "last_used"
    }
}

// MARK: - Analytics Models
struct AnalyticsSession: Codable {
    let sessionId: String
    let startedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case startedAt = "started_at"
    }
}

struct UserAnalyticsStats: Codable {
    let periodDays: Int
    let eventsByCategory: [String: Int]
    let sessions: SessionStats
    let learning: LearningStats
    let aiUsage: AIUsageStats
    
    enum CodingKeys: String, CodingKey {
        case periodDays = "period_days"
        case eventsByCategory = "events_by_category"
        case sessions, learning
        case aiUsage = "ai_usage"
    }
}

struct SessionStats: Codable {
    let totalSessions: Int?
    let totalDuration: Int?
    let avgSessionDuration: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case totalDuration = "total_duration"
        case avgSessionDuration = "avg_session_duration"
    }
}

struct LearningStats: Codable {
    let totalTimeSeconds: Int?
    let contentViewed: Int?
    let completionRate: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalTimeSeconds = "total_time_seconds"
        case contentViewed = "content_viewed"
        case completionRate = "completion_rate"
    }
}

struct AIUsageStats: Codable {
    let totalInteractions: Int?
    let tokensUsed: Int?
    let avgResponseTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalInteractions = "total_interactions"
        case tokensUsed = "tokens_used"
        case avgResponseTime = "avg_response_time"
    }
}

struct LearningInsights: Codable {
    let dailyActivity: [[String: Any]]?
    let streakDays: Int
    let totalTimeSeconds: Int
    let avgDailyTimeSeconds: Int
    let daysActive: Int
    let recommendations: [String]
    let insights: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case streakDays = "streak_days"
        case totalTimeSeconds = "total_time_seconds"
        case avgDailyTimeSeconds = "avg_daily_time_seconds"
        case daysActive = "days_active"
        case recommendations
        case dailyActivity = "daily_activity"
        case insights
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        totalTimeSeconds = try container.decode(Int.self, forKey: .totalTimeSeconds)
        avgDailyTimeSeconds = try container.decode(Int.self, forKey: .avgDailyTimeSeconds)
        daysActive = try container.decode(Int.self, forKey: .daysActive)
        recommendations = try container.decode([String].self, forKey: .recommendations)
        dailyActivity = nil
        insights = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encode(totalTimeSeconds, forKey: .totalTimeSeconds)
        try container.encode(avgDailyTimeSeconds, forKey: .avgDailyTimeSeconds)
        try container.encode(daysActive, forKey: .daysActive)
        try container.encode(recommendations, forKey: .recommendations)
    }
}

// MARK: - File Storage Models
struct FileUploadResponse: Codable {
    let success: Bool
    let filename: String
    let originalFilename: String
    let publicUrl: String
    let size: Int
    let contentType: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success, filename, size, message
        case originalFilename = "original_filename"
        case publicUrl = "public_url"
        case contentType = "content_type"
    }
}

struct PresignedUrlResponse: Codable {
    let success: Bool
    let uploadUrl: String?
    let publicUrl: String?
    let blobName: String?
    let expiresInSeconds: Int?
    let headers: [String: String]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, headers, error
        case uploadUrl = "upload_url"
        case publicUrl = "public_url"
        case blobName = "blob_name"
        case expiresInSeconds = "expires_in_seconds"
    }
}

struct StorageUsage: Codable {
    let totalFiles: Int
    let totalSizeBytes: Int
    let totalSizeMb: Double
    let byType: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case totalFiles = "total_files"
        case totalSizeBytes = "total_size_bytes"
        case totalSizeMb = "total_size_mb"
        case byType = "by_type"
    }
}

// MARK: - Notification Models
struct APIAppNotification: Codable, Identifiable {
    let id: Int
    let title: String
    let body: String
    let icon: String
    let imageUrl: String?
    let category: String
    let priority: String
    let actionType: String?
    let actionData: [String: String]?
    var isRead: Bool
    let createdAt: Date
    let readAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, body, icon, category, priority
        case imageUrl = "image_url"
        case actionType = "action_type"
        case actionData = "action_data"
        case isRead = "is_read"
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}


struct NotificationListResponse: Codable {
    let notifications: [APIAppNotification]
    let unreadCount: Int
    let total: Int
    
    enum CodingKeys: String, CodingKey {
        case notifications, total
        case unreadCount = "unread_count"
    }
}


struct UnreadCountResponse: Codable {
    let unreadCount: Int
    
    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}

// MARK: - Search Models
struct SearchResponse: Codable {
    let results: [String: Any]?
    let totalCount: Int
    let query: String
    let searchType: String
    
    enum CodingKeys: String, CodingKey {
        case query
        case totalCount = "total_count"
        case searchType = "search_type"
        case results
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = try container.decode(String.self, forKey: .query)
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        searchType = try container.decode(String.self, forKey: .searchType)
        results = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(totalCount, forKey: .totalCount)
        try container.encode(searchType, forKey: .searchType)
    }
}

struct AutocompleteResponse: Codable {
    let suggestions: [AutocompleteSuggestion]
}

struct AutocompleteSuggestion: Codable, Identifiable {
    var id: String { text }
    let text: String
    let type: String
    let score: Double?
}

struct TrendingResponse: Codable {
    let trending: [String]
}

// MARK: - Messaging Models
struct Conversation: Codable, Identifiable {
    let id: String
    let type: String
    let name: String?
    let participants: [ConversationParticipant]
    let lastMessage: MessagePreview?
    let unreadCount: Int
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, participants
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
        case updatedAt = "updated_at"
    }
}

struct ConversationParticipant: Codable, Identifiable {
    let id: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, username
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
    }
    
    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return username ?? "User"
    }
}

struct MessagePreview: Codable {
    let content: String
    let senderId: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case content
        case senderId = "sender_id"
        case createdAt = "created_at"
    }
}

struct Message: Codable, Identifiable {
    let id: String
    let conversationId: String
    let sender: ConversationParticipant
    let content: String
    let mediaUrl: String?
    let mediaType: String?
    let replyToId: String?
    let status: String
    let createdAt: Date
    let reactions: [APIMessageReaction]
    
    enum CodingKeys: String, CodingKey {
        case id, sender, content, status, reactions
        case conversationId = "conversation_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case replyToId = "reply_to_id"
        case createdAt = "created_at"
    }
}

struct APIMessageReaction: Codable {
    let emoji: String
    let userId: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case emoji
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

// MARK: - Social Models
struct SocialPost: Codable, Identifiable {
    let id: Int
    let authorId: Int
    let content: String?
    let postType: String
    let imageUrl: String?
    let videoUrl: String?
    let linkUrl: String?
    let linkTitle: String?
    let linkDescription: String?
    let isPublic: Bool
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date
    let commentCount: Int?
    let reactionCount: Int?
    let userReaction: String?
    
    enum CodingKeys: String, CodingKey {
        case id, content
        case authorId = "author_id"
        case postType = "post_type"
        case imageUrl = "image_url"
        case videoUrl = "video_url"
        case linkUrl = "link_url"
        case linkTitle = "link_title"
        case linkDescription = "link_description"
        case isPublic = "is_public"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case commentCount = "comment_count"
        case reactionCount = "reaction_count"
        case userReaction = "user_reaction"
    }
}

struct SocialComment: Codable, Identifiable {
    let id: Int
    let postId: Int
    let authorId: Int
    let content: String
    let parentCommentId: Int?
    let createdAt: Date
    let updatedAt: Date
    let reactionCount: Int?
    let userReaction: String?
    let replies: [SocialComment]?
    
    enum CodingKeys: String, CodingKey {
        case id, content, replies
        case postId = "post_id"
        case authorId = "author_id"
        case parentCommentId = "parent_comment_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case reactionCount = "reaction_count"
        case userReaction = "user_reaction"
    }
}

struct FeedResponse: Codable {
    let posts: [SocialPost]
    let total: Int
    let page: Int
    let perPage: Int
    let hasNext: Bool
    
    enum CodingKeys: String, CodingKey {
        case posts, total, page
        case perPage = "per_page"
        case hasNext = "has_next"
    }
}

struct UserSocialStats: Codable {
    let postsCount: Int
    let followersCount: Int
    let followingCount: Int
    let totalReactionsReceived: Int
    
    enum CodingKeys: String, CodingKey {
        case postsCount = "posts_count"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case totalReactionsReceived = "total_reactions_received"
    }
}

struct UserFollow: Codable {
    let id: Int
    let followerId: Int
    let followingId: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}

// MARK: - Monetization Models
struct MonetizationStatus: Codable {
    let tier: String
    let energy: Int
    let isPremium: Bool
    let maxEnergy: Int
    let stripeCustomerId: String?
    let subscriptionEndDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case tier, energy
        case isPremium = "is_premium"
        case maxEnergy = "max_energy"
        case stripeCustomerId = "stripe_customer_id"
        case subscriptionEndDate = "subscription_end_date"
    }
}

struct SubscriptionPlan: Codable, Identifiable {
    var id: String { name }
    let name: String
    let price: Double
    let currency: String
    let interval: String
    let features: [String]
}

struct SubscriptionPlansResponse: Codable {
    let plans: [SubscriptionPlan]
    let stripePublishableKey: String?
    
    enum CodingKeys: String, CodingKey {
        case plans
        case stripePublishableKey = "stripe_publishable_key"
    }
}

struct CheckoutResponse: Codable {
    let sessionId: String
    let checkoutUrl: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case checkoutUrl = "checkout_url"
    }
}

struct AdConfig: Codable {
    let enabled: Bool
    let networkCode: String?
    let appIdIos: String?
    let appIdAndroid: String?
    let placements: [String: String?]
    
    enum CodingKeys: String, CodingKey {
        case enabled, placements
        case networkCode = "network_code"
        case appIdIos = "app_id_ios"
        case appIdAndroid = "app_id_android"
    }
}

// MARK: - Learning Progress Models
struct CourseEnrollment: Codable, Identifiable {
    let id: Int
    let userId: Int
    let courseId: Int
    let enrolledAt: Date
    let completedAt: Date?
    let progressPercentage: Int
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case courseId = "course_id"
        case enrolledAt = "enrolled_at"
        case completedAt = "completed_at"
        case progressPercentage = "progress_percentage"
        case isActive = "is_active"
    }
}

struct LessonCompletion: Codable, Identifiable {
    let id: Int
    let userId: Int
    let lessonId: Int
    let completedAt: Date
    let timeSpentMinutes: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case lessonId = "lesson_id"
        case completedAt = "completed_at"
        case timeSpentMinutes = "time_spent_minutes"
    }
}

struct CourseProgressResponse: Codable {
    let courseId: Int
    let userId: Int
    let progressPercentage: Int
    let lessonsCompleted: Int
    let totalLessons: Int
    let timeSpentMinutes: Int
    let lastAccessedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case userId = "user_id"
        case progressPercentage = "progress_percentage"
        case lessonsCompleted = "lessons_completed"
        case totalLessons = "total_lessons"
        case timeSpentMinutes = "time_spent_minutes"
        case lastAccessedAt = "last_accessed_at"
    }
}

// MARK: - AI Content Generation Models
struct GeneratedCourse: Codable {
    let title: String
    let description: String
    let lessons: [GeneratedLesson]
    let estimatedDurationHours: Int
    let difficultyLevel: String
    
    enum CodingKeys: String, CodingKey {
        case title, description, lessons
        case estimatedDurationHours = "estimated_duration_hours"
        case difficultyLevel = "difficulty_level"
    }
}

struct GeneratedLesson: Codable, Identifiable {
    var id: String { title }
    let title: String
    let description: String
    let content: String?
    let durationMinutes: Int
    let orderIndex: Int
    
    enum CodingKeys: String, CodingKey {
        case title, description, content
        case durationMinutes = "duration_minutes"
        case orderIndex = "order_index"
    }
}

struct AssembledLessonContent: Codable {
    let title: String
    let content: String
    let summary: String?
    let keyPoints: [String]?
    let exercises: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title, content, summary
        case keyPoints = "key_points"
        case exercises
    }
}

// MARK: - Common Response Types

/// Empty response for endpoints that return no data
struct EmptyResponse: Codable {
    // Intentionally empty - used for endpoints that return 204 or empty JSON
}

struct CommunityEvent: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let eventType: String
    let startTime: Date
    let endTime: Date?
    let location: String?
    let hostId: String?
    let hostName: String?
    let attendeeCount: Int
    let maxAttendees: Int?
    let isOnline: Bool
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, location
        case eventType = "event_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case hostId = "host_id"
        case hostName = "host_name"
        case attendeeCount = "attendee_count"
        case maxAttendees = "max_attendees"
        case isOnline = "is_online"
        case imageUrl = "image_url"
    }
}

struct CommunityQuestion: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let authorId: String
    let authorName: String?
    let tags: [String]?
    let answerCount: Int
    let voteCount: Int
    let isAnswered: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, body, tags
        case authorId = "author_id"
        case authorName = "author_name"
        case answerCount = "answer_count"
        case voteCount = "vote_count"
        case isAnswered = "is_answered"
        case createdAt = "created_at"
    }
}

struct Badge: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let rarity: String
    let requirement: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, requirement
    }
}

struct Streak: Codable, Identifiable {
    let id: String
    let streakType: String
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: Date?
    
    init(id: String = UUID().uuidString, streakType: String, currentStreak: Int, longestStreak: Int, lastActivityDate: Date? = nil) {
        self.id = id
        self.streakType = streakType
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActivityDate = lastActivityDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case streakType = "streak_type"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActivityDate = "last_activity_date"
    }
}

struct SearchResults: Codable {
    let courses: [Course]?
    let users: [User]?
    let posts: [RepoPost]?
    let events: [CommunityEvent]?
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case courses, users, posts, events, total
    }
}

struct UnreadCount: Codable {
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case count
    }
}

struct ActivitySummary: Codable {
    let date: Date
    let lessonsCompleted: Int
    let xpEarned: Int
    let timeSpentMinutes: Int
    let activitiesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case date
        case lessonsCompleted = "lessons_completed"
        case xpEarned = "xp_earned"
        case timeSpentMinutes = "time_spent_minutes"
        case activitiesCount = "activities_count"
    }
}

struct Enrollment: Codable, Identifiable {
    let id: String
    let userId: String
    let courseId: String
    let enrolledAt: Date
    let status: String
    let progress: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case courseId = "course_id"
        case enrolledAt = "enrolled_at"
        case status
        case progress
    }
}

// MARK: - Test Prep Models
struct TestPrepData: Codable, Identifiable {
    var id: String { planId }
    let planId: String
    let title: String
    let testDate: Date
    let sessions: [TestPrepSession]
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case title
        case testDate = "test_date"
        case sessions
    }
}

struct TestPrepSession: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let topic: String
    let durationMinutes: Int
    let activityType: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, topic
        case durationMinutes = "duration_minutes"
        case activityType = "activity_type"
    }
}
