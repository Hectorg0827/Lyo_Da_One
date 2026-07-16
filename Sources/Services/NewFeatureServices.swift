import Foundation
import os

// MARK: - Push Notifications Service
@MainActor
class PushService: ObservableObject {
    private let client: NetworkClient
    
    @Published var devices: [PushDevice] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func registerDevice(token: String, type: String = "ios", info: [String: String]? = nil) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Push.registerDevice(
                token: token,
                type: type,
                info: info,
                appVersion: AppConfig.version,
                osVersion: nil // We can add UIDevice.current.systemVersion if we import UIKit
            )
        )
    }
    
    func listDevices() async throws -> [PushDevice] {
        let response: DevicesResponse = try await client.request(Endpoints.Push.listDevices)
        devices = response.devices
        return devices
    }
    
    func unregisterDevice(deviceId: String) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Push.unregisterDevice(deviceId: deviceId)
        )
        devices.removeAll { $0.id == deviceId }
    }
    
    func testPush() async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Push.testPush(title: "Test Push", body: "This is a test notification")
        )
    }
}

// MARK: - Analytics Service
@MainActor
class AnalyticsService: ObservableObject {
    private let client: NetworkClient
    
    @Published var currentSessionId: String?
    @Published var stats: UserAnalyticsStats?
    @Published var insights: LearningInsights?
    
    init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func startSession(deviceInfo: [String: String]? = nil) async throws -> String {
        let response: AnalyticsSession = try await client.request(
            Endpoints.Analytics.startSession(deviceInfo: deviceInfo)
        )
        currentSessionId = response.sessionId
        return response.sessionId
    }
    
    func trackEvent(
        name: String,
        category: String,
        properties: [String: String]? = nil
    ) async {
        do {
            let _: EmptyResponse = try await client.request(
                Endpoints.Analytics.trackEvent(
                    name: name,
                    category: category,
                    properties: properties,
                    sessionId: currentSessionId
                )
            )
        } catch {
            // Analytics failures should not disrupt UX
            Log.net.error("Analytics track event failed: \(error)")
        }
    }
    
    func trackScreenView(screenName: String, properties: [String: String]? = nil) async {
        do {
            let _: EmptyResponse = try await client.request(
                Endpoints.Analytics.trackScreenView(
                    screenName: screenName,
                    sessionId: currentSessionId,
                    properties: properties
                )
            )
        } catch {
            Log.net.error("Analytics track screen failed: \(error)")
        }
    }
    
    func trackLearningProgress(contentId: String, progress: Double, timeSpent: Int) async {
        do {
            let _: EmptyResponse = try await client.request(
                Endpoints.Analytics.trackLearningProgress(
                    contentId: contentId,
                    progress: progress,
                    timeSpent: timeSpent,
                    sessionId: currentSessionId
                )
            )
        } catch {
            Log.net.error("Analytics track learning progress failed: \(error)")
        }
    }
    
    func trackAIInteraction(interactionType: String) async {
        do {
            let _: EmptyResponse = try await client.request(
                Endpoints.Analytics.trackAIInteraction(
                    interactionType: interactionType,
                    sessionId: currentSessionId
                )
            )
        } catch {
            Log.net.error("Analytics track AI interaction failed: \(error)")
        }
    }
    
    func getUserStats(days: Int = 30) async throws -> UserAnalyticsStats {
        let response: UserAnalyticsStats = try await client.request(
            Endpoints.Analytics.getUserStats(days: days)
        )
        stats = response
        return response
    }
    
    func getLearningInsights() async throws -> LearningInsights {
        let response: LearningInsights = try await client.request(
            Endpoints.Analytics.getLearningInsights
        )
        insights = response
        return response
    }
}

// MARK: - Storage Service
@MainActor
class StorageService: ObservableObject {
    private let client: NetworkClient
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var usage: StorageUsage?
    
    init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func getPresignedUrl(
        filename: String,
        contentType: String,
        folder: String = "uploads"
    ) async throws -> PresignedUrlResponse {
        return try await client.request(
            Endpoints.Storage.getPresignedUrl(
                filename: filename,
                contentType: contentType,
                folder: folder
            )
        )
    }
    
