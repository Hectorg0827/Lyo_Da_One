import Foundation
import os

// Redundant models moved to LessonBlock.swift for unified rich-content rendering.


// MARK: - Live Lesson

/// A complete live lesson with multiple blocks
struct LiveLesson: Codable {
    let courseId: String
    let lessonId: String
    let title: String
    let subtitle: String?
    let blocks: [LessonBlock]
    let estimatedDuration: Int? // in minutes
    
    init(
        courseId: String,
        lessonId: String,
        title: String,
        subtitle: String? = nil,
        blocks: [LessonBlock],
        estimatedDuration: Int? = nil
    ) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.title = title
        self.subtitle = subtitle
        self.blocks = blocks
        self.estimatedDuration = estimatedDuration
    }
    
    var totalBlocks: Int {
        blocks.count
    }
    
    var quizCount: Int {
        blocks.filter { $0.type == .quizMcq }.count
    }
}

// MARK: - Chat Turn

/// A single turn in the lesson transcript
struct TranscriptMessage: Identifiable {
    let id: UUID
    let isUser: Bool
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), isUser: Bool, text: String, timestamp: Date = Date()) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Sentiment Signal

/// User feedback signals during the lesson
enum SentimentSignal: String, CaseIterable {
    case confused = "confused"
    case slower = "slower"
    case tooEasy = "too_easy"
    case quizMe = "quiz_me"
    
    var displayLabel: String {
        switch self {
        case .confused: return "I'm confused"
        case .slower: return "Slower"
        case .tooEasy: return "Too easy"
        case .quizMe: return "Quiz me"
        }
    }
    
    var icon: String {
        switch self {
        case .confused: return "questionmark.bubble"
        case .slower: return "tortoise"
        case .tooEasy: return "hare"
        case .quizMe: return "checkmark.circle"
        }
    }
}

// MARK: - Quiz Result

/// Result of a quiz attempt
struct QuizResult {
    let blockId: String
    let selectedIndex: Int
    let isCorrect: Bool
    let timestamp: Date
}

// MARK: - Lesson Progress

/// Progress tracking for a live lesson
struct LiveLessonProgress: Codable {
    let courseId: String
    let lessonId: String
    var currentBlockIndex: Int
    var completedBlocks: Set<String>
    var quizResults: [String: Bool] // blockId -> passed
    var lastAccessedAt: Date
    
    var isComplete: Bool {
        // Consider complete when on last block
        return false // Will be determined by ViewModel
    }
    
    init(courseId: String, lessonId: String) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.currentBlockIndex = 0
        self.completedBlocks = []
        self.quizResults = [:]
        self.lastAccessedAt = Date()
    }
}

// MARK: - Legacy LessonBlock Definitions (Moved back for compilation)

// MARK: - Block Type Enum (Extensible, Fail-Safe)

/// All possible block types that can be rendered in the AI Classroom
/// This is the SINGLE SOURCE OF TRUTH for block types
enum LessonBlockType: String, Codable, CaseIterable {
    // Content Blocks
    case text
    case heading
    case paragraph
    case summary
    case callout       // Info/warning/tip boxes
    
    // Interactive Blocks
    case quiz
    case quizMcq       // Multiple choice
    case quizTrueFalse
    case quizFillBlank
    case textInput     // Free-form answer
    case poll
    
    // Media Blocks
    case image
    case video
    case audio
    case animation     // Lottie/GIF
    
    // Code & Technical
    case code          // Syntax highlighted
    case codePlayground // Runnable code
    case terminal      // Command output
    
    // Data Visualization
    case chart         // Bar, line, pie charts
    case graph         // Network/flow graphs
    case diagram       // Mermaid/PlantUML
    case table
    case math          // LaTeX equations
    
    // Learning Aids
    case flashcard
    case flashcardDeck
    case notes
    case timeline
    case comparison    // Side-by-side
    case stepByStep    // Numbered steps
    
    // Navigation & Structure
    case divider
    case spacer
    case progress      // Progress indicator
    case checkpoint    // Save progress here
    
    // Fail-safe
    case unknown
    
    // MARK: - Safe Decoding
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Normalize: lowercase, handle snake_case
        let normalized = rawValue
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        // Try exact match first
        if let type = LessonBlockType(rawValue: rawValue.lowercased()) {
            self = type
            return
        }
        
