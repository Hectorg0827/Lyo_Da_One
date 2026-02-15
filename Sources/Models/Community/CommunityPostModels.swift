//
//  CommunityPostModels.swift
//  Lyo
//
//  Production-ready models for Community Posts, Comments, and Moderation
//

import Foundation

// MARK: - Paginated Response

/// Generic paginated response wrapper for list endpoints
struct CommunityPaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
    
    var hasNextPage: Bool { page < totalPages }
    var hasPreviousPage: Bool { page > 1 }
    
    enum CodingKeys: String, CodingKey {
        case items, page, limit
        case totalCount = "total_count"
        case totalPages = "total_pages"
    }
}

// MARK: - Community Post

/// Post type enum for the community feed
enum CommunityPostType: String, Codable, CaseIterable {
    case text
    case image
    case video
    case poll
    case achievement
    case courseShare = "course_share"
    case questionDiscussion = "question_discussion"
    case studyTip = "study_tip"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .video: return "Video"
        case .poll: return "Poll"
        case .achievement: return "Achievement"
        case .courseShare: return "Course Share"
        case .questionDiscussion: return "Question"
        case .studyTip: return "Study Tip"
        }
    }
    
    var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .video: return "video"
        case .poll: return "chart.bar"
        case .achievement: return "trophy"
        case .courseShare: return "book"
        case .questionDiscussion: return "questionmark.circle"
        case .studyTip: return "lightbulb"
        }
    }
}

/// Visibility options for community posts
enum CommunityPostVisibility: String, Codable, CaseIterable {
    case publicPost = "public"
    case followersOnly = "followers"
    case privatePost = "private"
    case groupOnly = "group"
    
    var displayName: String {
        switch self {
        case .publicPost: return "Public"
        case .followersOnly: return "Followers Only"
        case .privatePost: return "Private"
        case .groupOnly: return "Group Only"
        }
    }
    
    var iconName: String {
        switch self {
        case .publicPost: return "globe"
        case .followersOnly: return "person.2"
        case .privatePost: return "lock"
        case .groupOnly: return "person.3"
        }
    }
}

/// A social post in the community feed
struct CommunityPost: Identifiable, Codable, Equatable {
    let id: String
    let authorId: String
    let authorName: String
    let authorAvatar: String?
    let authorLevel: Int
    let content: String
    let mediaURLs: [String]
    let tags: [String]
    var likeCount: Int
    var commentCount: Int
    var hasLiked: Bool
    var hasBookmarked: Bool
    let postType: CommunityPostType
    let linkedCourseId: String?
    let linkedGroupId: String?
    let createdAt: Date
    let updatedAt: Date
    let isEdited: Bool
    let isPinned: Bool
    let visibility: CommunityPostVisibility
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case authorName = "author_name"
        case authorAvatar = "author_avatar"
        case authorLevel = "author_level"
        case content
        case mediaURLs = "media_urls"
        case tags
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case hasLiked = "has_liked"
        case hasBookmarked = "has_bookmarked"
        case postType = "post_type"
        case linkedCourseId = "linked_course_id"
        case linkedGroupId = "linked_group_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isEdited = "is_edited"
        case isPinned = "is_pinned"
        case visibility
    }
    
    static func == (lhs: CommunityPost, rhs: CommunityPost) -> Bool {
        lhs.id == rhs.id
    }
    
    // Custom decoder to handle Date parsing with fallback
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorAvatar = try container.decodeIfPresent(String.self, forKey: .authorAvatar)
        authorLevel = try container.decodeIfPresent(Int.self, forKey: .authorLevel) ?? 1
        content = try container.decode(String.self, forKey: .content)
        mediaURLs = try container.decodeIfPresent([String].self, forKey: .mediaURLs) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        hasLiked = try container.decodeIfPresent(Bool.self, forKey: .hasLiked) ?? false
        hasBookmarked = try container.decodeIfPresent(Bool.self, forKey: .hasBookmarked) ?? false
        postType = try container.decodeIfPresent(CommunityPostType.self, forKey: .postType) ?? .text
        linkedCourseId = try container.decodeIfPresent(String.self, forKey: .linkedCourseId)
        linkedGroupId = try container.decodeIfPresent(String.self, forKey: .linkedGroupId)
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        visibility = try container.decodeIfPresent(CommunityPostVisibility.self, forKey: .visibility) ?? .publicPost
        
        // Handle Date parsing with ISO8601 or fallback
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
        
        if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        }
    }
    
    // Memberwise initializer for testing/previews
    init(
        id: String,
        authorId: String,
        authorName: String,
        authorAvatar: String?,
        authorLevel: Int,
        content: String,
        mediaURLs: [String],
        tags: [String],
        likeCount: Int,
        commentCount: Int,
        hasLiked: Bool,
        hasBookmarked: Bool,
        postType: CommunityPostType,
        linkedCourseId: String?,
        linkedGroupId: String?,
        createdAt: Date,
        updatedAt: Date,
        isEdited: Bool,
        isPinned: Bool,
        visibility: CommunityPostVisibility
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.authorLevel = authorLevel
        self.content = content
        self.mediaURLs = mediaURLs
        self.tags = tags
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.hasLiked = hasLiked
        self.hasBookmarked = hasBookmarked
        self.postType = postType
        self.linkedCourseId = linkedCourseId
        self.linkedGroupId = linkedGroupId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isEdited = isEdited
        self.isPinned = isPinned
        self.visibility = visibility
    }
}

// MARK: - Post Comment

