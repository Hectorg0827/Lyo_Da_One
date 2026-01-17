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
