//
//  IntentRefinementEngine.swift
//  Lyo
//
//  Sits between MessageIntentClassifier (course_creation detected) and
//  CourseGenerationService. Decides whether the system has enough signal
//  to generate a tailored course, or whether to ask 1–2 chip-driven
//  clarification rounds first.
//
//  Design rules:
//   - NEVER ask more than 2 chip rounds before generation.
//   - If profile already has signal (or message is explicit), pass through immediately.
//   - All clarifications are conversational chips, not modal sheets.
//

import Foundation
import os

// MARK: - Refined Intent

public struct RefinedCourseIntent: Equatable {
    public let topic: String           // Display-cased topic ("Algebra 1")
    public let normalizedTopic: String // Lowercased ("algebra 1")
    public let scope: String?          // Optional sub-area ("Algebra 1 — quadratics")
    public let level: SkillBand
    public let goal: LearningGoal
    public let format: ContentFormat
    public let timeBudgetMinutes: Int
    public let confidence: Double      // 0.0 – 1.0

    /// Backend hint string ("course_creation_refined") for forcedIntent routing.
    public var forcedIntentTag: String { "course_creation_refined" }
}

// MARK: - Refinement Outcome

public enum RefinementOutcome {
    /// The classifier didn't think this was a course request — keep going as normal chat.
    case notACourseRequest
    /// Enough signal collected — caller should kick off course generation with this intent.
    case ready(RefinedCourseIntent)
    /// We need more signal. Caller should render the prompt as an assistant message
    /// (using `.suggestions(title:options:)`) and await the user's chip tap or reply.
    case needsClarification(ClarificationPrompt)
}

public struct ClarificationPrompt: Equatable {
    public let dimension: Dimension
    public let title: String
    public let chips: [String]   // Plain strings; tapping a chip sends it as a new message.

    public enum Dimension: String, Equatable {
        case scope     // "Which kind of algebra?"
        case level     // "How comfortable are you?"
        case goal      // "What's this for?" (rarely used)
    }
}

// MARK: - Engine

@MainActor
public final class IntentRefinementEngine: ObservableObject {
    public static let shared = IntentRefinementEngine()

    private let log = Logger(subsystem: "com.lyo.app", category: "IntentRefinement")
    private let classifier = MessageIntentClassifier.shared
    private let profileStore = LearnerProfileStore.shared

    // MARK: - Per-conversation slot-filling state

    /// In-progress refinement state. Reset on `notACourseRequest` or after `.ready`.
    private var pendingTopic: String?
    private var pendingScope: String?
    private var pendingLevel: SkillBand?
    private var pendingGoal: LearningGoal?
    private var roundsAsked: Int = 0

    /// Hard cap on clarification rounds per refinement.
    private let maxRounds = 2

    private init() {}

    // MARK: - Public API

    /// Process a user message. If a refinement is in progress, the message is
    /// interpreted as an answer to the last clarification. Otherwise the message
    /// is classified fresh.
    public func process(message: String) -> RefinementOutcome {
        let outcome = _process(message: message)
        emitTelemetry(for: outcome, message: message)
        return outcome
    }

    private func _process(message: String) -> RefinementOutcome {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .notACourseRequest }

        // Are we mid-flow? Treat the message as an answer to the last open slot.
        if pendingTopic != nil {
            return continueRefinement(answer: trimmed)
        }

        // Fresh message — only refine if it looks like a course request.
        let intent = classifier.classify(trimmed)
        guard intent.category == .courseCreation else {
            return .notACourseRequest
        }

        guard let extracted = intent.extractedTopic, !extracted.isEmpty else {
            // Course intent but no topic extracted — start by asking what to learn.
            pendingTopic = ""  // sentinel: refinement in progress, no topic yet
            roundsAsked = 1
            return .needsClarification(.init(
                dimension: .scope,
                title: "What would you like to learn?",
                chips: ["Algebra basics", "Spanish for travel", "Python fundamentals", "Public speaking"]
            ))
        }

