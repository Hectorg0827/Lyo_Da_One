import Foundation

struct User: Identifiable, Codable {
    let id: Int
    let email: String
    var name: String
    let avatarURL: String?
    let createdAt: Date
    
    // Backend fields
    let username: String?
    let firstName: String?
    let lastName: String?
    
    // Gamification fields (with defaults)
    let level: Int
    let xp: Int
    let streak: Int
    let totalLessonsCompleted: Int
    let achievements: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case level
        case xp
        case streak
        case totalLessonsCompleted = "total_lessons_completed"
        case achievements
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        
        // Handle Date
        // Try standard decoding first
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            // Fallback for fractional seconds if standard fails (though .iso8601 strategy should handle it)
            let dateString = try container.decode(String.self, forKey: .createdAt)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                createdAt = date
            } else {
                // Last resort fallback
                createdAt = Date()
            }
        }
        
        username = try container.decodeIfPresent(String.self, forKey: .username)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        
        // Handle name
        if let n = try container.decodeIfPresent(String.self, forKey: .name) {
            name = n
        } else if let first = firstName, let last = lastName {
            name = "\(first) \(last)"
        } else if let first = firstName {
            name = first
        } else if let u = username {
            name = u
        } else {
            name = "User"
        }
        
        // Handle gamification defaults
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        xp = try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        totalLessonsCompleted = try container.decodeIfPresent(Int.self, forKey: .totalLessonsCompleted) ?? 0
        achievements = try container.decodeIfPresent([String].self, forKey: .achievements) ?? []
    }
}

let jsonString = """
{
  "id" : 16,
  "is_verified" : false,
  "avatar_url" : null,
  "created_at" : "2025-11-24T02:21:06.302877",
  "is_active" : true,
  "bio" : null,
  "last_login" : null,
  "first_name" : "Hector",
  "updated_at" : "2025-11-24T02:21:06.302881",
  "username" : "test12",
  "last_name" : "Garcia",
  "email" : "test12@gmail.com"
}
"""

let jsonData = jsonString.data(using: .utf8)!
let decoder = JSONDecoder()
// The backend date format seems to be ISO8601 but with fractional seconds.
// Standard ISO8601DateFormatter might handle it, or we might need custom strategy.
// Let's try .iso8601 first.
decoder.dateDecodingStrategy = .iso8601

do {
    let user = try decoder.decode(User.self, from: jsonData)
    print("✅ Decoding successful: \(user)")
} catch {
    print("❌ Decoding failed: \(error)")
}
