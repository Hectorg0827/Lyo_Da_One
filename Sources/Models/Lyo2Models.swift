import Foundation

// MARK: - API Request Models

/// A single turn in conversation history for context continuity.
struct Lyo2ConversationTurn: Codable {
    let role: String   // "user" or "assistant"
    let content: String
}

struct Lyo2VoiceSessionContext: Codable {
    let active: Bool
    let transport: String
    let locale: String
    let turnId: String?
    let interruptedPreviousTurn: Bool
    let handsFree: Bool
    let delivery: String

    enum CodingKeys: String, CodingKey {
        case active
        case transport
        case locale
        case turnId = "turn_id"
        case interruptedPreviousTurn = "interrupted_previous_turn"
        case handsFree = "hands_free"
        case delivery
    }

    init(
        active: Bool = true,
        transport: String = "client_stt_tts",
        locale: String = Locale.current.identifier,
        turnId: String? = nil,
        interruptedPreviousTurn: Bool = false,
        handsFree: Bool = true,
        delivery: String = "segments"
    ) {
        self.active = active
        self.transport = transport
        self.locale = locale
        self.turnId = turnId
        self.interruptedPreviousTurn = interruptedPreviousTurn
        self.handsFree = handsFree
        self.delivery = delivery
    }
}

struct Lyo2RouterRequest: Codable {
    let userId: String
    let text: String?
    let media: [Lyo2MediaRef]?
    let attachmentIds: [String]?
    let activeArtifact: Lyo2ActiveArtifactContext?
    let forcedIntent: String?
    let stateSummary: [String: AnyCodable]
    let voiceSession: Lyo2VoiceSessionContext?
    /// Recent conversation history so the AI maintains context across turns.
    let conversationHistory: [Lyo2ConversationTurn]?
    let conversationId: String?
    let deviceId: String
    let clientMessageId: String?
    var timezone: String = TimeZone.current.identifier
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case text
        case media
        case attachmentIds = "attachment_ids"
        case activeArtifact = "active_artifact"
        case forcedIntent = "forced_intent"
        case stateSummary = "state_summary"
        case voiceSession = "voice_session"
        case conversationHistory = "conversation_history"
        case conversationId = "conversation_id"
        case deviceId = "device_id"
        case clientMessageId = "client_message_id"
        case timezone
    }
    
    init(
        userId: String,
        text: String?,
        media: [Lyo2MediaRef]? = nil,
        attachmentIds: [String]? = nil,
        activeArtifact: Lyo2ActiveArtifactContext? = nil,
        forcedIntent: String? = nil,
        stateSummary: [String: AnyCodable] = [:],
        voiceSession: Lyo2VoiceSessionContext? = nil,
        conversationHistory: [Lyo2ConversationTurn]? = nil,
        conversationId: String? = nil,
        deviceId: String = "ios",
        clientMessageId: String? = nil
    ) {
        self.userId = userId
        self.text = text
        self.media = media
        self.attachmentIds = attachmentIds
        self.activeArtifact = activeArtifact
        self.forcedIntent = forcedIntent
        self.stateSummary = stateSummary
        self.voiceSession = voiceSession
        self.conversationHistory = conversationHistory
        self.conversationId = conversationId
        self.deviceId = deviceId
        self.clientMessageId = clientMessageId
    }
}

struct Lyo2MediaRef: Codable {
    let modality: String // IMAGE or DOCUMENT for chat attachments
    let uri: String
    let mimeType: String
    let durationMs: Int?
    let name: String?
    let sizeBytes: Int?
    
    enum CodingKeys: String, CodingKey {
        case modality
        case uri
        case mimeType = "mime_type"
        case durationMs = "duration_ms"
        case name
        case sizeBytes = "size_bytes"
    }

    init(
        modality: String,
        uri: String,
        mimeType: String,
        durationMs: Int? = nil,
        name: String? = nil,
        sizeBytes: Int? = nil
    ) {
        self.modality = modality
        self.uri = uri
        self.mimeType = mimeType
        self.durationMs = durationMs
        self.name = name
        self.sizeBytes = sizeBytes
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

// MARK: - Shared Teaching Runtime

struct TeachingPolicyEvent: Codable {
    let action: String
    let reasonCode: String?
    let interactionRequired: Bool?
    let maxExpositionWords: Int?
    let preferredInstrument: String?
    let targetEvidenceType: String?
    let modelTier: String?
    let policyVersion: String?

    enum CodingKeys: String, CodingKey {
        case action
        case reasonCode = "reason_code"
        case interactionRequired = "interaction_required"
        case maxExpositionWords = "max_exposition_words"
        case preferredInstrument = "preferred_instrument"
        case targetEvidenceType = "target_evidence_type"
        case modelTier = "model_tier"
        case policyVersion = "policy_version"
    }
}

struct TeachingRuntimeClientState {
    var lastAction: String?
    var consecutiveChecks: Int = 0
    var consecutiveExplanations: Int = 0

    private static let checkActions: Set<String> = [
        "diagnose", "guide", "check_recall", "check_application",
        "check_transfer", "review",
    ]
    private static let explanationActions: Set<String> = [
        "explain", "demonstrate", "remediate",
    ]

    mutating func apply(_ policy: TeachingPolicyEvent) {
        guard [
            "answer", "diagnose", "explain", "demonstrate", "guide",
            "check_recall", "check_application", "check_transfer",
            "remediate", "review", "advance", "pause",
        ].contains(policy.action) else { return }

        if Self.checkActions.contains(policy.action) {
            consecutiveChecks = min(8, consecutiveChecks + 1)
            consecutiveExplanations = 0
        } else if Self.explanationActions.contains(policy.action) {
            consecutiveExplanations = min(8, consecutiveExplanations + 1)
            consecutiveChecks = 0
        } else {
            consecutiveChecks = 0
            consecutiveExplanations = 0
        }
        lastAction = policy.action
    }

    var dictionary: [String: Any] {
        var value: [String: Any] = [
            "consecutive_checks": consecutiveChecks,
            "consecutive_explanations": consecutiveExplanations,
        ]
        if let lastAction { value["last_action"] = lastAction }
        return value
    }
}

// MARK: - Streaming Response Events

enum Lyo2StreamEvent {
    /// Shared events (no v1/v2 distinction)
    case skeleton(blocks: [String])
    case clarification(text: String)
    case answer(block: Lyo2UIBlock)
    case artifact(block: Lyo2UIBlock)
    case error(message: String)
    case done
    case conversation(id: String)
    case teachingPolicy(policy: TeachingPolicyEvent)

    /// Canonical voice delivery events. These carry the exact same answer
    /// generated by Unified Chat; they only let the client begin speaking it
    /// before the complete answer event arrives.
    case voiceTextSegment(text: String, sequence: Int, messageId: String)
    case voiceReady(text: String, messageId: String, speak: Bool)
    case voiceIncomplete(text: String, messageId: String)
    
    /// v1 backward-compat events (still emitted by deployed backend)
    case actions(blocks: [Lyo2UIBlock])
    case openClassroom(block: Lyo2UIBlock)

    /// Scene-based classroom events (structured UI components)
    case sceneStart(scene: ClassroomScenePayload)

    /// v2 events (LyoResponse envelope — primary path)
    case lyoUI(response: LyoResponse)
    case lyoCommand(response: LyoResponse)
    case lyoSuggestions(response: LyoResponse)
    
    /// v2 unified block format (SmartBlock)
    case smartBlocks(blocks: [SmartBlock])
}
