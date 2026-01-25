import Foundation

/// DTOs matching the actual Backend JSON response for Community features
/// These differ from the Domain Models in Sources/Models/Community.swift (which expect nested User objects)

struct APIUserPreview: Codable {
    let id: Int
    let name: String
    let avatar: String?
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
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, currency
        case sellerAvatar = "seller_avatar"
        case images = "image_urls"
        case lat = "latitude"
        case lng = "longitude"
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

struct APIEducationalCenter: Codable, Identifiable {
    let id: Int
    let name: String
    let category: String // e.g., "Library", "Dance School"
    let description: String
    let lat: Double
    let lng: Double
    let imageURL: String?
    let address: String?
    let openingHours: String? // Simple string for now "9AM - 5PM"
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, description, lat, lng, address
        case imageURL = "image_url"
        case openingHours = "opening_hours"
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
import Foundation

// MARK: - Helper for dynamic JSON values
public struct AnyCodable: Codable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map(AnyCodable.init)
            try container.encode(codableArray)
        case let dict as [String: Any]:
            let codableDict = dict.mapValues(AnyCodable.init)
            try container.encode(codableDict)
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
