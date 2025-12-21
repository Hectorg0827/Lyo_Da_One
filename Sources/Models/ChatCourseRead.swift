import Foundation

struct ChatCourseRead: Identifiable, Codable {
    let id: String
    let userId: String?
    let title: String
    let description: String?
    let topic: String
    let difficulty: String
    let learningObjectives: [String]?
    let estimatedHours: Double?
    let isPublished: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case topic
        case difficulty
        case learningObjectives = "learning_objectives"
        case estimatedHours = "estimated_hours"
        case isPublished = "is_published"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
