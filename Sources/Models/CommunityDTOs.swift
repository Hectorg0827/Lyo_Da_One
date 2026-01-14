import Foundation

/// DTOs matching the actual Backend JSON response for Community features
/// These differ from the Domain Models in Sources/Models/Community.swift (which expect nested User objects)

struct APIStudyGroup: Codable, Identifiable {
    let id: String
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
    
    struct APIUserPreview: Codable {
        let id: String
        let name: String
        let avatar: String?
    }
    
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
    let id: String
    let title: String
    let description: String
    let date: Date
    let durationMinutes: Int
    let locationName: String
    let lat: Double?
    let lng: Double?
    let organizer: String
    let imageURL: String?
    let attendeesCount: Int
    let cost: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, date
        case durationMinutes = "duration_minutes"
        case locationName = "location_name"
        case lat, lng, organizer
        case imageURL = "image_url"
        case attendeesCount = "attendees_count"
        case cost
    }
}

struct APIMarketplaceListing: Codable, Identifiable {
    let id: String
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
        case images, lat, lng
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
