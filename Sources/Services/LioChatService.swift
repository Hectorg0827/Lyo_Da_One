import Foundation

// MARK: - Lio Chat Models

struct LioChatMessage: Identifiable, Codable {
    let id: String
    let isUser: Bool
    let text: String
    let timestamp: Date
    var source: String? // "ai", "local", "hybrid"
    var metadata: [String: String]?
    
    init(id: String = UUID().uuidString, isUser: Bool, text: String, timestamp: Date = Date(), source: String? = nil, metadata: [String: String]? = nil) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.source = source
        self.metadata = metadata
    }
}

// MARK: - Chat Response

struct LioChatResponse: Codable {
    let text: String
    let source: String? // "ai", "local", "hybrid"
    let action: LioChatAction?
    let suggestions: [String]?
    let meta: [String: String]?
    let contentTypes: [MessageContentType]?
    
    enum CodingKeys: String, CodingKey {
        case text
        case source
        case action
        case suggestions
        case meta
        case contentTypes
    }
    
    init(text: String, source: String? = nil, action: LioChatAction? = nil, suggestions: [String]? = nil, meta: [String: String]? = nil, contentTypes: [MessageContentType]? = nil) {
        self.text = text
        self.source = source
        self.action = action
        self.suggestions = suggestions
        self.meta = meta
        self.contentTypes = contentTypes
    }
}

struct LioChatAction: Codable {
    let type: String // "start_tutor", "start_lesson", "open_course"
    let parameters: [String: String]?
    
    init(type: String, parameters: [String: String]? = nil) {
        self.type = type
        self.parameters = parameters
    }
    
    // Custom decoding to handle empty/null parameters safely
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.parameters = try container.decodeIfPresent([String: String].self, forKey: .parameters)
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case parameters
    }
}

struct LioGreetingResponse: Codable {
    let greeting: String
    let contextUsed: Bool
    
    enum CodingKeys: String, CodingKey {
        case greeting
        case contextUsed = "context_used"
    }
}

// MARK: - Unified Response Type (From Backend)

enum BackendResponseType: String, Codable {
    case chat = "chat"
    case openClassroom = "OPEN_CLASSROOM"
    case quickExplain = "QUICK_EXPLAIN"
    case needsClarification = "NEEDS_CLARIFICATION"
    case error = "error"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = BackendResponseType(rawValue: value) ?? .chat
    }
}

// MARK: - Lio Chat Service

@MainActor final class LioChatService {
    static let shared = LioChatService()
    
    private let networkClient: NetworkRequestable
    private let tokenManager = TokenManager.shared
    private let intentClassifier = ChatIntentClassifier.shared
    
    // Conversation history for context
    private var conversationHistory: [LyoMessage] = []
    
    init(networkClient: NetworkRequestable = NetworkClient.shared) {
        self.networkClient = networkClient
    }
    
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    // MARK: - Send Message (Unified Flow)
    
    func sendMessage(
        text: String,
        sessionId: String? = nil,
        mode: String = "chat",
        contextHint: String? = nil,
        attachments: [MessageAttachment] = []
    ) async throws -> LioChatResponse {
        
        // 1. Add user message to history
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            content: text,
            isFromUser: true,
            timestamp: Date(),
            attachments: attachments.isEmpty ? nil : attachments
        )
        conversationHistory.append(userMessage)
        trimHistory()
        
        // 2. ALWAYS send to backend - NO local intent classification for course creation
        // This makes the backend the single source of truth for intent.
        let response = try await sendToBackend(
            message: text,
            sessionId: sessionId,
            contextHint: contextHint
        )
        
