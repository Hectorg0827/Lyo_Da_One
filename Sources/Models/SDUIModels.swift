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

    // Pass-through carrier for the rich BlockRendererView pipeline.
    // Populated only when type == .lessonBlock.
    let lessonBlock: LiveLessonBlock?

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
        case blockType = "block_type"
        case block
    }

    init(
        id: String,
        type: ComponentType,
        content: String,
        delayMs: Int = 0,
        animation: String = "fade_in",
        emotion: String? = nil,
        studentName: String? = nil,
        question: String? = nil,
        options: [SDUIQuizOption]? = nil,
        actionIntent: String? = nil,
        actionPayload: [String: String]? = nil,
        lessonBlock: LiveLessonBlock? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.delayMs = delayMs
        self.animation = animation
        self.emotion = emotion
        self.studentName = studentName
        self.question = question
        self.options = options
        self.actionIntent = actionIntent
        self.actionPayload = actionPayload
        self.lessonBlock = lessonBlock
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

        // Decode the rich-block payload carried by LessonBlock components.
        // The backend's LessonBlock has fields: { block_type: String, block: { ...LiveLessonBlock fields... } }
        // We merge `block_type` into the inner dict as `type`, then decode as LiveLessonBlock.
        if self.type == .lessonBlock,
           let blockData = try container.decodeIfPresent(LiveLessonBlockPayload.self, forKey: .block),
           let blockTypeRaw = try container.decodeIfPresent(String.self, forKey: .blockType) {
            self.lessonBlock = blockData.toLiveLessonBlock(typeRaw: blockTypeRaw, fallbackId: self.id)
        } else {
            self.lessonBlock = nil
        }
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
        case lessonBlock = "LessonBlock"
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

/// Bridge struct that decodes the inner `block` payload of a backend `LessonBlock`
/// component into a full `LiveLessonBlock`. The backend wire format is:
///
///   { "type": "LessonBlock", "block_type": "diagram",
///     "block": { "title": "…", "mermaid": "…" } }
///
/// `LiveLessonBlock`'s own decoder expects `type` *inside* the block dict, so we
/// can't decode the inner dict directly. Instead we mirror the fields the AI
/// commonly emits, then construct a `LiveLessonBlock` via its public initializer.
fileprivate struct LiveLessonBlockPayload: Decodable {
    let title: String?
    let content: String?
    let subtitle: String?
    let caption: String?
    let imageURL: URL?
    let code: String?
    let language: String?
    let isRunnable: Bool?
    let question: String?
    let options: [String]?
    let correctIndex: Int?
    let correctAnswer: String?
    let explanation: String?
    let hint: String?
    let mermaid: String?
    let latex: String?
    let front: String?
    let back: String?
    let cards: [FlashcardPayload]?
    let headers: [String]?
    let rows: [[String]]?
    let style: BlockStylePayload?
    let lyoCommentary: String?
    let mood: String?
    let chartType: String?
    let chartData: ChartDataPayload?

    enum CodingKeys: String, CodingKey {
        case title, content, subtitle, caption
        case imageURL = "image_url"
        case code, language
        case isRunnable = "is_runnable"
        case question, options
        case correctIndex = "correct_index"
        case correctAnswer = "correct_answer"
        case explanation, hint, mermaid, latex, front, back, cards, headers, rows, style
        case lyoCommentary = "lyo_commentary"
        case mood
        case chartType = "chart_type"
        case chartData = "chart_data"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Use try? on every field so a single bad value (e.g. invalid URL) cannot
        // poison the whole component — graceful degradation matches LiveLessonBlock's own decoder.
        self.title = try? c.decodeIfPresent(String.self, forKey: .title)
        self.content = try? c.decodeIfPresent(String.self, forKey: .content)
        self.subtitle = try? c.decodeIfPresent(String.self, forKey: .subtitle)
        self.caption = try? c.decodeIfPresent(String.self, forKey: .caption)
        if let s = try? c.decodeIfPresent(String.self, forKey: .imageURL) {
            self.imageURL = URL(string: s)
        } else {
            self.imageURL = nil
        }
        self.code = try? c.decodeIfPresent(String.self, forKey: .code)
        self.language = try? c.decodeIfPresent(String.self, forKey: .language)
        self.isRunnable = try? c.decodeIfPresent(Bool.self, forKey: .isRunnable)
        self.question = try? c.decodeIfPresent(String.self, forKey: .question)
        self.options = try? c.decodeIfPresent([String].self, forKey: .options)
        self.correctIndex = try? c.decodeIfPresent(Int.self, forKey: .correctIndex)
        self.correctAnswer = try? c.decodeIfPresent(String.self, forKey: .correctAnswer)
        self.explanation = try? c.decodeIfPresent(String.self, forKey: .explanation)
        self.hint = try? c.decodeIfPresent(String.self, forKey: .hint)
        self.mermaid = try? c.decodeIfPresent(String.self, forKey: .mermaid)
        self.latex = try? c.decodeIfPresent(String.self, forKey: .latex)
        self.front = try? c.decodeIfPresent(String.self, forKey: .front)
        self.back = try? c.decodeIfPresent(String.self, forKey: .back)
        self.cards = try? c.decodeIfPresent([FlashcardPayload].self, forKey: .cards)
        self.headers = try? c.decodeIfPresent([String].self, forKey: .headers)
        self.rows = try? c.decodeIfPresent([[String]].self, forKey: .rows)
        self.style = try? c.decodeIfPresent(BlockStylePayload.self, forKey: .style)
        self.lyoCommentary = try? c.decodeIfPresent(String.self, forKey: .lyoCommentary)
        self.mood = try? c.decodeIfPresent(String.self, forKey: .mood)
        self.chartType = try? c.decodeIfPresent(String.self, forKey: .chartType)
        self.chartData = try? c.decodeIfPresent(ChartDataPayload.self, forKey: .chartData)
    }

    func toLiveLessonBlock(typeRaw: String, fallbackId: String) -> LiveLessonBlock {
        let blockType = LessonBlockType(rawValue: typeRaw) ?? .unknown
        return LiveLessonBlock(
            id: fallbackId,
            type: blockType,
            title: title,
            content: content,
            subtitle: subtitle,
            imageURL: imageURL,
            caption: caption,
            code: code,
            language: language,
            isRunnable: isRunnable,
            question: question,
            options: options,
            correctIndex: correctIndex,
            correctAnswer: correctAnswer,
            explanation: explanation,
            hint: hint,
            chartType: chartType,
            chartData: chartData,
            latex: latex,
            mermaid: mermaid,
            front: front,
            back: back,
            cards: cards,
            headers: headers,
            rows: rows,
            style: style,
            lyoCommentary: lyoCommentary,
            mood: mood
        )
    }
}

// MARK: - Scene Models

struct SDUIScene: Identifiable, Codable {
    let id: String
    let sceneType: String
    var components: [SDUIComponent]

    init(id: String, sceneType: String, components: [SDUIComponent]) {
        self.id = id
        self.sceneType = sceneType
        self.components = components
    }

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
