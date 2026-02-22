import Foundation

// MARK: - API Request Models

/// A single turn in conversation history for context continuity.
struct Lyo2ConversationTurn: Codable {
    let role: String   // "user" or "assistant"
    let content: String
}

struct Lyo2RouterRequest: Codable {
    let userId: String
    let text: String?
    let media: [Lyo2MediaRef]?
    let activeArtifact: Lyo2ActiveArtifactContext?
    let stateSummary: [String: AnyCodable]
    /// Recent conversation history so the AI maintains context across turns.
    let conversationHistory: [Lyo2ConversationTurn]?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case text
        case media
        case activeArtifact = "active_artifact"
        case stateSummary = "state_summary"
        case conversationHistory = "conversation_history"
    }
    
    init(
        userId: String,
        text: String?,
        media: [Lyo2MediaRef]? = nil,
        activeArtifact: Lyo2ActiveArtifactContext? = nil,
        stateSummary: [String: AnyCodable] = [:],
        conversationHistory: [Lyo2ConversationTurn]? = nil
    ) {
        self.userId = userId
        self.text = text
        self.media = media
        self.activeArtifact = activeArtifact
        self.stateSummary = stateSummary
        self.conversationHistory = conversationHistory
    }
}

struct Lyo2MediaRef: Codable {
    let modality: String // TEXT, IMAGE, AUDIO, VIDEO, PDF
    let uri: String
    let mimeType: String
    
    enum CodingKeys: String, CodingKey {
        case modality
        case uri
        case mimeType = "mime_type"
    }
}

struct Lyo2ActiveArtifactContext: Codable {
    let artifactId: String
    let artifactType: String
    let artifactVersion: Int
    
    enum CodingKeys: String, CodingKey {
        case artifactId = "artifact_id"
        case artifactType = "artifact_type"
        case artifactVersion = "artifact_version"
    }
}

// MARK: - UI Block Models (Response)

enum Lyo2UIBlockType: String, Codable {
    case text = "TutorMessageBlock"
    case quiz = "QuizBlock"
    case flashcards = "FlashcardsBlock"
    case studyPlan = "StudyPlanBlock"
    case code = "CodeBlock"
    case ctaRow = "CTARow"
    case skeleton = "Skeleton"
    case a2uiComponent = "A2UIComponent"
    case openClassroomBlock = "OpenClassroomBlock"
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let val = try? container.decode(String.self)
        self = Lyo2UIBlockType(rawValue: val ?? "") ?? .unknown
    }
}

struct Lyo2UIBlock: Codable {
    let blockType: Lyo2UIBlockType
    let title: String?
    let priority: Int
    let content: [String: AnyCodable] // dynamic content
    let versionId: String?
    
    enum CodingKeys: String, CodingKey {
        case blockType = "type"       // Backend sends "type", not "block_type"
        case title
        case priority
        case content
        case versionId = "version_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockType = try container.decode(Lyo2UIBlockType.self, forKey: .blockType)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        content = try container.decodeIfPresent([String: AnyCodable].self, forKey: .content) ?? [:]
        versionId = try container.decodeIfPresent(String.self, forKey: .versionId)
    }
    
    /// Memberwise init for constructing blocks in code (e.g. clarification mapping).
    init(blockType: Lyo2UIBlockType, title: String? = nil, priority: Int = 0, content: [String: AnyCodable] = [:], versionId: String? = nil) {
        self.blockType = blockType
        self.title = title
        self.priority = priority
        self.content = content
        self.versionId = versionId
    }
}

// MARK: - Streaming Response Events

enum Lyo2StreamEvent {
    case skeleton(blocks: [String])
    case clarification(text: String)
    case answer(block: Lyo2UIBlock)
    case artifact(block: Lyo2UIBlock)
    case actions(blocks: [Lyo2UIBlock])
    case openClassroom(block: Lyo2UIBlock)
    case a2ui(block: Lyo2UIBlock)
    case error(message: String)
    case done
}
