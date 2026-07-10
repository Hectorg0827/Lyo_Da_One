import Foundation

// MARK: - Story Models

struct Story: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String?
    
    // New: Slides support
    var slides: [StorySlide]
    
    // Legacy support (optional, can be computed from first slide)
    var mediaURL: String? { slides.first?.mediaURL }
    var mediaType: MediaType { slides.first?.type == .video ? .video : .image }
    
    // Metadata
    let isLive: Bool
    let createdAt: Date
    let expiresAt: Date
    var isSeen: Bool
    
    // Linked Content (Contextual)
    let linkedCourseId: String?
    let linkedGroupId: String?
    let linkedReelId: String?
    var tags: [String] = []
    
    enum MediaType: String, Codable {
        case image
        case video
        case text
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case slides
        case isLive = "is_live"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isSeen = "is_seen"
        case linkedCourseId = "linked_course_id"
        case linkedGroupId = "linked_group_id"
        case linkedReelId = "linked_reel_id"
        case tags
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        userName = try container.decode(String.self, forKey: .userName)
        userAvatar = try container.decodeIfPresent(String.self, forKey: .userAvatar)
        
        // Robust Decoding for Slides
        if let decodedSlides = try container.decodeIfPresent([StorySlide].self, forKey: .slides) {
            slides = decodedSlides
        } else {
            // Fallback: If "slides" missing, try to construct one from legacy "media_url"
            // Note: We need to manually look for legacy keys if they existed in previous version, 
            // but for now we'll default to empty or simple text
            slides = []
        }
        
        isLive = try container.decode(Bool.self, forKey: .isLive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        isSeen = try container.decode(Bool.self, forKey: .isSeen)
        
        linkedCourseId = try container.decodeIfPresent(String.self, forKey: .linkedCourseId)
        linkedGroupId = try container.decodeIfPresent(String.self, forKey: .linkedGroupId)
        linkedReelId = try container.decodeIfPresent(String.self, forKey: .linkedReelId)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
    
    // Memberwise init for mocks
    init(id: String, userId: String, userName: String, userAvatar: String?, slides: [StorySlide], isLive: Bool, createdAt: Date, expiresAt: Date, isSeen: Bool, linkedCourseId: String? = nil, linkedGroupId: String? = nil, linkedReelId: String? = nil, tags: [String] = []) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userAvatar = userAvatar
        self.slides = slides
        self.isLive = isLive
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isSeen = isSeen
        self.linkedCourseId = linkedCourseId
        self.linkedGroupId = linkedGroupId
        self.linkedReelId = linkedReelId
        self.tags = tags
    }
}

struct StorySlide: Identifiable, Codable {
    let id: String
    let type: Story.MediaType
    let mediaURL: String?
    let text: String?
    let duration: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case mediaURL = "media_url"
        case text
        case duration
    }
}

struct CreateStoryRequest: Codable {
    let mediaURL: String
    let mediaType: Story.MediaType
    let isLive: Bool
    let caption: String?
    let linkedCourseId: String?
    let linkedGroupId: String?
    let tags: [String]
    
    init(mediaURL: String, mediaType: Story.MediaType = .image, isLive: Bool = false, caption: String? = nil, linkedCourseId: String? = nil, linkedGroupId: String? = nil, tags: [String] = []) {
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.isLive = isLive
        self.caption = caption
        self.linkedCourseId = linkedCourseId
        self.linkedGroupId = linkedGroupId
        self.tags = tags
    }
    
    enum CodingKeys: String, CodingKey {
        case mediaURL = "media_url"
        case mediaType = "media_type"
        case isLive = "is_live"
        case caption
        case linkedCourseId = "linked_course_id"
        case linkedGroupId = "linked_group_id"
        case tags
    }
}

// MARK: - Discovery Models

