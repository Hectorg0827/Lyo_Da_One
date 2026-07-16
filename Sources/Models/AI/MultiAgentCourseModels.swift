//
//  MultiAgentCourseModels.swift
//  Lyo
//
//  Models for multi-agent v2 course generation system
//

import Foundation

// MARK: - Course Intent

/// Initial intent analysis from orchestrator agent
struct CourseIntent: Codable, Identifiable {
    let id: String
    let topic: String
    let level: DifficultyLevel
    let teachingStyle: TeachingStyle
    let learningOutcomes: [String]
    let estimatedDuration: Int
    let targetAudience: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case topic
        case level
        case teachingStyle = "teaching_style"
        case learningOutcomes = "learning_outcomes"
        case estimatedDuration = "estimated_duration"
        case targetAudience = "target_audience"
    }
}

// MARK: - Difficulty Level

enum DifficultyLevel: String, Codable {
    case beginner
    case intermediate
    case advanced
    case mixed
}

// MARK: - Teaching Style

enum TeachingStyle: String, Codable {
    case interactive
    case theoretical
    case practical
    case projectBased = "project_based"
    case mixed
}

// MARK: - Curriculum Structure

/// Complete curriculum structure from curriculum architect agent
struct CurriculumStructure: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let modules: [ModuleOutline]
    let totalLessons: Int
    let estimatedHours: Int
    let prerequisites: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case modules
        case totalLessons = "total_lessons"
        case estimatedHours = "estimated_hours"
        case prerequisites
    }
}

// MARK: - Module Outline

/// Module structure within curriculum
struct ModuleOutline: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let order: Int
    let lessons: [LessonOutline]
    let estimatedHours: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case order
        case lessons
        case estimatedHours = "estimated_hours"
    }
}

// MARK: - Lesson Outline

/// Lesson structure within module
struct LessonOutline: Codable, Identifiable {
    let id: String
    let title: String
    let objectives: [String]
    let estimatedMinutes: Int
    let order: Int
    let dependencies: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case objectives
        case estimatedMinutes = "estimated_minutes"
        case order
        case dependencies
    }
}

// MARK: - Lesson Content

/// Full lesson content from content creator agent
struct LessonContent: Codable, Identifiable {
    let id: String
    let title: String
    let introduction: String?
    let contentBlocks: [ContentBlockWrapper]
    let summary: String?
    let keyTakeaways: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case introduction
        case contentBlocks = "content_blocks"
        case summary
        case keyTakeaways = "key_takeaways"
    }
}

// MARK: - Content Block Wrapper

/// Wrapper for polymorphic content blocks
struct ContentBlockWrapper: Codable, Identifiable {
    let type: String
    let content: ContentBlockData
    
    var id: String {
        switch content {
        case .text(let block): return block.id ?? UUID().uuidString
        case .code(let block): return block.id ?? UUID().uuidString
        case .exercise(let block): return block.id ?? UUID().uuidString
        case .media(let block): return block.id ?? UUID().uuidString
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let block = try container.decode(TextBlock.self, forKey: .content)
            content = .text(block)
        case "code":
            let block = try container.decode(CodeBlock.self, forKey: .content)
            content = .code(block)
        case "exercise":
            let block = try container.decode(ExerciseBlock.self, forKey: .content)
            content = .exercise(block)
        case "media":
            let block = try container.decode(MediaBlock.self, forKey: .content)
            content = .media(block)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch content {
        case .text(let block):
            try container.encode(block, forKey: .content)
        case .code(let block):
            try container.encode(block, forKey: .content)
        case .exercise(let block):
            try container.encode(block, forKey: .content)
        case .media(let block):
            try container.encode(block, forKey: .content)
        }
    }
}

// MARK: - Content Block Data

/// Polymorphic content block types
enum ContentBlockData {
    case text(TextBlock)
    case code(CodeBlock)
    case exercise(ExerciseBlock)
    case media(MediaBlock)
}

// MARK: - Text Block

struct TextBlock: Codable {
    let id: String?
    let content: String
    let format: TextFormat?
    
