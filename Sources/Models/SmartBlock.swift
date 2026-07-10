import Foundation

// MARK: - SmartBlock Type

/// Unified block type shared across chat, classroom, and course generation.
/// Forward-compatible: decodes unknown backend types to `.unknown` with fallback rendering.
public enum SmartBlockType: String, Codable, Sendable {
    case text           // subtypes: heading, paragraph, summary, callout, hook, revelation
    case code           // subtypes: snippet, playground, terminal
    case quiz           // subtypes: mcq, trueFalse, fillBlank, poll
    case flashcard      // subtypes: single, deck
    case dataViz        // subtypes: chart, graph, diagram, math, table
    case media          // subtypes: image, video, audio, animation
    case progress       // subtypes: checkpoint, celebration, divider, spacer, timeline
    case interactive    // subtypes: comparison, stepByStep, notes
    case masteryMap
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Handle both camelCase ("dataViz") and snake_case ("data_viz") from backend
        if let direct = SmartBlockType(rawValue: raw) {
            self = direct
        } else {
            // Convert snake_case to camelCase for rawValue lookup
            let parts = raw.split(separator: "_")
            let camelCased = parts.enumerated().map { index, part in
                index == 0 ? String(part) : part.capitalized
            }.joined()
            self = SmartBlockType(rawValue: camelCased) ?? .unknown
        }
    }
}

// MARK: - SmartBlock Content

/// Type-safe content container — each type has its own payload.
/// Encoding/decoding is handled by the parent `SmartBlock`.
public enum SmartBlockContent: Sendable {
    case text(TextBlockPayload)
    case code(CodeBlockPayload)
    case quiz(QuizBlockPayload)
    case flashcard(FlashcardBlockPayload)
    case dataViz(DataVizBlockPayload)
    case media(MediaBlockPayload)
    case progress(ProgressBlockPayload)
    case interactive(InteractiveBlockPayload)
    case masteryMap(MasteryMapBlockPayload)
    case unknown(rawJSON: [String: AnyCodable])
}

// MARK: - SmartBlock

/// A single renderable content block with schema versioning.
public struct SmartBlock: Codable, Identifiable, Sendable {
    public let id: String
    public let schemaVersion: Int
    public let type: SmartBlockType
    public let subtype: String?
    public let content: SmartBlockContent
    public let metadata: [String: AnyCodable]?
    
