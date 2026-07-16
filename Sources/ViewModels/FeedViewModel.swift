import Foundation
import SwiftUI
import Combine

// MARK: - Feed ViewModel
@MainActor
class FeedViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var posts: [RepoPost] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: LyoError?
    @Published var hasMore = true

    @Published var selectedAlgorithm: FeedAlgorithm = .forYou
    @Published var newPostContent = ""
    @Published var showingNewPostSheet = false

    // MARK: - Dependencies

    private let repository: SocialRepository
    private var cancellables = Set<AnyCancellable>()

    private var currentPage = 1
    private let pageLimit = 20

    // MARK: - Init

    init(repository: SocialRepository = DefaultSocialRepository()) {
        self.repository = repository
    }

    // MARK: - Feed Loading

    func loadFeed(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
            isLoading = true
        } else {
            isLoadingMore = true
        }

        error = nil

        do {
            let response = try await repository.getPosts(
                page: currentPage,
                limit: pageLimit,
                algorithm: selectedAlgorithm.rawValue
            )

            if refresh {
                posts = response.posts
            } else {
                posts.append(contentsOf: response.posts)
            }

            hasMore = response.hasMore
            currentPage = response.nextPage ?? currentPage + 1

        } catch {
            handleError(error)
        }

        isLoading = false
        isLoadingMore = false
    }

    func loadMore() async {
        guard !isLoadingMore && hasMore else { return }
        await loadFeed(refresh: false)
    }

    func refresh() async {
        await loadFeed(refresh: true)
    }

    // MARK: - Algorithm Selection

    func selectAlgorithm(_ algorithm: FeedAlgorithm) {
        guard algorithm != selectedAlgorithm else { return }
        selectedAlgorithm = algorithm
        Task {
            await refresh()
        }
    }

    // MARK: - Post Creation

    func createPost() async {
        guard !newPostContent.isEmpty else { return }

        isLoading = true
        error = nil

        do {
            let post = try await repository.createPost(content: newPostContent, attachments: nil)
            posts.insert(post, at: 0)
            newPostContent = ""
            showingNewPostSheet = false
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func deletePost(_ post: RepoPost) async {
        do {
            try await repository.deletePost(postId: post.id)
            posts.removeAll { $0.id == post.id }
        } catch {
            handleError(error)
        }
    }

    // MARK: - Post Interactions

    func likePost(_ post: RepoPost) async {
        // Optimistic update
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            var updatedPost = posts[index]
            updatedPost.isLiked.toggle()
            updatedPost.likes += updatedPost.isLiked ? 1 : -1
            posts[index] = updatedPost
        }

        do {
            try await repository.likePost(postId: post.id)
        } catch {
            // Revert on error
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                var updatedPost = posts[index]
                updatedPost.isLiked.toggle()
                updatedPost.likes += updatedPost.isLiked ? 1 : -1
                posts[index] = updatedPost
            }
            handleError(error)
        }
    }

    func commentOnPost(_ post: RepoPost, content: String) async {
        guard !content.isEmpty else { return }

        do {
            let _ = try await repository.commentOnPost(postId: post.id, content: content)

            // Update comment count
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                var updatedPost = posts[index]
                updatedPost.comments += 1
                posts[index] = updatedPost
            }

        } catch {
            handleError(error)
        }
    }

    func loadComments(for post: RepoPost) async -> [Comment] {
        do {
            return try await repository.getComments(postId: post.id)
        } catch {
            handleError(error)
            return []
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let lyoError = error as? LyoError {
            self.error = lyoError
        } else {
            self.error = .network(.serverError(500))
        }
    }

    // MARK: - Computed Properties

    var availableAlgorithms: [FeedAlgorithm] {
        return [.forYou, .following, .trending, .recent]
    }

    var isEmpty: Bool {
        posts.isEmpty && !isLoading
    }
}

// MARK: - Feed Algorithm
enum FeedAlgorithm: String, CaseIterable, Identifiable {
    case forYou = "for_you"
    case following
    case trending
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forYou: return "For You"
        case .following: return "Following"
        case .trending: return "Trending"
        case .recent: return "Recent"
        }
    }

    var icon: String {
        switch self {
        case .forYou: return "sparkles"
        case .following: return "person.2"
        case .trending: return "flame"
        case .recent: return "clock"
        }
    }
}
