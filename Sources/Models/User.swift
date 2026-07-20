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
        case firstName
        case lastName
        case avatarURL = "avatarUrl"  // avatar_url → avatarUrl via .convertFromSnakeCase
        case createdAt
        case level
        case xp
        case streak
        case totalLessonsCompleted
        case achievements
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let stringId = try? container.decode(String.self, forKey: .id), let intId = Int(stringId) {
            id = intId
        } else {
            id = 0
        }
        
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        
        // Handle Date
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                createdAt = date
            } else {
                createdAt = Date()
            }
        } else {
            createdAt = Date()
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(name, forKey: .name)
        try container.encode(avatarURL, forKey: .avatarURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(username, forKey: .username)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(level, forKey: .level)
        try container.encode(xp, forKey: .xp)
        try container.encode(streak, forKey: .streak)
        try container.encode(totalLessonsCompleted, forKey: .totalLessonsCompleted)
        try container.encode(achievements, forKey: .achievements)
    }
    
    // Memberwise init
    init(id: Int, email: String, name: String, avatarURL: String?, createdAt: Date, level: Int, xp: Int, streak: Int, totalLessonsCompleted: Int, achievements: [String]) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.level = level
        self.xp = xp
        self.streak = streak
        self.totalLessonsCompleted = totalLessonsCompleted
        self.achievements = achievements
        
        self.username = nil
        self.firstName = nil
        self.lastName = nil
    }
}
