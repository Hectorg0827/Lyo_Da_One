import Foundation

// MARK: - A2UI Streaming Event (for A2UI payload streaming)
enum A2UIStreamingEvent: Codable {
    case partialPayload(PartialPayloadEvent)
    case token(TokenEvent)
    case progress(ProgressEvent)
    case complete(CompleteEvent)
    case error(ErrorEvent)

    private enum CodingKeys: String, CodingKey {
        case event, id, timestamp, payload, token, progress, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let event = try container.decode(String.self, forKey: .event)
        switch event {
        case "partial_payload":
            let payload = try container.decode(OpenClassroomPayload.self, forKey: .payload)
            let id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            self = .partialPayload(PartialPayloadEvent(id: id, payload: payload))
        case "token":
            let token = try container.decode(String.self, forKey: .token)
            let id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            self = .token(TokenEvent(id: id, token: token))
        case "progress":
            let progress = try container.decode(ProgressEvent.self, forKey: .progress)
            self = .progress(progress)
        case "complete":
            let payload = try container.decodeIfPresent(OpenClassroomPayload.self, forKey: .payload)
            let id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            self = .complete(CompleteEvent(id: id, payload: payload))
        case "error":
            let err = try container.decode(ErrorEvent.self, forKey: .error)
            self = .error(err)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .event, in: container, debugDescription: "Unknown event type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .partialPayload(let e):
            try container.encode("partial_payload", forKey: .event)
            try container.encode(e.id, forKey: .id)
            try container.encode(e.payload, forKey: .payload)
        case .token(let e):
            try container.encode("token", forKey: .event)
            try container.encode(e.id, forKey: .id)
            try container.encode(e.token, forKey: .token)
        case .progress(let e):
            try container.encode("progress", forKey: .event)
            try container.encode(e, forKey: .progress)
        case .complete(let e):
            try container.encode("complete", forKey: .event)
            try container.encode(e.id, forKey: .id)
            try container.encodeIfPresent(e.payload, forKey: .payload)
        case .error(let e):
            try container.encode("error", forKey: .event)
            try container.encode(e, forKey: .error)
        }
    }
}

struct PartialPayloadEvent: Codable {
    let id: String
    let payload: OpenClassroomPayload
}

struct TokenEvent: Codable {
    let id: String
    let token: String
}

struct ProgressEvent: Codable {
    let percent: Double
    let etaSeconds: Int?
}

struct CompleteEvent: Codable {
    let id: String
    let payload: OpenClassroomPayload?
}

struct ErrorEvent: Codable {
    let id: String?
    let code: String
    let message: String
}
//
//  A2AModels.swift
//  Lyo
//
//  Google A2A (Agent-to-Agent) Protocol Models for iOS
//  Matches backend schema in lyo_app/ai_agents/a2a/schemas.py
//

// MARK: - Agent Card (A2A Protocol Discovery)

/// Self-describing agent capabilities per A2A protocol
struct A2AAgentCard: Codable, Identifiable {
    let name: String
    let description: String
    let url: String?
    let provider: A2AAgentProvider
    let version: String
    let capabilities: A2AAgentCapabilities
    let skills: [A2AAgentSkill]
    let authentication: A2AAuthentication?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, description, url, provider, version, capabilities, skills, authentication
    }
}

struct A2AAgentProvider: Codable {
    let organization: String
    let url: String?
}

struct A2AAgentCapabilities: Codable {
    let streaming: Bool
    let pushNotifications: Bool
    let batchProcessing: Bool

    enum CodingKeys: String, CodingKey {
        case streaming
        case pushNotifications = "push_notifications"
        case batchProcessing = "batch_processing"
    }
}

struct A2AAgentSkill: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let inputModes: [String]
    let outputModes: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case inputModes = "input_modes"
        case outputModes = "output_modes"
    }
}

struct A2AAuthentication: Codable {
    let schemes: [String]
    let credentials: String?
}

// MARK: - Pipeline State

/// Current state of the A2A pipeline
enum A2APipelinePhase: String, Codable, CaseIterable {
    case initialization = "initialization"
    case pedagogy = "pedagogy"
    case cinematic = "cinematic"
    case visual = "visual"
    case voice = "voice"
    case qaCheck = "qa_check"
    case assembly = "assembly"
    case finalization = "finalization"

    var displayName: String {
        switch self {
        case .initialization: return "Starting"
        case .pedagogy: return "Learning Design"
        case .cinematic: return "Scene Creation"
        case .visual: return "Visual Design"
        case .voice: return "Audio Preparation"
        case .qaCheck: return "Quality Check"
        case .assembly: return "Assembly"
        case .finalization: return "Finalizing"
        }
    }