struct Discovery: Identifiable, Codable {
    let id: Int
    let userId: Int
    let userName: String?
    let title: String
    let description: String?
    let thumbnailURL: String?
    let videoURL: String?
    var likes: Int
    let views: Int
    var isLiked: Bool
    let isSaved: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "userId"
        case userName = "authorName"
        case title
        case description
        case thumbnailURL = "thumbnailURL"
        case videoURL = "videoURL"
        case likes = "likeCount"
        case views = "viewCount"
        case isLiked = "isLiked"
        case isSaved = "isSaved"
        case createdAt = "createdAt"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. Decode ID robustly (String vs Int)
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = idInt
        } else if let idString = try? container.decode(String.self, forKey: .id), let idInt = Int(idString) {
            self.id = idInt
        } else {
            self.id = try container.decode(Int.self, forKey: .id)
        }
        
        // 2. Decode userId robustly (String vs Int)
        if let userIdInt = try? container.decode(Int.self, forKey: .userId) {
            self.userId = userIdInt
        } else if let userIdString = try? container.decode(String.self, forKey: .userId), let userIdInt = Int(userIdString) {
            self.userId = userIdInt
        } else {
            self.userId = try container.decode(Int.self, forKey: .userId)
        }
        
        // 3. Standard decoding for text/optional fields
        self.userName = try container.decodeIfPresent(String.self, forKey: .userName)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        self.videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
        
        // 4. Metrics & Flags (safely fallback to defaults if null/missing)
        self.likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        self.views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        self.isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        self.isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved) ?? false
        
        // 5. Date Decoding Resiliency
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                self.createdAt = date
            } else {
                let stdFormatter = ISO8601DateFormatter()
                stdFormatter.formatOptions = [.withInternetDateTime]
                if let date = stdFormatter.date(from: dateString) {
                    self.createdAt = date
                } else {
                    let dateForm = DateFormatter()
                    dateForm.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    self.createdAt = dateForm.date(from: dateString) ?? Date()
                }
            }
        } else {
            self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
    }
    
    // Memberwise initializer for preview/mocks
    init(id: Int, userId: Int, userName: String?, title: String, description: String?, thumbnailURL: String?, videoURL: String?, likes: Int, views: Int, isLiked: Bool, isSaved: Bool, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.videoURL = videoURL
        self.likes = likes
        self.views = views
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.createdAt = createdAt
    }
}

struct CreateDiscoveryRequest: Codable {
    let title: String
    let description: String?
    let videoURL: String
    let thumbnailURL: String?
    let durationSeconds: Double
    let subject: String?
    let topic: String?
    let level: String
    let tags: [String]
    let isPublic: Bool
    let enableCourseGeneration: Bool
    
    init(title: String, description: String? = nil, videoURL: String, thumbnailURL: String? = nil, durationSeconds: Double = 0.0, subject: String? = nil, topic: String? = nil, level: String = "beginner", tags: [String] = [], isPublic: Bool = true, enableCourseGeneration: Bool = true) {
        self.title = title
        self.description = description
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.durationSeconds = durationSeconds
        self.subject = subject
        self.topic = topic
        self.level = level
        self.tags = tags
        self.isPublic = isPublic
        self.enableCourseGeneration = enableCourseGeneration
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case videoURL = "videoUrl"
        case thumbnailURL = "thumbnailUrl"
        case durationSeconds = "durationSeconds"
        case subject
        case topic
        case level
        case tags
        case isPublic = "isPublic"
        case enableCourseGeneration = "enableCourseGeneration"
    }
}

struct SaveDiscoveryRequest: Codable {
    let discoveryId: String
    
    enum CodingKeys: String, CodingKey {
        case discoveryId = "discovery_id"
    }
}

struct DiscoveryResponse: Codable {
    let success: Bool
    let clip: Discovery?
    let message: String?
    let error: String?
}

// MARK: - Post Models

struct Post: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String?
    let content: String
    let mediaURLs: [String]
    let likes: Int
    let comments: Int
    let shares: Int
    let isLiked: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case content
        case mediaURLs = "media_urls"
        case likes
        case comments
        case shares
        case isLiked = "is_liked"
        case createdAt = "created_at"
    }
}

struct CreatePostRequest: Codable {
    let content: String
    let mediaURLs: [String]
    let visibility: PostVisibility
    
    enum CodingKeys: String, CodingKey {
        case content
        case mediaURLs = "media_urls"
        case visibility
    }
}

enum PostVisibility: String, Codable {
    case `public`
    case friends
    case `private`
}

// MARK: - Response Wrappers

struct StoriesResponse: Codable {
    let stories: [Story]
    let myStory: Story?
    
    enum CodingKeys: String, CodingKey {
        case stories
        case myStory = "my_story"
    }
}

struct DiscoveriesResponse: Codable {
    let discoveries: [Discovery]
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case discoveries
        case items
        case posts 
        case clips // backend use "clips"
        case total
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try multiple keys for discoveries
        if let d = try container.decodeIfPresent([Discovery].self, forKey: .discoveries) {
            self.discoveries = d
        } else if let items = try container.decodeIfPresent([Discovery].self, forKey: .items) {
            self.discoveries = items
        } else if let posts = try container.decodeIfPresent([Discovery].self, forKey: .posts) {
            self.discoveries = posts
        } else if let clips = try container.decodeIfPresent([Discovery].self, forKey: .clips) {
            self.discoveries = clips
        } else {
            self.discoveries = []
        }
        
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        self.hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(discoveries, forKey: .discoveries)
        try container.encode(total, forKey: .total)
        try container.encode(hasMore, forKey: .hasMore)
    }
}

struct PostsResponse: Codable {
    let posts: [Post]
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case posts = "items" // API returns "items"
        case total
        case hasMore = "has_more"
    }

    init(posts: [Post], total: Int, hasMore: Bool) {
        self.posts = posts
        self.total = total
        self.hasMore = hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.posts = try container.decodeIfPresent([Post].self, forKey: .posts) ?? []
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        self.hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}
