import Foundation
import SwiftUI
import AVFoundation
import Combine

// MARK: - TTS ViewModel
@MainActor
class TTSViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isLoading = false
    @Published var error: LyoError?

    @Published var currentWordIndex: Int?
    @Published var progress: Double = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var totalDuration: TimeInterval = 0.0

    @Published var selectedVoice: TTSVoice = .nova
    @Published var playbackSpeed: Float = 1.0
    @Published var availableVoices: [Voice] = []

    // MARK: - Private Properties

    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var wordTimings: [WordTiming] = []
    private var currentTTSResult: TTSResult?

    private let repository: TTSRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: TTSRepository = DefaultTTSRepository()) {
        self.repository = repository
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - TTS Generation

    func generateSpeech(for text: String) async {
        isLoading = true
        error = nil

        do {
            let result = try await repository.generate(
                text: text,
                voice: selectedVoice,
                speed: Double(playbackSpeed),
                withTimings: true
            )

            currentTTSResult = result
            totalDuration = result.duration ?? 0

            // Load audio
            guard let audioURL = URL(string: result.audioURL) else {
                throw LyoError.network(.invalidURL)
            }

            setupPlayer(with: audioURL)

            // Load word timings
            if let timingsURL = result.timingsURL {
                await loadWordTimings(from: timingsURL)
            } else {
                // Fallback: Load timings using ID
                wordTimings = try await repository.getTimings(id: result.id)
            }

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    private func loadWordTimings(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            wordTimings = try JSONDecoder.lyoDecoder.decode([WordTiming].self, from: data)
        } catch {
            print("Failed to load word timings: \(error)")
        }
    }

    func loadVoices() async {
        do {
            availableVoices = try await repository.getVoices()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Player Setup

    private func setupPlayer(with url: URL) {
        // Clean up existing player
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
        }
        audioPlayer = nil

        // Create new player
        let playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.rate = playbackSpeed

        // Add time observer for progress and word highlighting
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.updateProgress(time: time)
            }
        }

        // Observe player status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    // MARK: - Playback Controls

    func play() {
        guard let player = audioPlayer else { return }

        if isPaused {
            player.play()
            isPaused = false
        } else {
            player.seek(to: .zero)
            player.play()
        }

        isPlaying = true
        player.rate = playbackSpeed
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        isPaused = true
    }

    func stop() {
        audioPlayer?.pause()
        audioPlayer?.seek(to: .zero)
        isPlaying = false
        isPaused = false
        currentWordIndex = nil
        progress = 0
        currentTime = 0
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        audioPlayer?.seek(to: cmTime)
    }

    func changeSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            audioPlayer?.rate = speed
        }
    }

    func changeVoice(_ voice: TTSVoice) {
        selectedVoice = voice
    }

    // MARK: - Progress Tracking

    private func updateProgress(time: CMTime) {
        let seconds = CMTimeGetSeconds(time)
        currentTime = seconds

        if totalDuration > 0 {
            progress = seconds / totalDuration
        }

        // Update current word based on time
        updateCurrentWord(at: seconds)
    }

    private func updateCurrentWord(at timeInSeconds: TimeInterval) {
        let timeInMs = Int(timeInSeconds * 1000)

        // Find the word that should be highlighted at this time
        for (index, timing) in wordTimings.enumerated() {
            if timeInMs >= timing.startMs && timeInMs <= timing.endMs {
                if currentWordIndex != index {
                    currentWordIndex = index
                }
                return
            }
        }

        // If we're past all words, clear highlight
        if let lastTiming = wordTimings.last, timeInMs > lastTiming.endMs {
            currentWordIndex = nil
        }
    }

    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        isPaused = false
        currentWordIndex = nil
        progress = 0
        currentTime = 0
    }

    // MARK: - Word Highlighting

    func getHighlightedText(from text: String) -> [(String, Bool)] {
        // Split text into words
        let words = text.split(separator: " ").map(String.init)

        // Return tuples of (word, isHighlighted)
        return words.enumerated().map { index, word in
            let isHighlighted = (currentWordIndex == index)
            return (word, isHighlighted)
        }
    }

    // MARK: - Batch Generation

    func batchGenerate(texts: [String]) async -> [TTSResult] {
        isLoading = true
        error = nil

        var results: [TTSResult] = []

        do {
            results = try await repository.batchGenerate(texts: texts, voice: selectedVoice)
        } catch {
            handleError(error)
        }

        isLoading = false
        return results
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let lyoError = error as? LyoError {
            self.error = lyoError
        } else {
            self.error = .network(.serverError(500))
        }
    }

    // MARK: - Computed Properties

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedTotalDuration: String {
        formatTime(totalDuration)
    }

    var speedOptions: [Float] {
        [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    }

    var currentSpeedLabel: String {
        if playbackSpeed == 1.0 {
            return "Normal"
        } else {
            return "\(playbackSpeed)x"
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Cleanup

    nonisolated func cleanup() {
        Task { @MainActor in
            stop()
            if let observer = timeObserver {
                audioPlayer?.removeTimeObserver(observer)
            }
            audioPlayer = nil
            NotificationCenter.default.removeObserver(self)
        }
    }

    deinit {
        cleanup()
    }
}

// MARK: - Word Timing Extension
extension WordTiming {
    var durationMs: Int {
        endMs - startMs
    }
}