    func uploadAvatar(imageData: Data) async throws -> FileUploadResponse {
        // This would use multipart form data upload
        // For now, return a placeholder
        isUploading = true
        defer { isUploading = false }
        
        // Get presigned URL
        let presigned = try await getPresignedUrl(
            filename: "avatar_\(UUID().uuidString).jpg",
            contentType: "image/jpeg",
            folder: "avatars"
        )
        
        guard let uploadUrl = presigned.uploadUrl, let url = URL(string: uploadUrl) else {
            throw LyoError.serverError("Failed to get upload URL")
        }
        
        // Upload to the presigned URL using NetworkClient
        try await client.uploadBinary(
            url: url,
            data: imageData,
            contentType: "image/jpeg"
        )
        
        return FileUploadResponse(
            success: true,
            filename: presigned.blobName ?? "unknown",
            originalFilename: "avatar.jpg",
            publicUrl: presigned.publicUrl ?? "",
            size: imageData.count,
            contentType: "image/jpeg",
            message: "Avatar uploaded successfully"
        )
    }
    
    func deleteAvatar() async throws {
        let _: EmptyResponse = try await client.request(Endpoints.Storage.deleteAvatar)
    }
    
    func getUsage() async throws -> StorageUsage {
        let response: StorageUsage = try await client.request(Endpoints.Storage.getUsage)
        usage = response
        return response
    }
    
    func deleteFile(blobName: String) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Storage.deleteFile(blobName: blobName)
        )
    }
}

// MARK: - Notifications Service
@MainActor
class NotificationsService: ObservableObject {
    private let client: NetworkClient
    
    @Published var notifications: [APIAppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    
    init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func fetchNotifications(
        unreadOnly: Bool = false,
        category: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [APIAppNotification] {
        isLoading = true
        defer { isLoading = false }
        
        let response: NotificationListResponse = try await client.request(
            Endpoints.Notifications.getNotifications(
                unreadOnly: unreadOnly,
                category: category,
                limit: limit,
                offset: offset
            )
        )
        
        if offset == 0 {
            notifications = response.notifications
        } else {
            notifications.append(contentsOf: response.notifications)
        }
        unreadCount = response.unreadCount
        
        return response.notifications
    }
    
    func getUnreadCount() async throws -> Int {
        let response: UnreadCountResponse = try await client.request(
            Endpoints.Notifications.getUnreadCount
        )
        unreadCount = response.unreadCount
        return response.unreadCount
    }
    
    func markAsRead(notificationId: Int) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Notifications.markRead(notificationId: notificationId)
        )
        
        if notifications.contains(where: { $0.id == notificationId }) {
            // Create updated notification with isRead = true
            // Note: AppNotification is immutable, so we'd need to reload
            await MainActor.run {
                unreadCount = max(0, unreadCount - 1)
            }
        }
    }
    
    func markAllAsRead(category: String? = nil) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Notifications.markAllRead(category: category)
        )
        unreadCount = 0
    }
    
    func deleteNotification(notificationId: Int, archive: Bool = false) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Notifications.deleteNotification(
                notificationId: notificationId,
                archive: archive
            )
        )
        notifications.removeAll { $0.id == notificationId }
    }
}

// MARK: - Search Service
@MainActor
class SearchService: ObservableObject {
    private let client: NetworkClient
    
    @Published var suggestions: [AutocompleteSuggestion] = []
    @Published var trending: [String] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    
    init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func autocomplete(query: String, limit: Int = 10) async throws -> [AutocompleteSuggestion] {
        guard query.count >= 2 else { return [] }
        
        let response: AutocompleteResponse = try await client.request(
            Endpoints.Search.autocomplete(query: query, limit: limit)
        )
        suggestions = response.suggestions
        return response.suggestions
    }
    
