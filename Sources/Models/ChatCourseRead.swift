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


}
