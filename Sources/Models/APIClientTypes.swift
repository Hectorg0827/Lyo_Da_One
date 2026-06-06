import Foundation

// MARK: - API Client Response Types
// Types specifically for LyoAPIClient backend responses

/// Empty response for endpoints that don't return data
struct EmptyAPIResponse: Codable {}



/// Conversation for messaging
struct APIConversation: Codable, Identifiable {
    let id: String
    let type: String
    let name: String?
    let participantIds: [String]
    let lastMessagePreview: String?
    let unreadCount: Int
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, type, name
        case participantIds = "participant_ids"
        case lastMessagePreview = "last_message_preview"
        case unreadCount = "unread_count"
        case updatedAt = "updated_at"
    }
}

/// Message for messaging
struct APIMessage: Codable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let mediaUrl: String?
    let status: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, content, status
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case mediaUrl = "media_url"
        case createdAt = "created_at"
    }
}

/// App notification from backend
struct APINotification: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let icon: String?
    let category: String
    let isRead: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, body, icon, category
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

/// Learning insights from analytics
struct APILearningInsights: Codable {
    let streakDays: Int
    let totalTimeSeconds: Int
    let avgDailyTimeSeconds: Int
    let daysActive: Int
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case streakDays = "streak_days"
        case totalTimeSeconds = "total_time_seconds"
        case avgDailyTimeSeconds = "avg_daily_time_seconds"
        case daysActive = "days_active"
        case recommendations
    }
}
