import Foundation

// MARK: - Enums
public enum LyoCardTypeStr: String, Codable {
    case conceptCard = "concept_card"
    case diagramCard = "diagram_card"
    case analogyCard = "analogy_card"
    case quizCard = "quiz_card"
    case reflectCard = "reflect_card"
    case summaryCard = "summary_card"
    case transitionCard = "transition_card"
}

// MARK: - Core Protocols
public protocol LyoCard: Identifiable {
    var id: String { get }
    var type: String { get }
    var voiceText: String { get }
    var audioUrl: String? { get }
}

public extension LyoCard {
    var id: String { UUID().uuidString }
}

// MARK: - The 7 Card Types

public struct ConceptCard: LyoCard, Codable {
    public var id = UUID().uuidString
    public let type: String
    public let voiceText: String
    public let audioUrl: String?
    public let keyTerm: String
    public let bodyText: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case voiceText = "voice_text"
        case audioUrl = "audio_url"
        case keyTerm = "key_term"
        case bodyText = "body_text"
    }
}

public struct DiagramNode: Codable, Identifiable {
    public let id: String
    public let symbolName: String
    public let label: String
    public let colorHex: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case symbolName = "symbol_name"
        case label
        case colorHex = "color_hex"
    }
}

public struct DiagramConnection: Codable, Identifiable {
    public var id: String { "\(sourceId)-\(targetId)" }
    public let sourceId: String
    public let targetId: String
    public let label: String?
    
    enum CodingKeys: String, CodingKey {
        case sourceId = "source_id"
        case targetId = "target_id"
        case label
    }
}

public struct DiagramCard: LyoCard, Codable {
    public var id = UUID().uuidString
    public let type: String
    public let voiceText: String
    public let audioUrl: String?
    public let nodes: [DiagramNode]
    public let connections: [DiagramConnection]
    
    enum CodingKeys: String, CodingKey {
        case type
        case voiceText = "voice_text"
        case audioUrl = "audio_url"
        case nodes
        case connections
    }
}

public struct AnalogyCard: LyoCard, Codable {
    public var id = UUID().uuidString
    public let type: String
    public let voiceText: String
    public let audioUrl: String?
    public let conceptSide: String
    public let analogySide: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case voiceText = "voice_text"
        case audioUrl = "audio_url"
        case conceptSide = "concept_side"
        case analogySide = "analogy_side"
    }
}

public struct QuizCard: LyoCard, Codable {
    public var id = UUID().uuidString
    public let type: String
    public let voiceText: String
    public let audioUrl: String?
    public let question: String
    public let options: [String]
    public let correctOptionIndex: Int
    public let explanation: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case voiceText = "voice_text"
        case audioUrl = "audio_url"
        case question
        case options
        case correctOptionIndex = "correct_option_index"
        case explanation
    }
}

public struct ReflectCard: LyoCard, Codable {
    public var id = UUID().uuidString
    public let type: String
    public let voiceText: String
    public let audioUrl: String?
    public let prompt: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case voiceText = "voice_text"
        case audioUrl = "audio_url"
        case prompt
    }
}

public struct SummaryCard: LyoCard, Codable {
    public var id = UUID().uuidString
    public let type: String
    public let voiceText: String
    public let audioUrl: String?
    public let title: String
    public let keyPoints: [String]
    
    enum CodingKeys: String, CodingKey {
        case type
        case voiceText = "voice_text"
        case audioUrl = "audio_url"
        case title
        case keyPoints = "key_points"
    }
}

public struct TransitionCard: LyoCard, Codable {
    public var id = UUID().uuidString
    public let type: String
    public let voiceText: String
    public let audioUrl: String?
    public let title: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case voiceText = "voice_text"
        case audioUrl = "audio_url"
        case title
    }
}

// MARK: - Stream Chunking & Payload Wrapping

public struct LyoLessonPalette: Codable {
    public let color1Hex: String
    public let color2Hex: String
    public let color3Hex: String
    
    enum CodingKeys: String, CodingKey {
        case color1Hex = "color1_hex"
        case color2Hex = "color2_hex"
        case color3Hex = "color3_hex"
    }
}

public struct LyoLessonMetadata: Codable {
    public let topic: String
    public let palette: LyoLessonPalette
}

public enum LyoCardWrapper: Codable, Identifiable {
    case concept(ConceptCard)
    case diagram(DiagramCard)
    case analogy(AnalogyCard)
    case quiz(QuizCard)
    case reflect(ReflectCard)
    case summary(SummaryCard)
    case transition(TransitionCard)
    
    public var id: String {
        return card.id
    }
    
    public var card: any LyoCard {
        switch self {
        case .concept(let c): return c
        case .diagram(let c): return c
        case .analogy(let c): return c
        case .quiz(let c): return c
        case .reflect(let c): return c
        case .summary(let c): return c
        case .transition(let c): return c
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DiscriminatorCodingKey.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "concept_card": self = .concept(try ConceptCard(from: decoder))
        case "diagram_card": self = .diagram(try DiagramCard(from: decoder))
        case "analogy_card": self = .analogy(try AnalogyCard(from: decoder))
        case "quiz_card": self = .quiz(try QuizCard(from: decoder))
        case "reflect_card": self = .reflect(try ReflectCard(from: decoder))
        case "summary_card": self = .summary(try SummaryCard(from: decoder))
        case "transition_card": self = .transition(try TransitionCard(from: decoder))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown LyoCard type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .concept(let c): try c.encode(to: encoder)
        case .diagram(let c): try c.encode(to: encoder)
        case .analogy(let c): try c.encode(to: encoder)
        case .quiz(let c): try c.encode(to: encoder)
        case .reflect(let c): try c.encode(to: encoder)
        case .summary(let c): try c.encode(to: encoder)
        case .transition(let c): try c.encode(to: encoder)
        }
    }
    
    enum DiscriminatorCodingKey: String, CodingKey {
        case type
    }
}

public struct LyoStreamChunk: Codable {
    public let metadata: LyoLessonMetadata?
    public let card: LyoCardWrapper?
    public let isComplete: Bool
    
    enum CodingKeys: String, CodingKey {
        case metadata
        case card
        case isComplete = "is_complete"
    }
}
