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
struct BackendAIChatRequest: Encodable {
    let prompt: String
    let taskType: String?
    let maxTokens: Int
    let temperature: Double
    let context: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case taskType = "task_type"
        case maxTokens = "max_tokens"
        case temperature
        case context
    }
}

// Response from /api/v1/ai/chat
struct BackendAIChatResponse: Decodable {
    let content: String
    let primaryAi: String
    let secondaryAi: String?
    let taskType: String
    let reasoning: String?
    let conversationTone: String?
    let responseTimeMs: Double
    let tokensUsed: Int
    let costEstimate: Double
    let confidenceScore: Double
    let modelVersions: [String: String]
    let userId: Int?
    
    // New fields for Mentor Mode
    let responseMode: ResponseMode?
    let quickExplainer: QuickExplainerData?
    let courseProposal: CourseProposalData?
    
    enum CodingKeys: String, CodingKey {
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

struct BackendStudySessionResponse: Decodable {
    let response: String
    let conversationHistory: [ConversationMessage]
}

struct BackendQuizRequest: Encodable {
    let resourceId: String
    let quizType: String
    let questionCount: Int
}

struct BackendQuizQuestion: Decodable {
    let question: String
    let options: [String]
    let correctAnswer: String
}

struct BackendAnswerAnalysisRequest: Encodable {
    let question: String
    let correctAnswer: String
    let userAnswer: String
}

struct BackendAnswerAnalysisResponse: Decodable {
    let feedback: String
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
        let request = BackendAIChatRequest(
            prompt: message,
            taskType: "EDUCATIONAL_EXPLANATION",
            maxTokens: 500,
            temperature: 0.7,
            context: contextDict
        )
        
        let endpoint = "\(baseURL)/api/v1/ai/chat/stream"
        
        guard let url = URL(string: endpoint) else {
            onError(BackendAIError.invalidURL)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("iOS", forHTTPHeaderField: "X-Platform")
        
        do {
            urlRequest.httpBody = try jsonEncoder.encode(request)
        } catch {
            onError(error)
            return
        }
        
        print("🌊 Starting streaming request to: \(endpoint)")
        
        // Use URLSession with a streaming delegate
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: urlRequest) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    onError(error)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    onError(BackendAIError.invalidResponse)
                }
                return
            }
            
