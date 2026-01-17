//
//  BackendAIService.swift
//  Lyo
//
//  Routes AI chat through the backend for proper analytics, cost management, and dual-AI support
//  Backend uses Gemini (brain) + OpenAI (conversation) hybrid system
//

import Foundation

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

// MARK: - A2UI Models (Backend-Driven UI)
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
    }
}

enum A2UIContentType: String, Codable {
    case text
    case processing
    case topicSelection = "topic_selection"
    case courseRoadmap = "course_roadmap"
    case flashcards
    case quiz
    case suggestions
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = A2UIContentType(rawValue: value) ?? .unknown
    }
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

// Response from /api/v1/ai/chat
// Backend returns: { "response": "...", "conversationHistory": [...] }
struct BackendAIChatResponse: Codable {
    // Primary fields from backend ChatResponse
    let response: String?  // Backend's main response field
    let conversationHistory: [ConversationMessage]?
    let contentTypes: [A2UIContent]?
    
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
    
    enum CodingKeys: String, CodingKey {
        case response
        case conversationHistory
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
        case responseMode = "response_mode"
        case quickExplainer = "quick_explainer"
        case courseProposal = "course_proposal"
        case contentTypes = "content_types"
    }
    
    // Computed property for easy access to the AI response text
    var responseText: String {
        return response ?? content ?? "No response"
    }
    
    // Computed property for AI source (with fallback)
    var aiSource: String {
        return primaryAi ?? "gemini"
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
    let jobId: String
    let status: String
    let qualityTier: String
    let estimatedCostUSD: Double
    let message: String
    let pollUrl: String
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case qualityTier = "quality_tier"
        case estimatedCostUSD = "estimated_cost_usd"
        case message
        case pollUrl = "poll_url"
    }
}

