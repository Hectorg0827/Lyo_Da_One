import Foundation

/// Stage A.5 — multi-turn conversation memory + pattern detection.
///
/// Sits on top of Stage A's `IntentClassifier`. The classifier still looks at
/// one user message at a time; this layer accumulates the slots it extracts
/// across turns, so a low-confidence message like "Science." can fill the
/// `subject` slot for an active `.testPrep` intent established 3 turns ago.
///
/// Pure-Swift, in-memory, per-conversation. No backend, no LLM, no new latency.
/// State is reset when the user clears the chat or loads a saved conversation.
struct ConversationState {

    // MARK: - Tunables

    /// How many recent classifier outputs we remember (for arc detection).
    private static let windowCap = 5
    /// Levenshtein-derived similarity threshold for "same question" detection.
    private static let repeatSimilarity = 0.85
    /// How many same-topic messages in a row to flag `repeatedTopic`.
    private static let repeatedTopicThreshold = 3
    /// How many `.confusion` intents in a row to flag `clarifyingFollowups`.
    private static let confusionThreshold = 2

    // MARK: - State

    /// Most recent intent that's still considered active. Reset on goal shift,
    /// classroom open, or session boundary.
    var activeIntent: IntentClassifier.Intent = .unknown
    var intentEstablishedAt: Date? = nil

    /// Filled progressively across turns. Newer values override older ones.
    var subject: String? = nil
    var deadline: String? = nil
    var topics: [String] = []

    /// The dominant topic of the last few user messages (computed from
    /// extracted topics over the recent window).
    var recentTopic: String? = nil

    /// Sliding windows for arc detection (kept short — capped at `windowCap`).
    var recentIntents: [IntentClassifier.Intent] = []
    var recentMessages: [String] = []

    /// Once we've offered a card for the current active intent, suppress
    /// repeats until either (a) a goal shift, (b) classroom opens (caller
    /// resets), or (c) intent itself changes.
    var cardOfferedForCurrentIntent: Bool = false

    // MARK: - Update API

    /// Observe a new user message. Mutates state and returns whatever pattern
    /// the message triggered, if any. Caller can use the pattern *and* the
    /// updated state to decide what card (if any) to surface.
    mutating func observe(userMessage: String) -> Observation {
        let classification = IntentClassifier.classify(userMessage)
        return apply(classification: classification, message: userMessage)
    }

    /// Result of an observation step: the raw classification, the post-update
    /// state's active intent, and any conversational pattern detected.
    struct Observation {
        let classification: IntentClassifier.Classification
        let pattern: ConversationPattern?
    }

    private mutating func apply(
        classification: IntentClassifier.Classification,
        message: String
    ) -> Observation {

        // Step 1 — Push into windows BEFORE detection so the latest turn is included.
        recentIntents.append(classification.intent)
        recentMessages.append(message)
        if recentIntents.count > Self.windowCap {
            recentIntents.removeFirst(recentIntents.count - Self.windowCap)
        }
        if recentMessages.count > Self.windowCap {
            recentMessages.removeFirst(recentMessages.count - Self.windowCap)
        }

        // Step 2 — Pattern detection (uses the windows we just updated).
        let pattern = detectPattern(latestClassification: classification)

        // Step 3 — Apply state mutations driven by the pattern + classification.
        switch pattern {
        case .goalShift:
            // Reset everything related to the *previous* intent.
            resetIntentSlots()
            promote(intent: classification.intent)
            mergeSlots(from: classification)

        case .repeatedTopic, .clarifyingFollowups, .repeatedQuestion:
            // No reset; just refresh slots if the new message brought any.
            mergeSlots(from: classification)

        case .none:
            // Standard slot-fill: short low-confidence messages enrich the
            // active intent's slots; high-confidence messages can promote.
            if classification.confidence >= 0.75 && activeIntent == .unknown {
                promote(intent: classification.intent)
            }
            mergeSlots(from: classification)
        }

        // Step 4 — Refresh recentTopic from the rolling window.
        recentTopic = computeDominantTopic()

        return Observation(classification: classification, pattern: pattern)
    }

    /// Reset for a new conversation thread.
    mutating func reset() {
        self = ConversationState()
    }

    /// Mark the current card as offered so we don't re-offer it every turn.
    mutating func noteCardOffered() {
        cardOfferedForCurrentIntent = true
    }

    // MARK: - Pattern detection

    private func detectPattern(
        latestClassification: IntentClassifier.Classification
    ) -> ConversationPattern? {

        // Highest priority — goal shift (changes the whole picture).
        if let shift = detectGoalShift(latest: latestClassification) {
            return shift
        }

        // Repeated question — same/similar text submitted twice in a row.
        if let repeated = detectRepeatedQuestion(latest: recentMessages.last ?? "") {
            return .repeatedQuestion(text: repeated)
        }

        // Repeated topic — ≥3 turns focused on the same topic.
        if let repeatedTopic = detectRepeatedTopic() {
            return repeatedTopic
        }

        // Clarifying follow-ups — multiple `.confusion` in a row.
        if let confusion = detectClarifyingFollowups() {
            return confusion
        }

        return nil
    }

