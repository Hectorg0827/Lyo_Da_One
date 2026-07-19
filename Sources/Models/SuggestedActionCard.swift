import Foundation

/// Stage A — chat-side learning nudge.
///
/// Built locally by `IntentClassifier` after the AI replies. Renders as a
/// compact glass card under Lyo's message offering the most appropriate
/// next learning experience for the detected intent.
///
/// Stage A intentionally produces only **two kinds**: a guided lesson
/// shortcut and a study-plan card. Stage B will introduce more.
struct SuggestedActionCard: Codable, Equatable, Identifiable {
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let primaryLabel: String
    let chips: [String]
    let payload: Payload

    enum Kind: String, Codable {
        case guidedLesson  // "Want a guided lesson on this?"
        case studyPlan     // "Build a study plan for your test?"
    }

    /// Whatever data the primary action / chip taps need to act on.
    /// Kept loose (string dict) so we don't need a new payload schema
    /// for every variant. The view-model's tap handler unpacks per kind.
    struct Payload: Codable, Equatable {
        var topic: String?
        var subject: String?
        var deadline: String?
        var topics: [String]
    }
}
