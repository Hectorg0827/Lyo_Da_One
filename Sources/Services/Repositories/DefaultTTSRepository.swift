import Foundation

// MARK: - Default TTS Repository
class DefaultTTSRepository: TTSRepository {

    private let networkClient = NetworkClient.shared
    private let logger = NetworkLogger()

    init() {}

    // MARK: - TTS Generation

    func generate(text: String, voice: TTSVoice = .nova, speed: Double = 1.0, withTimings: Bool = true) async throws -> TTSResult {
        let result: TTSResult = try await networkClient.request(
            Endpoints.TTS.generate(text: text, voice: voice, speed: speed, withTimings: withTimings),
            cachePolicy: .default // Cache TTS for 2 hours
        )

        logger.log("✅ TTS generated: \(result.duration ?? 0)s")
        return result
    }

    func batchGenerate(texts: [String], voice: TTSVoice = .nova) async throws -> [TTSResult] {
        struct BatchResponse: Codable {
            let results: [TTSResult]
        }

        let response: BatchResponse = try await networkClient.request(
            Endpoints.TTS.batch(texts: texts, voice: voice),
            cachePolicy: .default
        )

        logger.log("✅ Batch TTS generated: \(response.results.count) audios")
        return response.results
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
