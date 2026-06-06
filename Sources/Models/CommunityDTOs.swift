import Foundation

/// DTOs matching the actual Backend JSON response for Community features
/// These differ from the Domain Models in Sources/Models/Community.swift (which expect nested User objects)

struct APIUserPreview: Codable {
    let id: Int
    let name: String
    let avatar: String?
}

struct APISharedCourse: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let creator: APIUserPreview
    let rating: Double
    let enrollments: Int
    let lessonCount: Int
    let thumbnailURL: String?
    let difficulty: String
    let tags: [String]
    let createdAt: Date
    let likes: Int
    let hasLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, creator, rating, enrollments, tags, likes
        case lessonCount = "lesson_count"
        case thumbnailURL = "thumbnail_url"
        case difficulty = "level"
        case createdAt = "created_at"
        case hasLiked = "has_liked"
    }
}

struct APIStudyGroup: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let subject: String
    let memberCount: Int
    let maxMembers: Int
    let nextSession: Date?
    let locationName: String?
    let isRemote: Bool
    let lat: Double?
    let lng: Double?
    let tags: [String]
    let host: APIUserPreview
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, subject
        case memberCount = "member_count"
        case maxMembers = "max_members"
        case nextSession = "next_session"
        case locationName = "location_name"
        case isRemote = "is_remote"
        case lat, lng, tags, host
    }
}

struct APIEducationalEvent: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let date: Date
    let durationMinutes: Int?
    let locationName: String
    let lat: Double?
    let lng: Double?
    let organizerId: Int
    let imageURL: String?
    let attendeeCount: Int
    let cost: Double?
    let roomId: String?
    let organizerProfile: APIUserPreview?
    // The instruction provided properties that seem to belong here,
    // but the instruction also mentioned APIMarketplaceListing.
    // Assuming the intent was to add these to APIEducationalEvent if they were missing or to update them.
    // The `actions` and `onAction` properties are UI-related and don't belong in a DTO.
    // The `imageURL` type was changed from String? to URL? in the instruction, reverting to String? for DTO consistency.
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, cost
        case organizerId = "organizer_id"
        case date = "start_time"
        case durationMinutes = "duration_minutes"
        case locationName = "location"
        case lat, lng
        case imageURL = "image_url"
        case attendeeCount = "attendee_count"
        case roomId = "room_id"
        case organizerProfile = "organizer_profile"
    }
}

struct APIMarketplaceListing: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let currency: String
    let sellerAvatar: String?
    let images: [String]
    let lat: Double?
    let lng: Double?
    let sellerName: String?
    let category: String?
    let condition: String?
    let createdAt: String?
    let locationName: String?
    let sellerId: Int?
    let sellerEmail: String?
    let sellerLevel: Int?
    let sellerXP: Int?
    let sellerStreak: Int?
    let sellerTotalLessonsCompleted: Int?
    let sellerAchievements: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, currency
        case sellerAvatar = "seller_avatar"
        case images = "image_urls"
        case lat = "latitude"
        case lng = "longitude"
        case sellerName = "seller_name"
        case category, condition, createdAt, locationName
        case sellerId = "seller_id"
        case sellerEmail = "seller_email"
        case sellerLevel = "seller_level"
        case sellerXP = "seller_xp"
        case sellerStreak = "seller_streak"
        case sellerTotalLessonsCompleted = "seller_total_lessons_completed"
        case sellerAchievements = "seller_achievements"
    }

    var seller: User {
        User(
            id: sellerId ?? id,
            email: sellerEmail ?? "",
            name: sellerName ?? "Seller",
            avatarURL: sellerAvatar,
            createdAt: Date(),
            level: sellerLevel ?? 1,
            xp: sellerXP ?? 0,
            streak: sellerStreak ?? 0,
            totalLessonsCompleted: sellerTotalLessonsCompleted ?? 0,
            achievements: sellerAchievements ?? []
        )
    }
    
    var createdAtDate: Date {
        let formatter = ISO8601DateFormatter()
        return createdAt.flatMap { formatter.date(from: $0) } ?? Date()
    }
}

struct APIMarketplaceListingRequest: Codable {
    let title: String
    let description: String
    let price: Double
    let currency: String
    let category: String
    let condition: String
    let lat: Double
    let lng: Double
    let images: [String]
    
    enum CodingKeys: String, CodingKey {
        case title, description, price, currency, category, condition
        case lat = "latitude"
        case lng = "longitude"
        case images = "image_urls"
    }
}

struct APICreateQuestionRequest: Codable {
    let content: String
    let tags: [String]
    let lat: Double
    let lng: Double
    let isAnonymous: Bool
    
    enum CodingKeys: String, CodingKey {
        case content, tags, lat, lng
        case isAnonymous = "is_anonymous"
    }
}

struct APIQuestionResponse: Codable {
    let id: String
    let status: String
}

// MARK: - Educational Center
struct APIEducationalCenter: Codable, Identifiable {
    let id: Int
    let name: String
    let category: String
    let description: String
    let lat: Double
    let lng: Double
    let address: String?
    let imageURL: String?
    let openingHours: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, description, lat, lng, address
        case imageURL = "image_url"
        case openingHours = "opening_hours"
    }
}

