import Foundation

// MARK: - Friend Challenges
// Shareable quiz duels: created from a lesson's checkpoints, shared by code
// (lyoapp://challenge/<code>), ranked on a scoreboard by score then time.

struct ChallengeQuestion: Codable, Equatable, Identifiable {
    let question: String
    let options: [String]
    let answerIndex: Int

    var id: String { question }

    enum CodingKeys: String, CodingKey {
        case question, options
        case answerIndex = "answer_index"
    }
}

struct FriendChallenge: Codable, Equatable {
    let code: String
    let topic: String
    let creatorName: String?
    let questions: [ChallengeQuestion]

    enum CodingKeys: String, CodingKey {
        case code, topic, questions
        case creatorName = "creator_name"
    }
}

struct ChallengeAttemptResult: Codable, Equatable, Identifiable {
    let userId: Int
    let userName: String?
    let score: Int
    let total: Int
    let secondsTaken: Double?

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case score, total
        case userId = "user_id"
        case userName = "user_name"
        case secondsTaken = "seconds_taken"
    }
}

struct ChallengeScoreboard: Codable, Equatable {
    let code: String
    let topic: String
    let creatorName: String?
    let attempts: [ChallengeAttemptResult]

    enum CodingKeys: String, CodingKey {
        case code, topic, attempts
        case creatorName = "creator_name"
    }
}
