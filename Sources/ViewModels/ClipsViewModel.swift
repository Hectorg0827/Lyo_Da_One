//
//  ClipsViewModel.swift
//  Lyo
//
//  ViewModel for the Clips recording screen — manages teleprompter,
//  chapter-based recording, educational overlays, and publishing.
//

import SwiftUI
import AVFoundation
import Combine
import os

// MARK: - Chapter Segment

/// A single recording segment in the chapter-based flow.
struct ChapterSegment: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    var isRecorded: Bool = false
    var videoURL: URL?
    var duration: TimeInterval = 0
    
    /// Default 4-chapter template for educational clips.
    static let defaultChapters: [ChapterSegment] = [
        ChapterSegment(title: "Intro",      color: Color(hex: "42A5F5")),
        ChapterSegment(title: "Key Point",  color: Color(hex: "AB47BC")),
        ChapterSegment(title: "Action",     color: Color(hex: "66BB6A")),
        ChapterSegment(title: "Summary",    color: Color(hex: "FFA726"))
    ]
}

// MARK: - Educational Overlay

/// An overlay element (arrow, highlight box, bullet list, callout) placed on the clip.
struct EducationalOverlay: Identifiable {
    let id = UUID()
    var type: OverlayType
    var position: CGPoint
    var timestamp: TimeInterval
    var content: String
    
    enum OverlayType: String, CaseIterable, Identifiable {
        case arrow       = "Arrow"
        case highlightBox = "Highlight"
        case bulletList  = "Bullets"
        case callout     = "Callout"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .arrow:        return "arrow.right"
            case .highlightBox: return "square.dashed"
            case .bulletList:   return "list.bullet.rectangle"
            case .callout:      return "text.bubble"
            }
        }
        
        var color: Color {
            switch self {
            case .arrow:        return Color(hex: "FF6B6B")
            case .highlightBox: return Color(hex: "4ECDC4")
            case .bulletList:   return Color(hex: "45B7D1")
            case .callout:      return Color(hex: "FFA726")
            }
        }
        
        var label: String {
            switch self {
            case .arrow:        return "CTA Arrow"
            case .highlightBox: return "Highlight Box"
            case .bulletList:   return "Bullet List"
            case .callout:      return "Callout Badge"
            }
        }
    }
}

// MARK: - Background Music

/// Background music preset.
struct BackgroundMusicPreset: Identifiable {
    let id = UUID()
    let name: String
    let genre: String
    let icon: String
    
    static let presets: [BackgroundMusicPreset] = [
        BackgroundMusicPreset(name: "Lo-Fi Chill",     genre: "lo-fi",    icon: "headphones"),
        BackgroundMusicPreset(name: "Ambient Focus",   genre: "ambient",  icon: "waveform"),
        BackgroundMusicPreset(name: "Soft Piano",      genre: "piano",    icon: "pianokeys"),
        BackgroundMusicPreset(name: "Study Beats",     genre: "beats",    icon: "metronome"),
        BackgroundMusicPreset(name: "None",            genre: "none",     icon: "speaker.slash")
    ]
}

// MARK: - Clips ViewModel

@MainActor
final class ClipsViewModel: ObservableObject {
    
    // MARK: - Teleprompter State
    @Published var scriptText: String = ""
    @Published var scrollSpeed: Double = 1.0          // 0.5 – 3.0
    @Published var isTeleprompterVisible: Bool = false
    @Published var isTeleprompterPaused: Bool = false
    @Published var teleprompterOpacity: Double = 0.75
    
    // MARK: - Chapter State
    @Published var chapters: [ChapterSegment] = ChapterSegment.defaultChapters
    @Published var activeChapterIndex: Int = 0
    @Published var isRecordingChapter: Bool = false
    
    // MARK: - Overlay State
    @Published var activeOverlays: [EducationalOverlay] = []
    @Published var selectedOverlayType: EducationalOverlay.OverlayType = .arrow
    @Published var isOverlayTrayVisible: Bool = false
    
    // MARK: - Music State
    @Published var selectedMusic: BackgroundMusicPreset? = BackgroundMusicPreset.presets.first
    @Published var isDuckingEnabled: Bool = true
    @Published var musicVolume: Double = 0.3
    
    // MARK: - Publishing State
    @Published var clipTitle: String = ""
    @Published var clipDescription: String = ""
    @Published var clipSubject: ClipSubject?
    @Published var clipLevel: LearningLevel = .beginner
    @Published var clipKeyPoints: [String] = []
    @Published var enableCourseGeneration: Bool = true
    @Published var isPublishing: Bool = false
    @Published var publishProgress: Double = 0
    @Published var publishError: String?
    @Published var isPublishComplete: Bool = false
    @Published var showMetadataSheet: Bool = false
    
    // MARK: - Services
    private let clipService = ClipService.shared
    private let haptics = HapticManager.shared
    
    // MARK: - Computed Properties
    
