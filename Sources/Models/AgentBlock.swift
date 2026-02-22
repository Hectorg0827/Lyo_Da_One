//
//  AgentBlock.swift
//  Lyo
//
//  Model for multipart agent responses. Each block represents one agent's
//  contribution to a response — allowing the UI to render them distinctly
//  so users FEEL the invisible faculty at work.
//

import Foundation

// MARK: - Agent Identity

/// Represents one of the specialized agents in Lyo's invisible faculty.
enum AgentRole: String, Codable, CaseIterable {
    case tutor          // Main explanation / Socratic dialogue
    case sentiment      // Emotional awareness, encouragement
    case quiz           // Knowledge checks, practice problems
    case content        // Supplemental resources, examples
    case metaCognition  // Study strategies, self-reflection prompts
    case orchestrator   // Overall coordination (usually hidden)
    
    /// Display-friendly name (never shown directly — drives animations)
    var displayName: String {
        switch self {
        case .tutor:         return "Tutor"
        case .sentiment:     return "Mentor"
        case .quiz:          return "Quiz Master"
        case .content:       return "Research"
        case .metaCognition: return "Study Coach"
        case .orchestrator:  return "Lyo"
        }
    }
    
    /// SF Symbol icon for the agent
    var icon: String {
        switch self {
        case .tutor:         return "brain.head.profile"
        case .sentiment:     return "heart.fill"
        case .quiz:          return "checkmark.circle.fill"
        case .content:       return "book.fill"
        case .metaCognition: return "lightbulb.fill"
        case .orchestrator:  return "sparkles"
        }
    }
    
    /// Suggested animation delay (staggered appearance in seconds)
    var entranceDelay: TimeInterval {
        switch self {
        case .orchestrator:  return 0.0
        case .tutor:         return 0.1
        case .sentiment:     return 0.3
        case .content:       return 0.5
        case .quiz:          return 0.7
        case .metaCognition: return 0.9
        }
    }
}

// MARK: - Agent Block

/// A single block of content contributed by one agent.
/// The Orchestrator emits an array of these per response.
struct AgentBlock: Identifiable, Codable, Equatable {
    let id: String
    let agent: AgentRole
    let blockType: AgentBlockType
    let content: String
    let metadata: AgentBlockMetadata?
    let timestamp: Date
    
    /// Whether this block should auto-reveal with animation
    var shouldAnimate: Bool = true
    
    init(
        id: String = UUID().uuidString,
        agent: AgentRole,
        blockType: AgentBlockType,
        content: String,
        metadata: AgentBlockMetadata? = nil,
        timestamp: Date = Date(),
        shouldAnimate: Bool = true
    ) {
        self.id = id
        self.agent = agent
        self.blockType = blockType
        self.content = content
        self.metadata = metadata
        self.timestamp = timestamp
        self.shouldAnimate = shouldAnimate
    }
    
    // Equatable — compare by id only for animation diffing
    static func == (lhs: AgentBlock, rhs: AgentBlock) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content
    }
    
    enum CodingKeys: String, CodingKey {
        case id, agent, blockType, content, metadata, timestamp
    }
}

// MARK: - Block Types

/// The kind of content an agent contributes
enum AgentBlockType: String, Codable {
    case explanation        // Rich text explanation (tutor)
    case encouragement      // Emotional support (sentiment)
    case checkpoint         // Quick comprehension check (quiz)
    case deepDive           // Extended example or resource (content)
    case reflection         // Self-assessment prompt (metaCognition)
    case summary            // Wrap-up from orchestrator
    case transition         // Segue between topics
    case codeExample        // Code snippet with explanation
    case analogy            // Real-world analogy
    case visualization      // Chart / diagram description
    case practicePrompt     // "Now try this..." prompt
    case quickTip           // Short tip or mnemonic
    case crossReference     // "Remember when we discussed..."
}

// MARK: - Block Metadata

/// Optional metadata for richer rendering
struct AgentBlockMetadata: Codable, Equatable {
    /// Confidence score (0-1) from the agent
    let confidence: Double?
    
    /// Tags for content categorization
    let tags: [String]?
    
    /// Related topic IDs for cross-referencing
    let relatedTopics: [String]?
    
    /// Suggested reading time in seconds
    let readingTime: Int?
    
    /// Difficulty level hint
    let difficulty: String?
    
    /// If this is a quiz checkpoint, the expected answer format
    let answerFormat: String?
    
    init(
        confidence: Double? = nil,
        tags: [String]? = nil,
        relatedTopics: [String]? = nil,
        readingTime: Int? = nil,
        difficulty: String? = nil,
        answerFormat: String? = nil
    ) {
        self.confidence = confidence
        self.tags = tags
        self.relatedTopics = relatedTopics
        self.readingTime = readingTime
        self.difficulty = difficulty
        self.answerFormat = answerFormat
    }
}

// MARK: - Multipart Response

/// A complete multi-agent response containing blocks from multiple agents.
/// This is what the Orchestrator produces and what the UI consumes.
struct MultipartAgentResponse: Codable {
    let sessionId: String
    let blocks: [AgentBlock]
    let totalAgentsInvolved: Int
    let processingTimeMs: Double?
    
    /// Blocks sorted by agent entrance delay for cinematic rendering
    var cinematicOrder: [AgentBlock] {
        blocks.sorted { $0.agent.entranceDelay < $1.agent.entranceDelay }
    }
    
    /// Only the blocks that carry substantive content (excludes orchestrator summaries)
    var visibleBlocks: [AgentBlock] {
        blocks.filter { $0.agent != .orchestrator }
    }
}

// MARK: - SSE Parsing Helpers

extension AgentBlock {
    /// Parse an AgentBlock from an SSE data line
    /// Expected format: {"agent":"tutor","blockType":"explanation","content":"...","metadata":{...}}
    static func fromSSE(_ jsonString: String) -> AgentBlock? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AgentBlock.self, from: data)
    }
}