        // Try normalized match
        for type in LessonBlockType.allCases {
            if type.rawValue.replacingOccurrences(of: "_", with: "") == normalized {
                self = type
                return
            }
        }
        
        // Legacy mappings
        switch normalized {
        case "explain", "explanation", "content":
            self = .paragraph
        case "mcq", "multiplechoice":
            self = .quizMcq
        case "example", "codeexample":
            self = .code
        case "interaction", "input":
            self = .textInput
        case "note", "notes":
            self = .notes
        default:
            Log.data.warning("Unknown block type: '\(rawValue)' - using .unknown")
            self = .unknown
        }
    }
}

// MARK: - Unified Block Model

/// Complete block model that can represent ANY content type
/// Designed to be parsed from backend JSON safely
struct LessonBlock: Identifiable, Codable {
    let id: String
    let type: LessonBlockType
    
    // Common fields
    let title: String?
    let content: String?       // Main text/markdown content
    let subtitle: String?
    
    // Media
    let imageURL: URL?
    let videoURL: URL?
    let audioURL: URL?
    let altText: String?
    let caption: String?
    
    // Code
    let code: String?
    let language: String?      // "swift", "python", etc.
    let isRunnable: Bool?
    
    // Quiz/Interactive
    let question: String?
    let options: [String]?
    let correctIndex: Int?
    let correctAnswer: String?
    let explanation: String?
    let hint: String?
    
    // Chart/Graph
    let chartType: String?     // "bar", "line", "pie", "network"
    let chartData: ChartDataPayload?
    
    // Math/Diagram
    let latex: String?         // LaTeX equation
    let mermaid: String?       // Mermaid diagram code
    
    // Flashcard
    let front: String?
    let back: String?
    let cards: [FlashcardPayload]?
    
    // Table
    let headers: [String]?
    let rows: [[String]]?
    
    // Styling
    let style: BlockStylePayload?
    
    // Metadata
    let duration: Int?         // Estimated seconds to complete
    let difficulty: String?
    let tags: [String]?
    
    // MARK: - Initializer
    
    init(
        id: String = UUID().uuidString,
        type: LessonBlockType,
        title: String? = nil,
        content: String? = nil,
        subtitle: String? = nil,
        imageURL: URL? = nil,
        videoURL: URL? = nil,
        audioURL: URL? = nil,
        altText: String? = nil,
        caption: String? = nil,
        code: String? = nil,
        language: String? = nil,
        isRunnable: Bool? = nil,
        question: String? = nil,
        options: [String]? = nil,
        correctIndex: Int? = nil,
        correctAnswer: String? = nil,
        explanation: String? = nil,
        hint: String? = nil,
        chartType: String? = nil,
        chartData: ChartDataPayload? = nil,
        latex: String? = nil,
        mermaid: String? = nil,
        front: String? = nil,
        back: String? = nil,
        cards: [FlashcardPayload]? = nil,
        headers: [String]? = nil,
        rows: [[String]]? = nil,
        style: BlockStylePayload? = nil,
        duration: Int? = nil,
        difficulty: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.audioURL = audioURL
        self.altText = altText
        self.caption = caption
        self.code = code
        self.language = language
        self.isRunnable = isRunnable
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.hint = hint
        self.chartType = chartType
        self.chartData = chartData
        self.latex = latex
        self.mermaid = mermaid
        self.front = front
        self.back = back
        self.cards = cards
        self.headers = headers
        self.rows = rows
        self.style = style
        self.duration = duration
        self.difficulty = difficulty
        self.tags = tags
    }
    
    // MARK: - Safe Accessors
    
    var body: String? { content ?? title } // Compatibility with old LessonBlock
    
    var assetURL: URL? { imageURL ?? videoURL } // Compatibility
    
    var safeContent: String {
        content ?? title ?? "[No content]"
    }
    
    var safeTitle: String {
        title ?? type.rawValue.capitalized
    }
    
    var isInteractive: Bool {
        switch type {
        case .quiz, .quizMcq, .quizTrueFalse, .quizFillBlank, .textInput, .poll, .codePlayground:
            return true
        default:
            return false
        }
    }
    