    func search(
        query: String,
        type: String = "all",
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> SearchResponse {
        isSearching = true
        defer { isSearching = false }
        
        return try await client.request(
            Endpoints.Search.search(query: query, type: type, limit: limit, offset: offset)
        )
    }
    
    func searchUsers(query: String, limit: Int = 20, offset: Int = 0) async throws -> SearchResponse {
        isSearching = true
        defer { isSearching = false }
        
        return try await client.request(
            Endpoints.Search.searchUsers(query: query, limit: limit, offset: offset)
        )
    }
    
    func getTrending(limit: Int = 10) async throws -> [String] {
        let response: TrendingResponse = try await client.request(
            Endpoints.Search.getTrending(limit: limit)
        )
        trending = response.trending
        return response.trending
    }
    
    func getRecentSearches(limit: Int = 10) async throws -> [String] {
        let response: RecentSearchesResponse = try await client.request(
            Endpoints.Search.getRecentSearches(limit: limit)
        )
        recentSearches = response.searches
        return response.searches
    }
    
    func clearRecentSearches() async throws {
        let _: EmptyResponse = try await client.request(Endpoints.Search.clearRecentSearches)
        recentSearches = []
    }
}

// MARK: - Messaging Service
@MainActor
class MessagingService: ObservableObject {
    static let shared = MessagingService()
    
    private let client: NetworkClient
    
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var messages: [Message] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    
    init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func fetchConversations(limit: Int = 20, offset: Int = 0) async throws -> [Conversation] {
        isLoading = true
        defer { isLoading = false }
        
        let response: ConversationsResponse = try await client.request(
            Endpoints.Messaging.getConversations(limit: limit, offset: offset)
        )
        
        if offset == 0 {
            conversations = response.conversations
        } else {
            conversations.append(contentsOf: response.conversations)
        }
        
        return response.conversations
    }
    
    func getConversation(conversationId: String) async throws -> Conversation {
        let response: Conversation = try await client.request(
            Endpoints.Messaging.getConversation(conversationId: conversationId)
        )
        currentConversation = response
        return response
    }
    
    func fetchMessages(
        conversationId: String,
        limit: Int = 50,
        before: String? = nil
    ) async throws -> [Message] {
        let response: MessagesResponse = try await client.request(
            Endpoints.Messaging.getMessages(
                conversationId: conversationId,
                limit: limit,
                before: before
            )
        )
        
        if before == nil {
            messages = response.messages
        } else {
            messages.insert(contentsOf: response.messages, at: 0)
        }
        
        return response.messages
    }
    
    func sendMessage(
        conversationId: String,
        content: String,
        mediaUrl: String? = nil,
        mediaType: String? = nil,
        replyToId: String? = nil
    ) async throws -> Message {
        let response: Message = try await client.request(
            Endpoints.Messaging.sendMessage(
                conversationId: conversationId,
                content: content,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
                replyToId: replyToId
            )
        )
        messages.append(response)
        return response
    }
    
    func createConversation(
        participantIds: [Int],
        name: String? = nil,
        isGroup: Bool = false
    ) async throws -> Conversation {
        let response: Conversation = try await client.request(
            Endpoints.Messaging.createConversation(
                participantIds: participantIds,
                name: name,
                isGroup: isGroup
            )
        )
        conversations.insert(response, at: 0)
        return response
    }
    
    func markAsRead(conversationId: String, messageId: String) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Messaging.markRead(conversationId: conversationId, messageId: messageId)
        )
    }
    
    func addReaction(conversationId: String, messageId: String, emoji: String) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Messaging.addReaction(
                conversationId: conversationId,
                messageId: messageId,
                emoji: emoji
            )
        )
    }
    
    func getUnreadCount() async throws -> Int {
        let response: MessagingUnreadCountResponse = try await client.request(
            Endpoints.Messaging.getUnreadCount
        )
        unreadCount = response.unreadCount
        return response.unreadCount
    }
    
    func leaveConversation(conversationId: String) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Messaging.leaveConversation(conversationId: conversationId)
        )
        conversations.removeAll { $0.id == conversationId }
    }
}

// MARK: - Social Service
@MainActor
class SocialService: ObservableObject {
    private let client: NetworkClient
    
    @Published var feed: [SocialPost] = []
    @Published var userPosts: [SocialPost] = []
    @Published var followers: [UserFollow] = []
    @Published var following: [UserFollow] = []
    @Published var isLoading = false
    @Published var hasMorePosts = true
    
    private var currentPage = 1
    
