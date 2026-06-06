import Foundation

// MARK: - Tutor Session Models

struct TutorSession: Codable, Identifiable {
    let id: String
    let courseId: String
    let lessonId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case lessonId = "lesson_id"
        case createdAt = "created_at"
    }
}

struct TutorMessage: Codable, Identifiable {
    let id: String
    let sessionId: String
    let sender: String   // "user" or "ai"
    let content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case sender
        case content
        case createdAt = "created_at"
    }
}

// MARK: - Request Models

struct TutorSessionCreate: Codable {
    let courseId: String
    let lessonId: String
    
    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case lessonId = "lesson_id"
    }
}

struct TutorMessageCreate: Codable {
    let sessionId: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case content
    }
}
