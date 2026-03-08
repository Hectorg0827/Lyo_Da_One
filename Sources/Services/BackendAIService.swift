//
//  BackendAIService.swift
//  Lyo
//
//  Routes AI chat through the backend for proper analytics, cost management, and dual-AI support
//  Backend uses Gemini (brain) + OpenAI (conversation) hybrid system
//

import Foundation
import os

// MARK: - Backend AI Error

enum BackendAIError: Error, LocalizedError {
    case invalidResponse
    case invalidPayload(String)
    case networkError(String)
    case serverError(String)
    case unauthorized
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .invalidPayload(let msg): return "Invalid payload: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .serverError(let msg): return "Server error: \(msg)"
        case .unauthorized: return "Unauthorized"
        case .rateLimited: return "Rate limited"
        }
    }
}

// MARK: - Backend AI Request/Response Models

// Request for /api/v1/ai/chat (public endpoint - no auth required)
// Backend schema expects: message (required), conversationHistory (optional), context (optional string)
struct BackendAIChatRequest: Encodable {
    let message: String
    let conversationHistory: [ConversationMessage]?
    let context: String?  // Must be a string, not a dictionary!
    
    enum CodingKeys: String, CodingKey {
        case message
        case conversationHistory
        case context
    }
}

// MARK: - A2UI Models 

// NOTE: We use the shared OpenClassroomPayload from Models/LyoChat.swift 
// and StackItemPayload/CoursePayload from Models/AICommandResponse.swift
// to avoid ambiguity.

// Private envelope for decoding the raw JSON structure
private struct OpenClassroomEnvelope: Codable {
    let type: String
    let payload: OpenClassroomPayload
}

/// A2UI Content payload from backend - supports multiple widget types
struct A2UIContent: Codable {
    let type: A2UIContentType
    
    // Course Roadmap Widget (nested structure)
    let courseRoadmap: A2UICourseRoadmap?
    
    // Quiz Widget (nested structure)
    let quiz: A2UIQuiz?
    
    // Topic Selection Widget
    let title: String?
    let topics: [A2UITopicOption]?
    
    // Flashcards Widget
    let cards: [A2UIFlashcard]?
    
    // Flat course roadmap fields (backwards compatibility)
    let modules: [A2UIFlatModule]?
    let totalModules: Int?
    let completedModules: Int?
    
    // Suggestions Widget (fallback for engagement)
    let suggestions: [String]?
    
    // Cinematic Widget (Immersive)
    let cinematic: A2UICinematic?
    
    // Generative UI Layout Hint (New)
    let layout: A2UILayout?
    
    enum CodingKeys: String, CodingKey {
        case type
        case courseRoadmap = "course_roadmap"
        case quiz
        case title
        case topics
        case cards
        case modules
        case totalModules
        case completedModules
        case suggestions
        case cinematic
        case layout
    }
}

enum A2UILayout: String, Codable {
    case standard, split, overlay, grid, hero
}

enum A2UIContentType: String, Codable {
    case text
    case processing
    case topicSelection = "topic_selection"
    case courseRoadmap = "course_roadmap"
    case flashcards
    case quiz
    case suggestions
    case cinematic
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = A2UIContentType(rawValue: value) ?? .unknown
    }
}

// MARK: - Cinematic Models
struct A2UICinematic: Codable, Identifiable {
    var id: String { title }
    let title: String
    let subtitle: String?
    let mood: String
    let videoUrl: String?
    let audioTrack: String?
    let hapticPattern: String?
}

// MARK: - Course Roadmap Models
struct A2UICourseRoadmap: Codable {
    let title: String
    let topic: String
    let level: String
    let modules: [A2UIModule]
}

struct A2UIModule: Codable {
    let title: String
    let description: String?
    let lessons: [A2UILesson]?
    