    init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func fetchFeed(page: Int = 1, perPage: Int = 20) async throws -> [SocialPost] {
        isLoading = true
        defer { isLoading = false }
        
        let response: FeedResponse = try await client.request(
            Endpoints.Social.getFeed(page: page, perPage: perPage)
        )
        
        if page == 1 {
            feed = response.posts
        } else {
            feed.append(contentsOf: response.posts)
        }
        
        currentPage = page
        hasMorePosts = response.hasNext
        
        return response.posts
    }
    
    func loadMorePosts() async throws {
        guard hasMorePosts, !isLoading else { return }
        _ = try await fetchFeed(page: currentPage + 1)
    }
    
    func createPost(
        content: String?,
        postType: String = "text",
        imageUrl: String? = nil,
        videoUrl: String? = nil,
        linkUrl: String? = nil,
        isPublic: Bool = true
    ) async throws -> SocialPost {
        let response: SocialPost = try await client.request(
            Endpoints.Social.createPost(
                content: content,
                postType: postType,
                imageUrl: imageUrl,
                videoUrl: videoUrl,
                linkUrl: linkUrl,
                isPublic: isPublic
            )
        )
        feed.insert(response, at: 0)
        return response
    }
    
    func getPost(postId: Int) async throws -> SocialPost {
        return try await client.request(Endpoints.Social.getPost(postId: postId))
    }
    
    func deletePost(postId: Int) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Social.deletePost(postId: postId)
        )
        feed.removeAll { $0.id == postId }
        userPosts.removeAll { $0.id == postId }
    }
    
    func reactToPost(postId: Int, reactionType: String) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Social.reactToPost(postId: postId, reactionType: reactionType)
        )
    }
    
    func removeReaction(postId: Int) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Social.removeReaction(postId: postId)
        )
    }
    
    func getComments(postId: Int, limit: Int = 20, offset: Int = 0) async throws -> [SocialComment] {
        let response: CommentsResponse = try await client.request(
            Endpoints.Social.getComments(postId: postId, limit: limit, offset: offset)
        )
        return response.comments
    }
    
    func addComment(postId: Int, content: String, parentId: Int? = nil) async throws -> SocialComment {
        return try await client.request(
            Endpoints.Social.addComment(postId: postId, content: content, parentId: parentId)
        )
    }
    
    func deleteComment(postId: Int, commentId: Int) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Social.deleteComment(postId: postId, commentId: commentId)
        )
    }
    
    func followUser(userId: Int) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Social.followUser(userId: userId)
        )
    }
    
    func unfollowUser(userId: Int) async throws {
        let _: EmptyResponse = try await client.request(
            Endpoints.Social.unfollowUser(userId: userId)
        )
    }
    
    func getFollowers(userId: Int, limit: Int = 20, offset: Int = 0) async throws -> FollowListResponse {
        return try await client.request(
            Endpoints.Social.getFollowers(userId: userId, limit: limit, offset: offset)
        )
    }
    
    func getFollowing(userId: Int, limit: Int = 20, offset: Int = 0) async throws -> FollowListResponse {
        return try await client.request(
            Endpoints.Social.getFollowing(userId: userId, limit: limit, offset: offset)
        )
    }
    
    func getUserStats(userId: Int) async throws -> UserSocialStats {
        return try await client.request(
            Endpoints.Social.getUserStats(userId: userId)
        )
    }
}

// MARK: - Response Types for Services
struct DevicesResponse: Codable {
    let devices: [PushDevice]
}

struct RecentSearchesResponse: Codable {
    let searches: [String]
}

struct ConversationsResponse: Codable {
    let conversations: [Conversation]
    let total: Int?
}

struct MessagesResponse: Codable {
    let messages: [Message]
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case hasMore = "has_more"
    }
}

struct MessagingUnreadCountResponse: Codable {
    let unreadCount: Int
    
    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}

struct CommentsResponse: Codable {
    let comments: [SocialComment]
    let total: Int?
}

struct FollowListResponse: Codable {
    let users: [FollowUser]
    let total: Int
}

struct FollowUser: Codable, Identifiable {
    let id: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let isFollowing: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, username
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case isFollowing = "is_following"
    }
}

struct EnergyResponse: Codable {
    let energy: Int
    let maxEnergy: Int
    let nextRegenTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case energy
        case maxEnergy = "max_energy"
        case nextRegenTime = "next_regen_time"
    }
}