    var icon: String {
        switch self {
        case .initialization: return "play.circle"
        case .pedagogy: return "book.circle"
        case .cinematic: return "film"
        case .visual: return "photo.artframe"
        case .voice: return "waveform"
        case .qaCheck: return "checkmark.shield"
        case .assembly: return "cube.box"
        case .finalization: return "checkmark.circle"
        }
    }
}

enum A2APhaseStatus: String, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"

    var color: String {
        switch self {
        case .pending: return "gray"
        case .running: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        case .skipped: return "orange"
        }
    }
}

struct A2APhaseProgress: Codable, Identifiable {
    let phase: A2APipelinePhase
    let status: A2APhaseStatus
    let startedAt: Date?
    let completedAt: Date?
    let durationMs: Double?
    let error: String?

    var id: String { phase.rawValue }

    enum CodingKeys: String, CodingKey {
        case phase, status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationMs = "duration_ms"
        case error
    }
}

// MARK: - Streaming Events

/// Types of A2A streaming events
enum A2AEventType: String, Codable {
    case pipelineStarted = "pipeline_started"
    case phaseStarted = "phase_started"
    case phaseProgress = "phase_progress"
    case phaseCompleted = "phase_completed"
    case phaseFailed = "phase_failed"
    case agentHandoff = "agent_handoff"
    case artifactCreated = "artifact_created"
    case pipelineCompleted = "pipeline_completed"
    case error = "error"

    // Legacy/Internal types from backend schema
    case contentChunk = "content_chunk"
    case thinking = "thinking"
    case agentStarted = "agent_started"
    case agentCompleted = "agent_completed"

    // Multi-agent V2 streaming event types (from routes_streaming.py)
    case started = "started"
    case agentWorking = "agent_working"
    case lessonComplete = "lesson_complete"
    case progress = "progress"
    case completed = "completed"
    case costUpdate = "cost_update"

    // Catch-all for any unrecognized backend events
    case unknown = "__unknown__"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = A2AEventType(rawValue: rawValue) ?? .unknown
    }
}

/// Streaming event from A2A pipeline.
/// Handles both the A2A orchestrator schema (event_type, pipeline_id)
/// and the multi-agent-v2 streaming schema (type, progress, message, data).
struct A2AStreamingEvent: Codable {
    let type: A2AEventType
    let timestamp: Date
    let pipelineId: String
    let phase: A2APipelinePhase?
    let progress: Int  // 0-100
    let message: String?
    let data: A2AEventData?

    // New fields from backend schema
    let chunkContent: String?
    let thinkingContent: String?
    let artifact: A2AArtifact?
    let payload: [String: A2AAnyCodableValue]?

    // MARK: - Custom Decoder
    // Backend may send the event type key as either "type" or "event_type"
    // and pipeline ID as either "pipeline_id" or "task_id".
    // Many fields are optional depending on the event source.

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexCodingKeys.self)

        // Decode event type — try "type" first, then "event_type"
        if let t = try? container.decode(A2AEventType.self, forKey: .init("type")) {
            self.type = t
        } else if let t = try? container.decode(A2AEventType.self, forKey: .init("event_type")) {
            self.type = t
        } else {
            self.type = .unknown
        }

        // Decode timestamp (optional — backend may omit it)
        if let ts = try? container.decode(Date.self, forKey: .init("timestamp")) {
            self.timestamp = ts
        } else {
            self.timestamp = Date()
        }

        // Pipeline ID — try "pipeline_id" then "task_id"
        if let pid = try? container.decode(String.self, forKey: .init("pipeline_id")) {
            self.pipelineId = pid
        } else if let tid = try? container.decode(String.self, forKey: .init("task_id")) {
            self.pipelineId = tid
        } else {
            self.pipelineId = "unknown"
        }

        self.phase = try? container.decode(A2APipelinePhase.self, forKey: .init("phase"))
        self.progress = (try? container.decode(Int.self, forKey: .init("progress"))) ?? 0
        self.message = try? container.decode(String.self, forKey: .init("message"))
        self.data = try? container.decode(A2AEventData.self, forKey: .init("data"))
        self.chunkContent = try? container.decode(String.self, forKey: .init("chunk_content"))
        self.thinkingContent = try? container.decode(String.self, forKey: .init("thinking_content"))
        self.artifact = try? container.decode(A2AArtifact.self, forKey: .init("artifact"))
        self.payload = try? container.decode(
            [String: A2AAnyCodableValue].self, forKey: .init("payload"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: FlexCodingKeys.self)
        try container.encode(type, forKey: .init("type"))
        try container.encode(timestamp, forKey: .init("timestamp"))
        try container.encode(pipelineId, forKey: .init("pipeline_id"))
        try container.encodeIfPresent(phase, forKey: .init("phase"))
        try container.encode(progress, forKey: .init("progress"))
        try container.encodeIfPresent(message, forKey: .init("message"))
        try container.encodeIfPresent(data, forKey: .init("data"))
        try container.encodeIfPresent(chunkContent, forKey: .init("chunk_content"))
        try container.encodeIfPresent(thinkingContent, forKey: .init("thinking_content"))
        try container.encodeIfPresent(artifact, forKey: .init("artifact"))
        try container.encodeIfPresent(payload, forKey: .init("payload"))
    }

    /// Manual init for testing/internal use
    init(
        type: A2AEventType, timestamp: Date = Date(), pipelineId: String = "",
        phase: A2APipelinePhase? = nil, progress: Int = 0, message: String? = nil,
        data: A2AEventData? = nil, chunkContent: String? = nil,
        thinkingContent: String? = nil, artifact: A2AArtifact? = nil,
        payload: [String: A2AAnyCodableValue]? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.pipelineId = pipelineId
        self.phase = phase
        self.progress = progress
        self.message = message
        self.data = data
        self.chunkContent = chunkContent
        self.thinkingContent = thinkingContent
        self.artifact = artifact
        self.payload = payload
    }
}

