import Foundation
import os

/// Client for the friend-challenge API (quiz duels with a scoreboard).
final class ChallengeService {
    static let shared = ChallengeService()
    private init() {}

    private struct CreateBody: Encodable {
        let topic: String
        let questions: [ChallengeQuestion]
    }

    private struct AttemptBody: Encodable {
        let score: Int
        let total: Int
        let secondsTaken: Double?

        enum CodingKeys: String, CodingKey {
            case score, total
            case secondsTaken = "seconds_taken"
        }
    }

    /// Creates a challenge from lesson quiz content; returns it with the share code.
    func create(topic: String, questions: [ChallengeQuestion]) async throws -> FriendChallenge {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/challenges",
            method: .post,
            body: CreateBody(topic: topic, questions: questions)
        )
        return try await NetworkClient.shared.request(endpoint)
    }

    func fetch(code: String) async throws -> FriendChallenge {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/challenges/\(code)",
            method: .get
        )
        return try await NetworkClient.shared.request(endpoint)
    }

    /// Records an attempt (latest per user wins) and returns the scoreboard.
    func submit(code: String, score: Int, total: Int, secondsTaken: Double?) async throws -> ChallengeScoreboard {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/challenges/\(code)/attempts",
            method: .post,
            body: AttemptBody(score: score, total: total, secondsTaken: secondsTaken)
        )
        return try await NetworkClient.shared.request(endpoint)
    }

    func scoreboard(code: String) async throws -> ChallengeScoreboard {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/challenges/\(code)/scoreboard",
            method: .get
        )
        return try await NetworkClient.shared.request(endpoint)
    }

    /// Share text for a freshly created challenge.
    static func shareMessage(for challenge: FriendChallenge) -> String {
        "🏆 I challenge you: \(challenge.topic)! Beat my score in Lyo → lyoapp://challenge/\(challenge.code) (code: \(challenge.code))"
    }
}
