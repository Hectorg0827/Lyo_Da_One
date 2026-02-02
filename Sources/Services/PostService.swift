import SwiftUI
import Combine

// MARK: - Post Service
@MainActor
class PostService: ObservableObject {
    static let shared = PostService()
    
    @Published var postsFeed: [Post] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let apiClient = LyoAPIClient.shared
    private let cloudStorage = CloudStorageService.shared
    
    private var currentOffset = 0
    private let pageSize = 20
    
    private init() {
        Task {
            await loadPostsFeed()
        }
    }
    
    // MARK: - Load Posts
    
    func loadPostsFeed(refresh: Bool = false) async {
        if refresh {
            currentOffset = 0
            postsFeed = []
        }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await apiClient.fetchPostsFeed(limit: pageSize, offset: currentOffset)
            
            if refresh {
                postsFeed = response.posts
            } else {
                postsFeed.append(contentsOf: response.posts)
            }
            
            currentOffset += response.posts.count
            
            print("✅ Loaded \(response.posts.count) posts from backend")
        } catch {
            print("❌ Failed to load posts: \(error.localizedDescription)")
            self.error = error.localizedDescription
            
            // Fallback to mock data only if explicitly allowed and on first load
            if postsFeed.isEmpty && AppConfig.allowMockFallbacks {
                print("⚠️ Using mock posts as fallback (AppConfig.allowMockFallbacks = true)")
                loadMockPosts()
            } else if postsFeed.isEmpty {
                // Propagate error if mocks are not allowed
                self.error = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Create Post
    
    func createPost(content: String, mediaURLs: [String] = [], visibility: PostVisibility = .public) async throws {
        isLoading = true
        error = nil
        
        do {
            let request = CreatePostRequest(
                content: content,
                mediaURLs: mediaURLs,
                visibility: visibility
            )
            
            let newPost = try await apiClient.createPost(request)
            
            // Insert at the beginning of the feed
            postsFeed.insert(newPost, at: 0)
            
            print("✅ Post created successfully")
        } catch {
            print("❌ Failed to create post: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Delete Post
    
    func deletePost(postId: String) async throws {
        do {
            try await apiClient.deletePost(postId: postId)
            
            // Remove from local state
            postsFeed.removeAll { $0.id == postId }
            
            print("✅ Post deleted successfully")
        } catch {
            print("❌ Failed to delete post: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Like/Unlike Post
    
    func likePost(postId: String) async {
        // Optimistically update local state
        if let index = postsFeed.firstIndex(where: { $0.id == postId }) {
            let updatedPost = postsFeed[index]
            // Note: This assumes Post has a way to update likes, may need to adjust based on model
            postsFeed[index] = updatedPost
        }
        
        do {
            try await apiClient.likePost(postId: postId)
        } catch {
            print("❌ Failed to like post: \(error.localizedDescription)")
        }
    }
    
    func unlikePost(postId: String) async {
        // Optimistically update local state
        if let index = postsFeed.firstIndex(where: { $0.id == postId }) {
            let updatedPost = postsFeed[index]
            postsFeed[index] = updatedPost
        }
        
        do {
            try await apiClient.unlikePost(postId: postId)
        } catch {
            print("❌ Failed to unlike post: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Upload Media
    
    func uploadPostMedia(imageURL: URL) async throws -> String {
        let data = try Data(contentsOf: imageURL)
        let filename = "\(UUID().uuidString).jpg"
        let result = try await cloudStorage.uploadFile(
            data: data,
            filename: filename,
            contentType: "image/jpeg",
            folder: "posts"
        )
        guard let publicURL = result.publicURL else { throw CloudStorageError.uploadFailed }
        return publicURL
    }
    
    func uploadPostVideo(videoURL: URL) async throws -> String {
        let data = try Data(contentsOf: videoURL)
        let filename = "\(UUID().uuidString).mp4"
        let result = try await cloudStorage.uploadFile(
            data: data,
            filename: filename,
            contentType: "video/mp4",
            folder: "posts"
        )
        guard let publicURL = result.publicURL else { throw CloudStorageError.uploadFailed }
        return publicURL
    }
    
    // MARK: - Mock Data (Fallback)
    
    private func loadMockPosts() {
        self.postsFeed = [
            Post(
                id: UUID().uuidString,
                userId: "user1",
                userName: "Alice",
                userAvatar: nil,
                content: "Just finished my calculus exam! 📚✨",
                mediaURLs: [],
                likes: 42,
                comments: 5,
                shares: 2,
                isLiked: false,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            Post(
                id: UUID().uuidString,
                userId: "user2",
                userName: "Bob",
                userAvatar: nil,
                content: "Study group at the library tomorrow at 3pm. Who's in? 📖",
                mediaURLs: [],
                likes: 28,
                comments: 12,
                shares: 4,
                isLiked: false,
                createdAt: Date().addingTimeInterval(-7200)
            ),
            Post(
                id: UUID().uuidString,
                userId: "user3",
                userName: "Charlie",
                userAvatar: nil,
                content: "Pro tip: Use the Pomodoro technique for better focus! 🍅⏰",
                mediaURLs: [],
                likes: 156,
                comments: 24,
                shares: 38,
                isLiked: true,
                createdAt: Date().addingTimeInterval(-14400)
            )
        ]
    }
}
