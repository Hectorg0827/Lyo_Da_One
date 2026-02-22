import Foundation
import SwiftUI
import AVFoundation
import Photos

// MARK: - Content Storage Service

/// Centralized content storage and management for all created media
@MainActor
class ContentStorageService: ObservableObject {
    static let shared = ContentStorageService()

    // MARK: - Published Properties
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var lastUploadedContent: CreatedContent?
    @Published var recentContent: [CreatedContent] = []

    // Service References
    private let storyService = StoryService.shared
    private let discoveryService = DiscoveryService.shared
    private let cloudStorage = CloudStorageService.shared
    private let apiClient = LyoAPIClient.shared

    private init() {
        loadRecentContent()
    }

    // MARK: - Main Storage Function

    /// Store content based on creation mode
    func storeContent(
        mode: CreateMode,
        videoURL: URL? = nil,
        photo: UIImage? = nil,
        title: String,
        description: String = "",
        tags: [String] = []
    ) async throws -> CreatedContent {

        isUploading = true
        uploadProgress = 0.0

        defer {
            isUploading = false
            uploadProgress = 0.0
        }

        do {
            let content: CreatedContent

            switch mode {
            case .clip, .reel:
                content = try await storeVideoContent(
                    type: mode == .clip ? .clip : .reel,
                    videoURL: videoURL,
                    title: title,
                    description: description,
                    tags: tags
                )

            case .story:
                content = try await storeStoryContent(
                    photo: photo,
                    videoURL: videoURL,
                    title: title,
                    tags: tags
                )

            case .post:
                content = try await storePostContent(
                    photo: photo,
                    videoURL: videoURL,
                    title: title,
                    description: description,
                    tags: tags
                )

            case .course:
                content = try await storeCourseContent(
                    videoURL: videoURL,
                    title: title,
                    description: description,
                    tags: tags
                )

            case .live:
                content = try await startLiveSession(
                    title: title,
                    description: description,
                    tags: tags
                )
            case .event:
                content = try await storePostContent(
                    photo: photo,
                    videoURL: videoURL,
                    title: title,
                    description: description,
                    tags: tags
                )
            }

            // Store locally and update UI
            recentContent.insert(content, at: 0)
            lastUploadedContent = content

            // Limit recent content to 50 items
            if recentContent.count > 50 {
                recentContent = Array(recentContent.prefix(50))
            }

            // Save to user defaults
            saveRecentContent()

            Log.media.info("✅ Successfully stored \(mode.rawValue) content: \(content.id)")

            return content

        } catch {
            Log.media.error("❌ Failed to store content: \(error.localizedDescription)")
            throw ContentStorageError.uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - Video Content (Clips & Reels)

    private func storeVideoContent(
        type: StorageContentType,
        videoURL: URL?,
        title: String,
        description: String,
        tags: [String]
    ) async throws -> CreatedContent {

        guard let videoURL = videoURL else {
            throw ContentStorageError.missingMedia
        }

        // Generate thumbnail
        updateProgress(0.1, "Generating thumbnail...")
        let thumbnail = await generateThumbnail(from: videoURL)

        // Upload video
        updateProgress(0.3, "Uploading video...")
        let videoCloudURL = try await cloudStorage.uploadVideo(videoURL)

        // Upload thumbnail if available
        var thumbnailCloudURL: String?
        if let thumbnail = thumbnail {
            updateProgress(0.6, "Uploading thumbnail...")
            thumbnailCloudURL = try await cloudStorage.uploadImage(thumbnail)
        }

        // Create discovery entry
        updateProgress(0.8, "Creating discovery entry...")
        let discoveryRequest = CreateDiscoveryRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            videoURL: videoCloudURL,
            thumbnailURL: thumbnailCloudURL
        )

        let discovery = try await apiClient.createDiscovery(discoveryRequest)

        // Add to local discoveries
        discoveryService.myDiscoveries.insert(discovery, at: 0)

        updateProgress(1.0, "Complete!")

        return CreatedContent(
            id: discovery.id,
            type: type,
            title: title,
            description: description,
            mediaURL: videoCloudURL,
            thumbnailURL: thumbnailCloudURL,
            tags: tags,
            createdAt: Date()
        )
    }

    // MARK: - Story Content

    private func storeStoryContent(
        photo: UIImage?,
        videoURL: URL?,
        title: String,
        tags: [String]
    ) async throws -> CreatedContent {

        var mediaCloudURL: String
        let mediaType: Story.MediaType

        if let videoURL = videoURL {
            // Video story
            updateProgress(0.3, "Uploading video story...")
            mediaCloudURL = try await cloudStorage.uploadVideo(videoURL)
            mediaType = .video
        } else if let photo = photo {
            // Photo story
            updateProgress(0.3, "Uploading photo story...")
            mediaCloudURL = try await cloudStorage.uploadImage(photo)
            mediaType = .image
        } else {
            throw ContentStorageError.missingMedia
        }

        updateProgress(0.7, "Creating story...")

        // Create story request
        let storyRequest = CreateStoryRequest(
            mediaURL: mediaCloudURL,
            mediaType: mediaType,
            isLive: false,
            caption: title.isEmpty ? nil : title,
            tags: tags
        )

        let story = try await apiClient.createStory(storyRequest)

        // Update story service
        storyService.myStory = story
        if !storyService.stories.contains(where: { $0.userId == story.userId }) {
            storyService.stories.insert(story, at: 0)
        }

        updateProgress(1.0, "Story created!")

        return CreatedContent(
            id: story.id,
            type: .story,
            title: title,
            description: "",
            mediaURL: mediaCloudURL,
            thumbnailURL: nil, // Stories don't need separate thumbnails
            tags: tags,
            createdAt: Date()
        )
    }

    // MARK: - Post Content

    private func storePostContent(
        photo: UIImage?,
        videoURL: URL?,
        title: String,
        description: String,
        tags: [String]
    ) async throws -> CreatedContent {

        var mediaURLs: [String] = []

        // Upload media if present
        if let photo = photo {
            updateProgress(0.3, "Uploading photo...")
            let photoURL = try await cloudStorage.uploadImage(photo)
            mediaURLs.append(photoURL)
        }

        if let videoURL = videoURL {
            updateProgress(0.5, "Uploading video...")
            let videoCloudURL = try await cloudStorage.uploadVideo(videoURL)
            mediaURLs.append(videoCloudURL)
        }

        updateProgress(0.8, "Creating post...")

        // Create post
        let postRequest = CreatePostRequest(
            content: description.isEmpty ? title : "\(title)\n\n\(description)",
            mediaURLs: mediaURLs,
            visibility: .public
        )

        let post = try await apiClient.createPost(postRequest)

        updateProgress(1.0, "Post created!")

        return CreatedContent(
            id: post.id,
            type: .post,
            title: title,
            description: description,
            mediaURL: mediaURLs.first,
            thumbnailURL: nil,
            tags: tags,
            createdAt: Date()
        )
    }

    // MARK: - Course Content

    private func storeCourseContent(
        videoURL: URL?,
        title: String,
        description: String,
        tags: [String]
    ) async throws -> CreatedContent {

        updateProgress(0.2, "Processing course content...")

        // For now, create as a special discovery with course tag
        var courseTags = tags
        courseTags.append("course")

        if let videoURL = videoURL {
            // Video-based course
            return try await storeVideoContent(
                type: .course,
                videoURL: videoURL,
                title: title,
                description: description,
                tags: courseTags
            )
        } else {
            // Text-based course - create as a post
            return try await storePostContent(
                photo: nil,
                videoURL: nil,
                title: title,
                description: description,
                tags: courseTags
            )
        }
    }

    // MARK: - Live Session

    private func startLiveSession(
        title: String,
        description: String,
        tags: [String]
    ) async throws -> CreatedContent {

        updateProgress(0.5, "Starting live session...")

        // Create a live story
        let storyRequest = CreateStoryRequest(
            mediaURL: "live://session/\(UUID().uuidString)",
            mediaType: .video,
            isLive: true,
            caption: title,
            tags: tags + ["live"]
        )

        let story = try await apiClient.createStory(storyRequest)

        // Update story service with live story
        storyService.myStory = story
        if let existingIndex = storyService.stories.firstIndex(where: { $0.userId == story.userId }) {
            storyService.stories[existingIndex] = story
        } else {
            storyService.stories.insert(story, at: 0)
        }

        updateProgress(1.0, "Live session started!")

        return CreatedContent(
            id: story.id,
            type: .live,
            title: title,
            description: description,
            mediaURL: story.mediaURL,
            thumbnailURL: nil,
            tags: tags,
            createdAt: Date()
        )
    }

    // MARK: - Helper Functions

    private func generateThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 512, height: 512)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)

        do {
            let cgImage = try await imageGenerator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            Log.media.warning("Failed to generate thumbnail: \(error)")
            return nil
        }
    }

    private func updateProgress(_ progress: Double, _ message: String) {
        DispatchQueue.main.async {
            self.uploadProgress = progress
            Log.media.info("Upload Progress: \(Int(progress * 100))% - \(message)")
        }
    }

    // MARK: - Local Storage

    private func saveRecentContent() {
        if let data = try? JSONEncoder().encode(recentContent) {
            UserDefaults.standard.set(data, forKey: "recentCreatedContent")
        }
    }

    private func loadRecentContent() {
        if let data = UserDefaults.standard.data(forKey: "recentCreatedContent"),
           let content = try? JSONDecoder().decode([CreatedContent].self, from: data) {
            recentContent = content
        }
    }

    // MARK: - Public Interface

    /// Get content by type for display in feeds
    func getContent(of type: StorageContentType) -> [CreatedContent] {
        return recentContent.filter { $0.type == type }
    }

    /// Clear all content
    func clearContent() {
        recentContent.removeAll()
        saveRecentContent()
    }

    /// Delete specific content
    func deleteContent(_ content: CreatedContent) async {
        // Remove from local storage
        recentContent.removeAll { $0.id == content.id }
        saveRecentContent()

        // TODO: Delete from backend services
        Log.media.info("Deleted content: \(content.id)")
    }
}

// MARK: - Created Content Model

struct CreatedContent: Identifiable, Codable {
    let id: String
    let type: StorageContentType
    let title: String
    let description: String
    let mediaURL: String?
    let thumbnailURL: String?
    let tags: [String]
    let createdAt: Date
}

// MARK: - Content Types

enum StorageContentType: String, Codable, CaseIterable {
    case clip = "clip"
    case reel = "reel"
    case story = "story"
    case post = "post"
    case course = "course"
    case live = "live"

    var displayName: String {
        switch self {
        case .clip: return "Clip"
        case .reel: return "Reel"
        case .story: return "Story"
        case .post: return "Post"
        case .course: return "Course"
        case .live: return "Live"
        }
    }
}

// MARK: - Content Storage Errors

enum ContentStorageError: LocalizedError {
    case missingMedia
    case uploadFailed(String)
    case networkError
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .missingMedia:
            return "No media content provided for upload"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .networkError:
            return "Network error occurred during upload"
        case .invalidContent:
            return "Content is invalid or corrupted"
        }
    }
}