/// Flexible coding keys that accept any string key.
private struct FlexCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

struct A2AEventData: Codable {
    let agentName: String?
    let artifactType: String?
    let artifactId: String?
    let fromAgent: String?
    let toAgent: String?
    let qaScore: Double?
    let error: String?
    let courseId: String?
    let totalDurationMs: Double?

    enum CodingKeys: String, CodingKey {
        case agentName = "agent_name"
        case artifactType = "artifact_type"
        case artifactId = "artifact_id"
        case fromAgent = "from_agent"
        case toAgent = "to_agent"
        case qaScore = "qa_score"
        case error
        case courseId = "course_id"
        case totalDurationMs = "total_duration_ms"
    }
}

// MARK: - Request/Response Models

/// Request for A2A course generation
struct A2AGenerateRequest: Encodable {
    let request: String
    let qualityTier: String
    let userContext: [String: String]?
    let enableQualityGates: Bool
    let enableVisuals: Bool
    let enableVoice: Bool
    let enableParallel: Bool

    enum CodingKeys: String, CodingKey {
        case request
        case qualityTier = "quality_tier"
        case userContext = "user_context"
        case enableQualityGates = "enable_quality_gates"
        case enableVisuals = "enable_visuals"
        case enableVoice = "enable_voice"
        case enableParallel = "enable_parallel"
    }

    init(
        topic: String,
        qualityTier: CourseQualityTier = .standard,
        userContext: [String: String]? = nil,
        enableQualityGates: Bool = true,
        enableVisuals: Bool = true,
        enableVoice: Bool = true,
        enableParallel: Bool = true
    ) {
        self.request = topic
        self.qualityTier = qualityTier.rawValue
        self.userContext = userContext
        self.enableQualityGates = enableQualityGates
        self.enableVisuals = enableVisuals
        self.enableVoice = enableVoice
        self.enableParallel = enableParallel
    }
}

struct A2ACourseJobResponse: Codable {
    let jobId: String
    let status: String
    let qualityTier: String
    let estimatedCostUsd: Double
    let message: String
    let pollUrl: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case qualityTier = "quality_tier"
        case estimatedCostUsd = "estimated_cost_usd"
        case message
        case pollUrl = "poll_url"
    }
}

struct CourseGenerationStatus: Codable {
    let jobId: String
    let status: String
    let progressPercent: Int
    let currentStep: String?
    let stepsCompleted: [String]
    let error: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case progressPercent = "progress_percent"
        case currentStep = "current_step"
        case stepsCompleted = "steps_completed"
        case error
    }
}

/// Response from A2A course generation (Final result)
struct A2ACourseResponse: Codable {
    let pipelineId: String
    let status: String
    let course: A2AGeneratedCourse?
    let phases: [A2APhaseProgress]
    let metrics: A2APipelineMetrics?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case pipelineId = "task_id"
        case status, course, phases, metrics, error
    }
}

struct A2AGeneratedCourse: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let modules: [A2ACourseModule]
    let learningObjectives: [String]
    let estimatedDuration: Int  // minutes
    let difficulty: String
    let visualAssets: [A2AVisualAsset]?
    let voiceAssets: [A2AVoiceAsset]?

    enum CodingKeys: String, CodingKey {
        case id, title, description, modules
        case learningObjectives = "learning_objectives"
        case estimatedDuration = "estimated_duration"
        case difficulty
        case visualAssets = "visual_assets"
        case voiceAssets = "voice_assets"
    }
}

struct A2ACourseModule: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let lessons: [A2ACourseLesson]
    let order: Int
}

struct A2ACourseLesson: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let durationMinutes: Int
    let order: Int
    let scenes: [A2AScene]?

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case durationMinutes = "duration_minutes"
        case order, scenes
    }
}

