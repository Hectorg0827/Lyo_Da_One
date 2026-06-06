import Foundation

public enum ActionType: String, Codable {
    case practiceQuestion = "practice_question"
    case hint = "hint"
    case explanation = "explanation"
    case review = "review"
    case challenge = "challenge"
    case encouragement = "encouragement"
    case `break` = "break"
}

public struct NextActionResponse: Codable {
    public let action: ActionType
    public let difficulty: String
    public let reason: [String]
    public let spacedRepetitionDue: Bool?
    public let content: [String: AnyCodable]?
    public let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case action
        case difficulty
        case reason
        case spacedRepetitionDue = "spaced_repetition_due"
        case content
        case metadata
    }
    
    // Backward compatibility computed properties
    public var actionType: ActionType { action }
    public var confidence: Double { 0.8 }  // Default since backend doesn't return this
    
    // Extract content string if available
    public var contentString: String {
        if let desc = content?["description"]?.value as? String {
            return desc
        }
        return reason.joined(separator: ". ")
    }
}

public struct PersonalizationContext: Codable {
    public let userId: String
    public let currentSkill: String?
    public let lessonId: String?
    public let performanceScore: Double?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case currentSkill = "current_skill"
        case lessonId = "lesson_id"
        case performanceScore = "performance_score"
    }
}

public struct AffectSignals: Codable {
    public let valence: Double
    public let arousal: Double
    public let confidence: Double
    public let source: [String]
    
    public init(valence: Double, arousal: Double, confidence: Double, source: [String] = []) {
        self.valence = valence
        self.arousal = arousal
        self.confidence = confidence
        self.source = source
    }
}

public struct SessionState: Codable {
    public let fatigue: Double
    public let focus: Double
    public let durationMinutes: Int?
    public let lastBreakMinutesAgo: Int?
    
    public init(fatigue: Double, focus: Double, durationMinutes: Int? = nil, lastBreakMinutesAgo: Int? = nil) {
        self.fatigue = fatigue
        self.focus = focus
        self.durationMinutes = durationMinutes
        self.lastBreakMinutesAgo = lastBreakMinutesAgo
    }
    
    enum CodingKeys: String, CodingKey {
        case fatigue, focus
        case durationMinutes = "duration_minutes"
        case lastBreakMinutesAgo = "last_break_minutes_ago"
    }
}

// Note: LearningLevel is defined in DiscoverModels.swift
// Using that definition to avoid duplication

public struct LearningContext: Codable, Equatable {
    public let topic: String
    public let learningLevel: LearningLevel
    public let contentType: ContentType
    public let source: ContentSource
    public let timestamp: Date
    public let clipId: String?
    public let complexity: ContextComplexity
    
    // Legacy support for older fields
    public let lessonId: String?
    public let skill: String?

    public enum ContentType: String, Codable {
        case video, course, quiz, conversation, explainer
    }

    public enum ContentSource: String, Codable {
        case chat, discover, community, classroom, stack
    }

    public enum ContextComplexity: String, Codable {
        case simple, moderate, complex
    }
    
    public init(
        topic: String,
        learningLevel: LearningLevel,
        contentType: ContentType,
        source: ContentSource,
        timestamp: Date = Date(),
        clipId: String? = nil,
        complexity: ContextComplexity = .moderate,
        lessonId: String? = nil,
        skill: String? = nil
    ) {
        self.topic = topic
        self.learningLevel = learningLevel
        self.contentType = contentType
        self.source = source
        self.timestamp = timestamp
        self.clipId = clipId
        self.complexity = complexity
        self.lessonId = lessonId
        self.skill = skill
    }
}


public struct PersonalizationStateUpdate: Codable {
    public let learnerId: String
    public let affect: AffectSignals?
    public let session: SessionState?
    public let context: LearningContext?
    
    public init(learnerId: String, affect: AffectSignals? = nil, session: SessionState? = nil, context: LearningContext? = nil) {
        self.learnerId = learnerId
        self.affect = affect
        self.session = session
        self.context = context
    }
    
    enum CodingKeys: String, CodingKey {
        case learnerId = "learner_id"
        case affect, session, context
    }
}

public struct KnowledgeTraceRequest: Codable {
    public let learnerId: String
    public let skillId: String
    public let itemId: String
    public let correct: Bool
    public let timeTakenSeconds: Double
    public let hintsUsed: Int
    public let attemptNumber: Int
    
    public init(learnerId: String, skillId: String, itemId: String, correct: Bool, timeTakenSeconds: Double, hintsUsed: Int = 0, attemptNumber: Int = 1) {
        self.learnerId = learnerId
        self.skillId = skillId
        self.itemId = itemId
        self.correct = correct
        self.timeTakenSeconds = timeTakenSeconds
        self.hintsUsed = hintsUsed
        self.attemptNumber = attemptNumber
    }
    
    enum CodingKeys: String, CodingKey {
        case learnerId = "learner_id"
        case skillId = "skill_id"
        case itemId = "item_id"
        case correct
        case timeTakenSeconds = "time_taken_seconds"
        case hintsUsed = "hints_used"
        case attemptNumber = "attempt_number"
    }
}

public struct MasteryProfile: Codable {
    public let learnerId: String
    public let skills: [String: Double]
    public let strengths: [String]
    public let weaknesses: [String]
    public let recommendedFocus: [String]
    public let learningVelocity: Double
    public let optimalDifficulty: Double
    
    enum CodingKeys: String, CodingKey {
        case learnerId = "learner_id"
        case skills
        case strengths
        case weaknesses
        case recommendedFocus = "recommended_focus"
        case learningVelocity = "learning_velocity"
        case optimalDifficulty = "optimal_difficulty"
    }
}

public struct CinemaInteraction: Codable {
    public let isCorrect: Bool
    public let responseTime: Double
    public let attempts: Int
    public let celebrationTriggered: Bool?
    public let feedback: String?
    public let metadata: [String: String]
    
    public init(isCorrect: Bool, responseTime: Double, attempts: Int, celebrationTriggered: Bool? = nil, feedback: String? = nil, metadata: [String: String] = [:]) {
        self.isCorrect = isCorrect
        self.responseTime = responseTime
        self.attempts = attempts
        self.celebrationTriggered = celebrationTriggered
        self.feedback = feedback
        self.metadata = metadata
    }
}