    // Memberwise initializer for manual construction
    init(title: String, description: String? = nil, lessons: [A2UILesson]? = nil) {
        self.title = title
        self.description = description
        self.lessons = lessons
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lessons = try container.decodeIfPresent([A2UILesson].self, forKey: .lessons)
    }
    
    enum CodingKeys: String, CodingKey {
        case title, description, lessons
    }
}

struct A2UILesson: Codable {
    let title: String
    let duration: String?
}

// Flat module for backwards compatibility
struct A2UIFlatModule: Codable {
    let id: String?
    let title: String
    let duration: String?
    let isCompleted: Bool?
    let isLocked: Bool?
}

// MARK: - Quiz Models
struct A2UIQuiz: Codable {
    let title: String
    let questions: [A2UIQuestion]
}

struct A2UIQuestion: Codable {
    let question: String
    let options: [String]
    let correctAnswer: String
    
    enum CodingKeys: String, CodingKey {
        case question
        case options
        case correctAnswer = "correct_answer"
    }
}

// MARK: - Topic Selection Models
struct A2UITopicOption: Codable {
    let title: String
    let icon: String?
    let gradientColors: [String]?
}

// MARK: - Flashcard Models
struct A2UIFlashcard: Codable {
    let front: String
    let back: String
    let hint: String?
}

// Response from /api/v1/chat (Chat Module with A2UI support)
// Backend returns: { "response": "...", "type": "OPEN_CLASSROOM", "payload": {...}, "conversationHistory": [...] }
struct BackendAIChatResponse: Codable {
    // Primary fields from backend ChatResponse
    let response: String?  // Backend's main response field
    let conversationHistory: [ConversationMessage]?
    let contentTypes: [A2UIContent]?
    
    /// Flexible A2UI Component container. Supports both single DynamicComponent 
    /// and arrays of legacy/hybrid components to prevent decoding failures.
    let uiComponent: AnyCodable? 

    
    // A2UI Command fields (OPEN_CLASSROOM, etc.)
    let type: String?  // e.g. "OPEN_CLASSROOM"
    let payload: OpenClassroomCommand.OpenClassroomPayload?  // The course/classroom payload
    
    // Legacy fields for backward compatibility (may not be present anymore)
    let content: String?  // Some endpoints still use this
    let primaryAi: String?
    let secondaryAi: String?
    let taskType: String?
    let reasoning: String?
    let conversationTone: String?
    let responseTimeMs: Double?
    let tokensUsed: Int?
    let costEstimate: Double?
    let confidenceScore: Double?
    let modelVersions: [String: String]?
    let userId: Int?
    
    // New fields for Mentor Mode
    let responseMode: ResponseMode?
    let quickExplainer: QuickExplainerData?
    let courseProposal: CourseProposalData?
    let studyPlan: TestPrepData?
    
    // Lyo Protocol Fields
    let lyoBlocks: [LyoBlock]?
    
    // Context-aware suggestion chips returned alongside each response
    let suggestions: [SuggestionChip]?
    
    enum CodingKeys: String, CodingKey {
        case response
        case conversationHistory = "conversationHistory"
        case type
        case payload
        case content
        case primaryAi = "primary_ai"
        case secondaryAi = "secondary_ai"
        case taskType = "task_type"
        case reasoning
        case conversationTone = "conversation_tone"
        case responseTimeMs = "response_time_ms"
        case tokensUsed = "tokens_used"
        case costEstimate = "cost_estimate"
        case confidenceScore = "confidence_score"
        case modelVersions = "model_versions"
        case userId = "user_id"
        case responseMode = "responseMode"
        case quickExplainer = "quickExplainer"
        case courseProposal = "courseProposal"
        case studyPlan = "study_plan"
        case contentTypes = "contentTypes"
        case uiComponent = "ui_component"   // backend sends snake_case
        case lyoBlocks = "lyoBlocks"
        case suggestions = "suggestions"
    }
    
    // Computed property for easy access to the AI response text
    var responseText: String {
        return response ?? content ?? "No response"
    }
    