struct A2AScene: Codable, Identifiable {
    let id: String
    let type: String
    let heading: String
    let content: String
    let visualPrompt: String?
    let voiceScript: String?
    let duration: Int  // seconds

    enum CodingKeys: String, CodingKey {
        case id, type, heading, content
        case visualPrompt = "visual_prompt"
        case voiceScript = "voice_script"
        case duration
    }
}

// MARK: - Asset Models

struct A2AVisualAsset: Codable, Identifiable {
    let id: String
    let sceneId: String
    let type: String  // image, diagram, animation
    let prompt: String
    let style: String
    let generatedUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sceneId = "scene_id"
        case type, prompt, style
        case generatedUrl = "generated_url"
    }
}

struct A2AVoiceAsset: Codable, Identifiable {
    let id: String
    let sceneId: String
    let text: String
    let ssml: String?
    let voice: String
    let emotion: String
    let audioUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sceneId = "scene_id"
        case text, ssml, voice, emotion
        case audioUrl = "audio_url"
    }
}

// MARK: - Pipeline Metrics

struct A2APipelineMetrics: Codable {
    let totalDurationMs: Double
    let phaseTimings: [String: Double]
    let agentHandoffs: Int
    let qaScore: Double?
    let tokensUsed: Int?
    let estimatedCostUsd: Double?

    enum CodingKeys: String, CodingKey {
        case totalDurationMs = "total_duration_ms"
        case phaseTimings = "phase_timings"
        case agentHandoffs = "agent_handoffs"
        case qaScore = "qa_score"
        case tokensUsed = "tokens_used"
        case estimatedCostUsd = "estimated_cost_usd"
    }
}

// MARK: - Pipeline Status Response

struct A2APipelineStatus: Codable {
    let pipelineId: String
    let status: String
    let progress: Int
    let currentPhase: A2APipelinePhase?
    let phases: [A2APhaseProgress]
    let course: A2AGeneratedCourse?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case pipelineId = "pipeline_id"
        case status, progress
        case currentPhase = "current_phase"
        case phases, course, error
    }
}

// MARK: - Agent Discovery

struct A2AAgentDiscovery: Codable {
    let agents: [A2AAgentCard]
    let protocolVersion: String
    let serverVersion: String

    enum CodingKeys: String, CodingKey {
        case agents
        case protocolVersion = "protocol_version"
        case serverVersion = "server_version"
    }
}

// MARK: - Agent Execution (Direct)

struct A2AAgentExecuteRequest: Encodable {
    let taskInput: A2ATaskInput

    enum CodingKeys: String, CodingKey {
        case taskInput = "task_input"
    }
}

struct A2ATaskInput: Codable {
    let taskId: String
    let prompt: String
    let context: [String: String]?
    let artifacts: [String]?  // Artifact IDs from previous agents

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case prompt, context, artifacts
    }
}

struct A2ATaskOutput: Codable {
    let taskId: String
    let status: String
    let result: String?
    let artifacts: [A2AArtifact]
    let metrics: A2ATaskMetrics?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status, result, artifacts, metrics
    }
}

struct A2AArtifact: Codable, Identifiable {
    let id: String
    let type: String
    let name: String
    let mimeType: String
    let data: String?  // Base64 or JSON string
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, type, name
        case mimeType = "mime_type"
        case data, metadata
    }
}

struct A2ATaskMetrics: Codable {
    let durationMs: Double
    let tokensUsed: Int?
    let modelUsed: String?

    enum CodingKeys: String, CodingKey {
        case durationMs = "duration_ms"
        case tokensUsed = "tokens_used"
        case modelUsed = "model_used"
    }
}

// MARK: - Course Quality Tier

/// Quality tier for course generation
enum CourseQualityTier: String, Codable, CaseIterable {
    case fast = "fast"
    case standard = "standard"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .standard: return "Standard"
        case .premium: return "Premium"
        }
    }

    var description: String {
        switch self {
        case .fast: return "Quick generation with basic structure"
        case .standard: return "Balanced quality and speed"
        case .premium: return "Highest quality with full multimedia"
        }
    }

    var estimatedTime: String {
        switch self {
        case .fast: return "~30 seconds"
        case .standard: return "~2 minutes"
        case .premium: return "~5 minutes"
        }
    }
}

// MARK: - V2 API Specific Response Models (Intermediate)

struct APICourseResult: Codable {
    let courseId: String
    let title: String
    let description: String
    let modules: [APICourseModule]
    let estimatedDuration: Int
    let difficulty: String

    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case title, description, modules
        case estimatedDuration = "estimated_duration"
        case difficulty
    }
}

struct APICourseModule: Codable {
    let id: String
    let title: String
    let description: String
    let lessons: [APICourseLesson]
}

struct APICourseLesson: Codable {
    let id: String
    let title: String
    let content: String
    let durationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case durationMinutes = "duration_minutes"
    }
}