/// A comment on a community post
struct PostComment: Identifiable, Codable, Equatable {
    let id: String
    let postId: String
    let authorId: String
    let authorName: String
    let authorAvatar: String?
    let content: String
    var likeCount: Int
    var hasLiked: Bool
    let parentId: String?  // For nested replies
    var replyCount: Int
    let createdAt: Date
    let isEdited: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case authorName = "author_name"
        case authorAvatar = "author_avatar"
        case content
        case likeCount = "like_count"
        case hasLiked = "has_liked"
        case parentId = "parent_id"
        case replyCount = "reply_count"
        case createdAt = "created_at"
        case isEdited = "is_edited"
    }
    
    static func == (lhs: PostComment, rhs: PostComment) -> Bool {
        lhs.id == rhs.id
    }
    
    // Custom decoder for Date handling
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorAvatar = try container.decodeIfPresent(String.self, forKey: .authorAvatar)
        content = try container.decode(String.self, forKey: .content)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        hasLiked = try container.decodeIfPresent(Bool.self, forKey: .hasLiked) ?? false
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
    }
    
    // Memberwise initializer
    init(
        id: String,
        postId: String,
        authorId: String,
        authorName: String,
        authorAvatar: String?,
        content: String,
        likeCount: Int,
        hasLiked: Bool,
        parentId: String?,
        replyCount: Int,
        createdAt: Date,
        isEdited: Bool
    ) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.content = content
        self.likeCount = likeCount
        self.hasLiked = hasLiked
        self.parentId = parentId
        self.replyCount = replyCount
        self.createdAt = createdAt
        self.isEdited = isEdited
    }
}

// MARK: - Request DTOs

struct CommunityCreatePostRequest: Codable {
    let content: String
    let mediaURLs: [String]?
    let tags: [String]?
    let postType: CommunityPostType
    let linkedCourseId: String?
    let linkedGroupId: String?
    let visibility: CommunityPostVisibility
    
    enum CodingKeys: String, CodingKey {
        case content
        case mediaURLs = "media_urls"
        case tags
        case postType = "post_type"
        case linkedCourseId = "linked_course_id"
        case linkedGroupId = "linked_group_id"
        case visibility
    }
    
    init(
        content: String,
        mediaURLs: [String]? = nil,
        tags: [String]? = nil,
        postType: CommunityPostType = .text,
        linkedCourseId: String? = nil,
        linkedGroupId: String? = nil,
        visibility: CommunityPostVisibility = .publicPost
    ) {
        self.content = content
        self.mediaURLs = mediaURLs
        self.tags = tags
        self.postType = postType
        self.linkedCourseId = linkedCourseId
        self.linkedGroupId = linkedGroupId
        self.visibility = visibility
    }
}

struct CommunityUpdatePostRequest: Codable {
    let content: String?
    let tags: [String]?
    let visibility: CommunityPostVisibility?
}

struct CommunityCreateCommentRequest: Codable {
    let content: String
    let parentId: String?
    
    enum CodingKeys: String, CodingKey {
        case content
        case parentId = "parent_id"
    }
    
    init(content: String, parentId: String? = nil) {
        self.content = content
        self.parentId = parentId
    }
}

// MARK: - Moderation

struct CommunityReportRequest: Codable {
    let targetType: CommunityReportTargetType
    let targetId: String
    let reason: CommunityReportReason
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetId = "target_id"
        case reason
        case description
    }
}

enum CommunityReportTargetType: String, Codable {
    case post
    case comment
    case user
    case group
    case event
}

enum CommunityReportReason: String, Codable, CaseIterable {
    case spam
    case harassment
    case hateSpeech = "hate_speech"
    case violence
    case sexualContent = "sexual_content"
    case misinformation
    case impersonation
    case copyright
    case other
    
    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment or Bullying"
        case .hateSpeech: return "Hate Speech"
        case .violence: return "Violence or Threats"
        case .sexualContent: return "Inappropriate Content"
        case .misinformation: return "Misinformation"
        case .impersonation: return "Impersonation"
        case .copyright: return "Copyright Violation"
        case .other: return "Other"
        }
    }
}

struct CommunityBlockUserRequest: Codable {
    let userId: String
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case reason
    }
}

struct CommunityReportResponse: Codable {
    let id: String
    let status: String
    let message: String
}

// MARK: - User Block Status

struct CommunityBlockedUser: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String?
    let blockedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case blockedAt = "blocked_at"
    }
}

// MARK: - Feed Filters

enum CommunitySortOption: String, CaseIterable, Identifiable {
    case recent
    case popular
    case trending
    case following
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .recent: return "Recent"
        case .popular: return "Popular"
        case .trending: return "Trending"
        case .following: return "Following"
        }
    }
    
    var iconName: String {
        switch self {
        case .recent: return "clock"
        case .popular: return "flame"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .following: return "person.2"
        }
    }
}

struct CommunityFeedFilters: Equatable {
    var sortBy: CommunitySortOption = .recent
    var postType: CommunityPostType?
    var tags: [String] = []
    var authorId: String?
    var groupId: String?
    
    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: sortBy.rawValue)
        ]
        
        if let postType = postType {
            items.append(URLQueryItem(name: "post_type", value: postType.rawValue))
        }
        
        if !tags.isEmpty {
            items.append(URLQueryItem(name: "tag", value: tags.first))
        }
        
        if let authorId = authorId {
            items.append(URLQueryItem(name: "author_id", value: authorId))
        }
        
        if let groupId = groupId {
            items.append(URLQueryItem(name: "group_id", value: groupId))
        }
        
        return items
    }
}

// MARK: - API Response Wrappers

struct CommunityLikeResponse: Codable {
    let liked: Bool
    let likeCount: Int
    
    enum CodingKeys: String, CodingKey {
        case liked
        case likeCount = "like_count"
    }
}

struct CommunityBookmarkResponse: Codable {
    let bookmarked: Bool
}
