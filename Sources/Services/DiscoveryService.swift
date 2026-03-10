import SwiftUI
import Combine
import os

// MARK: - Discovery Service
@MainActor
class DiscoveryService: ObservableObject {
    static let shared = DiscoveryService()
    
    @Published var myDiscoveries: [Discovery] = []
    @Published var savedDiscoveries: [Discovery] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let apiClient = LyoAPIClient.shared
    private let cloudStorage = CloudStorageService.shared
    
    private init() {
        Task { [weak self] in
            await self?.loadMyDiscoveries()
            await self?.loadSavedDiscoveries()
        }
    }
    
    // MARK: - Load Discoveries
    
    func loadMyDiscoveries() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiClient.fetchMyDiscoveries()
            myDiscoveries = response.discoveries
            Log.discover.info("Loaded \(self.myDiscoveries.count) my discoveries from backend")
        } catch {
            Log.discover.error("Failed to load my discoveries: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadSavedDiscoveries() async {
        do {
            let response = try await apiClient.fetchSavedDiscoveries()
            savedDiscoveries = response.discoveries
            Log.discover.info("Loaded \(self.savedDiscoveries.count) saved discoveries from backend")
        } catch {
            Log.discover.error("Failed to load saved discoveries: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create Discovery
    
    func addDiscovery(title: String, description: String? = nil, videoURL: String, thumbnailURL: String? = nil) async throws {
        isLoading = true
        error = nil
        
        do {
            let request = CreateDiscoveryRequest(
                title: title,
                description: description,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL
            )
            
            let newDiscovery = try await apiClient.createDiscovery(request)
            
            // Update local state
            myDiscoveries.insert(newDiscovery, at: 0)
            
            Log.discover.info("Discovery created: \(title)")
        } catch {
            Log.discover.error("Failed to create discovery: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Save/Unsave Discovery
    
    func saveDiscovery(discoveryId: Int) async throws {
        do {
            try await apiClient.saveDiscovery(discoveryId: String(discoveryId))
            await loadSavedDiscoveries()
            Log.discover.info("Discovery saved")
        } catch {
            Log.discover.error("Failed to save discovery: \(error.localizedDescription)")
            throw error
        }
    }
    
    func unsaveDiscovery(discoveryId: Int) async throws {
        do {
            try await apiClient.unsaveDiscovery(discoveryId: String(discoveryId))
            savedDiscoveries.removeAll { $0.id == discoveryId }
            Log.discover.info("Discovery unsaved")
        } catch {
            Log.discover.error("Failed to unsave discovery: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Social Interactions
    
    func likeDiscovery(discoveryId: Int) async throws {
        // Assume discoveryId maps to a Post ID (backend might expect String or Int, request() handles both)
        try await apiClient.likePost(id: String(discoveryId))
        
        // Optimistically update local state if present
        if let index = myDiscoveries.firstIndex(where: { $0.id == discoveryId }) {
            var item = myDiscoveries[index]
            item.isLiked = true
            item.likes += 1
            myDiscoveries[index] = item
        }
        
        Log.discover.info("Discovery liked: \(discoveryId)")
    }
    
    func unlikeDiscovery(discoveryId: Int) async throws {
        try await apiClient.unlikePost(id: String(discoveryId))
        
        if let index = myDiscoveries.firstIndex(where: { $0.id == discoveryId }) {
            var item = myDiscoveries[index]
            item.isLiked = false
            item.likes = max(0, item.likes - 1)
            myDiscoveries[index] = item
        }
        
        Log.discover.info("Discovery unliked: \(discoveryId)")
    }
    
    func fetchComments(discoveryId: Int) async throws -> [Comment] {
        return try await apiClient.fetchComments(postId: String(discoveryId))
    }
    
    func postComment(discoveryId: Int, content: String) async throws -> Comment {
        let comment = try await apiClient.createComment(postId: String(discoveryId), content: content)
        Log.discover.info("Comment posted on: \(discoveryId)")
        return comment
    }
    
    func uploadDiscoveryVideo(videoURL: URL) async throws -> String {
        // Upload to cloud storage (presigned PUT)
        let filename = "\(UUID().uuidString).mp4"
        let data = try Data(contentsOf: videoURL)
        let result = try await cloudStorage.uploadFile(
            data: data,
            filename: filename,
            contentType: "video/mp4",
            folder: "discoveries"
        )
        guard let url = result.publicURL else { throw CloudStorageError.uploadFailed }
        return url
    }
    
    func uploadThumbnail(imageURL: URL) async throws -> String {
        // Upload to cloud storage (presigned PUT)
        let filename = "\(UUID().uuidString).jpg"
        let data = try Data(contentsOf: imageURL)
        let result = try await cloudStorage.uploadFile(
            data: data,
            filename: filename,
            contentType: "image/jpeg",
            folder: "discoveries/thumbs"
        )
        guard let url = result.publicURL else { throw CloudStorageError.uploadFailed }
        return url
    }
    
    // MARK: - Mock Data (Fallback)
    
    private func loadMockDiscoveries() {
        self.myDiscoveries = [
            Discovery(
                id: 1,
                userId: 1,
                userName: "You",
                title: "My First Reel",
                description: nil,
                thumbnailURL: nil,
                videoURL: nil,
                likes: 120,
                views: 500,
                isLiked: false,
                isSaved: false,
                createdAt: Date()
            ),
            Discovery(
                id: 2,
                userId: 1,
                userName: "You",
                title: "Physics Experiment",
                description: nil,
                thumbnailURL: nil,
                videoURL: nil,
                likes: 85,
                views: 300,
                isLiked: false,
                isSaved: false,
                createdAt: Date()
            ),
            Discovery(
                id: 3,
                userId: 1,
                userName: "You",
                title: "Campus Tour",
                description: nil,
                thumbnailURL: nil,
                videoURL: nil,
                likes: 200,
                views: 1200,
                isLiked: false,
                isSaved: false,
                createdAt: Date()
            )
        ]
        
        self.savedDiscoveries = [
            Discovery(
                id: 4,
                userId: 2,
                userName: "Jane",
                title: "Math Hacks",
                description: nil,
                thumbnailURL: nil,
                videoURL: nil,
                likes: 5000,
                views: 10000,
                isLiked: false,
                isSaved: true,
                createdAt: Date()
            ),
            Discovery(
                id: 5,
                userId: 3,
                userName: "Bob",
                title: "Study Tips",
                description: nil,
                thumbnailURL: nil,
                videoURL: nil,
                likes: 300,
                views: 800,
                isLiked: false,
                isSaved: true,
                createdAt: Date()
            )
        ]
    }
}

