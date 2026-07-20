import Foundation

/// Stage A — lightweight on-device intent classifier.
///
/// Looks at the user's *latest* message and returns a learning intent +
/// any easily-extractable entities (subject, deadline phrase, topic list).
/// Pure regex/keyword, no network round-trip, no LLM. Sub-millisecond.
///
/// Stage B will add an LLM fallback for ambiguous inputs (when no rule
/// fires with high enough confidence). For now, ambiguous → `.unknown`,
/// and the chat falls back to plain text + static suggestion chips.
///
/// Types are nested inside the enum to avoid name collisions with the
/// pre-existing `LearningIntent` (LyoOrchestrator) and `ClassifiedIntent`
/// (MessageIntentClassifier) that live elsewhere in the codebase.
enum IntentClassifier {

    enum Intent: String {
        case testPrep         // "I have a test on Tuesday"
        case broadLearning    // "Teach me biology"
        case confusion        // "I don't understand X"
        case quickAnswer      // "What is photosynthesis?"
        case practice         // "Quiz me on cells"
        case unknown          // Nothing matched with confidence
    }

    struct Classification {
        let intent: Intent
        let confidence: Double           // 0.0 ... 1.0
        let subject: String?             // "science", "math", etc. when extractable
        let deadline: String?            // raw phrase: "Tuesday", "next week"
        let topics: [String]             // user-mentioned topics
    }

    /// Classify the latest user message.
    static func classify(_ message: String) -> Classification {
        let normalized = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return Classification(intent: .unknown, confidence: 0,
                                    subject: nil, deadline: nil, topics: [])
        }

        let subject = extractSubject(normalized)
        let deadline = extractDeadline(normalized)
        let topics = extractTopics(normalized)

        // Run rules in priority order. First-match-wins keeps it predictable.

        // 1. Test prep: keyword "test" / "exam" / "quiz on Tuesday" + a deadline phrase
        //    OR study verbs ("study", "prepare").
        if matchesAny(normalized, [
            "test on", "test next", "test this", "test tomorrow",
            "exam on", "exam next", "exam this", "exam tomorrow",
            "have a test", "have an exam", "have a quiz",
            "i have to study", "help me study", "need to study",
            "study for", "studying for", "preparing for",
            "i'm behind", "im behind", "catching up", "catch up",
            "midterm", "final exam", "finals are",
        ]) {
            return Classification(
                intent: .testPrep,
                confidence: deadline != nil ? 0.95 : 0.80,
                subject: subject,
                deadline: deadline,
                topics: topics
            )
        }

        // 2. Confusion: explicit "don't understand" / "can you explain"
        if matchesAny(normalized, [
            "don't understand", "dont understand", "don't get",
            "dont get this", "doesn't make sense", "doesnt make sense",
            "confused about", "confusing", "lost on",
            "can you explain", "explain it", "explain that",
            "step by step", "step-by-step", "break it down",
            "i'm stuck", "im stuck", "stuck on",
        ]) {
            return Classification(
                intent: .confusion,
                confidence: 0.85,
                subject: subject,
                deadline: nil,
                topics: topics
            )
        }

        // 3. Practice: explicit "quiz me", "test me", "give me practice"
        if matchesAny(normalized, [
            "quiz me", "test me", "give me practice", "practice me",
            "ask me questions", "drill me", "flashcards on",
            "make flashcards", "review me",
        ]) {
            return Classification(
                intent: .practice,
                confidence: 0.90,
                subject: subject,
                deadline: nil,
                topics: topics
            )
        }

        // 4. Broad learning: "teach me", "I want to learn", whole-subject scope
        if matchesAny(normalized, [
            "teach me", "i want to learn", "learn about",
            "from the beginning", "from scratch", "the whole",
            "an entire", "all of", "comprehensive",
            "build a course", "create a course", "make a course",
        ]) {
            return Classification(
                intent: .broadLearning,
                confidence: 0.85,
                subject: subject,
                deadline: nil,
                topics: topics
            )
        }

