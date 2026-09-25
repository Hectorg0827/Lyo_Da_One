import Foundation

/// DTOs matching the actual Backend JSON response for Community features
/// These differ from the Domain Models in Sources/Models/Community.swift (which expect nested User objects)

struct APIUserPreview: Codable, Equatable {
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

struct APIStudyGroup: Decodable, Identifiable {
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
    let privacy: String
    let isMember: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, subject
        case memberCount = "member_count"
        case maxMembers = "max_members"
        case nextSession = "next_session"
        case locationName = "location_name"
        case isRemote = "is_remote"
        case lat, lng, tags, host, privacy
        case isMember = "is_member"
        case creatorId = "creator_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? "General"
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        maxMembers = try container.decodeIfPresent(Int.self, forKey: .maxMembers) ?? 0
        nextSession = try container.decodeIfPresent(Date.self, forKey: .nextSession)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        isRemote = try container.decodeIfPresent(Bool.self, forKey: .isRemote) ?? true
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        privacy = try container.decodeIfPresent(String.self, forKey: .privacy) ?? "public"
        isMember = try container.decodeIfPresent(Bool.self, forKey: .isMember) ?? false
        host = try container.decodeIfPresent(APIUserPreview.self, forKey: .host)
            ?? APIUserPreview(
                id: try container.decodeIfPresent(Int.self, forKey: .creatorId) ?? 0,
                name: "Community host",
                avatar: nil
            )
    }
}

struct APICreateStudyGroupRequest: Codable {
    let name: String
    let description: String?
    let privacy: String
    let maxMembers: Int
    let requiresApproval: Bool
    let location: String?
    let isOnline: Bool
    let meetingUrl: String?
    let latitude: Double?
    let longitude: Double?
}

/// Create-event payload. Times encode as ISO-8601 instants with an offset;
/// the backend stores them as UTC. `clientRequestId` makes a retried or
/// double-tapped submit return the first event instead of a duplicate.
struct APICreateEducationalEventRequest: Codable {
    let title: String
    let description: String?
    let eventType: String
    let location: String?
    let isOnline: Bool
    let meetingUrl: String?
    let maxAttendees: Int?
    let startTime: Date
    let endTime: Date
    let timezone: String
    let latitude: Double?
    let longitude: Double?
    var attendanceMode: String? = nil
    var venueName: String? = nil
    var address: String? = nil
    var websiteUrl: String? = nil
    var imageUrl: String? = nil
    var organizerName: String? = nil
    var priceType: String? = nil
    var priceAmount: Double? = nil
    var currency: String? = nil
    var visibility: String? = nil
    var clientRequestId: String? = nil
}

/// Event update. Fields left nil are not sent, so an edit never touches
/// something the host did not change; keys in `cleared` are sent as explicit
/// nulls so a host can remove an optional detail (a website, a capacity).
struct APIUpdateEventRequest: Encodable {
    var title: String? = nil
    var description: String? = nil
    var eventType: String? = nil
    var location: String? = nil
    var isOnline: Bool? = nil
    var meetingUrl: String? = nil
    var maxAttendees: Int? = nil
    var startTime: Date? = nil
    var endTime: Date? = nil
    var timezone: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var attendanceMode: String? = nil
    var venueName: String? = nil
    var address: String? = nil
    var websiteUrl: String? = nil
    var imageUrl: String? = nil
    var organizerName: String? = nil
    var priceType: String? = nil
    var priceAmount: Double? = nil
    var currency: String? = nil
    var visibility: String? = nil
    var status: String? = nil
    /// snake_case keys to clear, e.g. "website_url".
    var cleared: Set<String> = []

    /// Optional details a host may remove; required fields are never cleared.
    static let clearableKeys: Set<String> = [
        "description", "location", "meeting_url", "max_attendees", "latitude", "longitude",
        "venue_name", "address", "website_url", "image_url", "organizer_name",
        "price_amount", "currency",
    ]

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        func put<Value: Encodable>(_ name: String, _ value: Value?) throws {
            if let value {
                try container.encode(value, forKey: Key(name))
            } else if cleared.contains(name), Self.clearableKeys.contains(name) {
                try container.encodeNil(forKey: Key(name))
            }
        }
        try put("title", title)
        try put("description", description)
        try put("event_type", eventType)
        try put("location", location)
        try put("is_online", isOnline)
        try put("meeting_url", meetingUrl)
        try put("max_attendees", maxAttendees)
        try put("start_time", startTime)
        try put("end_time", endTime)
        try put("timezone", timezone)
        try put("latitude", latitude)
        try put("longitude", longitude)
        try put("attendance_mode", attendanceMode)
        try put("venue_name", venueName)
        try put("address", address)
        try put("website_url", websiteUrl)
        try put("image_url", imageUrl)
        try put("organizer_name", organizerName)
        try put("price_type", priceType)
        try put("price_amount", priceAmount)
        try put("currency", currency)
        try put("visibility", visibility)
        try put("status", status)
    }
}

