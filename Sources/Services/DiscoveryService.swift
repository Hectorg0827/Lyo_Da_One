import SwiftUI
import Combine

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
        Task {
            await loadMyDiscoveries()
            await loadSavedDiscoveries()
        }
    }
    
    // MARK: - Load Discoveries
    
    func loadMyDiscoveries() async {
        isLoading = true
        error = nil
        
        do {
            myDiscoveries = try await apiClient.fetchMyDiscoveries()
            print("✅ Loaded \(myDiscoveries.count) my discoveries from backend")
        } catch {
            print("❌ Failed to load my discoveries: \(error.localizedDescription)")
            self.error = error.localizedDescription
            // Fallback to mock data only if explicitly allowed
            if AppConfig.allowMockFallbacks {
                print("⚠️ Using mock discoveries as fallback (AppConfig.allowMockFallbacks = true)")
                loadMockDiscoveries()
            } else {
                 self.error = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    func loadSavedDiscoveries() async {
        do {
            savedDiscoveries = try await apiClient.fetchSavedDiscoveries()
            print("✅ Loaded \(savedDiscoveries.count) saved discoveries from backend")
        } catch {
            print("❌ Failed to load saved discoveries: \(error.localizedDescription)")
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
            
            print("✅ Discovery created: \(title)")
        } catch {
            print("❌ Failed to create discovery: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Save/Unsave Discovery
    
    func saveDiscovery(discoveryId: String) async throws {
        do {
            try await apiClient.saveDiscovery(discoveryId: discoveryId)
            await loadSavedDiscoveries()
            print("✅ Discovery saved")
        } catch {
            print("❌ Failed to save discovery: \(error.localizedDescription)")
            throw error
        }
    }
    
    func unsaveDiscovery(discoveryId: String) async throws {
        do {
            try await apiClient.unsaveDiscovery(discoveryId: discoveryId)
            savedDiscoveries.removeAll { $0.id == discoveryId }
            print("✅ Discovery unsaved")
        } catch {
            print("❌ Failed to unsave discovery: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Upload Media
    
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
                id: UUID().uuidString,
                userId: "currentUser",
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
                id: UUID().uuidString,
                userId: "currentUser",
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
                id: UUID().uuidString,
                userId: "currentUser",
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
                id: UUID().uuidString,
                userId: "otherUser",
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
                id: UUID().uuidString,
                userId: "otherUser2",
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