        return startRefinement(rawTopic: extracted, rawMessage: trimmed)
    }

    /// Reset state — e.g. after a generation kicks off, or when the user starts a new chat.
    public func reset() {
        pendingTopic = nil
        pendingScope = nil
        pendingLevel = nil
        pendingGoal = nil
        roundsAsked = 0
    }

    // MARK: - Refinement steps

    private func startRefinement(rawTopic: String, rawMessage: String) -> RefinementOutcome {
        let topic = displayCased(rawTopic)
        pendingTopic = topic

        let lower = rawMessage.lowercased()
        let profile = profileStore.profile

        // 1. Try to harvest level from the message itself ("for beginners", "advanced").
        if let levelFromMsg = inferLevel(from: lower) {
            pendingLevel = levelFromMsg
        } else if let prior = profile.proficiency(for: topic), prior.confidence >= 0.7 {
            pendingLevel = prior.level
            log.info("📚 Reusing prior level \(prior.level.rawValue) for \(topic)")
        }

        // 2. Try to harvest goal/timing.
        pendingGoal = inferGoal(from: lower) ?? profile.primaryGoal

        // 3. Detect ambiguous topics that need scope clarification.
        if let prompt = scopePromptIfAmbiguous(topic: topic, fullMessage: lower) {
            roundsAsked += 1
            return .needsClarification(prompt)
        }

        // 4. If we still don't know level → ask.
        if pendingLevel == nil {
            roundsAsked += 1
            return .needsClarification(levelPrompt(for: topic))
        }

        // 5. We have everything. Ship it.
        return .ready(buildRefined())
    }

    private func continueRefinement(answer: String) -> RefinementOutcome {
        let lower = answer.lowercased()

        // Cancellation
        if ["cancel", "nevermind", "never mind", "stop", "exit"].contains(where: lower.contains) {
            reset()
            return .notACourseRequest
        }

        // Slot-fill in priority: scope first if unset and topic is bare/empty,
        // then level.
        if (pendingTopic ?? "").isEmpty {
            // We were asking for the topic itself.
            pendingTopic = displayCased(answer)
        } else if pendingScope == nil, scopeWasJustAsked() {
            pendingScope = displayCased(answer)
        } else if pendingLevel == nil {
            pendingLevel = inferLevel(from: lower) ?? .beginner
        }

        // After consuming the answer, decide what's next.
        if let topic = pendingTopic, !topic.isEmpty {
            // Maybe the now-known topic is itself ambiguous.
            if pendingScope == nil, let prompt = scopePromptIfAmbiguous(topic: topic, fullMessage: lower) {
                if roundsAsked < maxRounds {
                    roundsAsked += 1
                    return .needsClarification(prompt)
                }
            }

            if pendingLevel == nil {
                if roundsAsked < maxRounds {
                    roundsAsked += 1
                    return .needsClarification(levelPrompt(for: topic))
                }
                // Cap reached — default to beginner and ship.
                pendingLevel = .beginner
            }

            return .ready(buildRefined())
        }

        // Still no topic — re-ask once.
        if roundsAsked < maxRounds {
            roundsAsked += 1
            return .needsClarification(.init(
                dimension: .scope,
                title: "What would you like to learn?",
                chips: ["Algebra basics", "Spanish for travel", "Python fundamentals", "Public speaking"]
            ))
        }

        reset()
        return .notACourseRequest
    }

    // MARK: - Build final intent

    private func buildRefined() -> RefinedCourseIntent {
        let topic = pendingTopic ?? "General topic"
        let scoped = pendingScope.map { "\(topic) — \($0)" } ?? topic
        let level = pendingLevel ?? .beginner
        let goal = pendingGoal ?? .curiosity
        let format = profileStore.profile.preferredFormat
        let minutes = profileStore.profile.preferredSessionMinutes
        let confidence: Double = pendingScope != nil ? 0.95 : 0.85

        // Persist the level we inferred so next time we don't have to ask.
        profileStore.update { p in
            p.recordProficiency(domain: topic, level: level, confidence: confidence)
        }

        let refined = RefinedCourseIntent(
            topic: scoped,
            normalizedTopic: scoped.lowercased(),
            scope: pendingScope,
            level: level,
            goal: goal,
            format: format,
            timeBudgetMinutes: minutes,
            confidence: confidence
        )

        log.info("✅ Refined intent: \(scoped) | \(level.rawValue) | goal=\(goal.rawValue) | conf=\(confidence)")
        reset()
        return refined
    }

    // MARK: - Heuristics

    private func inferLevel(from lowered: String) -> SkillBand? {
        if containsAny(lowered, ["from scratch", "no idea", "never done", "complete beginner", "for beginners", "beginner"]) {
            return .beginner
        }
        if containsAny(lowered, ["refresh", "brush up", "review", "i used to", "rusty"]) {
            return .refresher
        }
        if containsAny(lowered, ["intermediate", "comfortable", "some experience"]) {
            return .intermediate
        }
        if containsAny(lowered, ["advanced", "deep dive", "expert", "master"]) {
            return .advanced
        }
        return nil
    }

    private func inferGoal(from lowered: String) -> LearningGoal? {
        if containsAny(lowered, ["exam", "test", "sat", "gre", "mcat", "lsat", "final"]) { return .examPrep }
        if containsAny(lowered, ["work", "job", "interview", "career", "promotion"]) { return .career }
        if containsAny(lowered, ["homework", "class", "school", "professor", "teacher"]) { return .school }
        if containsAny(lowered, ["refresh", "brush up", "review"]) { return .refresher }
        return nil
    }

    /// Topics where one word maps to many real courses.
    /// Returns a chip prompt if the user message doesn't already disambiguate.
    private func scopePromptIfAmbiguous(topic: String, fullMessage: String) -> ClarificationPrompt? {
        let key = topic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let options = Self.ambiguousTopics[key] else { return nil }

        // If message already mentions one of the options, we're disambiguated.
        if options.contains(where: { fullMessage.contains($0.lowercased()) }) {
            return nil
        }

        return ClarificationPrompt(
            dimension: .scope,
            title: "Got it — which kind of \(topic.lowercased())?",
            chips: options
        )
    }

    private func levelPrompt(for topic: String) -> ClarificationPrompt {
        ClarificationPrompt(
            dimension: .level,
            title: "How comfortable are you with \(topic.lowercased())?",
            chips: ["I'm new to this", "I need a refresher", "I'm comfortable", "Help me figure it out"]
        )
    }

    private func scopeWasJustAsked() -> Bool {
        // Heuristic: if we have a topic but no level yet AND no scope, the last
        // question likely was scope. Good enough for the FSM.
        return pendingTopic != nil && pendingLevel == nil && pendingScope == nil
    }

    // MARK: - Helpers

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private func displayCased(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        // If the user shouted ("ALGEBRA") or mumbled ("algebra"), title-case it.
        // Preserve mixed-case multi-word strings ("Algebra 1 — Quadratics").
        let hasMixedCase = trimmed.contains(where: { $0.isUppercase }) && trimmed.contains(where: { $0.isLowercase })
        if hasMixedCase { return trimmed }
        return trimmed.capitalized
    }

    // MARK: - Ambiguous topic registry
    //
    // Curated, conservative list. Add carefully — every entry forces an extra
    // chip round, which is friction. Only add when one word truly maps to
    // multiple distinct real courses.
    private static let ambiguousTopics: [String: [String]] = [
        "algebra":   ["Pre-Algebra", "Algebra 1", "Algebra 2", "Linear Algebra", "Abstract Algebra"],
        "math":      ["Arithmetic", "Algebra", "Geometry", "Calculus", "Statistics"],
        "spanish":   ["Travel Spanish", "Conversational Spanish", "Business Spanish", "Spanish for school"],
        "french":    ["Travel French", "Conversational French", "Business French", "French for school"],
        "english":   ["English grammar", "Business English", "English for IELTS/TOEFL", "Conversational English"],
        "physics":   ["Classical mechanics", "Electromagnetism", "Modern physics", "AP Physics"],
        "chemistry": ["General chemistry", "Organic chemistry", "Biochemistry", "AP Chemistry"],
        "biology":   ["Cell biology", "Genetics", "Anatomy", "AP Biology"],
        "history":   ["World history", "US history", "European history", "Ancient civilizations"],
        "python":    ["Python basics", "Python for data science", "Web with Django/Flask", "Python automation"],
        "javascript": ["JS fundamentals", "React", "Node.js", "TypeScript"],
        "guitar":    ["Acoustic basics", "Electric / rock", "Classical", "Jazz / theory"],
        "drawing":   ["Pencil sketching", "Digital art", "Anatomy & figure", "Comic / manga"],
        "cooking":   ["Quick weeknight meals", "Baking", "World cuisines", "Knife skills & technique"],
        "investing": ["Investing 101", "Stocks & ETFs", "Real estate", "Crypto"]
    ]

    // MARK: - Telemetry (Sprint 4)

    /// Emit a single analytics event per process() call so we can measure
    /// in production: how often we ask for clarification, on which topics,
    /// how many rounds, and what level we infer. Backed by LyoAnalyticsManager
    /// (already wired to backend + Firebase mirror).
    private func emitTelemetry(for outcome: RefinementOutcome, message: String) {
        let preview = String(message.prefix(80))
        switch outcome {
        case .notACourseRequest:
            // Don't spam analytics for every chat message — only log once we
            // know the engine made a real decision.
            return
        case .needsClarification(let prompt):
            LyoAnalyticsManager.shared.trackEvent("intent_refinement_clarification", parameters: [
                "dimension": prompt.dimension.rawValue,
                "round": roundsAsked,
                "topic": pendingTopic ?? "",
                "chip_count": prompt.chips.count,
                "message_preview": preview
            ])
        case .ready(let refined):
            LyoAnalyticsManager.shared.trackEvent("intent_refinement_ready", parameters: [
                "topic": refined.topic,
                "normalized_topic": refined.normalizedTopic,
                "level": refined.level.backendLevel,
                "scope": refined.scope ?? "",
                "goal": refined.goal.rawValue,
                "format": refined.format.rawValue,
                "rounds_asked": roundsAsked,
                "confidence": refined.confidence
            ])
        }
    }
}