            // Parse SSE data
            if let dataString = String(data: data, encoding: .utf8) {
                var fullContent = ""
                var responseTime: Double = 0
                
                // Split by "data: " and parse each event
                let lines = dataString.components(separatedBy: "\n")
                for line in lines {
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
                                    DispatchQueue.main.async {
                                        onChunk(content)
                                    }
                                }
                                
                            case "done":
                                responseTime = event["response_time_ms"] as? Double ?? 0
                                print("✅ Stream completed in \(responseTime)ms")
                                
                                // Update conversation history
                                DispatchQueue.main.async {
                                    self?.conversationHistory.append(ConversationMessage(role: "user", content: message))
                                    self?.conversationHistory.append(ConversationMessage(role: "assistant", content: fullContent))
                                    
                                    if let count = self?.conversationHistory.count, count > 10 {
                                        self?.conversationHistory = Array(self?.conversationHistory.suffix(10) ?? [])
                                    }
                                    
                                    onComplete(fullContent, responseTime)
                                }
                                
                            case "error":
                                let errorMsg = event["message"] as? String ?? "Unknown error"
                                print("❌ Stream error: \(errorMsg)")
                                DispatchQueue.main.async {
                                    onError(BackendAIError.serverError(errorMsg))
                                }
                                
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Study Session (Socratic Dialogue)
    
    /// Send a message through the backend AI for Socratic-style tutoring
    /// Uses backend's dual-AI system (Gemini for reasoning, OpenAI for conversation)
    func studySession(
        message: String,
        resourceId: String? = nil,
        mode: String = "focus"
    ) async throws -> (response: String, source: String) {
        
        // Update resource context if provided
        if let resourceId = resourceId {
            if resourceId != currentResourceId {
                // New topic - reset conversation
                conversationHistory.removeAll()
                currentResourceId = resourceId
            }
        }
        
        // Build context from mode and topic
        var contextDict: [String: String] = [
            "mode": mode,
            "topic": currentResourceId
        ]
        
        // Include conversation history context
        if !conversationHistory.isEmpty {
            let historyContext = conversationHistory.suffix(4).map { "\($0.role): \($0.content)" }.joined(separator: "\n")
            contextDict["conversation_history"] = historyContext
        }
        
        // Inject System Prompt
        contextDict["system_instruction"] = buildSystemPrompt(for: mode, resourceId: currentResourceId)
        
        // Build request for /api/v1/ai/chat endpoint (public, no auth required)
        let request = BackendAIChatRequest(
            prompt: message,
            taskType: "EDUCATIONAL_EXPLANATION",
            maxTokens: 500,
            temperature: 0.7,
            context: contextDict
        )
        
        let endpoint = "\(baseURL)/api/v1/ai/chat"
        
        do {
            let response: BackendAIChatResponse = try await postPublic(endpoint: endpoint, body: request)
            
            // Update local conversation history
            conversationHistory.append(ConversationMessage(role: "user", content: message))
            conversationHistory.append(ConversationMessage(role: "assistant", content: response.content))
            
            // Keep history reasonable size
            if conversationHistory.count > 10 {
                conversationHistory = Array(conversationHistory.suffix(10))
            }
            
            return (response: response.content, source: response.primaryAi)
            
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
    private func post<T: Encodable, R: Decodable>(endpoint: String, body: T) async throws -> R {
        guard let url = URL(string: endpoint) else {
            throw BackendAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth token
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode body
        request.httpBody = try jsonEncoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try jsonDecoder.decode(R.self, from: data)
        case 401:
            throw BackendAIError.unauthorized
        case 429:
            throw BackendAIError.rateLimited
        default:
            // Try to extract error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                throw BackendAIError.serverError(detail)
            }
            throw BackendAIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    /// POST request WITHOUT authentication (for public endpoints like /api/v1/ai/chat)
    private func postPublic<T: Encodable, R: Decodable>(endpoint: String, body: T) async throws -> R {
        guard let url = URL(string: endpoint) else {
            throw BackendAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("1.0", forHTTPHeaderField: "X-App-Version")
        
        // NO auth token for public endpoints
        
        // Encode body
        request.httpBody = try jsonEncoder.encode(body)
        
        // Debug: print request
        print("\n================================")
        print("📤 REQUEST")
        print("================================")
        print("Method: POST")
        print("URL: \(endpoint)")
        print("Headers:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            print("  \(key): \(value)")
        }
        if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            print("\nBody:")
            print(bodyStr)
        }
        print("================================\n")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAIError.invalidResponse
        }
        
        // Debug: print response
        print("\n================================")
        print("📥 RESPONSE")
        print("================================")
        print("URL: \(endpoint)")
        print("Status: \(httpResponse.statusCode) \(httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 ? "✅" : "⚠️")")
        print("\nHeaders:")
        for (key, value) in httpResponse.allHeaderFields {
            print("  \(key): \(value)")
        }
        if let bodyStr = String(data: data, encoding: .utf8) {
            let prettyBody = (try? JSONSerialization.jsonObject(with: data, options: []))
                .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: .prettyPrinted) }
                .flatMap { String(data: $0, encoding: .utf8) } ?? bodyStr
            print("\nBody:")
            print(prettyBody)
        }
        print("================================\n")
        
        switch httpResponse.statusCode {
        case 200...299:
            return try jsonDecoder.decode(R.self, from: data)
        case 429:
            throw BackendAIError.rateLimited
        default:
            // Try to extract error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                throw BackendAIError.serverError(detail)
            }
            throw BackendAIError.serverError("Server error: \(httpResponse.statusCode)")
        }
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
