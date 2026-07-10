import Foundation

/// Stage B1 — server-backed per-user learning profile.
///
/// Mirrors `lyo_app/learning_profile/schemas.py::LearningProfileRead`.
/// Used by `LyoAIViewModel` on chat startup to seed Lyo's prompt context
/// with what the user has worked on so the chat doesn't feel amnesiac
/// across sessions.
struct LearningProfile: Codable, Equatable {
    let userId: Int
    let knownSubjects: [String]
    let struggleTopics: [String]

    let lastClassroomTopic: String?
    let lastClassroomSessionId: String?
    let lastClassroomAt: Date?

    let totalClassroomSessions: Int

    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId, knownSubjects, struggleTopics
        case lastClassroomTopic, lastClassroomSessionId, lastClassroomAt
        case totalClassroomSessions
        case createdAt, updatedAt
    }

    /// True when the profile has any signal worth surfacing to the user.
    /// Empty profiles (first-ever launch) shouldn't trigger context-aware
    /// greetings — they should fall back to the default welcome.
    var hasContext: Bool {
        !knownSubjects.isEmpty
        || !struggleTopics.isEmpty
        || lastClassroomTopic != nil
    }
}

/// Partial-update payload sent to PATCH /api/v1/me/learning_profile.
/// Any nil field is left unchanged on the server.
struct LearningProfileUpdate: Codable {
    var knownSubjects: [String]? = nil
    var struggleTopics: [String]? = nil
    var lastClassroomTopic: String? = nil
    var lastClassroomSessionId: String? = nil
    /// When true, the server stamps `last_classroom_at = now()` and
    /// increments `total_classroom_sessions`.
    var recordClassroomSession: Bool = false
}
