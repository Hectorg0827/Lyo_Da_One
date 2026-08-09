import Foundation
import AVFoundation
import NaturalLanguage
import os

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()

    @Published var isSpeaking: Bool = false
    var onSpeechFinished: (() -> Void)?

    private let repository: TTSRepository = DefaultTTSRepository()
    private var speechQueue: [(text: String, language: String)] = []
    private var playbackTask: Task<Void, Never>?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playbackObserver: NSObjectProtocol?
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

        speechQueue.append(contentsOf: speechChunks(cleanText).map { ($0, language) })
        startPlaybackIfNeeded()
    }

    func stop() {
        speechQueue.removeAll()
        playbackTask?.cancel()
        playbackTask = nil
        cancelActivePlayback()
        deviceFallbackSynthesizer.stopSpeaking(at: .immediate)
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

            let item = speechQueue.removeFirst()
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
        }

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

    private func playLocalizedDeviceFallback(
        text: String,
        language: String
    ) async throws {
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
            deviceFallbackSynthesizer.stopSpeaking(at: .immediate)
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

    /// The shared voice accepts short teaching turns. Chunk long chat replies
    /// at natural boundaries so Listen keeps the same Kokoro voice instead of
    /// dropping immediately to device speech for responses over 1,200 chars.
    private func speechChunks(_ text: String, limit: Int = 1_100) -> [String] {
        var remaining = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var chunks: [String] = []

        while remaining.count > limit {
            let hardBoundary = remaining.index(remaining.startIndex, offsetBy: limit)
            let window = remaining[..<hardBoundary]
            let naturalBoundary = window.lastIndex(where: { character in
                character == "." || character == "!" || character == "?" ||
                    character == ";" || character == "," || character.isWhitespace
            })
            let splitIndex = naturalBoundary.map { remaining.index(after: $0) } ?? hardBoundary
            let chunk = String(remaining[..<splitIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !chunk.isEmpty { chunks.append(chunk) }
            remaining = String(remaining[splitIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !remaining.isEmpty { chunks.append(remaining) }
        return chunks
    }
}
