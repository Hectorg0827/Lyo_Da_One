import Foundation

// MARK: - The Lyo Protocol (Backend Logic)
// Matches the Pydantic schema from the system prompt strictly.

public enum LyoBlockType: String, Codable {
    case concept, quiz, code, reflection, image, video
}

public enum SemanticRole: String, Codable {
    case normal, hook, chapter, checkpoint, remedial, assessment
}

public enum PresentationHint: String, Codable {
    case inline, hero, cinematic
}

public struct LyoBlock: Codable, Identifiable {
    public let id: String
    public let type: LyoBlockType
    public let role: SemanticRole
    
    // The raw content payload (we decode partially to inspect 'kind')
    public let content: AnyCodable
    
    public let presentationHint: PresentationHint?
    public let requiresInteraction: Bool?
    public let interactionId: String?
    public let mood: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content
        case presentationHint = "presentation_hint"
        case requiresInteraction = "requires_interaction"
        case interactionId = "interaction_id"
        case mood
    }
}

// MARK: - The Content Payloads

public struct ConceptPayload: Codable {
    public let kind: String // "concept"
    public let markdown: String
    public let keyTakeaway: String?
    
    enum CodingKeys: String, CodingKey {
        case kind, markdown
        case keyTakeaway = "key_takeaway"
    }
}

public struct QuizPayload: Codable {
    public let kind: String // "quiz"
    public let question: String
    public let options: [QuizOption]
    public let correctOptionId: String
    public let explanation: String?
    
    enum CodingKeys: String, CodingKey {
        case kind, question, options, explanation
        case correctOptionId = "correct_option_id"
    }
}

public struct QuizOption: Codable, Identifiable {
    public let id: String
    public let text: String
}

public struct ImagePayload: Codable {
    public let kind: String // "image"
    public let url: URL
    public let caption: String?
}
