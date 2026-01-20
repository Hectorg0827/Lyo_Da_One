//
//  ClipService.swift
//  Lyo
//
//  Service for managing clip operations - create, fetch, delete, and course generation
//

import Foundation
import UIKit
import AVFoundation

// MARK: - Clip Service

/// Service for managing clip (short video) operations
final class ClipService {
    static let shared = ClipService()
    
    private let network = NetworkClient.shared
    private let cloudStorage = CloudStorageService.shared
    
    private init() {}
    
    // MARK: - Create Clip
    
    /// Create a new clip with video upload
    /// - Parameters:
    ///   - videoURL: Local URL of the video file
    ///   - title: Clip title
    ///   - description: Optional description
    ///   - metadata: Clip metadata for AI course generation
    ///   - progressHandler: Upload progress callback
    /// - Returns: Created Clip object
    func createClip(
        videoURL: URL,
        title: String,
        description: String?,
        metadata: ClipMetadata,
        isPublic: Bool = true,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Clip {
        progressHandler?(0.1)
        
        // 1. Read video data and get duration
        let videoData = try Data(contentsOf: videoURL)
        let duration = await getVideoDuration(url: videoURL)
        
        progressHandler?(0.2)
        
        // 2. Generate thumbnail
        let thumbnail = await generateThumbnail(from: videoURL)
        var thumbnailUrl: String? = nil
        
        if let thumbImage = thumbnail {
            let thumbResult = try await cloudStorage.uploadImage(
                image: thumbImage,
                folder: "clip_thumbnails",
                quality: 0.8
            )
            thumbnailUrl = thumbResult.publicURL
        }
        
        progressHandler?(0.4)
        
        // 3. Upload video to cloud storage
        let filename = "clip_\(UUID().uuidString).mp4"
        let uploadResult = try await cloudStorage.uploadFile(
            data: videoData,
            filename: filename,
            contentType: "video/mp4",
            folder: "clips",
            progressHandler: { progress in
                // Map 40-80% of total progress to video upload
                progressHandler?(0.4 + (progress * 0.4))
            }
        )
        
        guard let videoUrl = uploadResult.publicURL else {
            throw ClipError.uploadFailed
        }
        
        progressHandler?(0.85)
        
        // 4. Create clip record in backend
        let request = ClipCreateRequest(
            title: title,
            description: description,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            durationSeconds: duration,
            subject: metadata.subject,
            topic: metadata.topic,
            level: metadata.level,
            keyPoints: metadata.keyPoints,
            tags: metadata.tags,
            isPublic: isPublic,
            enableCourseGeneration: metadata.enableCourseGeneration
        )
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips",
            method: .post,
            body: request,
            requiresAuth: true
        )
        
        let response: ClipResponse = try await network.request(endpoint)
        
        guard response.success, let clip = response.clip else {
            throw ClipError.serverError(response.error ?? "Failed to create clip")
        }
        
        progressHandler?(1.0)
        
        print("✅ Clip created: \(clip.title)")
        return clip
    }
    
    // MARK: - Get User Clips
    
    /// Fetch clips created by the current user
    func getMyClips(page: Int = 1, perPage: Int = 20) async throws -> [Clip] {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips?page=\(page)&per_page=\(perPage)",
            method: .get,
            requiresAuth: true
        )
        