    // Computed property for AI source (with fallback)
    var aiSource: String {
        return primaryAi ?? "gemini"
    }
    
    // MARK: - A2UI Extractor (The Markdown Trap Fix)
    /// Robustly extracts A2UI JSON payloads even if wrapped in Markdown code blocks
    /// Pre-compiled regex for extracting OPEN_CLASSROOM JSON from response text (compiled once)
    private static let openClassroomRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"(?s)\{.*"type"\s*:\s*"OPEN_CLASSROOM".*\}"#, options: [])
    }()
    
    var extractedUI: OpenClassroomPayload? {
        let text = responseText
        
        // 1. Fast check: text must contain the type identifier
        guard text.contains("OPEN_CLASSROOM") else { return nil }
        
        // 2. Try to find JSON block pattern using cached regex
        guard let regex = BackendAIChatResponse.openClassroomRegex else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Check finding
        for match in results {
            let jsonString = nsString.substring(with: match.range)
            
            // Clean up potentially persistent markdown markers inside the match? 
            // Usually the regex above grabs the brace-to-brace content.
            // But if there are markdown ticks inside, we might need a stricter clean.
            // A common case: ```json\n{...}\n```. The regex above matches { to }.
            
            do {
                if let data = jsonString.data(using: .utf8) {
                    let envelope = try JSONDecoder().decode(OpenClassroomEnvelope.self, from: data)
                    return envelope.payload
                }
            } catch {
                Log.ai.error("Failed to decode JSON string: \(error.localizedDescription)")
            }

            // Fallback: Clean markdown code blocks and retry decoding
            let cleaned = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                if let data = cleaned.data(using: .utf8) {
                    let envelope = try JSONDecoder().decode(OpenClassroomEnvelope.self, from: data)
                    return envelope.payload
                }
            } catch {
                Log.ai.error("Failed to decode cleaned JSON string: \(error.localizedDescription)")
            }

            return nil
        }
        
        return nil
    }
}

// Legacy types for backwards compatibility
struct BackendStudySessionRequest: Encodable {
    let resourceId: String
    let conversationHistory: [ConversationMessage]
    let userInput: String
}

struct ConversationMessage: Codable {
    let role: String  // "system", "user", "assistant"
    let content: String
}

struct BackendStudySessionResponse: Codable {
    let response: String
    let conversationHistory: [ConversationMessage]
}

struct BackendQuizRequest: Encodable {
    let resourceId: String
    let quizType: String
    let questionCount: Int
}

struct BackendQuizQuestion: Codable {
    let question: String
    let options: [String]
    let correctAnswer: String
}

struct BackendAnswerAnalysisRequest: Encodable {
    let question: String
    let correctAnswer: String
    let userAnswer: String
}

struct BackendAnswerAnalysisResponse: Codable {
    let feedback: String
}

// MARK: - Course Generation Models

struct CourseGenerationJobResponse: Codable {
    // Note: Property names use camelCase, JSON uses snake_case
    // lyoDecoder's .convertFromSnakeCase handles this automatically
    let jobId: String
    let status: String
    let qualityTier: String
    let estimatedCostUsd: Double
    let message: String
    let pollUrl: String
}

struct CourseGenerationStatusResponse: Codable {
    // Note: Property names use camelCase, JSON uses snake_case
    // lyoDecoder's .convertFromSnakeCase handles this automatically
    let jobId: String
    let status: String
    let progressPercent: Int
    let currentStep: String?
    let stepsCompleted: [String]
    let estimatedTimeRemainingSeconds: Int?
    let createdAt: String
    let updatedAt: String?
    let error: String?
}

struct CourseOutlineModule: Codable {
    let id: String
    let title: String
    let description: String
}

struct CourseOutlineResponse: Codable {
    let courseId: String
    let title: String
    let description: String
    let modules: [CourseOutlineModule]
    let estimatedDuration: Int
    let difficulty: String
    let outlineHash: String
    let status: String
}