/// The full event row returned by /community/events/{id} and in node detail.
struct APICommunityEventRecord: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String?
    let eventType: String
    let location: String?
    let isOnline: Bool
    let meetingUrl: String?
    let maxAttendees: Int?
    let startTime: String
    let endTime: String
    let timezone: String?
    let status: String
    let organizerId: Int
    let latitude: Double?
    let longitude: Double?
    let imageUrl: String?
    let visibility: String?
    let priceType: String?
    let priceAmount: Double?
    let currency: String?
    let websiteUrl: String?
    let organizerName: String?
    let venueName: String?
    let address: String?
    let attendanceMode: String?
    let attendeeCount: Int?
    let isFull: Bool?
}

// MARK: - Learning Around Me

/// Canonical, flat map DTO shared by iOS, Android, and web. Membership,
/// attendance, and save flags are computed by the backend for the signed-in
/// account; clients never treat device storage as the source of truth.
struct APILearningNode: Codable, Identifiable, Equatable {
    var key: String
    var kind: String
    var category: String
    var id: String
    var title: String
    var description: String?
    var latitude: Double?
    var longitude: Double?
    var distanceKm: Double?
    var locationName: String?
    var isOnline: Bool
    var meetingUrl: String?
    var startsAt: String?
    var endsAt: String?
    var timezone: String?
    var host: APIUserPreview?
    var memberCount: Int?
    var attendeeCount: Int?
    var capacity: Int?
    var isJoined: Bool
    var isAttending: Bool
    var isSaved: Bool
    var courseId: Int?
    var lessonId: Int?
    var studyGroupId: Int?
    var imageUrl: String?
    var source: String
    var sourceUrl: String?
    // Contract 4. Optional so older payloads (and saved snapshots) decode.
    var lifecycle: String? = nil
    var rsvpStatus: String? = nil
    var goingCount: Int? = nil
    var interestedCount: Int? = nil
    var isFree: Bool? = nil
    var priceAmount: Double? = nil
    var currency: String? = nil
    var organizerName: String? = nil
    var venueName: String? = nil
    var address: String? = nil
    var attendanceMode: String? = nil
    var visibility: String? = nil
    var websiteUrl: String? = nil
    var phone: String? = nil
    var email: String? = nil
    var openingHours: String? = nil
    var placeType: String? = nil
    var relevance: String? = nil
    var isOwner: Bool? = nil
    var isFull: Bool? = nil
    /// On this event's guest list (a private or unlisted invitation).
    var isInvited: Bool? = nil
}

struct APINearbyLearningResponse: Decodable {
    let items: [APILearningNode]
    let centerLatitude: Double
    let centerLongitude: Double
    let radiusKm: Double
    let fetchedAt: String
    let degradedSources: [String]?
}

/// Everything the full detail screen needs in one request.
struct APILearningNodeDetail: Decodable {
    var node: APILearningNode
    let related: [APILearningNode]
    let canEdit: Bool
    let event: APICommunityEventRecord?
}

struct APIRSVPRequest: Encodable {
    let status: String
}

struct APIEventReportRequest: Encodable {
    let reason: String
    let description: String?
}

struct APIEventReportResponse: Decodable {
    let status: String
    let message: String
}

struct APIPlaceSuggestion: Decodable, Identifiable, Equatable {
    let name: String
    let label: String
    let kind: String
    let latitude: Double
    let longitude: Double
    let radiusKm: Double
    let isArea: Bool

    var id: String { "\(latitude),\(longitude),\(label)" }
}

struct APISearchResolution: Decodable {
    let query: String
    let intent: String
    let topic: String?
    let terms: [String]
    let categories: [String]
    let place: APIPlaceSuggestion?
    let places: [APIPlaceSuggestion]
}

struct APICommunityAnalyticsEvent: Encodable {
    let name: String
    let platform: String
    let properties: [String: String]
}

struct APILearningNodeSaveRequest: Encodable {
    let snapshot: APILearningNode
}