struct APIPrivateLesson: Codable, Identifiable {
    let id: Int
    let title: String
    let subject: String
    let instructor: APIUserPreview
    let cost: Double
    let durationMinutes: Int
    let description: String?
    let lat: Double?
    let lng: Double?
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, subject, instructor, cost, description
        case durationMinutes = "duration_minutes"
        case lat, lng
        case imageURL = "image_url"
    }
}

struct APIPrivateLessonRequest: Codable {
    let title: String
    let subject: String
    let cost: Double
    let durationMinutes: Int
    let description: String
    let lat: Double
    let lng: Double
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case title, subject, cost, description, lat, lng
        case durationMinutes = "duration_minutes"
        case imageURL = "image_url"
    }
}

struct APIInstitutionRequest: Codable {
    let name: String
    let category: String
    let description: String
    let lat: Double
    let lng: Double
    let address: String?
    let openingHours: String?
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name, category, description, lat, lng, address
        case openingHours = "opening_hours"
        case imageURL = "image_url"
    }
}

// MARK: - Booking DTOs

struct APIBookingSlot: Codable, Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let isAvailable: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case isAvailable = "is_available"
    }
}

struct APIBookingRequest: Codable {
    let lessonId: Int
    let slotId: String
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case slotId = "slot_id"
        case notes
    }
}

struct APIBookingResponse: Codable {
    let id: String
    let status: String // "pending", "confirmed"
    let message: String?
}

struct APIUserBooking: Codable, Identifiable {
    let id: String
    let lesson: APIPrivateLesson
    let startTime: Date
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, lesson, status
        case startTime = "start_time"
    }
}

// MARK: - Review DTOs

struct APIReview: Codable, Identifiable {
    let id: String
    let author: APIUserPreview
    let rating: Int // 1-5
    let text: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, author, rating, text, timestamp
    }
}

struct APIReviewRequest: Codable {
    let targetId: String
    let targetType: String // "lesson", "center", "user"
    let rating: Int
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case targetId = "target_id"
        case targetType = "target_type"
        case rating, text
    }
}

struct APIReviewStats: Codable {
    let averageRating: Double
    let reviewCount: Int
    
    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case reviewCount = "review_count"
    }
}

// MARK: - Course Social DTOs

struct CourseLikeResponse: Codable {
    let totalLikes: Int
    
    enum CodingKeys: String, CodingKey {
        case totalLikes = "total_likes"
    }
}

struct CourseRatingResponse: Codable {
    let averageRating: Double
    let totalRatings: Int
    
    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case totalRatings = "total_ratings"
    }
}

struct CourseSocialStats: Codable {
    let likes: Int
    let rating: Double
    let ratingCount: Int
    
    enum CodingKeys: String, CodingKey {
        case likes
        case rating
        case ratingCount = "rating_count"
    }
}

// MARK: - Beacon DTOs

enum APIBeacon: Identifiable, Decodable, Encodable {
    case event(APIEventBeacon)
    case user(APIUserActivityBeacon)
    case question(APIQuestionBeacon)
    case marketplace(APIMarketplaceBeacon)
    
    var id: String {
        switch self {
        case .event(let b): return "event-\(b.id)"
        case .user(let b): return "user-\(b.userId)"
        case .question(let b): return "question-\(b.id)"
        case .marketplace(let b): return "market-\(b.id)"
        }
    }
    
    // Helper to extract coordinate for Map use
    var coordinate: (lat: Double, lng: Double) {
        switch self {
        case .event(let b): return (b.latitude, b.longitude)
        case .user(let b): return (b.latitude ?? 0, b.longitude ?? 0)
        case .question(let b): return (b.latitude, b.longitude)
        case .marketplace(let b): return (b.latitude, b.longitude)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .event(let b):
            try container.encode("event", forKey: .type)
            try b.encode(to: encoder)
        case .user(let b):
            try container.encode("user_activity", forKey: .type)
            try b.encode(to: encoder)
        case .question(let b):
            try container.encode("question", forKey: .type)
            try b.encode(to: encoder)
        case .marketplace(let b):
            try container.encode("marketplace", forKey: .type)
            try b.encode(to: encoder)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "event":
            let val = try APIEventBeacon(from: decoder)
            self = .event(val)
        case "user_activity":
             let val = try APIUserActivityBeacon(from: decoder)
             self = .user(val)
        case "question":
             let val = try APIQuestionBeacon(from: decoder)
             self = .question(val)
        case "marketplace":
             let val = try APIMarketplaceBeacon(from: decoder)
             self = .marketplace(val)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown beacon type: \(type)")
        }
    }
}

struct APIEventBeacon: Codable {
    let id: Int
    let title: String
    let latitude: Double
    let longitude: Double
    let startTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, latitude, longitude
        case startTime = "start_time"
    }
}

struct APIUserActivityBeacon: Codable {
    let userId: Int
    let displayName: String
    let latitude: Double?
    let longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case latitude, longitude
    }
}

struct APIQuestionBeacon: Codable {
    let id: String
    let text: String
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case id, text, latitude, longitude
    }
}

struct APIMarketplaceBeacon: Codable {
    let id: Int
    let title: String
    let price: Double
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case id, title, price, latitude, longitude
    }
}