    public init(
        id: String = UUID().uuidString,
        schemaVersion: Int = 1,
        type: SmartBlockType,
        subtype: String? = nil,
        content: SmartBlockContent,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.type = type
        self.subtype = subtype
        self.content = content
        self.metadata = metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        type = try container.decode(SmartBlockType.self, forKey: .type)
        subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
        metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        
        // Decode content dict, then route to typed payload based on `type`
        let contentDict = try container.decode([String: AnyCodable].self, forKey: .content)
        let contentData = try JSONSerialization.data(
            withJSONObject: contentDict.mapValues { $0.value }
        )
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        
        switch type {
        case .text:
            content = .text(
                (try? dec.decode(TextBlockPayload.self, from: contentData))
                ?? TextBlockPayload(text: contentDict["text"]?.value as? String ?? "")
            )
        case .code:
            content = .code(
                (try? dec.decode(CodeBlockPayload.self, from: contentData))
                ?? CodeBlockPayload(language: "plain", code: contentDict["code"]?.value as? String ?? "")
            )
        case .quiz:
            content = .quiz(
                (try? dec.decode(QuizBlockPayload.self, from: contentData))
                ?? QuizBlockPayload(question: "", options: [], correctIndex: 0)
            )
        case .flashcard:
            content = .flashcard(
                (try? dec.decode(FlashcardBlockPayload.self, from: contentData))
                ?? FlashcardBlockPayload(front: "", back: "")
            )
        case .dataViz:
            content = .dataViz(
                (try? dec.decode(DataVizBlockPayload.self, from: contentData))
                ?? DataVizBlockPayload(format: "text", source: "")
            )
        case .media:
            content = .media(
                (try? dec.decode(MediaBlockPayload.self, from: contentData))
                ?? MediaBlockPayload(url: "", alt: nil)
            )
        case .progress:
            content = .progress(
                (try? dec.decode(ProgressBlockPayload.self, from: contentData))
                ?? ProgressBlockPayload(completed: 0, total: 1)
            )
        case .interactive:
            content = .interactive(
                (try? dec.decode(InteractiveBlockPayload.self, from: contentData))
                ?? InteractiveBlockPayload(items: [])
            )
        case .masteryMap:
            content = .masteryMap(
                (try? dec.decode(MasteryMapBlockPayload.self, from: contentData))
                ?? MasteryMapBlockPayload(title: "Course", nodes: [])
            )
        case .unknown:
            content = .unknown(rawJSON: contentDict)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(subtype, forKey: .subtype)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        
        switch content {
        case .text(let p): try container.encode(p, forKey: .content)
        case .code(let p): try container.encode(p, forKey: .content)
        case .quiz(let p): try container.encode(p, forKey: .content)
        case .flashcard(let p): try container.encode(p, forKey: .content)
        case .dataViz(let p): try container.encode(p, forKey: .content)
        case .media(let p): try container.encode(p, forKey: .content)
        case .progress(let p): try container.encode(p, forKey: .content)
        case .interactive(let p): try container.encode(p, forKey: .content)
        case .masteryMap(let p): try container.encode(p, forKey: .content)
        case .unknown(let dict): try container.encode(dict, forKey: .content)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, type, subtype, content, metadata
    }
}

// MARK: - Content Payloads

public struct TextBlockPayload: Codable, Sendable {
    public let text: String
    public var style: String?  // heading, paragraph, summary, callout, hook, revelation
    
    public init(text: String, style: String? = nil) {
        self.text = text
        self.style = style
    }
}

public struct CodeBlockPayload: Codable, Sendable {
    public let language: String
    public let code: String
    public var isRunnable: Bool?
    
    public init(language: String, code: String, isRunnable: Bool? = nil) {
        self.language = language
        self.code = code
        self.isRunnable = isRunnable
    }
}

public struct QuizBlockPayload: Codable, Sendable {
    public let question: String
    public let options: [QuizOptionPayload]
    public let correctIndex: Int
    public var explanation: String?
    public var hint: String?
    
    public init(question: String, options: [QuizOptionPayload], correctIndex: Int, explanation: String? = nil, hint: String? = nil) {
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.hint = hint
    }
}

public struct QuizOptionPayload: Codable, Sendable {
    public let id: String
    public let text: String
    
    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct FlashcardBlockPayload: Codable, Sendable {
    public let front: String
    public let back: String
    public var tags: String?
    
    public init(front: String, back: String, tags: String? = nil) {
        self.front = front
        self.back = back
        self.tags = tags
    }
}

public struct DataVizBlockPayload: Codable, Sendable {
    public let format: String  // mermaid, chart, table, math
    public let source: String
    public var title: String?
    
    public init(format: String, source: String, title: String? = nil) {
        self.format = format
        self.source = source
        self.title = title
    }
}

public struct MediaBlockPayload: Codable, Sendable {
    public let url: String
    public var alt: String?
    public var caption: String?
    
    public init(url: String, alt: String? = nil, caption: String? = nil) {
        self.url = url
        self.alt = alt
        self.caption = caption
    }
}

public struct ProgressBlockPayload: Codable, Sendable {
    public let completed: Int
    public let total: Int
    public var label: String?
    
    public init(completed: Int, total: Int, label: String? = nil) {
        self.completed = completed
        self.total = total
        self.label = label
    }
}

public struct InteractiveBlockPayload: Codable, Sendable {
    public let items: [InteractiveItem]
    public var title: String?
    
    public init(items: [InteractiveItem], title: String? = nil) {
        self.items = items
        self.title = title
    }
}

public struct InteractiveItem: Codable, Sendable {
    public let label: String
    public let detail: String
    
    public init(label: String, detail: String) {
        self.label = label
        self.detail = detail
    }
}

public struct MasteryMapBlockPayload: Codable, Sendable {
    public let title: String
    public let nodes: [MasteryNodePayload]
    
    public init(title: String, nodes: [MasteryNodePayload]) {
        self.title = title
        self.nodes = nodes
    }
}

public struct MasteryNodePayload: Codable, Sendable, Identifiable {
    public var id: String { nodeId }
    public let nodeId: String
    public let title: String
    public let status: String
    public var masteryLevel: Double?
    
    public init(nodeId: String = UUID().uuidString, title: String, status: String, masteryLevel: Double? = nil) {
        self.nodeId = nodeId
        self.title = title
        self.status = status
        self.masteryLevel = masteryLevel
    }
}
