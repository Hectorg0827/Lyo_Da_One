//
//  AudioPlaybackService.swift
//  Lyo
//
//  Service for playing TTS audio and managing audio playback
//

import Foundation
import AVFoundation
import os

/// Service for playing TTS audio and managing audio playback
@MainActor
class AudioPlaybackService: ObservableObject {
    static let shared = AudioPlaybackService()
    
    // MARK: - Published State
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isLoading = false
    @Published var currentProgress: Double = 0
    @Published var duration: TimeInterval = 0
    @Published var currentMessageId: String?
    @Published var error: AudioPlaybackError?
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var audioCache: [String: URL] = [:] // Cache TTS audio URLs
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay])
        } catch {
            Log.audio.error("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - TTS Playback
    
    /// Play text-to-speech for a message
    func playTTS(text: String, messageId: String, voice: TTSVoice = .nova) async {
        // Stop any current playback
        stop()
        
        currentMessageId = messageId
        isLoading = true
        error = nil
        
        // Check cache first
        let cacheKey = "\(text.hashValue)_\(voice.rawValue)"
        if let cachedURL = audioCache[cacheKey] {
            await playAudioFile(url: cachedURL)
            return
        }
        
        do {
            // Request TTS from backend
            let audioData = try await requestTTS(text: text, voice: voice)
            
            // Save to temp file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tts_\(UUID().uuidString).mp3")
            try audioData.write(to: tempURL)
            
            // Cache it
            audioCache[cacheKey] = tempURL
            
            // Play
            await playAudioFile(url: tempURL)
            
        } catch {
            Log.audio.error("TTS Error: \(error)")
            self.error = .ttsGenerationFailed(error.localizedDescription)
            isLoading = false
        }
    }
    
    /// Request TTS audio from backend
    private func requestTTS(text: String, voice: TTSVoice) async throws -> Data {
        let endpoint = Endpoints.TTS.generate(text: text, voice: voice, speed: 1.0, withTimings: false)
        return try await NetworkClient.shared.requestRawData(endpoint)
    }
    
    /// Play an audio file
    private func playAudioFile(url: URL) async {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            
            playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            
            // Observe duration
            if let duration = try? await playerItem?.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
            }
            
            // Add time observer for progress
            timeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                Task { @MainActor [weak self] in
                    guard let self = self, self.duration > 0 else { return }
                    self.currentProgress = CMTimeGetSeconds(time) / self.duration
                }
            }
            
            // Observe end of playback
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.stop()
                }
            }
            
            player?.play()
            isPlaying = true
            isPaused = false
            isLoading = false
            
            HapticManager.shared.playLightImpact()
            Log.audio.info("TTS playback started")
            
        } catch {
            Log.audio.error("Failed to play audio: \(error)")
            self.error = .playbackFailed(error.localizedDescription)
            isLoading = false
        }
    }
    
    // MARK: - Playback Controls
    
    func pause() {
        player?.pause()
        isPlaying = false
        isPaused = true
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        isPaused = false
    }
    
    func stop() {
        player?.pause()
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        player = nil
        playerItem = nil
        isPlaying = false
        isPaused = false
        isLoading = false
        currentProgress = 0
        duration = 0
        currentMessageId = nil
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func seek(to progress: Double) {
        guard let duration = playerItem?.duration else { return }
        let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: progress)
        player?.seek(to: targetTime)
    }
    
    // MARK: - Play Audio URL
    
    /// Play audio from a URL (for audio messages)
    func playAudioURL(_ url: URL, messageId: String) async {
        stop()
        
        currentMessageId = messageId
        isLoading = true
        
        await playAudioFile(url: url)
    }
    
    /// Play audio from a remote URL string
    func playRemoteAudio(_ urlString: String, messageId: String) async {
        guard let url = URL(string: urlString) else {
            error = .playbackFailed("Invalid URL")
            return
        }
        
        await playAudioURL(url, messageId: messageId)
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        for url in audioCache.values {
            try? FileManager.default.removeItem(at: url)
        }
        audioCache.removeAll()
    }
    
    /// Get cache size in bytes
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        for url in audioCache.values {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
}

// MARK: - Errors

enum AudioPlaybackError: LocalizedError {
    case ttsGenerationFailed(String)
    case playbackFailed(String)
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .ttsGenerationFailed(let message):
            return "TTS generation failed: \(message)"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        case .serverError:
            return "Server error"
        }
    }
}
