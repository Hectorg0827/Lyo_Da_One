import SwiftUI
import Combine

// MARK: - Story Error
enum StoryError: LocalizedError {
    case uploadFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload story media"
        case .loadFailed:
            return "Failed to load stories"
        }
    }
}

// MARK: - Story Service
@MainActor
class StoryService: ObservableObject {
    static let shared = StoryService()
    
    @Published var stories: [Story] = []
    @Published var myStory: Story? = nil
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let apiClient = LyoAPIClient.shared
    private let cloudStorage = CloudStorageService.shared
    
    private init() {
        Task {
            await loadStories()
        }
    }
    
    // MARK: - Load Stories
    
    func loadStories() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiClient.fetchStories()
            stories = response.stories
            myStory = response.myStory
            print("✅ Loaded \(stories.count) stories from backend")
        } catch {
            print("❌ Failed to load stories: \(error.localizedDescription)")
            self.error = error.localizedDescription
            // Production: Do not fallback to mocks automatically to ensure we see backend issues
            // loadMockStories() 
        }
        
        isLoading = false
    }
    
    // MARK: - Create Story
    
    func addStory(mediaURL: String, mediaType: Story.MediaType = .video, caption: String? = nil, isLive: Bool = false) async throws {
        isLoading = true
        error = nil
        
        do {
            let request = CreateStoryRequest(
                mediaURL: mediaURL,
                mediaType: mediaType,
                isLive: isLive,
                caption: caption,
                linkedCourseId: nil,
                linkedGroupId: nil,
                tags: []
            )
            
            let newStory = try await apiClient.createStory(request)
            
            // Update local state
            myStory = newStory
            await loadStories() // Refresh all stories
            
            print("✅ Story created successfully")
        } catch {
            print("❌ Failed to create story: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Delete Story
    
    func deleteStory(storyId: String) async throws {
        do {
            try await apiClient.deleteStory(storyId: storyId)
            
            // Update local state
            if myStory?.id == storyId {
                myStory = nil
            }
            stories.removeAll { $0.id == storyId }
            
            print("✅ Story deleted successfully")
        } catch {
            print("❌ Failed to delete story: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Mark as Seen
    
    func markAsSeen(storyId: String) async {
        // Optimistically update local state
        if let index = stories.firstIndex(where: { $0.id == storyId }) {
            stories[index].isSeen = true
        }
        
        // Update backend
        do {
            try await apiClient.markStorySeen(storyId: storyId)
        } catch {
            print("❌ Failed to mark story as seen: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Upload Media
    
    func uploadStoryMedia(videoURL: URL) async throws -> String {
        // Upload to cloud storage
        let filename = "\(UUID().uuidString).mp4"
        let data = try Data(contentsOf: videoURL)
        let result = try await cloudStorage.uploadFile(
            data: data,
            filename: filename,
            contentType: "video/mp4",
            folder: "stories"
        )
        guard let publicURL = result.publicURL else {
            throw StoryError.uploadFailed
        }
        return publicURL
    }
    
    func uploadStoryMedia(imageURL: URL) async throws -> String {
        // Upload image to cloud storage
        let filename = "\(UUID().uuidString).jpg"
        let data = try Data(contentsOf: imageURL)
        let result = try await cloudStorage.uploadFile(
            data: data,
            filename: filename,
            contentType: "image/jpeg",
            folder: "stories"
        )
        guard let publicURL = result.publicURL else {
            throw StoryError.uploadFailed
        }
        return publicURL
    }
    
    func uploadStoryMedia(image: UIImage) async throws -> String {
        // Compress and upload image to cloud storage
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StoryError.uploadFailed
        }
        let filename = "\(UUID().uuidString).jpg"
        let result = try await cloudStorage.uploadFile(
            data: data,
            filename: filename,
            contentType: "image/jpeg",
            folder: "stories"
        )
        guard let publicURL = result.publicURL else {
            throw StoryError.uploadFailed
        }
        return publicURL
    }
    
    // MARK: - Mock Data (Fallback)
    
    private func loadMockStories() {
        self.stories = [
            // 1. Lio Story (Official)
            Story(
                id: "story_lio",
                userId: "lio_ai",
                userName: "Lio AI",
                userAvatar: "sparkles", // Use system image for Lio
                slides: [
                    StorySlide(id: UUID().uuidString, type: .text, mediaURL: nil, text: "Hey! Did you know you can unlock a new Calculus badge today?", duration: 5),
                    StorySlide(id: UUID().uuidString, type: .image, mediaURL: "https://example.com/math.jpg", text: "Check out this quick tip!", duration: 5)
                ],
                isLive: false,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(86400),
                isSeen: false,
                linkedCourseId: "calculus_101",
                linkedGroupId: nil,
                linkedReelId: nil,
                tags: ["Tip", "Math"]
            ),
            // 2. Friend Story
            Story(
                id: UUID().uuidString,
                userId: "user2",
                userName: "Sarah M.",
                userAvatar: nil,
                slides: [
                    StorySlide(id: UUID().uuidString, type: .image, mediaURL: nil, text: "Studying late at the library 📚", duration: 5)
                ],
                isLive: true,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(86400),
                isSeen: false,
                linkedCourseId: nil,
                linkedGroupId: "nyc_study_group",
                linkedReelId: nil,
                tags: []
            ),
            // 3. Course Update
            Story(
                id: UUID().uuidString,
                userId: "course_bot",
                userName: "Physics 101",
                userAvatar: "atom",
                slides: [
                    StorySlide(id: UUID().uuidString, type: .text, mediaURL: nil, text: "New module released: Quantum Mechanics! ⚛️", duration: 5)
                ],
                isLive: false,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(86400),
                isSeen: false,
                linkedCourseId: "physics_101",
                linkedGroupId: nil,
                linkedReelId: nil,
                tags: ["Update"]
            )
        ]
    }
}