    enum TextFormat: String, Codable {
        case markdown
        case plain
        case html
    }
}

// MARK: - Code Block

struct CodeBlock: Codable {
    let id: String?
    let language: String
    let code: String
    let explanation: String?
    let runnable: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case language
        case code
        case explanation
        case runnable
    }
}

// MARK: - Exercise Block

struct ExerciseBlock: Codable {
    let id: String?
    let question: String
    let type: ExerciseType
    let options: [String]?
    let correctAnswer: String?
    let explanation: String?
    let hints: [String]?
    
    enum ExerciseType: String, Codable {
        case multipleChoice = "multiple_choice"
        case trueFalse = "true_false"
        case fillBlank = "fill_blank"
        case coding
        case essay
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case question
        case type
        case options
        case correctAnswer = "correct_answer"
        case explanation
        case hints
    }
}

// MARK: - Media Block

struct MediaBlock: Codable {
    let id: String?
    let type: MediaType
    let url: String?
    let caption: String?
    let description: String?
    
    enum MediaType: String, Codable {
        case image
        case video
        case diagram
        case audio
    }
}

// MARK: - Course Assessments

/// Assessments from assessment designer agent
struct CourseAssessments: Codable {
    let finalQuiz: [QuizQuestion]?
    let practiceExercises: [PracticeExercise]?
    let projects: [CourseProject]?
    
    enum CodingKeys: String, CodingKey {
        case finalQuiz = "final_quiz"
        case practiceExercises = "practice_exercises"
        case projects
    }
}

// MARK: - Quiz Question

struct QuizQuestion: Codable, Identifiable {
    let id: String
    let question: String
    let type: QuestionType
    let options: [String]?
    let correctAnswer: String
    let explanation: String?
    let difficulty: DifficultyLevel
    
    enum QuestionType: String, Codable {
        case multipleChoice = "multiple_choice"
        case trueFalse = "true_false"
        case fillBlank = "fill_blank"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case question
        case type
        case options
        case correctAnswer = "correct_answer"
        case explanation
        case difficulty
    }
}

// MARK: - Practice Exercise

struct PracticeExercise: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let difficulty: DifficultyLevel
    let estimatedMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case difficulty
        case estimatedMinutes = "estimated_minutes"
    }
}

// MARK: - Course Project

struct CourseProject: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let objectives: [String]
    let estimatedHours: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case objectives
        case estimatedHours = "estimated_hours"
    }
}

// MARK: - Quality Report

/// QA report from quality assurance agent
struct QualityReport: Codable {
    let overallScore: Double
    let recommendation: String
    let strengths: [String]
    let improvements: [String]
    let warnings: [String]?
    
    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case recommendation
        case strengths
        case improvements
        case warnings
    }
}

// MARK: - Multi-Agent Generated Course

/// Complete generated course from multi-agent v2 pipeline
struct MultiAgentGeneratedCourse: Codable, Identifiable {
    let id: String
    let intent: CourseIntent
    let curriculum: CurriculumStructure
    let lessons: [LessonContent]
    let assessments: CourseAssessments?
    let qaReport: QualityReport?
    let metadata: CourseMetadata
    
    enum CodingKeys: String, CodingKey {
        case id
        case intent
        case curriculum
        case lessons
        case assessments
        case qaReport = "qa_report"
        case metadata
    }
}

// MARK: - Course Metadata

struct CourseMetadata: Codable {
    let generatedAt: String
    let generationDuration: Double
    let qualityTier: String
    let totalCost: Double?
    let tokensUsed: Int?
    
    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case generationDuration = "generation_duration_seconds"
        case qualityTier = "quality_tier"
        case totalCost = "total_cost_usd"
        case tokensUsed = "tokens_used"
    }
}
