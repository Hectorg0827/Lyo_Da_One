import Foundation
import AVFoundation
import Combine

/// Engine responsible for downloading, caching, and playing card audio
/// while exposing real-time amplitude metering to drive the Voice Orb.
@MainActor
public class LyoAudioEngine: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = LyoAudioEngine()
    
    @Published public var currentAmplitude: Float = 0.0
    @Published public var isPlaying: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var meteringTimer: Timer?
    private var playbackCompletion: (() -> Void)?
    
    private let cacheDirectory: URL
    
    private override init() {
        // Setup cache directory in temporary folder
        self.cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("LyoAudioCache")
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        
        super.init()
        
        // Setup audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    /// Pre-fetches audio to the local cache without playing it
    public func prefetchAudio(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let destinationURL = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return // Already cached
        }
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, error in
            guard let localURL = localURL, error == nil else { return }
            try? FileManager.default.moveItem(at: localURL, to: destinationURL)
        }
        task.resume()
    }
    
    /// Plays the audio at the specified URL, downloading it first if necessary.
    public func playAudio(from urlString: String, completion: @escaping () -> Void) {
        stop() // Stop any current playback
        self.playbackCompletion = completion
        
        guard let url = URL(string: urlString) else {
            // If URL is invalid, just complete immediately so the app doesn't hang
            completion()
            return
        }
        
        let destinationURL = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            // Play from cache
            self.startPlayback(fileURL: destinationURL)
        } else {
            // Download and play
            let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, _, error in
                guard let self = self else { return }
                
                if let localURL = localURL, error == nil {
                    try? FileManager.default.moveItem(at: localURL, to: destinationURL)
                    Task { @MainActor in
                        self.startPlayback(fileURL: destinationURL)
                    }
                } else {
                    Task { @MainActor in
                        self.playbackCompletion?()
                        self.playbackCompletion = nil
                    }
                }
            }
            task.resume()
        }
    }
    
    public func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentAmplitude = 0.0
        meteringTimer?.invalidate()
        meteringTimer = nil
        
        // Call the completion if it was interrupted
        playbackCompletion?()
        playbackCompletion = nil
    }
    
    private func startPlayback(fileURL: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true // Essential for the Voice Orb
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            
            // Start metering at 60fps for smooth visual updates
            meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.updateMetering()
            }
        } catch {
            print("Failed to play audio: \(error)")
            playbackCompletion?()
            playbackCompletion = nil
        }
    }
    
    private func updateMetering() {
        guard let player = audioPlayer, player.isPlaying else { return }
        
        player.updateMeters()
        
        // Power is in decibels ranges from roughly -160 to 0.
        // We normalize it to a 0.0 - 1.0 scale for easy visual multiplication.
        let powerCount = player.averagePower(forChannel: 0)
        
        // A simple linear mapping for demonstration (-50dB to 0dB -> 0.0 to 1.0)
        let minDb: Float = -50.0
        var normalized = max(0.0, powerCount - minDb) / abs(minDb)
        normalized = min(1.0, normalized)
        
        // Add a smooth falloff to make it look organic
        currentAmplitude = currentAmplitude * 0.7 + normalized * 0.3
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentAmplitude = 0.0
            self.meteringTimer?.invalidate()
            self.meteringTimer = nil
            
            self.playbackCompletion?()
            self.playbackCompletion = nil
        }
    }
}
