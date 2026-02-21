import SwiftUI
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
        case .bwProfessional: return .black // Or .clear, depending on implementation
        case .lyoBlue: return Color(hex: "6366F1").opacity(0.2)
        }
    }
    
    var filterDesaturation: Double {
        return self == .bwProfessional ? 1.0 : 0.0
    }
}

// MARK: - Stories ViewModel

@MainActor
final class StoriesViewModel: ObservableObject {
    
    // MARK: - Recording State
    @Published var isRecording: Bool = false
    @Published var isHandsFreeMode: Bool = false
    @Published var recordedSnippetsCount: Int = 0 // Max 4 for 60s total / 15s each
    
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
    
    // MARK: - Actions
    
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
    
    // MARK: - Publishing
    
    func publishStory(videoURL: URL?, image: UIImage?) async {
        guard videoURL != nil || image != nil else { return }
        
        isPublishing = true
        publishProgress = 0.1
        
        do {
            var mediaPublicURL: String
            var mediaType: Story.MediaType
            
            if let videoURL = videoURL {
                mediaPublicURL = try await storyService.uploadStoryMedia(videoURL: videoURL)
                mediaType = .video
            } else if let image = image {
                mediaPublicURL = try await storyService.uploadStoryMedia(image: image)
                mediaType = .image
            } else {
                throw StoryError.uploadFailed
            }
            
            publishProgress = 0.6
            
            // For Stories, typically no caption from UI yet, but we could add one
            try await storyService.addStory(
                mediaURL: mediaPublicURL,
                mediaType: mediaType,
                caption: nil,
                isLive: false // Or true if hands-free streaming
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
    
    func reset() {
        isRecording = false
        recordedSnippetsCount = 0
        activeStickers = []
        isStickerTrayVisible = false
        currentPreset = .normal
        isPublishing = false
        publishProgress = 0
        publishError = nil
        isPublishComplete = false
    }
}