    var activeChapter: ChapterSegment {
        chapters[activeChapterIndex]
    }
    
    var allChaptersRecorded: Bool {
        chapters.allSatisfy { $0.isRecorded }
    }
    
    var totalDuration: TimeInterval {
        chapters.reduce(0) { $0 + $1.duration }
    }
    
    var formattedTotalDuration: String {
        let seconds = Int(totalDuration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    
    var completedChapterCount: Int {
        chapters.filter(\.isRecorded).count
    }
    
    /// Maximum clip length per-chapter (22.5s × 4 = 90s total)
    let maxChapterDuration: TimeInterval = 22.5
    
    // MARK: - Chapter Actions
    
    func selectChapter(at index: Int) {
        guard index >= 0, index < chapters.count else { return }
        activeChapterIndex = index
        haptics.selection()
    }
    
    func startRecordingChapter() {
        isRecordingChapter = true
        haptics.heavy()
    }
    
    func stopRecordingChapter(videoURL: URL, duration: TimeInterval) {
        chapters[activeChapterIndex].videoURL = videoURL
        chapters[activeChapterIndex].duration = duration
        chapters[activeChapterIndex].isRecorded = true
        isRecordingChapter = false
        haptics.success()
        
        // Auto-advance to next unrecorded chapter
        if let nextUnrecorded = chapters.firstIndex(where: { !$0.isRecorded }) {
            activeChapterIndex = nextUnrecorded
        }
    }
    
    func reRecordChapter(at index: Int) {
        guard index >= 0, index < chapters.count else { return }
        chapters[index].isRecorded = false
        chapters[index].videoURL = nil
        chapters[index].duration = 0
        activeChapterIndex = index
        haptics.medium()
    }
    
    // MARK: - Teleprompter Actions
    
    func toggleTeleprompter() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isTeleprompterVisible.toggle()
        }
        haptics.light()
    }
    
    func toggleTeleprompterPause() {
        isTeleprompterPaused.toggle()
    }
    
    // MARK: - Overlay Actions
    
    func addOverlay(at position: CGPoint, timestamp: TimeInterval = 0) {
        let overlay = EducationalOverlay(
            type: selectedOverlayType,
            position: position,
            timestamp: timestamp,
            content: selectedOverlayType.label
        )
        activeOverlays.append(overlay)
        haptics.light()
    }
    
    func removeOverlay(_ id: UUID) {
        activeOverlays.removeAll { $0.id == id }
    }
    
    func toggleOverlayTray() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isOverlayTrayVisible.toggle()
        }
        haptics.light()
    }
    
    // MARK: - Publishing
    
    /// Publish the final clip — merges chapter videos, uploads, and creates the clip via backend.
    func publishClip(cameraManager: EnhancedCameraManager) async {
        guard !clipTitle.isEmpty else {
            publishError = "Please add a title for your clip"
            return
        }
        
        isPublishing = true
        publishProgress = 0.1
        
        do {
            // 1. Collect chapter video URLs (use the last recorded chapter video for now)
            let videoURLs = chapters.compactMap(\.videoURL)
            guard let primaryVideo = videoURLs.first else {
                publishError = "No recorded chapters found"
                isPublishing = false
                return
            }
            
            publishProgress = 0.2
            
            // 2. Build metadata from form
            let metadata = ClipMetadata(
                subject: clipSubject?.rawValue,
                topic: nil,
                level: clipLevel,
                keyPoints: clipKeyPoints,
                transcript: nil,
                tags: [],
                enableCourseGeneration: enableCourseGeneration
            )
            
            publishProgress = 0.3
            
            // 3. Use ClipService for cloud upload + backend record creation
            let clip = try await clipService.createClip(
                videoURL: primaryVideo,
                title: clipTitle,
                description: clipDescription.isEmpty ? nil : clipDescription,
                metadata: metadata,
                isPublic: true,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        // Map 30-90% of total to upload
                        self?.publishProgress = 0.3 + (progress * 0.6)
                    }
                }
            )
            
            publishProgress = 1.0
            Log.ui.info("✅ Clip published via backend: \(clip.title) [id: \(clip.id)]")
            
            isPublishComplete = true
            haptics.success()
            
        } catch {
            Log.ui.error("❌ Clip publish failed: \(error)")
            publishError = error.localizedDescription
            haptics.error()
        }
        
        isPublishing = false
    }
    
    // MARK: - Reset
    
    func reset() {
        chapters = ChapterSegment.defaultChapters
        activeChapterIndex = 0
        isRecordingChapter = false
        scriptText = ""
        isTeleprompterVisible = false
        activeOverlays = []
        clipTitle = ""
        clipDescription = ""
        clipSubject = nil
        clipLevel = .beginner
        clipKeyPoints = []
        enableCourseGeneration = true
        isPublishing = false
        publishProgress = 0
        publishError = nil
        isPublishComplete = false
    }
}
