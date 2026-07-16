import Foundation

enum FeedPostType: String, Codable {
    case video
    case image
    case text
}

struct FeedCreator: Codable {
    let id: String
    let name: String
}

struct FeedItem: Identifiable, Codable {
    let id: String
    let postType: FeedPostType
    let courseId: String?
    let lessonId: String?
    let title: String
    let videoUrl: String?
    let thumbnailUrl: String?
    let creator: FeedCreator
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postType = "post_type"
        case courseId = "course_id"
        case lessonId = "lesson_id"
        case title
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case creator
        case createdAt = "created_at"
    }
}
