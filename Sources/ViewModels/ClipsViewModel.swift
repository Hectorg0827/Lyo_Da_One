//
//  ClipsViewModel.swift
//  Lyo
//
//  ViewModel for the Clips recording screen — manages teleprompter,
//  chapter-based recording, educational overlays, background music,
//  chapter video merging, and publishing.
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
    /// Bundled file name (without extension). nil = "None" preset.
    let fileName: String?
    
    static let presets: [BackgroundMusicPreset] = [
        BackgroundMusicPreset(name: "Lo-Fi Chill",     genre: "lo-fi",    icon: "headphones",    fileName: "lofi_chill"),
        BackgroundMusicPreset(name: "Ambient Focus",   genre: "ambient",  icon: "waveform",      fileName: "ambient_focus"),
        BackgroundMusicPreset(name: "Soft Piano",      genre: "piano",    icon: "pianokeys",      fileName: "soft_piano"),
        BackgroundMusicPreset(name: "Study Beats",     genre: "beats",    icon: "metronome",      fileName: "study_beats"),
        BackgroundMusicPreset(name: "None",            genre: "none",     icon: "speaker.slash",  fileName: nil)
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
    @Published var chapterElapsed: TimeInterval = 0
    
    // MARK: - Overlay State
    @Published var activeOverlays: [EducationalOverlay] = []
    @Published var selectedOverlayType: EducationalOverlay.OverlayType = .arrow
    @Published var isOverlayTrayVisible: Bool = false
    
    // MARK: - Music State
    @Published var selectedMusic: BackgroundMusicPreset? = BackgroundMusicPreset.presets.first
    @Published var isDuckingEnabled: Bool = true
    @Published var musicVolume: Double = 0.3
    @Published var isMusicPlaying: Bool = false
    
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
    
    // MARK: - Audio Engine
    private var musicPlayer: AVAudioPlayer?
    private var normalVolume: Float = 0.3
    private let duckedVolume: Float = 0.08
    
    // MARK: - Chapter Timer
    private var chapterTimer: Timer?
    
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
    
    /// Remaining time for the current chapter while recording
    var chapterTimeRemaining: TimeInterval {
        max(0, maxChapterDuration - chapterElapsed)
    }
    
    var formattedChapterRemaining: String {
        let seconds = Int(chapterTimeRemaining)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    
    // MARK: - Chapter Actions
    
    func selectChapter(at index: Int) {
        guard index >= 0, index < chapters.count else { return }
        activeChapterIndex = index
        haptics.selection()
    }
    
    /// Start recording the active chapter — starts timer and auto-scrolls teleprompter.
    func startRecordingChapter() {
        isRecordingChapter = true
        chapterElapsed = 0
        haptics.heavy()
        
        // Start per-chapter countdown timer
        startChapterTimer()
        
        // Auto-start teleprompter if visible and has text
        if isTeleprompterVisible && !scriptText.isEmpty {
            isTeleprompterPaused = false
        }
        
        // Duck background music if enabled
        if isDuckingEnabled && isMusicPlaying {
            setMusicVolume(duckedVolume, animated: true)
        }
    }
    
    /// Stop recording the active chapter — saves video, stops timer, auto-pauses teleprompter.
    func stopRecordingChapter(videoURL: URL, duration: TimeInterval) {
        chapters[activeChapterIndex].videoURL = videoURL
        chapters[activeChapterIndex].duration = min(duration, maxChapterDuration)
        chapters[activeChapterIndex].isRecorded = true
        isRecordingChapter = false
        haptics.success()
        
        // Stop chapter timer
        stopChapterTimer()
        
        // Auto-pause teleprompter
        if isTeleprompterVisible {
            isTeleprompterPaused = true
        }
        
        // Restore music volume
        if isDuckingEnabled && isMusicPlaying {
            setMusicVolume(normalVolume, animated: true)
        }
        
        // Auto-advance to next unrecorded chapter
        if let nextUnrecorded = chapters.firstIndex(where: { !$0.isRecorded }) {
            activeChapterIndex = nextUnrecorded
        }
    }
    
    func reRecordChapter(at index: Int) {
        guard index >= 0, index < chapters.count else { return }
        // Clean up old video file
        if let oldURL = chapters[index].videoURL {
            try? FileManager.default.removeItem(at: oldURL)
        }
        chapters[index].isRecorded = false
        chapters[index].videoURL = nil
        chapters[index].duration = 0
        activeChapterIndex = index
        haptics.medium()
    }
    
    // MARK: - Chapter Timer
    
    private func startChapterTimer() {
        chapterElapsed = 0
        chapterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.chapterElapsed += 0.1
            }
        }
    }
    
    private func stopChapterTimer() {
        chapterTimer?.invalidate()
        chapterTimer = nil
    }
    
    /// Returns true if the chapter timer has expired (called from the view to auto-stop).
    var shouldAutoStopRecording: Bool {
        chapterElapsed >= maxChapterDuration
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
    
    /// Update the position of an overlay (for drag-to-reposition).
    func updateOverlayPosition(_ id: UUID, to newPosition: CGPoint) {
        if let index = activeOverlays.firstIndex(where: { $0.id == id }) {
            activeOverlays[index].position = newPosition
        }
    }
    
    func toggleOverlayTray() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isOverlayTrayVisible.toggle()
        }
        haptics.light()
    }
    
    // MARK: - Background Music
    
    /// Load and play the selected music preset.
    func playMusic() {
        guard let preset = selectedMusic, let fileName = preset.fileName else {
            stopMusic()
            return
        }
        
        // Try to load from bundle
        if let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") ??
                      Bundle.main.url(forResource: fileName, withExtension: "m4a") ??
                      Bundle.main.url(forResource: fileName, withExtension: "wav") {
            do {
                // Configure audio session for playback + recording simultaneously
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                
                musicPlayer = try AVAudioPlayer(contentsOf: url)
                musicPlayer?.numberOfLoops = -1 // Loop indefinitely
                normalVolume = Float(musicVolume)
                musicPlayer?.volume = normalVolume
                musicPlayer?.prepareToPlay()
                musicPlayer?.play()
                isMusicPlaying = true
                
                Log.ui.info("🎵 Music started: \(preset.name)")
            } catch {
                Log.ui.error("Failed to play music \(fileName): \(error)")
                isMusicPlaying = false
            }
        } else {
            Log.ui.warning("Music file not found in bundle: \(fileName)")
            // No bundled file — set state but don't crash
            isMusicPlaying = false
        }
    }
    
    func pauseMusic() {
        musicPlayer?.pause()
        isMusicPlaying = false
    }
    
    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
        isMusicPlaying = false
    }
    
    /// Update the playback volume (called when slider changes).
    func updateMusicVolume(_ volume: Double) {
        normalVolume = Float(volume)
        if !(isDuckingEnabled && isRecordingChapter) {
            musicPlayer?.volume = normalVolume
        }
    }
    
    /// Animate volume change for ducking.
    private func setMusicVolume(_ target: Float, animated: Bool) {
        if animated {
            // Smooth fade over 0.3s
            let steps = 10
            let stepDuration = 0.03
            let current = musicPlayer?.volume ?? normalVolume
            let delta = (target - current) / Float(steps)
            
            for i in 0..<steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                    self?.musicPlayer?.volume = current + delta * Float(i + 1)
                }
            }
        } else {
            musicPlayer?.volume = target
        }
    }
    
    /// Called when the selected music preset changes.
    func onMusicPresetChanged() {
        stopMusic()
        if selectedMusic?.fileName != nil {
            playMusic()
        }
    }
    
    // MARK: - Video Merging
    
    /// Merge all recorded chapter videos into a single output file using AVMutableComposition.
    func mergeChapterVideos() async throws -> URL {
        let videoURLs = chapters.compactMap(\.videoURL)
        
        guard !videoURLs.isEmpty else {
            throw ClipError.invalidVideo
        }
        
        // If only one chapter, return it directly
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
            throw ClipError.invalidVideo
        }
        
        var currentTime = CMTime.zero
        
        for url in videoURLs {
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            // Add video track
            if let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
                
                // Apply the first video's transform to maintain orientation
                if currentTime == .zero {
                    let transform = try await sourceVideoTrack.load(.preferredTransform)
                    videoTrack.preferredTransform = transform
                }
            }
            
            // Add audio track (if available)
            if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
            }
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        // Export the composition
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyo_merged_\(UUID().uuidString).mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ClipError.invalidVideo
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            Log.ui.info("✅ Merged \(videoURLs.count) chapters into: \(outputURL)")
            return outputURL
        case .failed:
            let errorMsg = exportSession.error?.localizedDescription ?? "Unknown export error"
            Log.ui.error("❌ Video merge failed: \(errorMsg)")
            throw ClipError.serverError("Video merge failed: \(errorMsg)")
        case .cancelled:
            throw ClipError.serverError("Video export was cancelled")
        default:
            throw ClipError.serverError("Unexpected export status")
        }
    }
    
    // MARK: - Publishing
    
    /// Publish the final clip — merges chapter videos, uploads, and creates the clip via backend.
    func publishClip(cameraManager: EnhancedCameraManager) async {
        guard !clipTitle.isEmpty else {
            publishError = "Please add a title for your clip"
            return
        }
        
        isPublishing = true
        publishProgress = 0.05
        
        do {
            // 1. Merge all chapter videos into one
            publishProgress = 0.1
            let mergedVideoURL = try await mergeChapterVideos()
            
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
                videoURL: mergedVideoURL,
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
            
            // Clean up temporary merged file (not the individual chapters)
            if mergedVideoURL.lastPathComponent.contains("lyo_merged_") {
                try? FileManager.default.removeItem(at: mergedVideoURL)
            }
            
        } catch {
            Log.ui.error("❌ Clip publish failed: \(error)")
            publishError = error.localizedDescription
            haptics.error()
        }
        
        isPublishing = false
    }
    
    // MARK: - Reset
    
    func reset() {
        // Stop music
        stopMusic()
        
        // Stop timers
        stopChapterTimer()
        
        // Clean up chapter video files
        for chapter in chapters {
            if let url = chapter.videoURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        chapters = ChapterSegment.defaultChapters
        activeChapterIndex = 0
        isRecordingChapter = false
        chapterElapsed = 0
        scriptText = ""
        isTeleprompterVisible = false
        isTeleprompterPaused = false
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
    
    deinit {
        chapterTimer?.invalidate()
        musicPlayer?.stop()
    }
}
