import Foundation

// MARK: - Default Social Repository
/// Thin façade over `LyoRepository`, which carries the live `SocialRepository`
/// implementation backed by the real `/api/v1/feed` and `/api/v1/posts` endpoints.
/// Previously these methods threw `.notImplemented`, which crashed the live feed
/// (FocusView / FeedView) on any create/like/comment action.
class DefaultSocialRepository: SocialRepository {

    private let backend: SocialRepository

    init(backend: SocialRepository = LyoRepository.shared) {
        self.backend = backend
    }

    // MARK: - Posts

    func getPosts(page: Int = 1, limit: Int = 20, algorithm: String? = nil) async throws -> RepoFeedResponse {
        try await backend.getPosts(page: page, limit: limit, algorithm: algorithm)
    }

    func createPost(content: String, attachments: [String]? = nil) async throws -> RepoPost {
        try await backend.createPost(content: content, attachments: attachments)
    }

    func getPost(postId: String) async throws -> RepoPost {
        try await backend.getPost(postId: postId)
    }

    func deletePost(postId: String) async throws {
        try await backend.deletePost(postId: postId)
    }

    // MARK: - Interactions

    func likePost(postId: String) async throws {
        try await backend.likePost(postId: postId)
    }

    func commentOnPost(postId: String, content: String) async throws -> Comment {
        try await backend.commentOnPost(postId: postId, content: content)
    }

    func getComments(postId: String) async throws -> [Comment] {
        try await backend.getComments(postId: postId)
    }
}

// MARK: - Mock Social Repository
class MockSocialRepository: SocialRepository {

    private var posts: [RepoPost] = []

    init() {
        // Generate mock posts
        let mockUser = UserDTO(
            id: "user1",
            name: "John Doe",
            email: "john@example.com",
            avatarURL: nil,
            level: 5,
            xp: 2500
        )

        posts = [
            RepoPost(
                id: "1",
                content: "Just completed my first Python course! 🎉",
                author: mockUser,
                attachments: nil,
                likes: 42,
                comments: 5,
                isLiked: false,
                createdAt: Date(),
                postType: "text"
            ),
            RepoPost(
                id: "2",
                content: "Anyone studying for calculus exam next week?",
                author: mockUser,
                attachments: nil,
                likes: 18,
                comments: 12,
                isLiked: true,
                createdAt: Date().addingTimeInterval(-3600),
                postType: "text"
            )
        ]
    }

    func getPosts(page: Int, limit: Int, algorithm: String?) async throws -> RepoFeedResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        return RepoFeedResponse(
            posts: Array(posts.prefix(limit)),
            nextPage: page + 1,
            hasMore: false
        )
    }

    func createPost(content: String, attachments: [String]?) async throws -> RepoPost {
        try await Task.sleep(nanoseconds: 300_000_000)

        let mockUser = UserDTO(
            id: "user1",
            name: "Current User",
            email: "user@example.com",
            avatarURL: nil,
            level: 5,
            xp: 2500
        )

        let post = RepoPost(
            id: UUID().uuidString,
            content: content,
            author: mockUser,
            attachments: attachments,
            likes: 0,
            comments: 0,
            isLiked: false,
            createdAt: Date(),
            postType: "text"
        )

        posts.insert(post, at: 0)
        return post
    }

    func getPost(postId: String) async throws -> RepoPost {
        try await Task.sleep(nanoseconds: 200_000_000)

        if let post = posts.first(where: { $0.id == postId }) {
            return post
        }

        throw LyoError.network(.notFound)
    }

    func deletePost(postId: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        posts.removeAll { $0.id == postId }
    }

    func likePost(postId: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        // Mock implementation
    }

    func commentOnPost(postId: String, content: String) async throws -> Comment {
        try await Task.sleep(nanoseconds: 300_000_000)

        let mockUser = UserDTO(
            id: "user1",
            name: "Current User",
            email: "user@example.com",
            avatarURL: nil,
            level: 5,
            xp: 2500
        )

        return Comment(
            id: UUID().uuidString,
            postId: postId,
            author: mockUser,
            content: content,
            likes: 0,
            createdAt: Date()
        )
    }

    func getComments(postId: String) async throws -> [Comment] {
        try await Task.sleep(nanoseconds: 300_000_000)

        let mockUser = UserDTO(
            id: "user2",
            name: "Jane Smith",
            email: "jane@example.com",
            avatarURL: nil,
            level: 8,
            xp: 5000
        )

        return [
            Comment(
                id: "1",
                postId: postId,
                author: mockUser,
                content: "Great work! Keep it up! 👏",
                likes: 3,
                createdAt: Date()
            )
        ]
    }
}
