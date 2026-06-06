//
//  LearnerProfile.swift
//  Lyo
//
//  Persistent learner-context model used by the IntentRefinementEngine to
//  decide whether a course request needs clarification before generation.
//
//  Stored locally via LearnerProfileStore (UserDefaults). The backend can
//  later be authoritative — this client model is the offline fallback and
//  the immediate signal the refinement engine reads.
//

import Foundation

// MARK: - Skill Bands

/// The level we tag a topic with for course generation.
public enum SkillBand: String, Codable, CaseIterable, Equatable {
    case beginner  // No prior exposure
    case refresher  // Had it once, needs a brush-up
    case intermediate  // Comfortable with fundamentals
    case advanced  // Wants depth / edge cases

    /// String the backend course generator accepts for `level`.
    /// "refresher" doesn't exist server-side — map to intermediate with faster pacing.
    public var backendLevel: String {
        switch self {
        case .beginner: return "beginner"
        case .refresher: return "intermediate"
        case .intermediate: return "intermediate"
        case .advanced: return "advanced"
        }
    }

    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .refresher: return "Refresher"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

// MARK: - Goal & Format

public enum LearningGoal: String, Codable, Equatable {
    case curiosity  // "I just want to understand"
    case examPrep  // "I have a test"
    case career  // "I need this for work"
    case school  // "It's homework / class"
    case refresher  // "I knew this once"
}

public enum ContentFormat: String, Codable, Equatable {
    case visual  // Diagrams, charts, animations
    case conversational  // Lyo explains step by step
    case practiceHeavy  // More quizzes / exercises
    case balanced  // Default mix
}

public enum AcademicLevel: String, Codable, Equatable {
    case k8
    case highSchool
    case undergrad
    case grad
    case professional
    case unknown
}

// MARK: - Proficiency Estimate

public struct ProficiencyEstimate: Codable, Equatable {
    public var level: SkillBand
    public var confidence: Double  // 0.0 – 1.0
    public var lastAssessedAt: Date

    public init(level: SkillBand, confidence: Double, lastAssessedAt: Date = Date()) {
        self.level = level
        self.confidence = max(0, min(1, confidence))
        self.lastAssessedAt = lastAssessedAt
    }
}

// MARK: - Learner Profile

/// All durable signal about *who is learning what, how, and why*.
/// Read by IntentRefinementEngine; written by the chat flow + course completions.
public struct LearnerProfile: Codable, Equatable {
    public var skillsByDomain: [String: ProficiencyEstimate]
    public var completedTopicIds: Set<String>
    public var primaryGoal: LearningGoal
    public var preferredFormat: ContentFormat
    public var academicLevel: AcademicLevel
    public var preferredSessionMinutes: Int
    public var lastUpdated: Date

    public init(
        skillsByDomain: [String: ProficiencyEstimate] = [:],
        completedTopicIds: Set<String> = [],
        primaryGoal: LearningGoal = .curiosity,
        preferredFormat: ContentFormat = .balanced,
        academicLevel: AcademicLevel = .unknown,
        preferredSessionMinutes: Int = 15,
        lastUpdated: Date = Date()
    ) {
        self.skillsByDomain = skillsByDomain
        self.completedTopicIds = completedTopicIds
        self.primaryGoal = primaryGoal
        self.preferredFormat = preferredFormat
        self.academicLevel = academicLevel
        self.preferredSessionMinutes = preferredSessionMinutes
        self.lastUpdated = lastUpdated
    }

    /// Lookup proficiency for a domain (case-insensitive).
    public func proficiency(for domain: String) -> ProficiencyEstimate? {
        let key = LearnerProfile.normalize(domain)
        return skillsByDomain[key]
    }

    /// Has the learner already completed a course on this topic? (case-insensitive substring match)
    public func hasCompleted(topic: String) -> Bool {
        let lower = topic.lowercased()
        return completedTopicIds.contains {
            $0.lowercased().contains(lower) || lower.contains($0.lowercased())
        }
    }

    public mutating func recordProficiency(domain: String, level: SkillBand, confidence: Double) {
        let key = LearnerProfile.normalize(domain)
        skillsByDomain[key] = ProficiencyEstimate(level: level, confidence: confidence)
        lastUpdated = Date()
    }

    public mutating func markCompleted(topicId: String) {
        completedTopicIds.insert(topicId)
        lastUpdated = Date()
    }

    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - Profile Store

/// Lightweight persistence layer for `LearnerProfile`.
/// Uses UserDefaults so it is available immediately on cold start with no I/O.
@MainActor
public final class LearnerProfileStore: ObservableObject {
    public static let shared = LearnerProfileStore()

    @Published public private(set) var profile: LearnerProfile

    private let storageKey = "lyo.learnerProfile.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(LearnerProfile.self, from: data)
        {
            self.profile = decoded
        } else {
            self.profile = LearnerProfile()
        }
    }

    public func update(_ mutate: (inout LearnerProfile) -> Void) {
        var p = profile
        mutate(&p)
        p.lastUpdated = Date()
        profile = p
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
