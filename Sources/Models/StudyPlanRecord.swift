import Foundation

/// Stage B2 — server-backed study plan.
///
/// Mirrors `lyo_app/study_plans/schemas.py::StudyPlanRecordRead`.
struct StudyPlanRecord: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    let subject: String
    let topics: [String]
    let deadline: String?
    let dailyBreakdown: [String]
    let status: Status
    let sourceConversationId: String?

    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?

    enum Status: String, Codable {
        case active
        case completed
        case abandoned
    }

    /// One-line summary suitable for inclusion in a chat-context line.
    var contextLine: String {
        var parts = ["Active study plan: \(subject)"]
        if let deadline { parts.append("by \(deadline)") }
        if !topics.isEmpty {
            parts.append("(topics: \(topics.prefix(3).joined(separator: ", ")))")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Write payloads

struct StudyPlanRecordCreate: Codable {
    var subject: String
    var topics: [String] = []
    var deadline: String? = nil
    var dailyBreakdown: [String] = []
    var sourceConversationId: String? = nil
}

struct StudyPlanRecordUpdate: Codable {
    var subject: String? = nil
    var topics: [String]? = nil
    var deadline: String? = nil
    var dailyBreakdown: [String]? = nil
    var status: StudyPlanRecord.Status? = nil
}
