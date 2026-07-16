import SwiftUI
import AVFoundation
import Combine
import os

// MARK: - Interaction Sticker Types

enum StoryStickerType: String, Identifiable, CaseIterable {
    case qa = "Q&A"
    case poll = "Poll"
    case countdown = "Countdown"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .qa: return "questionmark.bubble.fill"
        case .poll: return "chart.bar.fill"
        case .countdown: return "timer"
        }
    }
    
    var color: Color {
        switch self {
        case .qa: return Color(hex: "6366F1")
        case .poll: return Color(hex: "EC4899")
        case .countdown: return Color(hex: "F59E0B")
        }
    }
}

struct StorySticker: Identifiable {
    let id = UUID()
    var type: StoryStickerType
    var position: CGPoint
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var content: String
}

// MARK: - Studio Preset

enum StudioPreset: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case warmOffice = "Warm Office"
    case cleanTech = "Clean Tech"
    case bwProfessional = "B&W Pro"
    case lyoBlue = "Lyo Blue"
    
    var id: String { rawValue }
    
    var blendMode: BlendMode {
        switch self {
        case .normal: return .normal
        case .warmOffice: return .overlay
        case .cleanTech: return .hardLight
        case .bwProfessional: return .color
        case .lyoBlue: return .softLight
        }
    }
    
    var colorOverlay: Color {
        switch self {
        case .normal: return .clear
        case .warmOffice: return Color.orange.opacity(0.15)
        case .cleanTech: return Color.cyan.opacity(0.1)
        case .bwProfessional: return .black
        case .lyoBlue: return Color(hex: "6366F1").opacity(0.2)
        }
    }
    
    var filterDesaturation: Double {
        return self == .bwProfessional ? 1.0 : 0.0
    }
}

// MARK: - Story Segment

/// A single recorded snippet in a multi-segment story.
struct StorySegment: Identifiable {
    let id = UUID()
    var videoURL: URL?
    var image: UIImage?
    var duration: TimeInterval
    var isVideo: Bool { videoURL != nil }
}

// MARK: - Stories ViewModel

@MainActor
final class StoriesViewModel: ObservableObject {
    
    // MARK: - Recording State
    @Published var isRecording: Bool = false
    @Published var isHandsFreeMode: Bool = false
    
    // MARK: - Multi-Segment State
    @Published var segments: [StorySegment] = []
    let maxSegments = 4
    let maxSegmentDuration: TimeInterval = 15.0
    
