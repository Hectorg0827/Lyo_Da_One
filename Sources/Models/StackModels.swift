import Foundation

enum StackItemType: String, Codable {
    case lesson
    case video
    case event
    case group
    case person
    case question
    case session
    case achievement
    case path
    case course
}

enum StackItemStatus: String, Codable {
    case active
    case completed
    case archived
}

struct StackItemContext: Codable {
    let source: String?
    let courseId: String?
    let lessonId: String?
    let locationName: String?
    let startTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case source
        case courseId = "course_id"
        case lessonId = "lesson_id"
        case locationName = "location_name"
        case startTime = "start_time"
    }
}

struct StackItem: Identifiable, Codable {
    let id: String
    let type: StackItemType
    let refId: String
    let tags: [String]?
    let status: StackItemStatus
    let contextData: StackItemContext?
    let createdAt: Date
    let pinned: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case refId = "ref_id"
        case tags
        case status
        case contextData = "context_data"
        case createdAt = "created_at"
        case pinned
    }
}

struct CreateStackItemRequest: Codable {
    let type: StackItemType
    let refId: String
    let title: String?
    let tags: [String]?
    let contextData: [String: String]? // Simplified for creation

    init(
        type: StackItemType,
        refId: String,
        title: String? = nil,
        tags: [String]? = nil,
        contextData: [String: String]? = nil
    ) {
        self.type = type
        self.refId = refId
        self.title = title
        self.tags = tags
        self.contextData = contextData
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case refId = "ref_id"
        case title
        case tags
        case contextData = "context_data"
    }
}

struct UpdateStackItemRequest: Codable {
    let pinned: Bool?
    let status: StackItemStatus?
}

// MARK: - Extensions
extension StackItem {
    var title: String {
        // In a real app, this would resolve the refId to a Course/Lesson title
        // For now, we return a placeholder or try to extract from context if we had a generic map
        return "Course" 
    }
    
    var subtitle: String? {
        return tags?.first
    }
    
    /// Convenience accessor for courseId from contextData
    var courseId: String? {
        return contextData?.courseId
    }
}
