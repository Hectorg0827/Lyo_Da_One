import Foundation

// MARK: - SDUI Component Models

/// A single Server-Driven UI component sent progressively over the WebSocket stream
struct SDUIComponent: Identifiable, Codable, Equatable {
    static func == (lhs: SDUIComponent, rhs: SDUIComponent) -> Bool {
        return lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.content == rhs.content &&
        lhs.delayMs == rhs.delayMs &&
        lhs.animation == rhs.animation &&
        lhs.emotion == rhs.emotion &&
        lhs.studentName == rhs.studentName &&
        lhs.question == rhs.question &&
        lhs.options == rhs.options &&
        lhs.actionIntent == rhs.actionIntent
    }

    let id: String
    let type: ComponentType
    let content: String
    let delayMs: Int
    let animation: String
    
    // Additional optional fields depending on the component
    let emotion: String?
    let studentName: String?
    let question: String?
    let options: [SDUIQuizOption]?
    let actionIntent: String?
    let actionPayload: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case componentId = "component_id"
        case id
        case type
        case content
        case text
        case label
        case delayMs = "delay_ms"
        case animation
        case emotion
        case studentName = "student_name"
        case question
        case options
        case actionIntent = "action_intent"
        case actionPayload = "action_payload"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both "component_id" and "id"
        if let cid = try container.decodeIfPresent(String.self, forKey: .componentId) {
            self.id = cid
        } else {
            self.id = try container.decode(String.self, forKey: .id)
        }
        self.type = try container.decode(ComponentType.self, forKey: .type)
        // Accept "content", "text", or "label" (CTA buttons use "label")
        if let c = try container.decodeIfPresent(String.self, forKey: .content) {
            self.content = c
        } else if let t = try container.decodeIfPresent(String.self, forKey: .text) {
            self.content = t
        } else if let l = try container.decodeIfPresent(String.self, forKey: .label) {
            self.content = l
        } else {
            self.content = ""
        }
        self.delayMs = try container.decodeIfPresent(Int.self, forKey: .delayMs) ?? 0
        self.animation = try container.decodeIfPresent(String.self, forKey: .animation) ?? "fade_in"
        self.emotion = try container.decodeIfPresent(String.self, forKey: .emotion)
        self.studentName = try container.decodeIfPresent(String.self, forKey: .studentName)
        self.question = try container.decodeIfPresent(String.self, forKey: .question)
        self.options = try container.decodeIfPresent([SDUIQuizOption].self, forKey: .options)
        self.actionIntent = try container.decodeIfPresent(String.self, forKey: .actionIntent)
        self.actionPayload = try container.decodeIfPresent([String: String].self, forKey: .actionPayload)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .componentId)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(delayMs, forKey: .delayMs)
        try container.encode(animation, forKey: .animation)
        try container.encodeIfPresent(emotion, forKey: .emotion)
        try container.encodeIfPresent(studentName, forKey: .studentName)
        try container.encodeIfPresent(question, forKey: .question)
        try container.encodeIfPresent(options, forKey: .options)
        try container.encodeIfPresent(actionIntent, forKey: .actionIntent)
        try container.encodeIfPresent(actionPayload, forKey: .actionPayload)
    }
    
    enum ComponentType: String, Codable {
        case teacherMessage = "TeacherMessage"
        case studentPrompt = "StudentPrompt"
        case quizCard = "QuizCard"
        case ctaButton = "CTAButton"
        case textBlock = "TextBlock"
        case codeBlock = "CodeBlock"
        case progressBar = "ProgressBar"
        // Fallback for unknown types
        case unknown
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = ComponentType(rawValue: rawValue) ?? .unknown
        }
    }
}

struct SDUIQuizOption: Identifiable, Codable, Equatable {
    let id: String
    let label: String
}

// MARK: - Scene Models

struct SDUIScene: Identifiable, Codable {
    let id: String
    let sceneType: String
    var components: [SDUIComponent]
    
    enum CodingKeys: String, CodingKey {
        case sceneId = "scene_id"
        case id
        case sceneType = "scene_type"
        case components
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both "scene_id" and "id"
        if let sid = try container.decodeIfPresent(String.self, forKey: .sceneId) {
            self.id = sid
        } else {
            self.id = try container.decode(String.self, forKey: .id)
        }
        self.sceneType = try container.decode(String.self, forKey: .sceneType)
        self.components = try container.decodeIfPresent([SDUIComponent].self, forKey: .components) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .sceneId)
        try container.encode(sceneType, forKey: .sceneType)
        try container.encode(components, forKey: .components)
    }
}

// MARK: - WebSocket Message Envelopes

enum WebSocketMessageType: String, Codable {
    case sceneStream = "scene_stream"
    case componentStream = "component_stream"
    case control = "control"
    case error = "error"
}

struct WebSocketEnvelope: Codable {
    let type: String
    let sessionId: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case eventType = "event_type"
        case sessionId = "session_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        
        if let explicitType = try container.decodeIfPresent(String.self, forKey: .type) {
            self.type = explicitType
        } else if let fallbackType = try container.decodeIfPresent(String.self, forKey: .eventType) {
            self.type = fallbackType
        } else {
            self.type = "unknown"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
    }
}

// Data payload for scene_stream events
struct SceneStreamPayload: Codable {
    let eventType: String
    let scene: SDUIScene?
    
    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case scene
    }
}