struct CourseModuleResponse: Codable {
    let courseId: String
    let module: CourseGenerationService.BackendCourseResult.BackendModule
    let status: String
}

// MARK: - Backend AI Service

@MainActor
final class BackendAIService {
    static let shared = BackendAIService()
    
    private var baseURL: String { AppConfig.baseURL }
    private let tokenManager = TokenManager.shared
    
    // Conversation state
    private var conversationHistory: [ConversationMessage] = []
    private var currentResourceId: String = "general_learning"
    
    private init() {
        Log.ai.info("BackendAIService initialized - using hybrid AI (Gemini + OpenAI)")
    }
    
    // MARK: - JSON Coders
    
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
    
    // MARK: - Context-Aware Suggestions

    /// Fetches context-aware suggestion chips from the fast `/api/v1/ai/chat` endpoint.
    /// Returns an empty array on failure — callers should already show fallback chips.
    func fetchSuggestions(trigger message: String) async throws -> [SuggestionChip] {
        let endpoint = Endpoints.AI.chat(message: message, provider: nil, context: nil)
        let response: BackendAIChatResponse = try await NetworkClient.shared.request(endpoint)
        return response.suggestions ?? []
    }

    // MARK: - Streaming Study Session
    
    /// Stream AI response in real-time using Server-Sent Events
    /// Much better UX - shows text as it's generated instead of waiting
    ///
    /// Includes:
    /// - 60-second timeout watchdog (resets on each chunk)
    /// - Automatic retry (up to 2 attempts on transient failures)
    /// - Safe MainActor dispatch for all callbacks
    func streamStudySession(
        message: String,
        resourceId: String? = nil,
        mode: String = "focus",
        onChunk: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (String, Double) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) {
        // Update resource context if provided
        if let resourceId = resourceId {
            if resourceId != currentResourceId {
                conversationHistory.removeAll()
                currentResourceId = resourceId
            }
        }
        
        // Build context
        var contextDict: [String: String] = [
            "mode": mode,
            "topic": currentResourceId
        ]
        
        if !conversationHistory.isEmpty {
            let historyContext = conversationHistory.suffix(4).map { "\($0.role): \($0.content)" }.joined(separator: "\n")
            contextDict["conversation_history"] = historyContext
        }
        
        Task {
            let maxRetries = 2
            var lastError: Error?
            
            for attempt in 0...maxRetries {
                if attempt > 0 {
                    let backoff = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000
                    Log.ai.info("SSE retry attempt \(attempt)/\(maxRetries) after \(attempt)s backoff")
                    try? await Task.sleep(nanoseconds: backoff)
                }
                
                do {
                    try await performStream(
                        message: message,
                        contextDict: contextDict,
                        onChunk: onChunk,
                        onComplete: onComplete
                    )
                    return // Success — exit retry loop
                } catch is CancellationError {
                    onError(CancellationError())
                    return
                } catch {
                    lastError = error
                    let isTransient = (error as NSError).code == NSURLErrorTimedOut
                        || (error as NSError).code == NSURLErrorNetworkConnectionLost
                    if !isTransient || attempt == maxRetries {
                        Log.ai.error("SSE stream failed (attempt \(attempt + 1)): \(error.localizedDescription)")
                        onError(error)
                        return
                    }
                }
            }
            onError(lastError ?? BackendAIError.networkError("Stream failed after retries"))
        }
    }
    
    /// Internal stream execution with a 60-second stall timeout
    private func performStream(
        message: String,
        contextDict: [String: String],
        onChunk: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (String, Double) -> Void
    ) async throws {
        let streamTimeout: UInt64 = 60_000_000_000 // 60 seconds
        
        let (bytes, response) = try await NetworkClient.shared.stream(Endpoints.AI.chatStream(message: message, context: contextDict))
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw BackendAIError.invalidResponse
        }
        
        var fullContent = ""
        var responseTime: Double = 0
        