        let response: ClipsListResponse = try await network.request(endpoint)
        return response.clips
    }
    
    // MARK: - Get Discover Clips
    
    /// Fetch clips for the Discover feed
    func getDiscoverClips(page: Int = 1, perPage: Int = 20) async throws -> [Clip] {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips/discover?page=\(page)&per_page=\(perPage)",
            method: .get,
            requiresAuth: true
        )
        
        let response: ClipsListResponse = try await network.request(endpoint)
        return response.clips
    }
    
    // MARK: - Get Clip by ID
    
    /// Fetch a specific clip by ID
    func getClip(id: String) async throws -> Clip {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips/\(id)",
            method: .get,
            requiresAuth: true
        )
        
        let response: ClipResponse = try await network.request(endpoint)
        
        guard response.success, let clip = response.clip else {
            throw ClipError.notFound
        }
        
        return clip
    }
    
    // MARK: - Update Clip
    
    /// Update clip metadata
    func updateClip(id: String, update: ClipUpdateRequest) async throws -> Clip {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips/\(id)",
            method: .put,
            body: update,
            requiresAuth: true
        )
        
        let response: ClipResponse = try await network.request(endpoint)
        
        guard response.success, let clip = response.clip else {
            throw ClipError.serverError(response.error ?? "Failed to update clip")
        }
        
        return clip
    }
    
    // MARK: - Delete Clip
    
    /// Delete a clip
    func deleteClip(id: String) async throws {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips/\(id)",
            method: .delete,
            requiresAuth: true
        )
        
        let _: EmptyResponse = try await network.request(endpoint)
        print("✅ Clip deleted: \(id)")
    }
    
    // MARK: - Like/Unlike Clip
    
    /// Toggle like status for a clip
    func toggleLike(clipId: String) async throws -> Bool {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips/\(clipId)/like",
            method: .post,
            requiresAuth: true
        )
        
        struct LikeResponse: Codable {
            let isLiked: Bool
            let likeCount: Int
        }
        
        let response: LikeResponse = try await network.request(endpoint)
        return response.isLiked
    }
    
    // MARK: - Record View
    
    /// Record a view for a clip
    func recordView(clipId: String) async {
        do {
            let endpoint = DynamicEndpoint(
                urlString: "/api/v1/clips/\(clipId)/view",
                method: .post,
                requiresAuth: true
            )
            let _: EmptyResponse = try await network.request(endpoint)
        } catch {
            // Silently fail - view recording is not critical
            print("⚠️ Failed to record clip view: \(error)")
        }
    }
    
    // MARK: - Generate Course from Clip
    
    /// Generate a course from a clip using AI
    func generateCourseFromClip(
        clipId: String,
        courseTitle: String? = nil,
        targetLevel: String? = nil,
        additionalContext: String? = nil
    ) async throws -> String {
        let request = GenerateCourseFromClipRequest(
            clipId: clipId,
            courseTitle: courseTitle,
            targetLevel: targetLevel,
            additionalContext: additionalContext
        )
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/clips/\(clipId)/generate-course",
            method: .post,
            body: request,
            requiresAuth: true
        )
        
        let response: GenerateCourseFromClipResponse = try await network.request(endpoint)
        
        guard response.success, let courseId = response.courseId else {
            throw ClipError.courseGenerationFailed(response.error ?? "Failed to generate course")
        }
        
        print("✅ Course generated from clip: \(courseId)")
        return courseId
    }
    
    // MARK: - Helper Methods
    
    /// Get video duration in seconds
    private func getVideoDuration(url: URL) async -> Double {
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            print("⚠️ Failed to get video duration: \(error)")
            return 0
        }
    }
    
    /// Generate thumbnail from video at first frame
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
            print("⚠️ Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}

// MARK: - Clip Errors

enum ClipError: LocalizedError {
    case uploadFailed
    case notFound
    case serverError(String)
    case courseGenerationFailed(String)
    case invalidVideo
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload video"
        case .notFound:
            return "Clip not found"
        case .serverError(let message):
            return message
        case .courseGenerationFailed(let message):
            return "Course generation failed: \(message)"
        case .invalidVideo:
            return "Invalid video format"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - Demo Clips

extension ClipService {
    /// Generate demo clips for testing/demo mode
    static func generateDemoClips() -> [Clip] {
        return [
            Clip(
                id: "demo-clip-1",
                userId: 1,
                title: "Understanding Quadratic Equations",
                description: "A quick explanation of solving quadratic equations using the quadratic formula",
                videoURL: URL(string: "https://storage.googleapis.com/lyo-clips/demo/quadratic.mp4")!,
                thumbnailURL: URL(string: "https://storage.googleapis.com/lyo-clips/demo/quadratic_thumb.jpg"),
                durationSeconds: 45,
                metadata: ClipMetadata(
                    subject: "Mathematics",
                    topic: "Algebra",
                    level: .intermediate,
                    keyPoints: ["Quadratic formula", "Discriminant", "Roots"],
                    enableCourseGeneration: true
                ),
                viewCount: 1250,
                likeCount: 89,
                authorName: "Prof. Smith",
                isPublic: true
            ),
            Clip(
                id: "demo-clip-2",
                userId: 2,
                title: "Photosynthesis Explained",
                description: "How plants convert sunlight into energy",
                videoURL: URL(string: "https://storage.googleapis.com/lyo-clips/demo/photosynthesis.mp4")!,
                thumbnailURL: URL(string: "https://storage.googleapis.com/lyo-clips/demo/photosynthesis_thumb.jpg"),
                durationSeconds: 60,
                metadata: ClipMetadata(
                    subject: "Science",
                    topic: "Biology",
                    level: .beginner,
                    keyPoints: ["Chlorophyll", "Light reaction", "Carbon dioxide"],
                    enableCourseGeneration: true
                ),
                viewCount: 2340,
                likeCount: 156,
                authorName: "Dr. Green",
                isPublic: true
            ),
            Clip(
                id: "demo-clip-3",
                userId: 3,
                title: "Spanish Verb Conjugation Tips",
                description: "Master regular verb endings in Spanish",
                videoURL: URL(string: "https://storage.googleapis.com/lyo-clips/demo/spanish.mp4")!,
                thumbnailURL: URL(string: "https://storage.googleapis.com/lyo-clips/demo/spanish_thumb.jpg"),
                durationSeconds: 55,
                metadata: ClipMetadata(
                    subject: "Languages",
                    topic: "Spanish",
                    level: .beginner,
                    keyPoints: ["-ar verbs", "-er verbs", "-ir verbs"],
                    enableCourseGeneration: true
                ),
                viewCount: 890,
                likeCount: 67,
                authorName: "Maria Lopez",
                isPublic: true
            )
        ]
    }
}