struct APIAccountStudyGroup: Decodable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let memberCount: Int?
    let location: String?
    let isOnline: Bool
    let imageUrl: String?
}

struct APIAccountCommunityEvent: Decodable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let startTime: String
    let endTime: String
    let location: String?
    let isOnline: Bool
    let attendeeCount: Int?
}

struct APICommunityMeResponse: Decodable {
    let joinedGroups: [APIAccountStudyGroup]
    let attendingEvents: [APIAccountCommunityEvent]
    var savedNodes: [APILearningNode]
    let following: [APIUserPreview]
    let updatedAt: String
    var hosting: [APILearningNode]?
    var going: [APILearningNode]?
    var interested: [APILearningNode]?
    /// Upcoming events this account was invited to and hasn't answered yet.
    var invited: [APILearningNode]?
}

// MARK: - Private event invitations

/// A shareable invite link. Only the host ever sees these.
struct APIEventInvite: Decodable, Identifiable, Equatable {
    let id: Int
    let token: String
    let url: String
    let createdAt: String
    let expiresAt: String?
    let maxUses: Int?
    let useCount: Int
    let active: Bool
}

/// Someone on the guest list, and how they answered.
struct APIEventGuest: Decodable, Identifiable, Equatable {
    let user: APIUserPreview
    /// "link" (joined with an invite link) or "direct" (invited by name).
    let source: String
    let invitedAt: String
    let rsvpStatus: String?

    var id: Int { user.id }
}

struct APIEventInvitesResponse: Decodable, Equatable {
    var links: [APIEventInvite]
    var guests: [APIEventGuest]
}

/// What an invite link opens, before the learner accepts it.
struct APIInvitePreview: Decodable, Equatable {
    /// valid, expired, revoked, used_up, ended, or cancelled.
    let status: String
    let alreadyGuest: Bool
    let isHost: Bool
    let eventId: Int
    let title: String
    let startsAt: String?
    let endsAt: String?
    let timezone: String?
    let locationName: String?
    let attendanceMode: String?
    let visibility: String?
    let host: APIUserPreview?
    let organizerName: String?
    let imageUrl: String?
}

struct APIInviteCreateRequest: Encodable {
    /// nil means anyone with the link can use it until it expires.
    let maxUses: Int?
    let expiresInDays: Int

    enum CodingKeys: String, CodingKey { case maxUses, expiresInDays }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Sent explicitly as null so "anyone" is never mistaken for a default.
        try container.encode(maxUses, forKey: .maxUses)
        try container.encode(expiresInDays, forKey: .expiresInDays)
    }
}

struct APIGuestCreateRequest: Encodable {
    let userId: Int
}

struct APICreatePrivateLessonRequest: Codable {
    let title: String
    let description: String?
    let subject: String
    let pricePerHour: Double
    let currency: String
    let durationMinutes: Int
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let isOnline: Bool
    let meetingUrl: String?
}

struct APIEducationalEvent: Decodable, Identifiable {
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
    let userAttendanceStatus: String?

    var isAttending: Bool { userAttendanceStatus != nil }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, cost
        case organizerId = "organizer_id"
        case date = "start_time"
        case durationMinutes = "duration_minutes"
        case locationName = "location"
        case lat = "latitude"
        case lng = "longitude"
        case imageURL = "image_url"
        case attendeeCount = "attendee_count"
        case roomId = "room_id"
        case organizerProfile = "organizer_profile"
        case userAttendanceStatus = "user_attendance_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        date = try container.decode(Date.self, forKey: .date)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName) ?? "Online"
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        organizerId = try container.decodeIfPresent(Int.self, forKey: .organizerId) ?? 0
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        attendeeCount = try container.decodeIfPresent(Int.self, forKey: .attendeeCount) ?? 0
        cost = try container.decodeIfPresent(Double.self, forKey: .cost)
        roomId = try container.decodeIfPresent(String.self, forKey: .roomId)
        organizerProfile = try container.decodeIfPresent(APIUserPreview.self, forKey: .organizerProfile)
        userAttendanceStatus = try container.decodeIfPresent(String.self, forKey: .userAttendanceStatus)
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

struct APICourseLikeResponse: Codable {
    let totalLikes: Int
    
    enum CodingKeys: String, CodingKey {
        case totalLikes = "total_likes"
    }
}

struct APICourseRatingResponse: Codable {
    let averageRating: Double
    let totalRatings: Int
    
    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case totalRatings = "total_ratings"
    }
}

struct APICourseSocialStats: Codable {
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
