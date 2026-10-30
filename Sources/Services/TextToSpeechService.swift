import Foundation
import AVFoundation
import NaturalLanguage
import os

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()

    @Published var isSpeaking: Bool = false
    @Published private(set) var liveSpokenText: String = ""
    var onSpeechFinished: (() -> Void)?

    private let repository: TTSRepository = DefaultTTSRepository()
    private var speechQueue: [(text: String, language: String)] = []
    private var playbackGeneration = 0
    private var playbackTask: Task<Void, Never>?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playbackObserver: NSObjectProtocol?
    private var progressObserver: Any?
    private var spokenPrefix = ""
    private var currentSegment = ""
    private var playbackContinuation: CheckedContinuation<Void, Error>?
    private var currentVoice: TTSVoice = .nova
    private var currentSpeed: Double = 0.96
    private let deviceFallbackSynthesizer = AVSpeechSynthesizer()

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

    func speak(text: String, language: String = "auto") {
        stop()
        enqueue(text, language: language)
    }

    func enqueue(_ text: String, language: String = "auto") {
        let cleanText = prepareSpeechText(text)
        guard !cleanText.isEmpty else { return }

        speechQueue.append((cleanText, language))
        startPlaybackIfNeeded()
    }

    func stop() {
        playbackGeneration += 1
        speechQueue.removeAll()
        playbackTask?.cancel()
        playbackTask = nil
        cancelActivePlayback()
        deviceFallbackSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        liveSpokenText = ""
        spokenPrefix = ""
        currentSegment = ""

        if !VoiceInputService.shared.isRecording {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                Log.audio.error("Failed to deactivate audio session: \(error)")
            }
        }
    }

    private func startPlaybackIfNeeded() {
        guard playbackTask == nil else { return }

        let generation = playbackGeneration
        playbackTask = Task { [weak self] in
            await self?.processQueue(generation: generation)
        }
    }

    private func processQueue(generation: Int) async {
        defer {
            if generation == playbackGeneration { playbackTask = nil }
        }

        while !Task.isCancelled && generation == playbackGeneration {
            guard !speechQueue.isEmpty else { break }

            let item = speechQueue.removeFirst()
            currentSegment = item.text
            isSpeaking = true

            do {
                try await playGeneratedSpeech(for: item.text, language: item.language)
            } catch is CancellationError {
                break
            } catch {
                Log.audio.error("Backend TTS playback failed: \(error)")
                guard !Task.isCancelled else { break }
                do {
                    try await playLocalizedDeviceFallback(
                        text: item.text,
                        language: item.language
                    )
                } catch {
                    Log.audio.error("Localized device TTS fallback failed: \(error)")
                }
            }
            guard !Task.isCancelled && generation == playbackGeneration else { break }
            spokenPrefix = (spokenPrefix + " " + currentSegment).trimmingCharacters(in: .whitespacesAndNewlines)
            liveSpokenText = spokenPrefix
        }

        // A canceled turn may finish after a new question has started speech.
        // It must never clear that new task, player, or speaking indicator.
        guard generation == playbackGeneration else { return }
        let finishedNaturally = !Task.isCancelled && speechQueue.isEmpty
        isSpeaking = false
        cleanupPlayer()

        if finishedNaturally {
            onSpeechFinished?()
        }
    }

    private func playGeneratedSpeech(for text: String, language: String) async throws {
        let result = try await repository.generate(
            text: text,
            voice: currentVoice,
            speed: currentSpeed,
            withTimings: false,
            language: language
        )

        guard !Task.isCancelled else { throw CancellationError() }
        guard let url = URL(string: result.audioURL) else {
            throw LyoError.network(.invalidURL)
        }

        defer {
            if url.isFileURL {
                try? FileManager.default.removeItem(at: url)
            }
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
                        guard self?.playerItem === item else { return }
                        self?.resumePlaybackContinuation()
                    }
                }
                progressObserver = player.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.15, preferredTimescale: 600),
                    queue: .main
                ) { [weak self, weak player] time in
                    Task { @MainActor [weak self] in
                        guard let self, self.player === player else { return }
                        let duration = player?.currentItem?.duration.seconds ?? 0
                        guard duration.isFinite, duration > 0 else { return }
                        let fraction = min(1, max(0, time.seconds / duration))
                        let words = self.currentSegment.split(separator: " ")
                        let read = words.prefix(Int(Double(words.count) * fraction)).joined(separator: " ")
                        self.liveSpokenText = (self.spokenPrefix + " " + read)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                player.play()
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                guard self?.playerItem === item else { return }
                self?.cancelActivePlayback()
            }
        })

        cleanupPlayer(keepSessionActive: true)
    }

    private func playLocalizedDeviceFallback(
        text: String,
        language: String
    ) async throws {
        let generation = playbackGeneration
        let detectedFamily = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
        let family = language.lowercased() == "auto"
            ? detectedFamily
            : language.split(separator: "-").first.map(String.init)
        let localeByFamily = [
            "en": "en-US",
            "es": "es-US",
            "fr": "fr-FR",
            "it": "it-IT",
            "pt": "pt-BR",
        ]
        let resolvedLanguage = localeByFamily[family ?? "en"] ?? language
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: resolvedLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(currentSpeed)
        utterance.pitchMultiplier = 1.0
        try Task.checkCancellation()
        deviceFallbackSynthesizer.speak(utterance)

        do {
            while deviceFallbackSynthesizer.isSpeaking {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        } catch {
            if generation == playbackGeneration {
                deviceFallbackSynthesizer.stopSpeaking(at: .immediate)
            }
            throw error
        }
    }

    private func resumePlaybackContinuation() {
        guard let continuation = playbackContinuation else { return }
        playbackContinuation = nil
        removePlaybackObserver()
        continuation.resume()
    }

    private func cancelActivePlayback() {
        removeProgressObserver()
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
        removeProgressObserver()
        player?.pause()
        player = nil
        playerItem = nil
        removePlaybackObserver()

        if !keepSessionActive && !VoiceInputService.shared.isRecording {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                Log.audio.error("Failed to deactivate audio session: \(error)")
            }
        }
    }

    private func removeProgressObserver() {
        if let progressObserver {
            player?.removeTimeObserver(progressObserver)
            self.progressObserver = nil
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
        // Match VoiceInputService so speech playback does not tear down the
        // microphone. This is one full-duplex conversational audio session,
        // with iOS voiceChat echo cancellation doing the acoustic separation.
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
        )
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