    var isCallout: Bool {
        type == .callout
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, content, subtitle
        case imageURL = "image_url"
        case videoURL = "video_url"
        case audioURL = "audio_url"
        case altText = "alt_text"
        case caption
        case code, language
        case isRunnable = "is_runnable"
        case question, options
        case correctIndex = "correct_index"
        case correctAnswer = "correct_answer"
        case explanation, hint
        case chartType = "chart_type"
        case chartData = "chart_data"
        case latex, mermaid
        case front, back, cards
        case headers, rows
        case style
        case duration, difficulty, tags
    }
    
    // MARK: - Safe Decoder
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields with safe fallbacks
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.type = (try? container.decode(LessonBlockType.self, forKey: .type)) ?? .unknown
        
        // Optional fields - all use decodeIfPresent
        self.title = try? container.decodeIfPresent(String.self, forKey: .title)
        self.content = try? container.decodeIfPresent(String.self, forKey: .content)
        self.subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
        
        // URLs
        if let urlString = try? container.decodeIfPresent(String.self, forKey: .imageURL) {
            self.imageURL = URL(string: urlString)
        } else {
            self.imageURL = nil
        }
        if let urlString = try? container.decodeIfPresent(String.self, forKey: .videoURL) {
            self.videoURL = URL(string: urlString)
        } else {
            self.videoURL = nil
        }
        if let urlString = try? container.decodeIfPresent(String.self, forKey: .audioURL) {
            self.audioURL = URL(string: urlString)
        } else {
            self.audioURL = nil
        }
        
        self.altText = try? container.decodeIfPresent(String.self, forKey: .altText)
        self.caption = try? container.decodeIfPresent(String.self, forKey: .caption)
        self.code = try? container.decodeIfPresent(String.self, forKey: .code)
        self.language = try? container.decodeIfPresent(String.self, forKey: .language)
        self.isRunnable = try? container.decodeIfPresent(Bool.self, forKey: .isRunnable)
        self.question = try? container.decodeIfPresent(String.self, forKey: .question)
        self.options = try? container.decodeIfPresent([String].self, forKey: .options)
        self.correctIndex = try? container.decodeIfPresent(Int.self, forKey: .correctIndex)
        self.correctAnswer = try? container.decodeIfPresent(String.self, forKey: .correctAnswer)
        self.explanation = try? container.decodeIfPresent(String.self, forKey: .explanation)
        self.hint = try? container.decodeIfPresent(String.self, forKey: .hint)
        self.chartType = try? container.decodeIfPresent(String.self, forKey: .chartType)
        self.chartData = try? container.decodeIfPresent(ChartDataPayload.self, forKey: .chartData)
        self.latex = try? container.decodeIfPresent(String.self, forKey: .latex)
        self.mermaid = try? container.decodeIfPresent(String.self, forKey: .mermaid)
        self.front = try? container.decodeIfPresent(String.self, forKey: .front)
        self.back = try? container.decodeIfPresent(String.self, forKey: .back)
        self.cards = try? container.decodeIfPresent([FlashcardPayload].self, forKey: .cards)
        self.headers = try? container.decodeIfPresent([String].self, forKey: .headers)
        self.rows = try? container.decodeIfPresent([[String]].self, forKey: .rows)
        self.style = try? container.decodeIfPresent(BlockStylePayload.self, forKey: .style)
        self.duration = try? container.decodeIfPresent(Int.self, forKey: .duration)
        self.difficulty = try? container.decodeIfPresent(String.self, forKey: .difficulty)
        self.tags = try? container.decodeIfPresent([String].self, forKey: .tags)
    }
}

// MARK: - Supporting Payloads

struct ChartDataPayload: Codable {
    let labels: [String]?
    let datasets: [ChartDataset]?
    let xAxis: String?
    let yAxis: String?
    
    struct ChartDataset: Codable {
        let label: String?
        let data: [Double]
        let color: String?
    }
}

struct FlashcardPayload: Codable {
    let front: String
    let back: String
    let hint: String?
}

struct BlockStylePayload: Codable {
    let backgroundColor: String?
    let textColor: String?
    let borderColor: String?
    let icon: String?
    let calloutType: String?  // "info", "warning", "tip", "error"
    
    enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case textColor = "text_color"
        case borderColor = "border_color"
        case icon
        case calloutType = "callout_type"
    }
}
