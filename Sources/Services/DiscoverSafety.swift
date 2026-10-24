import Foundation

/// Why a learner reports a Discover video. Each is a reason the API stores
/// (POST /api/v1/clips/{id}/report); the labels match the web sheet.
///
/// Mirrors web `discover-report.mjs` and Android `DiscoverSafety.kt`;
/// `scripts/verify-discover-safety-parity.mjs` holds the three to the same
/// reasons, labels and messages.
enum DiscoverReportReason: String, CaseIterable, Identifiable {
    case sexualContent = "sexual_content"
    case violence = "violence"
    case harassment = "harassment"
    case spam = "spam"
    case misinformation = "misinformation"
    case copyright = "copyright"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sexualContent: return "Sexual or inappropriate"
        case .violence: return "Violent or dangerous"
        case .harassment: return "Hate or bullying"
        case .spam: return "Spam or misleading"
        case .misinformation: return "Wrong or false science"
        case .copyright: return "Copyright"
        case .other: return "Something else"
        }
    }
}

/// Reporting a Discover video and blocking the person who posted it.
///
/// A reported video leaves the reporter's feed at once, and three reports
/// from different learners hide it until a moderator decides. A block
/// (POST /api/v1/community/blocks) hides both people from each other in
/// Discover: videos, comments and every action on them.
enum DiscoverSafety {
    /// The longest note the API accepts with a report.
    static let noteLimit = 1000

    /// What a finished report or block came to. For a report, `succeeded`
    /// means the video leaves the feed; for a block, the person is blocked.
    struct Outcome: Equatable {
        let succeeded: Bool
        let message: String
    }

    /// A learner cannot report their own video; the API refuses it. When
    /// either id is unknown the button stays, and the server decides.
    static func canReport(ownerId: String?, viewerId: String?) -> Bool {
        guard let ownerId, !ownerId.isEmpty, let viewerId, !viewerId.isEmpty else { return true }
        return ownerId != viewerId
    }

    /// Blocking needs an owner who is someone else; with either id unknown it
    /// is not offered. Library videos are uploaded by Lyo's own account and
    /// credited to their source, so blocking that account would empty the
    /// library: it is not offered there either.
    static func canBlock(ownerId: String?, viewerId: String?, isLibrary: Bool) -> Bool {
        guard !isLibrary, let ownerId, !ownerId.isEmpty, let viewerId, !viewerId.isEmpty else { return false }
        return ownerId != viewerId
    }

    /// Reported (201) and already reported (200) take the video out of the
    /// feed, as does 404: it is gone or already hidden. Anything else is a
    /// failure the learner can retry, and the video stays.
    static func reportOutcome(status: Int) -> Outcome {
        switch status {
        case 200, 201: return Outcome(succeeded: true, message: "Thanks. We'll review this video.")
        case 404: return Outcome(succeeded: true, message: "This video is no longer available.")
        default: return Outcome(succeeded: false, message: "Your report couldn't be sent. Please try again.")
        }
    }

    /// Blocked (201) takes every video by that person out of the feed; 404
    /// means the account is gone. Anything else can be retried.
    static func blockOutcome(status: Int, name: String) -> Outcome {
        switch status {
        case 200, 201:
            return Outcome(succeeded: true, message: "Blocked \(name). You won't see each other's videos or comments.")
        case 404:
            return Outcome(succeeded: false, message: "This account no longer exists.")
        default:
            return Outcome(succeeded: false, message: "Couldn't block this account. Please try again.")
        }
    }

    /// The pages to request for feed page `page` after `removed` loaded
    /// videos left the feed by a report or a block. The server stops sending
    /// them, so every later page starts that many places earlier; asking for
    /// the page before too, and skipping duplicates, keeps none from being
    /// skipped.
    static func pagesToFetch(page: Int, removed: Int, perPage: Int) -> [Int] {
        let back = (max(0, removed) + perPage - 1) / perPage
        let first = max(1, page - back)
        return Array(first...max(first, page))
    }
}

/// One account the learner blocked (GET /api/v1/community/blocks). The
/// shared decoder turns `user_id` and `user_name` into these names.
struct BlockedAccount: Decodable, Identifiable, Equatable {
    let userId: Int
    let userName: String

    var id: Int { userId }
}
