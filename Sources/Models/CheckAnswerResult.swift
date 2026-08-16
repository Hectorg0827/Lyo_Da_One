import Foundation

/// Server verdict for an answered in-chat check.
///
/// Mirrors the backend's `CheckAnswerResponse` (lyo_app/api/v1/stream_lyo2.py)
/// and web's `CheckAnswerResult` (web/src/types/index.ts). The client renders
/// this — it never computes `correct` itself, and `correct_index` on the wire
/// is present for display only *after* a verdict exists, never used to grade.
public struct CheckAnswerResult: Codable, Equatable, Sendable {
    public let correct: Bool
    public let correctIndex: Int
    /// Echoed back so the chosen option can be highlighted after a reload.
    public let selectedIndex: Int
    public let explanation: String?
    /// The confusion this particular wrong answer reveals, when known.
    public let misconception: String?
    public let bailedOut: Bool
    public let skillId: String?
    public let mastery: Double?

    enum CodingKeys: String, CodingKey {
        case correct
        case correctIndex = "correct_index"
        case selectedIndex = "selected_index"
        case explanation
        case misconception
        case bailedOut = "bailed_out"
        case skillId = "skill_id"
        case mastery
    }
}

/// A learner's answer to an in-chat check, sent to the server for grading.
///
/// Deliberately carries neither the question nor the answer key — the server
/// reads those back from the block it already emitted, so the client cannot
/// assert its own correctness. Mirrors `CheckAnswerRequest` server-side.
public struct CheckAnswerRequest: Encodable, Sendable {
    public let conversationId: String
    public let blockId: String
    public let selectedIndex: Int
    public let timeTakenMs: Int
    public let hintUsed: Bool

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case blockId = "block_id"
        case selectedIndex = "selected_index"
        case timeTakenMs = "time_taken_ms"
        case hintUsed = "hint_used"
    }

    public init(
        conversationId: String,
        blockId: String,
        selectedIndex: Int,
        timeTakenMs: Int = 0,
        hintUsed: Bool = false
    ) {
        self.conversationId = conversationId
        self.blockId = blockId
        self.selectedIndex = selectedIndex
        self.timeTakenMs = timeTakenMs
        self.hintUsed = hintUsed
    }
}
