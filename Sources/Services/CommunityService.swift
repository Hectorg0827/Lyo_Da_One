//
//  CommunityService.swift
//  Lyo
//
//  Service layer for Community Feed operations with caching and moderation
//

import Foundation
import os

struct FeedFilters: Encodable {
    let postType: String?
    let tags: [String]?
    let sortBy: String

    init(postType: String? = nil, tags: [String]? = nil, sortBy: String = "recent") {
        self.postType = postType
        self.tags = tags
        self.sortBy = sortBy
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let postType = postType {
            items.append(URLQueryItem(name: "post_type", value: postType))
        }
        if let tags = tags, !tags.isEmpty {
            items.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }
        items.append(URLQueryItem(name: "sort_by", value: sortBy))
        return items
    }
}

/// Service for Community Feed API operations
@MainActor
final class CommunityService {
    
    static let shared = CommunityService()
    
    // MARK: - Private Properties
    
    private var blockedUserIds: Set<String> = []
    private var postsCache: [String: CommunityPost] = [:]
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute
    
    private init() {
        Task {
            await loadBlockedUsers()
        }
    }
    
    // MARK: - Posts CRUD
    
    /// Fetch paginated posts with filters
    func fetchPosts(
        page: Int = 1,
        limit: Int = 20,
        filters: CommunityFeedFilters = CommunityFeedFilters()
    ) async throws -> CommunityPaginatedResponse<CommunityPost> {
        let feedFilters = FeedFilters(
            postType: filters.postType?.rawValue,
            tags: filters.tags,
            sortBy: filters.sortBy.rawValue
        )
        
        let endpoint = Endpoints.CommunityFeed.getPosts(page: page, limit: limit, filters: feedFilters)
        let response: CommunityPaginatedResponse<CommunityPost> = try await NetworkClient.shared.request(endpoint)
        
        // Filter out blocked users and cache posts
        let filteredItems = response.items.filter { !blockedUserIds.contains($0.authorId) }
        filteredItems.forEach { postsCache[$0.id] = $0 }
        lastFetchTime = Date()
        
        return CommunityPaginatedResponse(
            items: filteredItems,
            page: response.page,
            limit: response.limit,
            totalCount: response.totalCount,
            totalPages: response.totalPages
        )
    }
    
    /// Create a new post
    func createPost(_ request: CommunityCreatePostRequest) async throws -> CommunityPost {
        let endpoint = Endpoints.CommunityFeed.createPost(request: request)
        let post: CommunityPost = try await NetworkClient.shared.request(endpoint)
        postsCache[post.id] = post
        return post
    }
    
    /// Get a single post by ID
    func getPost(id: String) async throws -> CommunityPost {
        // Check cache first
        if let cached = postsCache[id],
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            return cached
        }
        