struct CourseGenerationStatusResponse: Codable {
    let jobId: String
    let status: String
    let progressPercent: Int
    let currentStep: String?
    let stepsCompleted: [String]
    let estimatedTimeRemainingSec: Int?
    let createdAt: String
    let updatedAt: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case progressPercent = "progress_percent"
        case currentStep = "current_step"
        case stepsCompleted = "steps_completed"
        case estimatedTimeRemainingSec = "estimated_time_remaining_seconds"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case error
    }
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
        print("🧠 BackendAIService initialized - using hybrid AI (Gemini + OpenAI)")
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
    
    // MARK: - Streaming Study Session
    
    /// Stream AI response in real-time using Server-Sent Events
    /// Much better UX - shows text as it's generated instead of waiting
    func streamStudySession(
        message: String,
        resourceId: String? = nil,
        mode: String = "focus",
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping (String, Double) -> Void,
        onError: @escaping (Error) -> Void
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
        
        // Build request
        // Note: Request body is constructed in Endpoint.swift for chatStream
        
        Task {
            do {
                let (bytes, response) = try await NetworkClient.shared.stream(Endpoints.AI.chatStream(message: message, context: contextDict))
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    onError(BackendAIError.invalidResponse)
                    return
                }
                
                var fullContent = ""
                var responseTime: Double = 0
                
                for try await line in bytes.lines {
                    if line.hasPrefix("data: ") {
                        let jsonStr = String(line.dropFirst(6))
                        if let jsonData = jsonStr.data(using: .utf8),
                           let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            
                            let eventType = event["type"] as? String ?? ""
                            
                            switch eventType {
                            case "start":
                                let primaryAI = event["primary_ai"] as? String ?? "unknown"
                                print("🚀 Stream started with \(primaryAI)")
                                
                            case "chunk":
                                if let content = event["content"] as? String {
                                    fullContent += content
                                    onChunk(content)
                                }
                                
                            case "done":
                                responseTime = event["response_time_ms"] as? Double ?? 0
                                print("✅ Stream completed in \(responseTime)ms")
                                
                                // Update conversation history
                                self.conversationHistory.append(ConversationMessage(role: "user", content: message))
                                self.conversationHistory.append(ConversationMessage(role: "assistant", content: fullContent))
                                
                                if self.conversationHistory.count > 10 {
                                    self.conversationHistory = Array(self.conversationHistory.suffix(10))
                                }
                                
                                onComplete(fullContent, responseTime)
                                
                            case "error":
                                let errorMsg = event["message"] as? String ?? "Unknown error"
                                print("❌ Stream error: \(errorMsg)")
                                onError(BackendAIError.serverError(errorMsg))
                                
                            default:
                                break
                            }
                        }
                    }
                }
            } catch {
                onError(error)
            }
        }
    }
    
    // MARK: - Study Session (Socratic Dialogue)
    
    /// Send a message through the backend AI for Socratic-style tutoring
    /// Uses backend's dual-AI system (Gemini for reasoning, OpenAI for conversation)
    func studySession(
        message: String,
        resourceId: String? = nil,
        mode: String = "focus"
    ) async throws -> (response: String, source: String, uiContent: [A2UIContent]?, wasCommand: Bool) {
        
        // Update resource context if provided
        if let resourceId = resourceId {
            if resourceId != currentResourceId {
                // New topic - reset conversation
                conversationHistory.removeAll()
                currentResourceId = resourceId
            }
        }
        
        // Build the system prompt - this must be sent as part of conversation history
        // NOT in the context field (which backend treats as metadata)
        let systemPrompt = buildSystemPrompt(for: mode, resourceId: currentResourceId)
        
        // Build conversation history with system prompt at the start
        var historyWithSystem: [ConversationMessage] = []
        
        // Add system prompt as first message if this is a new conversation
        if conversationHistory.isEmpty {
            historyWithSystem.append(ConversationMessage(role: "system", content: systemPrompt))
        }
        
        // Add existing conversation history
        historyWithSystem.append(contentsOf: conversationHistory.suffix(8))
        
        // Build request - context should be simple metadata, not the full prompt
        let contextMetadata = "mode=\(mode),topic=\(currentResourceId)"
        
        let request = BackendAIChatRequest(
            message: message,
            conversationHistory: historyWithSystem.isEmpty ? nil : historyWithSystem,
            context: contextMetadata
        )
        
        let endpoint = "\(baseURL)/api/v1/ai/chat"
        
        do {
            let response: BackendAIChatResponse = try await postPublic(endpoint: endpoint, body: request)
            
            let rawResponse = response.responseText
            
            // Parse response to check for commands
            let (displayText, wasCommand) = AICommandHandler.shared.processResponse(rawResponse)
            
            // Update local conversation history with the original user message
            // and the display text (not raw JSON if it was a command)
            conversationHistory.append(ConversationMessage(role: "user", content: message))
            conversationHistory.append(ConversationMessage(role: "assistant", content: displayText))
            
            // Keep history reasonable size
            if conversationHistory.count > 10 {
                conversationHistory = Array(conversationHistory.suffix(10))
            }
            
            return (response: displayText, source: response.aiSource, uiContent: response.contentTypes, wasCommand: wasCommand)
            
        } catch {
            print("⚠️ Backend AI failed: \(error). Will fallback to local.")
            throw error
        }
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
        
        let endpoint = "\(baseURL)/api/v2/courses/estimate-cost"
        
        return try await postPublic(endpoint: endpoint, body: request)
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
        
        let endpoint = "\(baseURL)/api/v2/courses/generate"
        
        return try await postJSONDict(endpoint: endpoint, body: requestDict)
    }
    
    /// Poll for course generation status
    func getCourseGenerationStatus(jobId: String) async throws -> CourseGenerationStatusResponse {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/status/\(jobId)",
            method: .get,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - System Prompt Builder
    
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
        ```

        ### 2.1. Rules for the JSON output

        * You must output **valid JSON only**.
        * Do **NOT** include markdown, code fences, backticks, comments, or any extra text.
        * The top-level field **must** be `"type": "OPEN_CLASSROOM"`.
        * `"payload.stack_item.category"` must be `"Course"` for course requests.
        * `"payload.stack_item.status"` must be `"active"` for new courses.
        * `"payload.stack_item.due"` can be `null` unless the user explicitly mentions a deadline (then you can set a simple string like `"Exam next month"`).
        * `title` and `subtitle` must be short enough to fit on a mobile card:
          * `title`: very short, clear, and attractive.
          * `subtitle`: one line that summarizes the focus or benefit.
        * `language` must match the language the user used in the request (e.g., Spanish vs English).
        * `objectives` should be **2–5 short bullet-style phrases**, not long paragraphs.

        The app will:
        * Use `stack_item` to create a card in “Today’s Stack”.
        * Use `course` to configure the AI Classroom for that topic.

        ---

        ## 3. Normal chat behavior (no classroom)

        If the user is **not clearly** asking for a full course or class:
        * Answer directly in chat as a helpful tutor.
        * Be clear and concise. Use steps and examples when helpful.
        * You may **offer** a course as an option, e.g.:
          * “If you want, I can create a full course on this for you.”
        * But only trigger the JSON event **after** the user explicitly agrees or asks for a course.

        When in normal chat mode, you must NOT send the `OPEN_CLASSROOM` JSON.
        """
    }
    
    // MARK: - Network Helpers
    
    /// POST request WITH authentication (for auth-required endpoints)
    private func post<T: Encodable, R: Codable>(endpoint: String, body: T) async throws -> R {
        let dynamicEndpoint = DynamicEndpoint(
            urlString: endpoint,
            method: .post,
            body: body,
            requiresAuth: true
        )
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
    
    /// POST request WITHOUT authentication (for public endpoints like /api/v1/ai/chat)
    private func postPublic<T: Encodable, R: Codable>(endpoint: String, body: T) async throws -> R {
        let dynamicEndpoint = DynamicEndpoint(
            urlString: endpoint,
            method: .post,
            body: body,
            requiresAuth: false
        )
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
}

// MARK: - Errors

enum BackendAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please log in to use AI features"
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .serverError(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
