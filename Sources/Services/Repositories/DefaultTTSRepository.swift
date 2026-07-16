import Foundation

// MARK: - Backend /api/v1/tts/synthesize response shape
private struct BackendTTSResponse: Codable {
    let audio_base64: String
    let voice: String
    let format: String
    let duration_estimate_seconds: Double
}

// MARK: - Default TTS Repository
class DefaultTTSRepository: TTSRepository {

    private let networkClient = NetworkClient.shared
    private let logger = NetworkLogger()

    init() {}

    // MARK: - TTS Generation

    /// Synthesize text via the backend and return a `TTSResult` whose `audioURL`
    /// is a local `file://` URL suitable for AVPlayer.
    func generate(text: String, voice: TTSVoice = .nova, speed: Double = 1.0, withTimings: Bool = true) async throws -> TTSResult {
        // 1. Call backend — returns { audio_base64, voice, format, duration_estimate_seconds }
        let response: BackendTTSResponse = try await networkClient.request(
            Endpoints.TTS.generate(text: text, voice: voice, speed: speed, withTimings: withTimings),
            cachePolicy: .default
        )

        // 2. Decode base64 → Data
        guard let audioData = Data(base64Encoded: response.audio_base64) else {
            logger.log("❌ TTS: base64 decode failed")
            throw LyoError.network(.invalidResponse)
        }

        // 3. Write to a uniquely-named temp file so AVPlayer can stream it
        let filename = "tts_\(UUID().uuidString.prefix(8)).\(response.format)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try audioData.write(to: tempURL)

        let result = TTSResult(
            id: UUID().uuidString,
            audioURL: tempURL.absoluteString,
            timingsURL: nil,
            duration: response.duration_estimate_seconds,
            cost: nil
        )

        logger.log("✅ TTS generated: \(result.duration ?? 0)s — \(filename)")
        return result
    }

    /// Generate audio for multiple texts by calling the synthesize endpoint in
    /// parallel (the backend has no native batch endpoint at /api/v1/tts).
    func batchGenerate(texts: [String], voice: TTSVoice = .nova) async throws -> [TTSResult] {
        return try await withThrowingTaskGroup(of: TTSResult.self) { group in
            for text in texts {
                group.addTask { [self] in
                    try await self.generate(text: text, voice: voice, speed: 1.0, withTimings: false)
                }
            }
            var results: [TTSResult] = []
            for try await result in group {
                results.append(result)
            }
            logger.log("✅ Batch TTS generated: \(results.count) audios")
            return results
        }
    }

    func getAudioURL(id: String) async throws -> URL {
        struct AudioResponse: Codable {
            let audioURL: String

            enum CodingKeys: String, CodingKey {
                case audioURL = "audio_url"
            }
        }

        let response: AudioResponse = try await networkClient.request(
            Endpoints.TTS.getAudio(id: id),
            cachePolicy: .default
        )

        guard let url = URL(string: response.audioURL) else {
            throw LyoError.network(.invalidURL)
        }

        logger.log("✅ Audio URL retrieved: \(id)")
        return url
    }

    func getTimings(id: String) async throws -> [WordTiming] {
        struct TimingsResponse: Codable {
            let timings: [WordTiming]
        }

        let response: TimingsResponse = try await networkClient.request(
            Endpoints.TTS.getTimings(id: id),
            cachePolicy: .default
        )

        logger.log("✅ Word timings retrieved: \(response.timings.count) words")
        return response.timings
    }

    func getVoices() async throws -> [Voice] {
        struct VoicesResponse: Codable {
            let voices: [Voice]
        }

        let response: VoicesResponse = try await networkClient.request(
            Endpoints.TTS.voices,
            cachePolicy: .default // Cache for 1 hour
        )

        logger.log("✅ Voices fetched: \(response.voices.count)")
        return response.voices
    }
}

// MARK: - Mock TTS Repository
class MockTTSRepository: TTSRepository {

    func generate(text: String, voice: TTSVoice, speed: Double, withTimings: Bool) async throws -> TTSResult {
        try await Task.sleep(nanoseconds: 800_000_000)
        return TTSResult(
            id: UUID().uuidString,
            audioURL: "https://example.com/audio/mock.mp3",
            timingsURL: withTimings ? "https://example.com/timings/mock.json" : nil,
            duration: Double(text.count) / 10.0, // Rough estimate
            cost: 0.002
        )
    }

    func batchGenerate(texts: [String], voice: TTSVoice) async throws -> [TTSResult] {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        return texts.map { text in
            TTSResult(
                id: UUID().uuidString,
                audioURL: "https://example.com/audio/mock_\(UUID().uuidString).mp3",
                timingsURL: "https://example.com/timings/mock_\(UUID().uuidString).json",
                duration: Double(text.count) / 10.0,
                cost: 0.002
            )
        }
    }

    func getAudioURL(id: String) async throws -> URL {
        try await Task.sleep(nanoseconds: 200_000_000)
        return URL(string: "https://example.com/audio/\(id).mp3")!
    }

    func getTimings(id: String) async throws -> [WordTiming] {
        try await Task.sleep(nanoseconds: 300_000_000)
        let words = ["Hello", "world", "this", "is", "mock", "timing"]
        return words.enumerated().map { index, word in
            WordTiming(
                word: word,
                startMs: index * 500,
                endMs: (index + 1) * 500
            )
        }
    }

    func getVoices() async throws -> [Voice] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return [
            Voice(
                id: "alloy",
                name: "Alloy",
                language: "en-US",
                gender: "neutral",
                previewURL: "https://example.com/preview/alloy.mp3"
            ),
            Voice(
                id: "echo",
                name: "Echo",
                language: "en-US",
                gender: "male",
                previewURL: "https://example.com/preview/echo.mp3"
            ),
            Voice(
                id: "nova",
                name: "Nova",
                language: "en-US",
                gender: "female",
                previewURL: "https://example.com/preview/nova.mp3"
            )
        ]
    }
}
