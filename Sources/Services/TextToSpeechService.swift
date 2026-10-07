import Foundation
import AVFoundation
import NaturalLanguage
import os

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()

    @Published var isSpeaking: Bool = false
    var onSpeechFinished: (() -> Void)?

    private struct SpeechQueueItem {
        let id = UUID()
        let text: String
        let language: String
        let voice: TTSVoice
        let speed: Double
    }

    private struct PrefetchedSpeech {
        let itemID: UUID
        let task: Task<TTSResult, Error>
    }

    private let repository: TTSRepository = DefaultTTSRepository()
    private var speechQueue: [SpeechQueueItem] = []
    /// Exactly one queued segment is rendered ahead while the current segment
    /// is playing. This overlaps network/TTS latency with speech without
    /// creating an unbounded burst against the shared provider.
    private var prefetchedSpeech: PrefetchedSpeech?
    private var playbackGeneration = 0
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

        speechQueue.append(
            SpeechQueueItem(
                text: cleanText,
                language: language,
                voice: currentVoice,
                speed: currentSpeed
            )
        )
        if isSpeaking {
            prefetchNextIfNeeded()
        }
        startPlaybackIfNeeded()
    }

    func stop() {
        playbackGeneration += 1
        speechQueue.removeAll()
        discardPrefetchedSpeech()
        playbackTask?.cancel()
        playbackTask = nil
        cancelActivePlayback()
        deviceFallbackSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false

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
            isSpeaking = true

            do {
                let result = try await generatedResult(for: item)
                guard !Task.isCancelled, generation == playbackGeneration else {
                    throw CancellationError()
                }

                // Render the following phrase while this one is audibly
                // playing. In normal conversation the next canonical segment
                // is therefore ready before AVPlayer reaches the boundary.
                prefetchNextIfNeeded()
                try await playGeneratedSpeech(result)
            } catch is CancellationError {
                break
            } catch {
                Log.audio.error("Backend TTS playback failed: \(error)")
                guard !Task.isCancelled else { break }
                do {
                    try await playLocalizedDeviceFallback(
                        text: item.text,
                        language: item.language,
                        speed: item.speed
                    )
                } catch {
                    Log.audio.error("Localized device TTS fallback failed: \(error)")
                }
            }
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

    private func generatedResult(for item: SpeechQueueItem) async throws -> TTSResult {
        if let prefetched = prefetchedSpeech, prefetched.itemID == item.id {
            prefetchedSpeech = nil
            return try await prefetched.task.value
        }

        return try await repository.generate(
            text: item.text,
            voice: item.voice,
            speed: item.speed,
            withTimings: false,
            language: item.language
        )
    }

    private func discardPrefetchedSpeech() {
        guard let prefetched = prefetchedSpeech else { return }
        prefetchedSpeech = nil
        let task = prefetched.task

        // Always observe the task result, even when stop() races with the last
        // network byte. A completed prefetch owns a temp file until somebody
        // explicitly removes it; cancellation by itself cannot reclaim that.
        Task {
            let result = await task.result
            guard case .success(let speech) = result,
                  let url = URL(string: speech.audioURL),
                  url.isFileURL
            else { return }
            try? FileManager.default.removeItem(at: url)
        }
        task.cancel()
    }

    private func prefetchNextIfNeeded() {
        guard let next = speechQueue.first else { return }
        if prefetchedSpeech?.itemID == next.id { return }

        discardPrefetchedSpeech()
        let task = Task<TTSResult, Error> { [repository] in
            try Task.checkCancellation()
            return try await repository.generate(
                text: next.text,
                voice: next.voice,
                speed: next.speed,
                withTimings: false,
                language: next.language
            )
        }
        prefetchedSpeech = PrefetchedSpeech(itemID: next.id, task: task)
    }

    private func playGeneratedSpeech(_ result: TTSResult) async throws {
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
        language: String,
        speed: Double
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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(speed)
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

        if !keepSessionActive && !VoiceInputService.shared.isRecording {
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
