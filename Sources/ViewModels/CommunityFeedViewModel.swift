//
//  CommunityFeedViewModel.swift
//  Lyo
//
//  ViewModel for the Community Feed with pagination, filtering, and moderation
//

import Foundation
import Combine
import SwiftUI
import os

@MainActor
final class CommunityFeedViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var posts: [CommunityPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: String?
    @Published private(set) var hasMorePages = true
    
    @Published var filters = CommunityFeedFilters()
    @Published var showCreatePost = false
    @Published var showFilters = false
    @Published var showReportSheet = false
    @Published var selectedPostForAction: CommunityPost?
    
    // Toast notifications
    @Published var toastMessage: String?
    @Published var toastType: ToastType = .success
    
    enum ToastType {
        case success, error, info
    }
    
    // MARK: - Private Properties
    
    private let service: CommunityService
    private var currentPage = 1
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(service: CommunityService) {
        self.service = service
        setupBindings()
    }
    
    convenience init() {
        self.init(service: .shared)
    }
    
    private func setupBindings() {
        // Reload when filters change
        $filters
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Initial data load
    func loadInitialData() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        currentPage = 1
        
        do {
            let response = try await service.fetchPosts(
                page: currentPage,
                limit: pageSize,
                filters: filters
            )
            
            posts = response.items
            hasMorePages = response.hasNextPage
            Log.social.info("Loaded \(self.posts.count) posts (page \(self.currentPage))")
        } catch {
            self.error = error.localizedDescription
            Log.social.error("Failed to load posts: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refresh feed (pull-to-refresh)
    func refresh() async {
        currentPage = 1
        hasMorePages = true
        
        do {
            let response = try await service.fetchPosts(
                page: currentPage,
                limit: pageSize,
                filters: filters
            )
            
            posts = response.items
            hasMorePages = response.hasNextPage
            error = nil
            Log.social.info("Refreshed feed - \(self.posts.count) posts")
        } catch {
            self.error = error.localizedDescription
            showToast("Failed to refresh", type: .error)
        }
    }
    
    /// Load more posts (infinite scroll)
    func loadMoreIfNeeded(currentPost: CommunityPost) async {
        // Trigger load when reaching last 3 items
        guard let index = posts.firstIndex(where: { $0.id == currentPost.id }),
              index >= posts.count - 3,
              hasMorePages,
              !isLoadingMore else {
            return
        }
        
        await loadMore()
    }
    
    private func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let response = try await service.fetchPosts(
                page: currentPage,
                limit: pageSize,
                filters: filters
            )
            
            // Deduplicate
            let existingIds = Set(posts.map { $0.id })
            let newPosts = response.items.filter { !existingIds.contains($0.id) }
            
            posts.append(contentsOf: newPosts)
            hasMorePages = response.hasNextPage
            Log.social.info("Loaded \(newPosts.count) more posts (page \(self.currentPage))")
        } catch {
            currentPage -= 1 // Revert page increment on failure
            Log.social.error("Failed to load more: \(error)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Post Actions
    
    /// Toggle like on a post
    func toggleLike(post: CommunityPost) {
        // Optimistic update
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].hasLiked.toggle()
            posts[index].likeCount += posts[index].hasLiked ? 1 : -1
        }
        
        Task {
            do {
                let response = try await service.toggleLike(postId: post.id)
                
                // Sync with server
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].hasLiked = response.liked
                    posts[index].likeCount = response.likeCount
                }
            } catch {
                // Revert on failure
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].hasLiked.toggle()
                    posts[index].likeCount += posts[index].hasLiked ? 1 : -1
                }
                showToast("Failed to like post", type: .error)
            }
        }
    }
    
    /// Toggle bookmark on a post
    func toggleBookmark(post: CommunityPost) {
        // Optimistic update
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].hasBookmarked.toggle()
        }
        
        Task {
            do {
                let response = try await service.toggleBookmark(postId: post.id)
                
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].hasBookmarked = response.bookmarked
                }
                
                showToast(response.bookmarked ? "Bookmarked" : "Removed bookmark", type: .success)
            } catch {
                // Revert on failure
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].hasBookmarked.toggle()
                }
                showToast("Failed to bookmark", type: .error)
            }
        }
    }
    
    /// Create a new post
    func createPost(
        content: String,
        mediaURLs: [String] = [],
        tags: [String] = [],
        postType: CommunityPostType = .text,
        visibility: CommunityPostVisibility = .publicPost
    ) async throws {
        let request = CommunityCreatePostRequest(
            content: content,
            mediaURLs: mediaURLs.isEmpty ? nil : mediaURLs,
            tags: tags.isEmpty ? nil : tags,
            postType: postType,
            visibility: visibility
        )
        
        do {
            let newPost = try await service.createPost(request)
            posts.insert(newPost, at: 0)
            showCreatePost = false
            showToast("Post created!", type: .success)
        } catch {
            showToast("Failed to create post", type: .error)
            throw error
        }
    }
    
    /// Delete a post
    func deletePost(_ post: CommunityPost) {
        Task {
            do {
                try await service.deletePost(id: post.id)
                posts.removeAll { $0.id == post.id }
                showToast("Post deleted", type: .success)
            } catch {
                showToast("Failed to delete post", type: .error)
            }
        }
    }
    
    /// Report a post
    func reportPost(_ post: CommunityPost, reason: CommunityReportReason, description: String?) async {
        let request = CommunityReportRequest(
            targetType: .post,
            targetId: post.id,
            reason: reason,
            description: description
        )
        
        do {
            _ = try await service.reportContent(request)
            showToast("Report submitted", type: .success)
        } catch {
            showToast("Failed to submit report", type: .error)
        }
    }
    
    /// Block a user
    func blockUser(_ userId: String) async {
        do {
            try await service.blockUser(userId: userId)
            
            // Remove all posts from blocked user
            posts.removeAll { $0.authorId == userId }
            showToast("User blocked", type: .success)
        } catch {
            showToast("Failed to block user", type: .error)
        }
    }
    
    // MARK: - Helpers
    
    func showToast(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.toastMessage = nil
        }
    }
    
    func clearFilters() {
        filters = CommunityFeedFilters()
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension CommunityFeedViewModel {
    static var preview: CommunityFeedViewModel {
        let vm = CommunityFeedViewModel()
        vm.posts = [
            CommunityPost(
                id: "1",
                authorId: "user1",
                authorName: "Jane Doe",
                authorAvatar: nil,
                authorLevel: 5,
                content: "Just completed the AI/ML course! 🎉 Highly recommend it to anyone interested in machine learning.",
                mediaURLs: [],
                tags: ["ai", "machinelearning", "completed"],
                likeCount: 42,
                commentCount: 7,
                hasLiked: true,
                hasBookmarked: false,
                postType: .achievement,
                linkedCourseId: "course123",
                linkedGroupId: nil,
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-3600),
                isEdited: false,
                isPinned: false,
                visibility: .publicPost
            ),
            CommunityPost(
                id: "2",
                authorId: "user2",
                authorName: "John Smith",
                authorAvatar: nil,
                authorLevel: 3,
                content: "Can someone explain the difference between supervised and unsupervised learning?",
                mediaURLs: [],
                tags: ["question", "ai"],
                likeCount: 15,
                commentCount: 23,
                hasLiked: false,
                hasBookmarked: true,
                postType: .questionDiscussion,
                linkedCourseId: nil,
                linkedGroupId: nil,
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-7200),
                isEdited: false,
                isPinned: false,
                visibility: .publicPost
            )
        ]
        return vm
    }
}
#endif