    var recordedSnippetsCount: Int { segments.count }
    var canRecordMore: Bool { segments.count < maxSegments }
    var hasSegments: Bool { !segments.isEmpty }
    
    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }
    
    var formattedTotalDuration: String {
        let seconds = Int(totalDuration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    
    // MARK: - Preset State
    @Published var currentPreset: StudioPreset = .normal
    
    // MARK: - Sticker State
    @Published var activeStickers: [StorySticker] = []
    @Published var isStickerTrayVisible: Bool = false
    
    // MARK: - Publishing State
    @Published var isPublishing: Bool = false
    @Published var publishProgress: Double = 0
    @Published var publishError: String?
    @Published var isPublishComplete: Bool = false
    
    // MARK: - Services
    private let storyService = StoryService.shared
    private let haptics = HapticManager.shared
    
    // MARK: - Preset Actions
    
    func cyclePreset(forward: Bool = true) {
        let all = StudioPreset.allCases
        if let currentIdx = all.firstIndex(of: currentPreset) {
            let nextIdx = forward
                ? (currentIdx + 1) % all.count
                : (currentIdx - 1 + all.count) % all.count
            currentPreset = all[nextIdx]
            haptics.light()
        }
    }
    
    // MARK: - Segment Management
    
    /// Called when a video recording finishes — adds a new segment.
    func addVideoSegment(url: URL, duration: TimeInterval) {
        guard canRecordMore else { return }
        let segment = StorySegment(
            videoURL: url,
            image: nil,
            duration: min(duration, maxSegmentDuration)
        )
        segments.append(segment)
        haptics.success()
    }
    
    /// Called when a photo is captured — adds as a static segment (5s display).
    func addPhotoSegment(image: UIImage) {
        guard canRecordMore else { return }
        let segment = StorySegment(
            videoURL: nil,
            image: image,
            duration: 5.0  // Photo stories display for 5s
        )
        segments.append(segment)
        haptics.success()
    }
    
    /// Delete the last segment (undo-style).
    func deleteLastSegment() {
        guard let last = segments.popLast() else { return }
        // Clean up video file
        if let url = last.videoURL {
            try? FileManager.default.removeItem(at: url)
        }
        haptics.medium()
    }
    
    // MARK: - Sticker Actions
    
    /// Add a sticker of the given type at the center of the screen.
    func addSticker(type: StoryStickerType) {
        let sticker = StorySticker(
            type: type,
            position: CGPoint(x: 0.5, y: 0.4),  // Center-ish
            content: type.rawValue
        )
        activeStickers.append(sticker)
        haptics.light()
    }
    
    /// Update sticker position (for drag gestures).
    func updateStickerPosition(_ id: UUID, to newPosition: CGPoint) {
        if let index = activeStickers.firstIndex(where: { $0.id == id }) {
            activeStickers[index].position = newPosition
        }
    }
    
    /// Remove a sticker.
    func removeSticker(_ id: UUID) {
        activeStickers.removeAll { $0.id == id }
    }
    
    // MARK: - Video Merging
    
    /// Merge all video segments into one file for upload.
    func mergeSegments() async throws -> URL {
        let videoURLs = segments.compactMap(\.videoURL)
        
        guard !videoURLs.isEmpty else {
            throw StoryError.uploadFailed
        }
        
        // Single segment — return directly
        if videoURLs.count == 1 {
            return videoURLs[0]
        }
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw StoryError.uploadFailed
        }
        
        var currentTime = CMTime.zero
        
        for url in videoURLs {
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            if let sourceVideo = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: sourceVideo, at: currentTime)
                if currentTime == .zero {
                    let transform = try await sourceVideo.load(.preferredTransform)
                    videoTrack.preferredTransform = transform
                }
            }
            
            if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudio, at: currentTime)
            }
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyo_story_\(UUID().uuidString).mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw StoryError.uploadFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            Log.ui.info("✅ Merged \(videoURLs.count) story segments into: \(outputURL)")
            return outputURL
        default:
            let msg = exportSession.error?.localizedDescription ?? "Unknown"
            Log.ui.error("❌ Story merge failed: \(msg)")
            throw StoryError.uploadFailed
        }
    }
    
    // MARK: - Publishing
    
    /// Publish the story — merges segments if needed, then uploads via StoryService.
    func publishStory(videoURL: URL?, image: UIImage?) async {
        // If called with a direct URL/image from single-shot recording
        if segments.isEmpty {
            if let url = videoURL {
                addVideoSegment(url: url, duration: 15.0)
            } else if let img = image {
                addPhotoSegment(image: img)
            }
        }
        
        guard hasSegments else { return }
        
        isPublishing = true
        publishProgress = 0.1
        
        do {
            var mediaPublicURL: String
            var mediaType: Story.MediaType
            
            let videoSegments = segments.filter(\.isVideo)
            let photoSegments = segments.filter { !$0.isVideo }
            
            if !videoSegments.isEmpty {
                // Merge video segments
                publishProgress = 0.2
                let mergedURL = try await mergeSegments()
                
                publishProgress = 0.4
                mediaPublicURL = try await storyService.uploadStoryMedia(videoURL: mergedURL)
                mediaType = .video
                
                // Clean up merged temp file
                if mergedURL.lastPathComponent.contains("lyo_story_") {
                    try? FileManager.default.removeItem(at: mergedURL)
                }
            } else if let firstPhoto = photoSegments.first?.image {
                publishProgress = 0.4
                mediaPublicURL = try await storyService.uploadStoryMedia(image: firstPhoto)
                mediaType = .image
            } else {
                throw StoryError.uploadFailed
            }
            
            publishProgress = 0.7
            
            try await storyService.addStory(
                mediaURL: mediaPublicURL,
                mediaType: mediaType,
                caption: nil,
                isLive: false
            )
            
            publishProgress = 1.0
            Log.ui.info("✅ Story published via backend")
            
            isPublishComplete = true
            haptics.success()
            
        } catch {
            Log.ui.error("❌ Story publish failed: \(error)")
            publishError = error.localizedDescription
            haptics.error()
        }
        
        isPublishing = false
    }
    
    // MARK: - Reset
    
    func reset() {
        isRecording = false
        
        // Clean up segment files
        for segment in segments {
            if let url = segment.videoURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        segments = []
        
        activeStickers = []
        isStickerTrayVisible = false
        currentPreset = .normal
        isPublishing = false
        publishProgress = 0
        publishError = nil
        isPublishComplete = false
    }
}