        // Wrap the stream iteration with a timeout watchdog
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Shared state for timeout coordination
            let lastActivity = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
            lastActivity.pointee = DispatchTime.now().uptimeNanoseconds
            defer { lastActivity.deallocate() }
            
            // Watchdog: fires if no chunks arrive for 60s
            group.addTask {
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5s
                    let elapsed = DispatchTime.now().uptimeNanoseconds - lastActivity.pointee
                    if elapsed > streamTimeout {
                        throw BackendAIError.networkError("Stream stalled — no data for 60 seconds")
                    }
                }
            }
            
            // Main stream consumer
            group.addTask { [self] in
                for try await line in bytes.lines {
                    lastActivity.pointee = DispatchTime.now().uptimeNanoseconds
                    
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonStr = String(line.dropFirst(6))
                    guard let jsonData = jsonStr.data(using: .utf8),
                          let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }
                    
                    let eventType = event["type"] as? String ?? ""
                    
                    switch eventType {
                    case "start":
                        let primaryAI = event["primary_ai"] as? String ?? "unknown"
                        Log.ai.info("Stream started with \(primaryAI)")
                        
                    case "chunk":
                        if let content = event["content"] as? String {
                            fullContent += content
                            onChunk(content)
                        }
                        
                    case "done":
                        responseTime = event["response_time_ms"] as? Double ?? 0
                        Log.ai.info("Stream completed in \(responseTime)ms")
                        
                        // Update conversation history on MainActor
                        await MainActor.run {
                            self.conversationHistory.append(ConversationMessage(role: "user", content: message))
                            self.conversationHistory.append(ConversationMessage(role: "assistant", content: fullContent))
                            if self.conversationHistory.count > 10 {
                                self.conversationHistory = Array(self.conversationHistory.suffix(10))
                            }
                        }
                        
                        onComplete(fullContent, responseTime)
                        return // Stream finished normally
                        
                    case "error":
                        let errorMsg = event["message"] as? String ?? "Unknown error"
                        Log.ai.error("Stream error: \(errorMsg)")
                        throw BackendAIError.serverError(errorMsg)
                        
                    default:
                        break
                    }
                }
            }
            
            // Wait for either the stream to finish or the watchdog to fire
            try await group.next()
            group.cancelAll()
        }
    }
    
    // MARK: - Study Session (Socratic Dialogue)
    
    /// Send a message through the backend AI for Socratic-style tutoring
    /// Uses backend's dual-AI system (Gemini for reasoning, OpenAI for conversation)
    func studySession(
        message: String,
        resourceId: String? = nil,
        mode: String = "focus",
        history: [ConversationMessage]? = nil
    ) async throws -> (response: String, source: String, uiContent: [A2UIContent]?, uiComponent: AnyCodable?, wasCommand: Bool, openClassroomPayload: OpenClassroomPayload?, mappedComponents: [A2UIComponent]?) {
        
        // Update resource context if provided
        if let resourceId = resourceId {
            if resourceId != currentResourceId {
                // New topic - reset conversation (only if using internal history)
                if history == nil {
                     conversationHistory.removeAll()
                }
                currentResourceId = resourceId
            }
        }
        
        // Build the system prompt - this must be sent as part of conversation history
        // NOT in the context field (which backend treats as metadata)
        let systemPrompt = buildSystemPrompt(for: mode, resourceId: currentResourceId)
        
        // Build conversation history with system prompt at the start
        var historyWithSystem: [ConversationMessage] = []
        
        // Add system prompt as first message if this is a new conversation
        // Use provided history or internal history
        let previousHistory = history ?? conversationHistory
        
        if previousHistory.isEmpty {
            historyWithSystem.append(ConversationMessage(role: "system", content: systemPrompt))
        }
        
        // Add existing conversation history
        historyWithSystem.append(contentsOf: previousHistory.suffix(8))
        
        // Build request - context should be simple metadata, not the full prompt
        let contextMetadata = "mode=\(mode),topic=\(currentResourceId)"
        
        let request = BackendAIChatRequest(
            message: message,
            conversationHistory: historyWithSystem.isEmpty ? nil : historyWithSystem,
            context: contextMetadata
        )
        
        // CRITICAL: Use /api/v1/chat (Chat Module) NOT /api/v1/ai/chat (AI Study)
        // The Chat Module returns A2UI payloads with type: "OPEN_CLASSROOM" and payload fields
        // that trigger classroom navigation in the iOS app
        let endpoint = "\(baseURL)/api/v1/chat"
        
        let dynamicEndpoint = DynamicEndpoint(
            urlString: endpoint,
            method: .post,
            body: request,
            requiresAuth: true
        )
        
        let chatResponse: BackendAIChatResponse = try await NetworkClient.shared.request(dynamicEndpoint)
        
        // Update internal conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: message))
        conversationHistory.append(ConversationMessage(role: "assistant", content: chatResponse.responseText))
        if conversationHistory.count > 10 {
            conversationHistory = Array(conversationHistory.suffix(10))
        }
        
        // Detect A2UI command
        let wasCommand = chatResponse.type == "OPEN_CLASSROOM"
        let openClassroomPayload = chatResponse.extractedUI
        
        // Map A2UI components if uiComponent JSON is present
        var mappedComponents: [A2UIComponent]? = nil
        if let uiComp = chatResponse.uiComponent,
           let jsonData = try? JSONEncoder().encode(uiComp) {
            mappedComponents = A2IPayloadMapper.mapFromJSON(jsonData)
        }
        
        return (
            response: chatResponse.responseText,
            source: chatResponse.aiSource,
            uiContent: chatResponse.contentTypes,
            uiComponent: chatResponse.uiComponent,
            wasCommand: wasCommand,
            openClassroomPayload: openClassroomPayload,
            mappedComponents: mappedComponents
        )
    }
    
    // MARK: - Generate Quiz
    
    /// Generate a quiz through the backend AI
    func generateQuiz(
        resourceId: String,
        quizType: String = "multiple_choice",
        questionCount: Int = 5
    ) async throws -> [BackendQuizQuestion] {
        
        let request = BackendQuizRequest(
            resourceId: resourceId,
            quizType: quizType,
            questionCount: questionCount
        )
        
        let endpoint = "\(baseURL)/api/v1/ai/generate-quiz"
        
        return try await post(endpoint: endpoint, body: request)
    }
    
    // MARK: - Analyze Answer
    
    /// Get AI feedback on a quiz answer
    func analyzeAnswer(
        question: String,
        correctAnswer: String,
        userAnswer: String
    ) async throws -> String {
        
        let request = BackendAnswerAnalysisRequest(
            question: question,
            correctAnswer: correctAnswer,
            userAnswer: userAnswer
        )
        
        let endpoint = "\(baseURL)/api/v1/ai/analyze-answer"
        
        let response: BackendAnswerAnalysisResponse = try await post(endpoint: endpoint, body: request)
        return response.feedback
    }
    
    // MARK: - Conversation Management
    
    /// Clear conversation history (start fresh)
    func clearConversation() {
        conversationHistory.removeAll()
        currentResourceId = "general_learning"
    }
    
    /// Set the learning context/topic
    func setContext(resourceId: String) {
        if resourceId != currentResourceId {
            conversationHistory.removeAll()
            currentResourceId = resourceId
        }
    }
    
    // MARK: - Course Generation (Multi-Agent v2)
    
    /// Estimate cost for generating a course
    func estimateCost(
        topic: String,
        options: CourseGenerationOptions
    ) async throws -> CostEstimate {
        let request = CostEstimateRequest(
            topic: topic,
            options: options
        )
        
        let endpoint = Endpoints.CourseGenerationV2.estimateCost(body: request)
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    /// Generate a course with enhanced quality and feature controls
    func generateCourse(
        topic: String,
        options: CourseGenerationOptions = .recommended,
        userContext: [String: String]? = nil
    ) async throws -> CourseGenerationJobResponse {
        var requestDict: [String: Any] = [
            "request": topic,
            "quality_tier": options.qualityTier.rawValue,
            "enable_code_examples": options.includeCodeExamples,
            "enable_practice_exercises": options.includePracticeExercises,
            "enable_final_quiz": options.includeFinalQuiz,
            "enable_multimedia_suggestions": options.includeMultimediaSuggestions,
            "qa_strictness": options.qaStrictness,
            "target_language": options.targetLanguage
        ]
        
        if let budget = options.maxBudgetUSD {
            requestDict["max_budget_usd"] = budget
        }
        
        if let context = userContext {
            requestDict["user_context"] = context
        }
        
        let endpoint = Endpoints.CourseGenerationV2.generate(body: DataWrapper(data: try JSONSerialization.data(withJSONObject: requestDict)))
        
        return try await NetworkClient.shared.request(endpoint)
    }

    /// Generate course outline immediately and continue full generation in background
    func generateCourseOutline(
        topic: String,
        options: CourseGenerationOptions = .recommended,
        userContext: [String: String]? = nil
    ) async throws -> CourseOutlineResponse {
        var requestDict: [String: Any] = [
            "request": topic,
            "quality_tier": options.qualityTier.rawValue,
            "enable_code_examples": options.includeCodeExamples,
            "enable_practice_exercises": options.includePracticeExercises,
            "enable_final_quiz": options.includeFinalQuiz,
            "enable_multimedia_suggestions": options.includeMultimediaSuggestions,
            "qa_strictness": options.qaStrictness,
            "target_language": options.targetLanguage
        ]

        if let budget = options.maxBudgetUSD {
            requestDict["max_budget_usd"] = budget
        }

        if let context = userContext {
            requestDict["user_context"] = context
        }

        let endpoint = Endpoints.CourseGenerationV2.outline(body: DataWrapper(data: try JSONSerialization.data(withJSONObject: requestDict)))
        return try await NetworkClient.shared.request(endpoint)
    }

    func getCourseModule(courseId: String, moduleId: String) async throws -> CourseModuleResponse {
        let endpoint = Endpoints.CourseGenerationV2.getModule(courseId: courseId, moduleId: moduleId)
        return try await NetworkClient.shared.request(endpoint)
    }

    func generateCourseModule(courseId: String, moduleId: String) async throws -> CourseModuleResponse {
        let endpoint = Endpoints.CourseGenerationV2.generateModule(courseId: courseId, moduleId: moduleId, body: nil)
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - V2 Generator Endpoints (Strict LyoSchema)

    private struct GenerateCourseV2Request: Encodable {
        let topic: String
        let targetAudience: String
        let learningObjectives: [String]

        enum CodingKeys: String, CodingKey {
            case topic
            case targetAudience = "target_audience"
            case learningObjectives = "learning_objectives"
        }
    }
    
    /// Fetches the static 'Spanish 101' demo course to verify V2 schema parsing.
    func fetchSpanish101Demo() async throws -> LyoCourse {
        let endpoint = Endpoints.CourseGenerationV2.generatorDemo
        return try await NetworkClient.shared.request(endpoint)
    }
    
    /// Generates a full V2 course (blocking call for MVP)
    func generateCourseV2(topic: String, audience: String, objectives: [String]) async throws -> LyoCourse {
        let body = GenerateCourseV2Request(
            topic: topic,
            targetAudience: audience,
            learningObjectives: objectives
        )
        
        let endpoint = Endpoints.CourseGenerationV2.generatorGenerate(body: body)
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    /// Poll for course generation status
    func getCourseGenerationStatus(jobId: String) async throws -> CourseGenerationStatusResponse {
        let endpoint = Endpoints.CourseGenerationV2.status(jobId: jobId)
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - System Prompt Builder
    
    // MARK: - Private Networking Helpers
    
    /// Generic POST helper (authenticated)
    private func post<T: Encodable, R: Codable>(endpoint: String, body: T) async throws -> R {
        let dynamicEndpoint = DynamicEndpoint(
            urlString: endpoint,
            method: .post,
            body: body,
            requiresAuth: true
        )
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
    
    /// Generic POST helper (public / no auth)
    internal func postPublic<T: Encodable, R: Codable>(endpoint: String, body: T) async throws -> R {
        let dynamicEndpoint = DynamicEndpoint(
            urlString: endpoint,
            method: .post,
            body: body,
            requiresAuth: false
        )
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
    
    private func buildSystemPrompt(for mode: String, resourceId: String) -> String {
        return """
        You are **Lyo**, the AI assistant inside the **Lyo** learning app.
        Lyo is an AI-powered learning and life-long growth platform that should feel:
        * Friendly, modern, slightly playful (not like a boring school LMS)
        * Smart and “AI-powered” but not overwhelming
        * Useful for both students and life-learners

        The app has multiple main surfaces:
        1. **Chat Screen (this screen)** – conversational interface with Lyo.
        2. **AI Classroom** – a dedicated area where full courses, lessons, and structured learning flows live.
        3. **Stack** – a “today’s stack” view of the user’s active items (courses, tutors, chats, tasks, etc.), shown as cards.

        Your job in this chat:
        * Answer normal questions directly in chat.
        * Detect when the user wants a **course / class / structured learning plan**, and in that case:
          * Do NOT build the whole course in chat.
          * Instead, send a structured JSON “UI event” so the app can:
            1. Open the AI Classroom for that topic, and
            2. Add an item to the user’s Stack.

        You must always respect this separation:
        * Chat = quick help, explanations, small tasks.
        * AI Classroom = full courses / structured, multi-step learning experiences.
        * Stack = cards that represent things the user can open / resume / join.

        ---

        ## 1. When to trigger the AI Classroom

        You must treat the user as requesting a **course / class / structured plan** when they clearly ask for any of the following:
        * “Create a course on X…”
        * “Make a full course about…”
        * “Create a study plan / learning plan for…”
        * “Teach me X from zero / from scratch.”
        * “Start a class on…”
        * “I want a full program to learn…”
        * “Take me to the classroom for…”

        Also treat it as a course request when:
        * The user asks for step-by-step learning across multiple lessons.
        * The request obviously implies **multiple sessions or lessons**, not just a single answer.

        In those situations:
        * **Do NOT** generate a long, multi-lesson course directly in this chat.
        * **Do NOT** send multiple messages.
        * **DO** send exactly one JSON object following the schema defined below.

        If the request is **only** a short question or a single concept, you must **stay in chat** and answer normally, even if it’s about a topic you could make a course for.

        Examples that should **stay in chat** (normal answer, no JSON):
        * “What is a variable in Python?”
        * “Explain the difference between a list and a dictionary.”
        * “How do I calculate compound interest?”
        * “What’s a good way to memorize vocabulary?”

        ---

        ## 2. Output format for classroom requests

        When the user clearly wants a **course / class / structured learning plan**, you must respond with **only** a single JSON object using this structure:

        ```json
        {
          "type": "OPEN_CLASSROOM",
          "payload": {
            "stack_item": {
              "category": "Course",
              "title": "<short course title for the Stack card>",
              "subtitle": "<one-line description or goal for the card>",
              "status": "active",
              "due": null
            },
            "course": {
              "title": "<short course title>",
              "topic": "<main topic in a few words>",
              "level": "<beginner|intermediate|advanced|mixed>",
              "language": "<user language, e.g. 'English' or 'Spanish'>",
              "duration": "<approx duration, e.g. '6 lessons' or '4 weeks'>",
              "objectives": [
                "<short learning objective 1>",
                "<short learning objective 2>",
                "<short learning objective 3>"
              ]
            }
          }
        }
        """
    }
}