    private func detectGoalShift(
        latest: IntentClassifier.Classification
    ) -> ConversationPattern? {
        // Goal shift requires:
        //   - A previously-established intent that's subject-bearing.
        //   - A NEW high-confidence intent on a DIFFERENT subject.
        guard activeIntent != .unknown,
              activeIntent != latest.intent || subject != latest.subject,
              latest.confidence >= 0.80,
              let newSubject = latest.subject,
              let oldSubject = subject,
              newSubject != oldSubject
        else { return nil }
        return .goalShift(from: activeIntent, to: latest.intent)
    }

    private func detectRepeatedQuestion(latest: String) -> String? {
        // Skip the latest entry itself — compare against the previous N.
        let priors = recentMessages.dropLast()
        let normalizedLatest = latest.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedLatest.count >= 8 else { return nil }
        for prior in priors {
            let np = prior.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if similarity(np, normalizedLatest) >= Self.repeatSimilarity {
                return latest
            }
        }
        return nil
    }

    private func detectRepeatedTopic() -> ConversationPattern? {
        // Look at the last `repeatedTopicThreshold` messages — if they all
        // mention the same topic (case-insensitive), flag it.
        let n = Self.repeatedTopicThreshold
        guard recentMessages.count >= n else { return nil }
        let recent = recentMessages.suffix(n)
        // Pull dominant token from each message via the classifier's topic
        // extractor (run as part of the classification we already did).
        let topicsPerTurn: [String?] = recent.map { msg in
            let cls = IntentClassifier.classify(msg)
            return cls.topics.first?.lowercased()
                ?? cls.subject?.lowercased()
        }
        guard let first = topicsPerTurn.first ?? nil,
              !first.isEmpty,
              topicsPerTurn.allSatisfy({ $0 == first })
        else { return nil }
        return .repeatedTopic(topic: first, count: n)
    }

    private func detectClarifyingFollowups() -> ConversationPattern? {
        let n = Self.confusionThreshold
        guard recentIntents.count >= n else { return nil }
        let recent = recentIntents.suffix(n)
        guard recent.allSatisfy({ $0 == .confusion }) else { return nil }
        return .clarifyingFollowups(count: n)
    }

    // MARK: - Slot management

    private mutating func promote(intent: IntentClassifier.Intent) {
        activeIntent = intent
        intentEstablishedAt = Date()
        cardOfferedForCurrentIntent = false
    }

    private mutating func resetIntentSlots() {
        activeIntent = .unknown
        intentEstablishedAt = nil
        subject = nil
        deadline = nil
        topics = []
        cardOfferedForCurrentIntent = false
    }

    private mutating func mergeSlots(from classification: IntentClassifier.Classification) {
        if let s = classification.subject  { subject = s }
        if let d = classification.deadline { deadline = d }
        if !classification.topics.isEmpty {
            // Append-only, dedupe (case-insensitive), cap at 8 to avoid bloat.
            for t in classification.topics where !topics.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                topics.append(t)
            }
            if topics.count > 8 { topics = Array(topics.suffix(8)) }
        }
    }

    private func computeDominantTopic() -> String? {
        // Count topic mentions across the last `windowCap` user messages.
        var tally: [String: Int] = [:]
        for msg in recentMessages {
            let cls = IntentClassifier.classify(msg)
            for t in cls.topics {
                tally[t.lowercased(), default: 0] += 1
            }
            if let s = cls.subject {
                tally[s.lowercased(), default: 0] += 1
            }
        }
        return tally.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Conversation patterns

enum ConversationPattern: Equatable {
    case repeatedTopic(topic: String, count: Int)
    case clarifyingFollowups(count: Int)
    case repeatedQuestion(text: String)
    case goalShift(from: IntentClassifier.Intent, to: IntentClassifier.Intent)
}

// MARK: - String similarity (Levenshtein-based, normalized)

/// Returns 0.0 (totally different) to 1.0 (identical). O(n*m) but our inputs
/// are user messages, not novels — fine for sub-ms classification.
private func similarity(_ a: String, _ b: String) -> Double {
    if a == b { return 1.0 }
    if a.isEmpty || b.isEmpty { return 0.0 }
    let distance = levenshtein(a, b)
    let longest = max(a.count, b.count)
    return 1.0 - (Double(distance) / Double(longest))
}

private func levenshtein(_ a: String, _ b: String) -> Int {
    let aChars = Array(a)
    let bChars = Array(b)
    var dist = Array(repeating: Array(repeating: 0, count: bChars.count + 1),
                     count: aChars.count + 1)
    for i in 0...aChars.count { dist[i][0] = i }
    for j in 0...bChars.count { dist[0][j] = j }
    for i in 1...aChars.count {
        for j in 1...bChars.count {
            if aChars[i - 1] == bChars[j - 1] {
                dist[i][j] = dist[i - 1][j - 1]
            } else {
                dist[i][j] = 1 + min(
                    dist[i - 1][j],     // deletion
                    dist[i][j - 1],     // insertion
                    dist[i - 1][j - 1]  // substitution
                )
            }
        }
    }
    return dist[aChars.count][bChars.count]
}