        let endpoint = Endpoints.CommunityFeed.getPost(id: id)
        let post: CommunityPost = try await NetworkClient.shared.request(endpoint)
        postsCache[post.id] = post
        return post
    }
    
    /// Update a post
    func updatePost(id: String, request: CommunityUpdatePostRequest) async throws -> CommunityPost {
        let endpoint = Endpoints.CommunityFeed.updatePost(id: id, request: request)
        let post: CommunityPost = try await NetworkClient.shared.request(endpoint)
        postsCache[post.id] = post
        return post
    }
    
    /// Delete a post
    func deletePost(id: String) async throws {
        let endpoint = Endpoints.CommunityFeed.deletePost(id: id)
        try await NetworkClient.shared.requestVoid(endpoint)
        postsCache.removeValue(forKey: id)
    }
    
    // MARK: - Likes & Bookmarks
    
    /// Toggle like on a post (optimistic update)
    func toggleLike(postId: String) async throws -> CommunityLikeResponse {
        // Optimistic update
        if var post = postsCache[postId] {
            post.hasLiked.toggle()
            post.likeCount += post.hasLiked ? 1 : -1
            postsCache[postId] = post
        }
        
        do {
            let endpoint = Endpoints.CommunityFeed.likePost(id: postId)
            let response: CommunityLikeResponse = try await NetworkClient.shared.request(endpoint)
            
            // Sync with server response
            if var post = postsCache[postId] {
                post.hasLiked = response.liked
                post.likeCount = response.likeCount
                postsCache[postId] = post
            }
            
            return response
        } catch {
            // Revert optimistic update on failure
            if var post = postsCache[postId] {
                post.hasLiked.toggle()
                post.likeCount += post.hasLiked ? 1 : -1
                postsCache[postId] = post
            }
            throw error
        }
    }
    
    /// Toggle bookmark on a post
    func toggleBookmark(postId: String) async throws -> CommunityBookmarkResponse {
        // Optimistic update
        if var post = postsCache[postId] {
            post.hasBookmarked.toggle()
            postsCache[postId] = post
        }
        
        do {
            let endpoint = Endpoints.CommunityFeed.bookmarkPost(id: postId)
            let response: CommunityBookmarkResponse = try await NetworkClient.shared.request(endpoint)
            
            // Sync with server response
            if var post = postsCache[postId] {
                post.hasBookmarked = response.bookmarked
                postsCache[postId] = post
            }
            
            return response
        } catch {
            // Revert on failure
            if var post = postsCache[postId] {
                post.hasBookmarked.toggle()
                postsCache[postId] = post
            }
            throw error
        }
    }
    
    // MARK: - Comments
    
    /// Fetch comments for a post
    func fetchComments(
        postId: String,
        page: Int = 1,
        limit: Int = 20,
        parentId: String? = nil
    ) async throws -> CommunityPaginatedResponse<PostComment> {
        let endpoint = Endpoints.CommunityFeed.getComments(postId: postId, page: page, limit: limit)
        let response: CommunityPaginatedResponse<PostComment> = try await NetworkClient.shared.request(endpoint)
        
        // Filter out blocked users
        let filteredItems = response.items.filter { !blockedUserIds.contains($0.authorId) }
        
        return CommunityPaginatedResponse(
            items: filteredItems,
            page: response.page,
            limit: response.limit,
            totalCount: response.totalCount,
            totalPages: response.totalPages
        )
    }
    
    /// Create a comment
    func createComment(postId: String, request: CommunityCreateCommentRequest) async throws -> PostComment {
        let endpoint = Endpoints.CommunityFeed.createComment(postId: postId, request: request)
        let comment: PostComment = try await NetworkClient.shared.request(endpoint)
        
        // Update post comment count in cache
        if var post = postsCache[postId] {
            post.commentCount += 1
            postsCache[postId] = post
        }
        
        return comment
    }
    
    /// Delete a comment
    func deleteComment(postId: String, commentId: String) async throws {
        let endpoint = Endpoints.CommunityFeed.deleteComment(postId: postId, commentId: commentId)
        try await NetworkClient.shared.requestVoid(endpoint)
        
        // Update post comment count in cache
        if var post = postsCache[postId] {
            post.commentCount = max(0, post.commentCount - 1)
            postsCache[postId] = post
        }
    }
    
    /// Like a comment
    func likeComment(postId: String, commentId: String) async throws -> CommunityLikeResponse {
        let endpoint = Endpoints.CommunityFeed.likeComment(postId: postId, commentId: commentId)
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Moderation
    
    /// Report content
    func reportContent(_ request: CommunityReportRequest) async throws -> CommunityReportResponse {
        let endpoint = Endpoints.CommunityFeed.report(request: request)
        return try await NetworkClient.shared.request(endpoint)
    }
    
    /// Block a user
    func blockUser(userId: String, reason: String? = nil) async throws {
        let request = CommunityBlockUserRequest(userId: userId, reason: reason)
        let endpoint = Endpoints.CommunityFeed.blockUser(request: request)
        try await NetworkClient.shared.requestVoid(endpoint)
        
        blockedUserIds.insert(userId)
        
        // Remove blocked user's posts from cache
        postsCache = postsCache.filter { $0.value.authorId != userId }
    }
    
    /// Unblock a user
    func unblockUser(userId: String) async throws {
        let endpoint = Endpoints.CommunityFeed.unblockUser(userId: userId)
        try await NetworkClient.shared.requestVoid(endpoint)
        blockedUserIds.remove(userId)
    }
    
    /// Get list of blocked users
    func getBlockedUsers() async throws -> [CommunityBlockedUser] {
        let endpoint = Endpoints.CommunityFeed.getBlockedUsers
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Cache Management
    
    /// Clear all caches
    func clearCache() {
        postsCache.removeAll()
        lastFetchTime = nil
    }
    
    /// Get cached post
    func getCachedPost(id: String) -> CommunityPost? {
        postsCache[id]
    }
    
    /// Update cached post
    func updateCachedPost(_ post: CommunityPost) {
        postsCache[post.id] = post
    }
    
    // MARK: - Private Helpers
    
    private func loadBlockedUsers() async {
        do {
            let blocked = try await getBlockedUsers()
            blockedUserIds = Set(blocked.map { $0.userId })
            Log.social.info("📛 Loaded \(self.blockedUserIds.count) blocked users")
        } catch {
            Log.social.warning("Failed to load blocked users: \(error.localizedDescription)")
        }
    }
    
    /// Check if a user is blocked
    func isUserBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }
}

// MARK: - NetworkClient Extensions for void responses

extension NetworkClient {
    /// Make a request that returns no body (204 No Content)
    /// Routes through the standard NetworkClient pipeline for proper SaaS headers
    func requestVoid<E: Endpoint>(_ endpoint: E) async throws {
        // Use the standard request pipeline with EmptyResponse to get headers injected
        let _: EmptyResponse = try await self.request(endpoint)
    }
}
