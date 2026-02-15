//
//  LyoCourseProtocol.swift
//  Lyo
//
//  The "AI Learning OS" Protocol.
//  Defines the strict schema for AI-generated courses, modules, lessons, and artifacts.
//

import Foundation

// MARK: - 1. Course Object (The Manifest)

public struct LyoCourse: Codable, Identifiable {
    public let id: String
    public let title: String
    public let targetAudience: String
    public let learningObjectives: [String]
    public let modules: [LyoModule]
    public let generationSource: String // "ai", "human", "hybrid"
    public let version: String
    public let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id = "course_id"
        case title
        case targetAudience = "target_audience"
        case learningObjectives = "learning_objectives"
        case modules
        case generationSource = "generation_source"
        case version
        case metadata
    }
}

// MARK: - 2. Module Object

public struct LyoModule: Codable, Identifiable {
    public let id: String
    public let title: String
    public let goal: String
    public let lessons: [LyoLesson]
    
    enum CodingKeys: String, CodingKey {
        case id = "module_id"
        case title
        case goal
        case lessons
    }
}

// MARK: - 3. Lesson Object

public struct LyoLesson: Codable, Identifiable {
    public let id: String
    public let title: String
    public let goal: String
    public let artifacts: [LyoArtifact]
    public let durationMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "lesson_id"
        case title
        case goal
        case artifacts
        case durationMinutes = "duration_minutes"
    }
}

// MARK: - 4. Artifact Object (The Executable Unit)

public struct LyoArtifact: Codable, Identifiable {
    public let id: String
    public let type: ArtifactType
    public let renderTarget: String // "native", "cinematic", "external"
    public let content: AnyCodable // Dynamic payload based on type
    public let aiMetadata: ArtifactAIMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id = "artifact_id"
        case type
        case renderTarget = "render_target"
        case content
        case aiMetadata = "ai_metadata"
    }
}

public enum ArtifactType: String, Codable {
    case conceptExplainer = "concept_explainer"
    case notes = "notes"
    case flashcards = "flashcards"
    case quiz = "quiz"
    case problemSet = "problem_set"
    case reading = "reading"
}

public struct ArtifactAIMetadata: Codable {
    public let generatedBy: String
    public let confidence: Double
    public let reasoning: String?
    
    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case confidence
        case reasoning
    }
}

// MARK: - 5. Content Payloads (Specific Schemas)

// A. Concept Explainer (Cinematic or Text)
public struct ConceptExplainerPayload: Codable {
    public let markdown: String
    public let hook: String?
    public let visualPrompt: String? // For cinematic generation
    public let keyTakeaways: [String]
    
    enum CodingKeys: String, CodingKey {
        case markdown, hook
        case visualPrompt = "visual_prompt"
        case keyTakeaways = "key_takeaways"
    }
}

// B. Flashcards (Spaced Repetition)
public struct LyoFlashcardsPayload: Codable {
    public let topic: String
    public let cards: [LyoFlashcard]
}

public struct LyoFlashcard: Codable, Identifiable {
    public var id: String { front } // Simple ID
    public let front: String
    public let back: String
    public let hint: String?
}

// C. Quiz (Assessment)
public struct LyoQuizArtifactPayload: Codable {
    public let questions: [LyoQuizQuestion]
}

public struct LyoQuizQuestion: Codable, Identifiable {
    public let id: String
    public let text: String
    public let type: String // "single_choice", "multiple_choice", "true_false"
    public let options: [LyoQuizOption]
    public let correctOptionId: String
    public let explanation: String?
    
    enum CodingKeys: String, CodingKey {
        case id, text, type, options, explanation
        case correctOptionId = "correct_option_id"
    }
}

public struct LyoQuizOption: Codable, Identifiable {
    public let id: String
    public let text: String
    
    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

// D. Notes (Rich Text / Cheat Sheet)
public struct NotesPayload: Codable {
    public let title: String
    public let sections: [NoteSection]
}

public struct NoteSection: Codable, Identifiable {
    public var id: String { title }
    public let title: String
    public let contentMarkdown: String
    public let isCallout: Bool
    
    enum CodingKeys: String, CodingKey {
        case title
        case contentMarkdown = "content"
        case isCallout = "is_callout"
    }
}

// E. Reading (Long Form)
public struct ReadingPayload: Codable {
    public let title: String
    public let contentMarkdown: String
    public let estimatedReadTimeMinutes: Int
    public let sourceUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case contentMarkdown = "content"
        case estimatedReadTimeMinutes = "read_time"
        case sourceUrl = "source_url"
    }
}