        // 5. Quick answer: short factual question shape
        //    "What is X?" / "How does Y work?" / "Why does Z..."
        let questionStarters = ["what is", "what's", "what are",
                                "who is", "who was", "where is",
                                "how does", "how do", "how can",
                                "why does", "why is", "when did",
                                "define ", "definition of"]
        let isShort = normalized.count < 120 && message.contains("?")
        if isShort && questionStarters.contains(where: { normalized.hasPrefix($0) }) {
            return Classification(
                intent: .quickAnswer,
                confidence: 0.80,
                subject: subject,
                deadline: nil,
                topics: topics
            )
        }

        // Nothing matched with confidence
        return Classification(
            intent: .unknown,
            confidence: 0,
            subject: subject,
            deadline: deadline,
            topics: topics
        )
    }

    // MARK: - Entity extraction

    /// Best-effort subject lookup. Conservative — returns nil if uncertain.
    private static func extractSubject(_ text: String) -> String? {
        let map: [String: String] = [
            "science": "science", "biology": "biology", "chemistry": "chemistry",
            "physics": "physics", "math": "math", "mathematics": "math",
            "calculus": "calculus", "algebra": "algebra", "geometry": "geometry",
            "history": "history", "english": "english", "literature": "literature",
            "spanish": "spanish", "french": "french", "italian": "italian",
            "computer science": "computer science", "programming": "programming",
            "coding": "programming", "economics": "economics", "psychology": "psychology",
            "philosophy": "philosophy", "art": "art", "music": "music",
        ]
        for (needle, value) in map where text.contains(needle) {
            return value
        }
        return nil
    }

    /// Pull out deadline phrases like "on Tuesday", "next Monday", "tomorrow".
    private static func extractDeadline(_ text: String) -> String? {
        let weekdays = ["monday", "tuesday", "wednesday", "thursday",
                        "friday", "saturday", "sunday"]
        for day in weekdays {
            if text.contains(day) {
                let prefix = text.contains("next \(day)") ? "next "
                           : text.contains("this \(day)") ? "this " : ""
                return "\(prefix)\(day)"
            }
        }
        if text.contains("tomorrow") { return "tomorrow" }
        if text.contains("next week") { return "next week" }
        if text.contains("this week") { return "this week" }
        if text.contains("tonight") { return "tonight" }
        return nil
    }

    /// Lightweight topic extraction — looks for "about X, Y, and Z" / "on X"
    /// and splits the resulting phrase. Conservative: returns [] when in doubt.
    private static func extractTopics(_ text: String) -> [String] {
        // Patterns like: "about cells, photosynthesis, and ecosystems"
        //                "on the French Revolution"
        let patterns = [
            #"about (.+?)(?:\.|$)"#,
            #"on (.+?)(?:\.|$)"#,
            #"covering (.+?)(?:\.|$)"#,
            #"includes (.+?)(?:\.|$)"#,
            #"included? (.+?)(?:\.|$)"#,
        ]
        for pattern in patterns {
            if let match = firstCaptureGroup(in: text, pattern: pattern) {
                return splitTopicList(match)
            }
        }
        return []
    }

    private static func splitTopicList(_ phrase: String) -> [String] {
        // Replace " and " with comma, then split + trim.
        let normalized = phrase.replacingOccurrences(of: " and ", with: ",")
        let parts = normalized.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Reject if any part looks suspiciously long (probably not a topic list)
        let cleaned = parts.filter { !$0.isEmpty && $0.count <= 60 }
        return cleaned.count >= 2 ? cleaned : []
    }

    // MARK: - Tiny helpers

    private static func matchesAny(_ text: String, _ phrases: [String]) -> Bool {
        for p in phrases where text.contains(p) {
            return true
        }
        return false
    }

    private static func firstCaptureGroup(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