        // 3. Handle response based on backend's type field
        return try await handleUnifiedResponse(response)
    }
    
    // MARK: - Backend Communication
    
    private func sendToBackend(
        message: String,
        sessionId: String?,
        contextHint: String?
    ) async throws -> ChatResponse {
        
        let payload = ChatModuleRequest(
            message: message,
            modeHint: nil, // Let backend decide
            action: nil,
            conversationId: sessionId,
            sessionId: sessionId,
            conversationHistory: buildHistoryPayload(),
            context: contextHint,
            includeCtas: true,
            includeChips: true
        )
        
        let payloadData = try jsonEncoder.encode(payload)
        let endpoint = Endpoints.ChatModule.sendMessage(payload: payloadData)
        
        do {
            return try await networkClient.request(endpoint)
        } catch {
            // Check if it's an auth error or if we should fallback
            let normalizedError = LyoError.from(error: error)
            
            // Fallback on Auth Error (Unauthenticated user trying chat)
            if case .network(.unauthorized) = normalizedError {
                return try await sendToPublicFallback(message: message, contextHint: contextHint)
            }
            
            // Fallback on Server Crash (500)
            // Backend bug workaround: If full chat module fails, try the simpler study session endpoint
            if case .network(.serverError(let code)) = normalizedError, code == 500 {
                print("🔥 LioChatService: Backend crashed (500). Retrying with public fallback...")
                return try await sendToPublicFallback(message: message, contextHint: contextHint)
            }
            
            // For other errors, only fallback if configured
            if AppConfig.allowMockFallbacks {
                return try await sendToPublicFallback(message: message, contextHint: contextHint)
            }
            
            throw error
        }
    }
    
    private func sendToPublicFallback(
        message: String,
        contextHint: String?
    ) async throws -> ChatResponse {
        
        print("⚠️ LioChatService: Using public AI fallback...")
        
        let (text, source, uiContent, _, wasCommand, openClassroomPayload) = try await BackendAIService.shared.studySession(
            message: message,
            resourceId: contextHint,
            mode: "chat"
        )
        
        // Convert BackendAIService response to ChatResponse format
        return ChatResponse(
            response: text,
            provider: source,
            cost: 0,
            tokens: 0,
            cached: false,
            responseMode: .chat,
            quickExplainer: nil,
            courseProposal: nil,
            conversationHistory: nil,
            type: wasCommand ? "OPEN_CLASSROOM" : "chat",
            openClassroomPayload: openClassroomPayload,
            contentTypes: uiContent
        )
    }
    
    // MARK: - Response Handling (Unified Switch)
    
    private func handleUnifiedResponse(_ response: ChatResponse) async throws -> LioChatResponse {
        let responseType = BackendResponseType(rawValue: response.type ?? "chat") ?? .chat
        
        print("📨 LioChatService: Backend response type -> \(responseType.rawValue)")
        
        // Before returning, add AI message to local history
        let aiMessage = LyoMessage(
            id: UUID().uuidString,
            content: response.response,
            isFromUser: false,
            timestamp: Date()
        )
        conversationHistory.append(aiMessage)
        trimHistory()
        
        switch responseType {
        case .openClassroom:
            return handleOpenClassroomResponse(response)
            
        case .needsClarification:
            return handleClarificationResponse(response)
            
        case .quickExplain:
            return handleQuickExplainResponse(response)
            
        case .chat, .error:
            return handleNormalChatResponse(response)
        }
    }
    
    // MARK: - Response Type Handlers
    
    private func handleOpenClassroomResponse(_ response: ChatResponse) -> LioChatResponse {
        // If we have a payload, use it
        if let payload = response.openClassroomPayload {
            return handleOPEN_CLASSROOMResponse(payload, originalText: response.response)
        }
        
        // Fallback: Try to extract from response text (Markdown extraction)
        if let extractedPayload = extractOpenClassroomPayload(from: response.response) {
            print("✅ LioChatService: Extracted course payload from markdown text")
            return handleOPEN_CLASSROOMResponse(extractedPayload, originalText: response.response)
        }
        
        // If extraction fails, treat as normal chat but with a warning
        print("⚠️ LioChatService: OPEN_CLASSROOM type received but no valid payload found")
        return handleNormalChatResponse(response)
    }
    
    private func handleOPEN_CLASSROOMResponse(_ payload: OpenClassroomPayload, originalText: String) -> LioChatResponse {
        var courseId = payload.course.id ?? ""
        
        // Logic: If we have a valid generated/rescued ID, use it.
        // Otherwise, setup for generation.
        if !courseId.isEmpty && (courseId.hasPrefix("gen_") || courseId.hasPrefix("mock_")) {
             print("✅ LioChatService: Using existing course ID: \(courseId)")
             // Course is already populated in Service by rescue logic or standard flow
        } else {
             // Standard flow: JSON came with metadata but no content/ID
             // 🔧 FIX: Populate the generated course so LiveClassroomViewModel can find it
             CourseGenerationService.shared.populateGeneratedCourse(from: payload.course)
             
             // Use GENERATE: prefix with topic so classroom triggers full generation
             courseId = "GENERATE:\(payload.course.topic)"
        }
        
        // Construct action parameters
        let actionParams: [String: String] = [
            "courseId": courseId,
            "courseTitle": payload.course.title,
            "topic": payload.course.topic,
            "level": payload.course.level
        ]
        
        // 🔧 FIX: Don't pass originalText since it may contain raw JSON
        // We generate clean confirmation text instead
        
        let confirmationText = """
        🎓 Perfect! I'm setting up your **\(payload.course.title)** course now!
        
        I've analyzed your request and prepared a personalized learning path for **\(payload.course.topic)**.
        
        Get ready for an interactive experience! 🚀
        """
        
        return LioChatResponse(
            text: confirmationText,
            source: "classroom_trigger",
            action: LioChatAction(type: "open_classroom", parameters: actionParams),
            suggestions: ["Let's go!", "Tell me more first"],
            meta: ["mode": "open_classroom"],
            contentTypes: nil  // Don't parse originalText which may contain JSON
        )
    }
    
    private func handleClarificationResponse(_ response: ChatResponse) -> LioChatResponse {
        let (text, contentTypes) = processChatResponseContent(response.response, response.contentTypes)
        let suggestions = response.quickExplainer?.chips ?? ["Beginner", "Intermediate", "Advanced"]
        
        return LioChatResponse(
            text: text,
            source: "clarification",
            suggestions: suggestions,
            meta: ["mode": "clarification"],
            contentTypes: contentTypes
        )
    }
    
    private func handleQuickExplainResponse(_ response: ChatResponse) -> LioChatResponse {
        let (text, contentTypes) = processChatResponseContent(response.response, response.contentTypes)
        let suggestions = response.quickExplainer?.chips ?? ["Tell me more", "Create a course", "Quiz me"]
        
        return LioChatResponse(
            text: text,
            source: "quick_explain",
            suggestions: suggestions,
            meta: ["type": "quick_explain"],
            contentTypes: contentTypes
        )
    }
    
    private func handleNormalChatResponse(_ response: ChatResponse) -> LioChatResponse {
        // RESCUE POINT: Check if valid course markdown was returned despite type being 'chat'
        if let rescuedPayload = rescueCourseFromMarkdown(response.response) {
            print("🛟 LioChatService: Rescued course payload from raw Markdown")
            return handleOPEN_CLASSROOMResponse(rescuedPayload, originalText: response.response)
        }

        let (text, contentTypes) = processChatResponseContent(response.response, response.contentTypes)
        
        return LioChatResponse(
            text: text,
            source: response.provider ?? "chat",
            suggestions: response.quickExplainer?.chips,
            contentTypes: contentTypes
        )
    }

    /// Emergency parser for when the AI writes a course in Markdown instead of returning JSON
    private func rescueCourseFromMarkdown(_ text: String) -> OpenClassroomPayload? {
        // Heuristic: Must have at least "Module" and "Lesson" headers
        guard text.contains("Module") && text.contains("Lesson") else { return nil }
        
        // 1. Parse content and populate Service
        let rescuedId = CourseGenerationService.shared.populateRescuedCourse(from: text)

        // 2. Extract Title
        var title = "New Course"
        let topic = "Generated Course"
        
        let lines = text.components(separatedBy: .newlines)
        if let titleLine = lines.first(where: { $0.contains("Course:") || $0.hasPrefix("# ") }),
           let colonIndex = titleLine.lastIndex(of: ":") {
            // "## Full Course: Foundations of Basic Arithmetic" -> "Foundations of Basic Arithmetic"
            title = String(titleLine[titleLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "*#")))
        } else if let titleLine = lines.first(where: { $0.hasPrefix("# ") }) {
             title = titleLine.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
        }

        // 3. Create Payload using the ID
        var courseData = CoursePayload(
            id: rescuedId, // Use the ID from the service
            title: title,
            topic: title, // Use title as topic
            level: "Beginner",
            language: "English",
            duration: "Self-paced",
            objectives: ["Master \(title)"]
        )
        
        return OpenClassroomPayload(stackItem: StackItemPayload(category: "Course", title: title, subtitle: "AI Generated Course", status: "active", due: nil), course: courseData)
    }
    
    /// Unified helper to process response text and A2UI content (Hybrid Fallback)
    private func processChatResponseContent(_ responseText: String, _ backendTypes: [A2UIContent]?) -> (text: String, types: [MessageContentType]?) {
        var text = responseText
        var contentTypes = convertContentTypes(backendTypes)
        
        // Hybrid Fallback: If no explicit contentTypes, check if the text contains A2UI widgets
        if contentTypes == nil || contentTypes?.isEmpty == true {
            let parseResult = A2UIParser.parse(text)
            // Check if we found meaningful widgets (not just text)
            let hasWidgets = parseResult.contentTypes.contains { type in
                switch type {
                case .text: return false
                default: return true
                }
            }
            
            if hasWidgets {
                print("🧩 LioChatService: Hybrid Parser found widgets in text")
                text = parseResult.cleanText
                contentTypes = parseResult.contentTypes
            }
        }
        
        return (text, contentTypes)
    }
    
    // MARK: - JSON Extraction (Robust Fallback)
    
    private func extractOpenClassroomPayload(from text: String) -> OpenClassroomPayload? {
        guard text.contains("OPEN_CLASSROOM") else { return nil }
        
        // Strategy 1: Find balanced JSON block (Most robust for LLM output)
        if let jsonString = extractBalancedJSON(from: text),
           let payload = decodePayload(from: jsonString) {
            return payload
        }
        
        // Strategy 2: Regex for code blocks
        let patterns = [
            #"```json\s*(\{[\s\S]*?\})\s*```"#,
            #"```\s*(\{[\s\S]*?\})\s*```"#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let jsonString = String(text[range])
                if let payload = decodePayload(from: jsonString) {
                    return payload
                }
            }
        }
        
        return nil
    }
    
    private func extractBalancedJSON(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{") else { return nil }
        
        var braceCount = 0
        var endIndex: String.Index?
        
        for index in text.indices[startIndex...] {
            switch text[index] {
            case "{": braceCount += 1
            case "}":
                braceCount -= 1
                if braceCount == 0 {
                    endIndex = index
                    break
                }
            default: break
            }
        }
        
        guard let end = endIndex else { return nil }
        let jsonString = String(text[startIndex...end])
        return jsonString.contains("OPEN_CLASSROOM") ? jsonString : nil
    }
    
    private func decodePayload(from jsonString: String) -> OpenClassroomPayload? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        struct Envelope: Codable {
            let type: String
            let payload: OpenClassroomPayload
        }
        
        do {
            let decoded = try jsonDecoder.decode(Envelope.self, from: data)
            return decoded.type == "OPEN_CLASSROOM" ? decoded.payload : nil
        } catch {
            print("⚠️ LioChatService: JSON decode error: \(error)")
            return nil
        }
    }
    
    // MARK: - Content Type Conversion
    
    private func convertContentTypes(_ backendTypes: [A2UIContent]?) -> [MessageContentType]? {
        guard let types = backendTypes, !types.isEmpty else { return nil }
        
        return types.compactMap { content -> MessageContentType? in
            switch content.type {
            case .text:
                return .text
                
            case .processing:
                return .processing(step: "Processing...", progress: nil)
                
            case .topicSelection:
                guard let topics = content.topics else { return nil }
                let options = topics.map { TopicOption(title: $0.title, icon: $0.icon ?? "book.fill", gradientColors: $0.gradientColors) }
                return .topicSelection(title: content.title ?? "Choose a Topic", topics: options)
                
            case .quiz:
                guard let quiz = content.quiz, let q = quiz.questions.first else { return nil }
                let correctIndex = q.options.firstIndex(of: q.correctAnswer) ?? 0
                return .quiz(question: q.question, options: q.options, correctIndex: correctIndex, explanation: nil)
                
            case .courseRoadmap:
                if let roadmap = content.courseRoadmap {
                    let modules = roadmap.modules.enumerated().map { i, m in
                        CourseModule(id: "mod_\(i)", title: m.title, duration: nil, isCompleted: false, isLocked: i > 0)
                    }
                    return .courseRoadmap(title: roadmap.title, modules: modules, totalModules: modules.count, completedModules: 0)
                }
                return nil
                
            case .flashcards:
                guard let cards = content.cards else { return nil }
                let flashcards = cards.map { Flashcard(front: $0.front, back: $0.back, isMastered: false) }
                return .flashcards(title: content.title ?? "Flashcards", cards: flashcards)
                
            case .suggestions:
                guard let suggestions = content.suggestions, !suggestions.isEmpty else { return nil }
                return .suggestions(title: content.title ?? "What's next?", options: suggestions)
                
            case .cinematic:
                guard let data = content.cinematic else { return nil }
                return .cinematic(data: data)
                
            case .unknown:
                return nil
            }
        }
    }
    
    // MARK: - Internal Helpers
    
    private func buildHistoryPayload() -> [ChatModuleHistoryItem] {
        conversationHistory.suffix(10).map { msg in
            ChatModuleHistoryItem(
                role: msg.isFromUser ? "user" : "assistant",
                content: msg.content
            )
        }
    }
    
    private func trimHistory() {
        if conversationHistory.count > 20 {
            conversationHistory = Array(conversationHistory.suffix(20))
        }
    }
    
    func clearSession() {
        conversationHistory.removeAll()
        intentClassifier.resetWizard()
        print("🆕 Chat session cleared")
    }
    
    // MARK: - Legacy Types (To Be Removed)
    
    private struct ChatModuleRequest: Codable {
        let message: String
        let modeHint: String?
        let action: String?
        let conversationId: String?
        let sessionId: String?
        let conversationHistory: [ChatModuleHistoryItem]?
        let context: String?
        let includeCtas: Bool
        let includeChips: Bool
        
        enum CodingKeys: String, CodingKey {
            case message
            case modeHint = "mode_hint"
            case action
            case conversationId = "conversation_id"
            case sessionId = "session_id"
            case conversationHistory = "conversation_history"
            case context
            case includeCtas = "include_ctas"
            case includeChips = "include_chips"
        }
    }
    
    private struct ChatModuleHistoryItem: Codable {
        let role: String
        let content: String
    }
    
    // MARK: - Streaming Message (Live AI)
    
    func sendMessageStreaming(
        text: String,
        sessionId: String? = nil,
        contextHint: String? = nil,
        speakResponse: Bool = false,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (LioChatResponse) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // 1. Setup Stream Processor
        let processor = LyoStreamProcessor()
        
        // 2. Hook up Sentence-Level TTS (The "Live" Magic)
        if speakResponse {
            processor.onSentenceReady = { sentence in
                print("🗣️ Live AI Speaking: \(sentence)")
                TextToSpeechService.shared.enqueue(sentence)
            }
        }
        
        // 3. Prepare Request
        let payload = ChatModuleRequest(
            message: text,
            modeHint: "chat",
            action: nil,
            conversationId: nil,
            sessionId: sessionId,
            conversationHistory: buildHistoryPayload(),
            context: contextHint,
            includeCtas: true,
            includeChips: true
        )
        
        guard let payloadData = try? jsonEncoder.encode(payload) else {
            onError(LyoError.network(.invalidRequest))
            return
        }
        
        // 4. Start Stream
        let endpoint = "\(NetworkClient.baseURL)/chat/stream"
        let streamManager = StreamingResponseManager()
        
        Task {
            await streamManager.stream(
                endpoint: endpoint,
                method: "POST",
                body: payloadData
            ) { [weak self] event in
                switch event {
                case .blockEmit(let content, let type):
                    if type == "delta" {
                        // Feed content to processor for sentence extraction
                        _ = processor.append(content)
                        // Callback for UI typing effect
                        onToken(content)
                    }
                    
                case .sessionDone:
                    // Create a synthetic response
                    // In a real implementation, we should parse the "message_complete" event full JSON
                    // But for now, we assume success.
                    let response = LioChatResponse(
                        text: "", // Content was streamed
                        source: "ai_stream",
                        suggestions: ["Tell me more"],
                        meta: ["mode": "live"]
                    )
                    DispatchQueue.main.async {
                        onComplete(response)
                    }
                    
                case .error(let error):
                    DispatchQueue.main.async {
                        onError(error)
                    }
                    
                default: break
                }
            }
        }
    }
    
    // MARK: - Proactive Greeting
    
    func getProactiveGreeting() async throws -> LioGreetingResponse {
        return try await NetworkClient.shared.request(Endpoints.ChatModule.getGreeting)
    }
}
