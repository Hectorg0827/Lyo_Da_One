import Foundation
import AVFoundation
import os

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()

    @Published var isSpeaking: Bool = false
    var onSpeechFinished: (() -> Void)?

    private let repository: TTSRepository = DefaultTTSRepository()
    private var speechQueue: [String] = []
    private var playbackTask: Task<Void, Never>?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playbackObserver: NSObjectProtocol?
    private var playbackContinuation: CheckedContinuation<Void, Error>?
    private var currentVoice: TTSVoice = .nova
    private var currentSpeed: Double = 0.96

    override init() {
        super.init()

        do {
            try configureAudioSession(active: false)
        } catch {
            Log.audio.error("Failed to configure audio session: \(error)")
        }
    }

    func setEmotion(_ emotion: String) {
        switch emotion.lowercased() {
        case "warm":
            currentVoice = .nova
            currentSpeed = 0.94
        case "excited":
            currentVoice = .shimmer
            currentSpeed = 1.02
        case "frustrated":
            currentVoice = .alloy
            currentSpeed = 0.9
        case "confused":
            currentVoice = .nova
            currentSpeed = 0.88
        default:
            currentVoice = .nova
            currentSpeed = 0.96
        }
    }

    func speak(text: String) {
        stop()
        enqueue(text)
    }

    func enqueue(_ text: String) {
        let cleanText = prepareSpeechText(text)
        guard !cleanText.isEmpty else { return }

        speechQueue.append(cleanText)
        startPlaybackIfNeeded()
    }

    func stop() {
        speechQueue.removeAll()
        playbackTask?.cancel()
        playbackTask = nil
        cancelActivePlayback()
        isSpeaking = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            Log.audio.error("Failed to deactivate audio session: \(error)")
        }
    }

    private func startPlaybackIfNeeded() {
        guard playbackTask == nil else { return }

        playbackTask = Task { [weak self] in
            await self?.processQueue()
        }
    }

    private func processQueue() async {
        defer { playbackTask = nil }

        while !Task.isCancelled {
            guard !speechQueue.isEmpty else { break }

            let text = speechQueue.removeFirst()
            isSpeaking = true

            do {
                try await playGeneratedSpeech(for: text)
            } catch is CancellationError {
                break
            } catch {
                Log.audio.error("Backend TTS playback failed: \(error)")
            }
        }

        let finishedNaturally = !Task.isCancelled && speechQueue.isEmpty
        isSpeaking = false
        cleanupPlayer()

        if finishedNaturally {
            onSpeechFinished?()
        }
    }

    private func playGeneratedSpeech(for text: String) async throws {
        let result = try await repository.generate(
            text: text,
            voice: currentVoice,
            speed: currentSpeed,
            withTimings: false
        )

        guard !Task.isCancelled else { throw CancellationError() }
        guard let url = URL(string: result.audioURL) else {
            throw LyoError.network(.invalidURL)
        }

        try await playAudio(url: url)
    }

    private func playAudio(url: URL) async throws {
        try configureAudioSession(active: true)
        cleanupPlayer(keepSessionActive: true)

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        self.playerItem = item
        self.player = player

        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                playbackContinuation = continuation
                playbackObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.resumePlaybackContinuation()
                    }
                }
                player.play()
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelActivePlayback()
            }
        })

        cleanupPlayer(keepSessionActive: true)
    }

    private func resumePlaybackContinuation() {
        guard let continuation = playbackContinuation else { return }
        playbackContinuation = nil
        removePlaybackObserver()
        continuation.resume()
    }

    private func cancelActivePlayback() {
        player?.pause()
        player = nil
        playerItem = nil

        if let continuation = playbackContinuation {
            playbackContinuation = nil
            removePlaybackObserver()
            continuation.resume(throwing: CancellationError())
        } else {
            removePlaybackObserver()
        }
    }

    private func cleanupPlayer(keepSessionActive: Bool = false) {
        player?.pause()
        player = nil
        playerItem = nil
        removePlaybackObserver()

        if !keepSessionActive {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                Log.audio.error("Failed to deactivate audio session: \(error)")
            }
        }
    }

    private func removePlaybackObserver() {
        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
            self.playbackObserver = nil
        }
    }

    private func configureAudioSession(active: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowAirPlay])
        if active {
            try session.setActive(true)
        }
    }

    private func prepareSpeechText(_ raw: String) -> String {
        var clean = raw
        clean = clean.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"#{1,6}\s*"#, with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"`(.+?)`"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"__(.+?)__"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"_(.+?)_"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"(?m)^[\-\*\+]\s+"#, with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"(?m)^\d+\.\s+"#, with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"\n+"#, with: " ", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
