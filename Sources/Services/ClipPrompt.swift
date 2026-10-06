import Foundation

// MARK: - Teach-it prompt
//
// What the app says when a learner finishes something, and how long the clip
// it is asking for may run.
//
// A new video feed's hardest problem is supply, not demand: an empty Discover
// is a dead Discover. Finishing a lesson is the one moment a learner has
// something specific to say and feels good enough to say it, and the app
// already knows what they just covered — so the invitation can name it
// instead of asking into the void.
//
// Pure strings and numbers, no view and no network, for the same reason
// `FocusPresentation` is: three platforms show this copy and cap this
// recording, and three copies of a sentence drift.

enum ClipPrompt {

    /// How long a single-take clip may run, in seconds.
    ///
    /// Shared with the recorder, so the invitation cannot promise a length the
    /// camera will not allow. The guided four-chapter studio still exists for
    /// anyone who wants it; this is the number the one-tap path uses.
    static let quickTakeSeconds = 60

    /// What the finish screen offers.
    static let callToAction = "Teach it"

    /// The sentence above the button.
    ///
    /// A known topic is named, because "teach Organic Chemistry" is a far
    /// easier thing to act on than "teach something". An unknown one is not
    /// invented — the generic line is used instead, since a prompt that
    /// confidently names the wrong course is worse than one that names none.
    static func invitation(topic: String?) -> String {
        if let topic = trimmed(topic) {
            return "You just finished \(topic). Teach it in \(quickTakeSeconds) seconds?"
        }
        return "Teach what you just learned in \(quickTakeSeconds) seconds?"
    }

    /// The title the composer opens with, or nil to leave it empty.
    ///
    /// Nil rather than a placeholder when the topic is unknown: a title the
    /// learner did not write and did not mean is published under their name.
    static func draftTitle(topic: String?) -> String? {
        guard let topic = trimmed(topic) else { return nil }
        return "What I learned about \(topic)"
    }

    /// The subject the composer tags the clip with, or nil when unknown.
    static func draftSubject(topic: String?) -> String? {
        trimmed(topic)
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
