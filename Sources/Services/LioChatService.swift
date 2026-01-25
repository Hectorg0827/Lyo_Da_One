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

// MARK: - Lio Chat Service

@MainActor final class LioChatService {
    static let shared = LioChatService()
    
    private let networkClient: NetworkRequestable
    
    init(networkClient: NetworkRequestable = NetworkClient.shared) {
        self.networkClient = networkClient
    }
    
    private var baseURL: String { AppConfig.baseURL }
    private let tokenManager = TokenManager.shared
    
    // Conversation history for context
    private var conversationHistory: [LyoMessage] = []
    
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
    
    /// Converts 0.0-1.0 difficulty to human-readable level
    private func difficultyToLevel(_ difficulty: Double) -> String {
        if difficulty < 0.35 {
            return "beginner"
        } else if difficulty < 0.65 {
            return "intermediate"
        } else {
            return "advanced"
        }
    }
    
    // MARK: - Send Message (Uses OpenAI Service)
    
    // MARK: - Dependencies
    private let intentClassifier = ChatIntentClassifier.shared
    private let courseWizard = CourseWizardHandler.shared
    private let aiRepository = DefaultAIRepository()

    private struct ChatModuleHistoryItem: Codable {
        let role: String
        let content: String
    }

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

    private func chatHistoryPayload() -> [ChatModuleHistoryItem] {
        conversationHistory.suffix(10).map { msg in
            ChatModuleHistoryItem(
                role: msg.isFromUser ? "user" : "assistant",
                content: msg.content
            )
        }
    }

    private func sendChatModuleMessage(
        message: String,
        sessionId: String? = nil,
        modeHint: String?,
        action: String?,
        contextHint: String?
    ) async throws -> ChatResponse {
        
        let payload = ChatModuleRequest(
            message: message,
            modeHint: modeHint,
            action: action,
            conversationId: sessionId,
            sessionId: sessionId,
            conversationHistory: chatHistoryPayload(),
            context: contextHint,
            includeCtas: true,
            includeChips: true
        )
        
        let payloadData = try jsonEncoder.encode(payload)
        let endpoint = Endpoints.ChatModule.sendMessage(payload: payloadData)
        
        let backend: ChatResponse = try await self.networkClient.request(endpoint)
        
        // 1. Check for Top-Level JSON Event (Ideal Case)
        if backend.type == "OPEN_CLASSROOM", let payload = backend.openClassroomPayload {
            print("🎓 LioChatService: Received OPEN_CLASSROOM event (Top-Level)")
            return createOpenClassroomResponse(payload)
        }
        
        // 2. Check for Embedded JSON in Text (Fallback/LLM output)
        if backend.response.contains("OPEN_CLASSROOM") {
            if let payload = extractOpenClassroomPayload(from: backend.response) {
                print("🎓 LioChatService: Extracted OPEN_CLASSROOM event from Markdown")
                return createOpenClassroomResponse(payload)
            }
        }
        
        return backend
    }
    
    // MARK: - Helper: Create Synthetic Response
    
    private func createOpenClassroomResponse(_ payload: OpenClassroomPayload) -> ChatResponse {
        let confirmationText = "🎉 I've created your **\(payload.course.title)** course! Opening the classroom now..."
        
        return ChatResponse(
            response: confirmationText,
            provider: "classroom_trigger",
            cost: 0,
            tokens: 0,
            cached: false,
            responseMode: .course,
            quickExplainer: nil,
            courseProposal: nil,
            conversationHistory: nil,
            type: "OPEN_CLASSROOM",
            openClassroomPayload: payload
        )
    }
    
    // MARK: - Helper: Extract JSON from Markdown
    


    // MARK: - Handle Authenticated Chat Response
    
    private func handleBackendResponse(_ backend: ChatResponse, validatedText: String) -> LioChatResponse {
        // Construct Action
        var chatAction: LioChatAction? = nil
        
        // Check for OPEN_CLASSROOM Trigger
        if backend.type == "OPEN_CLASSROOM", let payload = backend.openClassroomPayload {
            // We encode the payload into the action parameters so the UI (ViewModel) can use it
            // ensuring we don't lose the course details.
            var params: [String: String] = [
                "courseTitle": payload.course.title,
                "topic": payload.course.topic,
                "level": payload.course.level
            ]
            
            if let courseId = payload.course.id {
                params["courseId"] = courseId
            }
            
            // Try to encode full payload for robust client handling
            if let data = try? jsonEncoder.encode(payload),
               let jsonString = String(data: data, encoding: .utf8) {
                params["payload_json"] = jsonString
            }
            
            chatAction = LioChatAction(type: "open_classroom", parameters: params)
        }
        
        // Map A2UI Content - Convert ALL backend A2UIContent types to MessageContentType
        var mappedContentTypes: [MessageContentType]? = nil
        
        if let backendTypes = backend.contentTypes {
            mappedContentTypes = backendTypes.compactMap { content -> MessageContentType? in
                switch content.type {
                case .text:
                    // Text type is represented by the message content itself
                    return .text
                    
                case .processing:
                    // Processing/loading indicator
                    return .processing(step: "Processing...", progress: nil)
                    
                case .topicSelection:
                    // Topic selection widget
                    if let topics = content.topics {
                        let topicOptions = topics.map { topic in
                            TopicOption(
                                title: topic.title,
                                icon: topic.icon ?? "book.fill",
                                gradientColors: topic.gradientColors
                            )
                        }
                        return .topicSelection(
                            title: content.title ?? "Choose a Topic",
                            topics: topicOptions
                        )
                    }
                    return nil
                    
                case .quiz:
                    guard let quiz = content.quiz, let firstQ = quiz.questions.first else { return nil }
                    let correctIndex = firstQ.options.firstIndex(of: firstQ.correctAnswer) ?? 0
                    return .quiz(
                        question: firstQ.question,
                        options: firstQ.options,
                        correctIndex: correctIndex,
                        explanation: nil
                    )
                    
                case .courseRoadmap:
                    // Handle nested structure first
                    if let map = content.courseRoadmap {
                        let modules = map.modules.enumerated().map { index, mod in
                            CourseModule(
                                id: "mod_\(index)",
                                title: mod.title,
                                duration: mod.lessons.map { "\($0.count) lessons" } ?? "TBD",
                                isCompleted: false,
                                isLocked: index > 0
                            )
                        }
                        return .courseRoadmap(
                            title: map.title,
                            modules: modules,
                            totalModules: modules.count,
                            completedModules: 0
                        )
                    }
                    // Fallback: flat modules format
                    if let flatModules = content.modules {
                        let uiModules = flatModules.map { mod in
                            CourseModule(
                                id: mod.id ?? UUID().uuidString,
                                title: mod.title,
                                duration: mod.duration,
                                isCompleted: mod.isCompleted ?? false,
                                isLocked: mod.isLocked ?? false
                            )
                        }
                        return .courseRoadmap(
                            title: content.title ?? "Course Roadmap",
                            modules: uiModules,
                            totalModules: content.totalModules ?? uiModules.count,
                            completedModules: content.completedModules ?? 0
                        )
                    }
                    return nil
                    
                case .flashcards:
                    // Flashcard carousel widget
                    if let cards = content.cards {
                        let flashcardModels = cards.map { card in
                            Flashcard(
                                front: card.front,
                                back: card.back,
                                isMastered: false
                            )
                        }
                        return .flashcards(
                            title: content.title ?? "Study Flashcards",
                            cards: flashcardModels
                        )
                    }
                    return nil
                    
                case .suggestions:
                    // Smart follow-up suggestions widget
                    if let suggestions = content.suggestions, !suggestions.isEmpty {
                        return .suggestions(
                            title: content.title ?? "What's next?",
                            options: suggestions
                        )
                    }
                    return nil
                    
                case .unknown:
                    print("⚠️ Unknown A2UI content type received in handleBackendResponse")
                    return nil
                }
            }
        }

        return LioChatResponse(
            text: validatedText,
            source: "backend_chat",
            action: chatAction,
            suggestions: backend.quickExplainer?.chips,
            meta: ["provider": backend.provider ?? "chat"],
            contentTypes: mappedContentTypes
        )
    }
    
    // ... (Fallback helpers)
    
    // MARK: - Helper: Extract JSON from Markdown
    
    private func extractOpenClassroomPayload(from text: String) -> OpenClassroomPayload? {
        print("🔍 Extracting OPEN_CLASSROOM JSON from response (\(text.count) chars)")
        print("🔍 Contains OPEN_CLASSROOM: \(text.contains("OPEN_CLASSROOM"))")
        
        // Quick exit if no OPEN_CLASSROOM present
        guard text.contains("OPEN_CLASSROOM") else {
            print("🔍 No OPEN_CLASSROOM found in text, skipping extraction")
            return nil
        }
        
        // 1. Try multiple regex patterns for code blocks
        let patterns = [
            #"(?s)```json\s*(\{.+\})\s*```"#,     // ```json {...} ``` (greedy)
            #"(?s)```\s*(\{.+\})\s*```"#,         // ``` {...} ``` (no json specifier)
        ]
        
        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsString = text as NSString
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first, match.numberOfRanges > 1 {
                    let jsonString = nsString.substring(with: match.range(at: 1))
                    print("🔍 Pattern \(index + 1) matched: \(jsonString.prefix(50))...")
                    if let payload = decodePayload(from: jsonString) {
                        print("✅ Successfully extracted payload from pattern \(index + 1)")
                        return payload
                    }
                }
            }
        }
        print("🔍 No code block patterns matched")
        
        // 2. Fallback: Find balanced JSON block containing "OPEN_CLASSROOM"
        // Use a more robust approach: find the outermost {} that contains OPEN_CLASSROOM
        if let jsonString = extractBalancedJSON(from: text) {
            print("🔍 Balanced JSON extraction found: \(jsonString.prefix(50))...")
            if let payload = decodePayload(from: jsonString) {
                print("✅ Successfully extracted payload from balanced JSON")
                return payload
            }
        }
        
        // 3. Last resort: Simple first-to-last brace extraction
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            let jsonString = String(text[start.lowerBound...end.upperBound])
            if jsonString.contains("OPEN_CLASSROOM") {
                print("🔍 Simple brace extraction found candidate (\(jsonString.count) chars)")
                if let payload = decodePayload(from: jsonString) {
                    print("✅ Successfully extracted payload from simple extraction")
                    return payload
                }
            }
        }
        
        print("⚠️ Failed to extract OPEN_CLASSROOM payload from text")
        return nil
    }
    
    /// Extract balanced JSON by counting braces
    private func extractBalancedJSON(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{") else { return nil }
        
        var braceCount = 0
        var endIndex: String.Index?
        
        for index in text.indices[startIndex...] {
            let char = text[index]
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    endIndex = index
                    break
                }
            }
        }
        
        guard let end = endIndex else { return nil }
        let jsonString = String(text[startIndex...end])
        
        // Only return if it contains OPEN_CLASSROOM
        return jsonString.contains("OPEN_CLASSROOM") ? jsonString : nil
    }
    
    private func decodePayload(from jsonString: String) -> OpenClassroomPayload? {
        guard let data = jsonString.data(using: .utf8) else { 
            print("⚠️ Decode failed: Invalid UTF8")
            return nil 
        }
        
        struct EmbeddedTrigger: Codable {
            let type: String
            let payload: OpenClassroomPayload
        }
        
        do {
            let decoded = try jsonDecoder.decode(EmbeddedTrigger.self, from: data)
            print("✅ JSON Decode Success: \(decoded.type)")
            return decoded.type == "OPEN_CLASSROOM" ? decoded.payload : nil
        } catch {
            print("⚠️ LioChatService: JSON Decode failed: \(error)")
            // Try lenient decoding if needed?
            return nil
        }
    }
    
    // MARK: - Proactive Greeting
    
    func getProactiveGreeting() async throws -> LioGreetingResponse {
        return try await NetworkClient.shared.request(Endpoints.ChatModule.getGreeting)
    }

    // MARK: - Session Management

    func startNewSession() {
        conversationHistory.removeAll()
        intentClassifier.resetWizard() // Reset wizard state if active
        print("🆕 LioChatService: Session cleared")
    }
    
    // MARK: - Send Message (Hybrid: Backend -> OpenAI -> Local)
    
    func sendMessage(
        text: String,
        sessionId: String? = nil,
        mode: String,
        context: [String: Any]? = nil,
        contextHint: String? = nil
    ) async throws -> LioChatResponse {
        
        // 1. FAIL-PROOF: Classify Intent First
        // This runs locally appropriately routes the user request
        let intent = intentClassifier.classifyIntent(text)
        print("🎯 LioChatService Intent: \(intent)")
        
        switch intent {
        case .courseCreation(let topic):
            // SMART COURSE CREATION FLOW
            // 1. Check if we have user's mastery profile for auto-difficulty detection
            // 2. If profile known → generate course automatically at optimal level
            // 3. If profile unknown → ask via wizard
            
            do {
                // Try to get user's learning profile
                let profile = try? await PersonalizationService.shared.getMasteryProfile()
                
                if let profile = profile, profile.optimalDifficulty > 0 {
                    // User has a profile - use their optimal difficulty
                    let level = difficultyToLevel(profile.optimalDifficulty)
                    print("🎓 Auto-generating course at \(level) level based on user profile")
                    
                    // Generate actual course via Cinema service
                    let course = try await InteractiveCinemaService.shared.generateGraphCourse(
                        topic: topic,
                        level: level
                    )
                    
                    // Return response with action to open classroom
                    let confirmationText = "🎉 Your **\(topic)** course is ready! I've tailored it for \(level) level based on your progress. Opening now..."
                    
                    let aiMessage = LyoMessage(
                        id: UUID().uuidString,
                        content: confirmationText,
                        isFromUser: false,
                        timestamp: Date()
                    )
                    conversationHistory.append(aiMessage)
                    
                    return LioChatResponse(
                        text: confirmationText,
                        source: "course_generator",
                        action: LioChatAction(type: "open_classroom", parameters: ["courseId": course.id, "topic": topic]),
                        suggestions: ["Start Learning", "View Outline"],
                        meta: ["courseId": course.id, "level": level]
                    )
                } else {
                    // No profile yet - start wizard to ask about level
                    print("🎓 No user profile - starting course wizard for level selection")
                    intentClassifier.startWizard(topic: topic)
                    
                    let clarificationText = """
                    I'd love to create a **\(topic)** course for you! 🎓
                    
                    To personalize it perfectly, what's your current level with this subject?
                    
                    • **Beginner** - New to this topic
                    • **Intermediate** - Some experience
                    • **Advanced** - Ready for deep dives
                    """
                    
                    let aiMessage = LyoMessage(
                        id: UUID().uuidString,
                        content: clarificationText,
                        isFromUser: false,
                        timestamp: Date()
                    )
                    conversationHistory.append(aiMessage)
                    
                    return LioChatResponse(
                        text: clarificationText,
                        source: "course_wizard",
                        action: nil,
                        suggestions: ["Beginner", "Intermediate", "Advanced"],
                        meta: ["mode": "course_wizard", "topic": topic]
                    )
                }
            } catch {
                // Fallback to backend chat if something fails
                print("⚠️ Course generation failed, falling back to chat: \(error)")
                let backend = try await sendChatModuleMessage(
                    message: text,
                    sessionId: sessionId,
                    modeHint: "course_planner",
                    action: "create_course",
                    contextHint: topic
                )

                let validatedText = validateNotCourseContent(backend.response)
                var aiMessage = LyoMessage(
                    id: UUID().uuidString,
                    content: validatedText,
                    isFromUser: false,
                    timestamp: Date()
                )
                aiMessage.responseMode = backend.responseMode
                aiMessage.quickExplainer = backend.quickExplainer
                aiMessage.courseProposal = backend.courseProposal
                conversationHistory.append(aiMessage)

                return LioChatResponse(
                    text: validatedText,
                    source: "backend_chat",
                    action: nil,
                    suggestions: backend.quickExplainer?.chips,
                    meta: ["mode": "course_planner"]
                )
            }
            
        case .courseWizardContinue(let action):
             // Continue wizard locally - NO backend call
             let response = await courseWizard.handleWizardStep(action: action)
             return response.toLioChatResponse()
             
        case .quickExplanation(let topic):
            // Quick explainer via backend (real)
            return try await handleQuickExplanation(text: text, topic: topic, mode: mode, context: context)
            
        case .generalChat:
             // Fallthrough to normal hybrid flow
             break
        }
        
        // 2. Local Action Triggers (Legacy/Fallback)
        if let hint = contextHint, !hint.isEmpty {
            let lowerText = text.lowercased()
            if lowerText.contains("yes") || lowerText.contains("sure") || lowerText.contains("start") || lowerText.contains("ok") {
                if hint.contains("tutor") {
                    return LioChatResponse(
                        text: "Great! I'm starting a tutor session for you now. We can dive deeper into this topic together! 🎓",
                        source: "local",
                        action: LioChatAction(type: "start_tutor", parameters: ["topic": "Learning"]),
                        suggestions: nil,
                        meta: nil
                    )
                } else if hint.contains("lesson") {
                    return LioChatResponse(
                        text: "Excellent choice! Loading the live lesson for you. Let's learn! 📚",
                        source: "local",
                        action: LioChatAction(type: "start_lesson", parameters: ["lessonId": "intro_1"]),
                        suggestions: nil,
                        meta: nil
                    )
                }
            }
        }
        
        // Add user message to history
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            content: text,
            isFromUser: true,
            timestamp: Date()
        )
        conversationHistory.append(userMessage)
        if conversationHistory.count > 10 {
            conversationHistory = Array(conversationHistory.suffix(10))
        }

        // 3. Primary: Real backend chat module (/api/v1/chat)
        var authFailed = false
        
        // Only attempt authenticated chat if we have a token
        if await tokenManager.getToken() != nil {
            do {
                print("🧠 LioChatService: Attempting backend chat module...")
                let backend = try await sendChatModuleMessage(
                    message: text,
                    sessionId: sessionId,
                    modeHint: nil,
                    action: nil,
                    contextHint: contextHint
                )

                let validatedText = validateNotCourseContent(backend.response)
                var aiMessage = LyoMessage(
                    id: UUID().uuidString,
                    content: validatedText,
                    isFromUser: false,
                    timestamp: Date()
                )
                aiMessage.responseMode = backend.responseMode

                if let qe = backend.quickExplainer {
                    // If backend schema doesn't include concept, use the inferred topic if available.
                    let concept = qe.concept.isEmpty ? (contextHint ?? "") : qe.concept
                    aiMessage.quickExplainer = QuickExplainerData(concept: concept, explanation: qe.explanation, chips: qe.chips)
                } else {
                    aiMessage.quickExplainer = nil
                }

                aiMessage.courseProposal = backend.courseProposal
                conversationHistory.append(aiMessage)



                return handleBackendResponse(backend, validatedText: validatedText)
            } catch {
                print("⚠️ LioChatService: Backend chat failed (\(error)).")

                // If the user is unauthorized (common when backend auth is down), fall back to the public AI chat endpoint.
                let normalizedError = LyoError.from(error: error)
                if case .network(.unauthorized) = normalizedError {
                    authFailed = true
                } else {
                    // For other errors, only continue if mocks are allowed
                    guard AppConfig.allowMockFallbacks else {
                        throw error
                    }
                }
            }
        } else {
            // No token available, skip straight to public fallback
            authFailed = true
        }

        // ... rest of method
        
        // Fallback: Public AI Chat (if auth failed or no token)
        if authFailed {
            // ... (existing fallback logic)
        }
        
        // ...
        
        // Fallback: Public AI Chat (if auth failed or no token)
        if authFailed {
            do {
                let (response, source, uiContent, _, wasCommand, openClassroomPayload) = try await BackendAIService.shared.studySession(
                    message: text,
                    resourceId: contextHint,
                    mode: mode
                )

                let validatedText = validateNotCourseContent(response)
                
                // Convert UI Content (A2UI -> LyoMessage Types)
                let mappedContentTypes = convertToMessageContentType(uiContent)
                
                // Handle OPEN_CLASSROOM command directly from backend
                if wasCommand, let classroomPayload = openClassroomPayload {
                    print("🎓 LioChatService: OPEN_CLASSROOM payload received - triggering navigation")
                    let commandPayload = AICommandPayload(
                        stackItem: nil,
                        course: CoursePayload(
                            id: classroomPayload.course.id,
                            title: classroomPayload.course.title,
                            topic: classroomPayload.course.topic,
                            level: classroomPayload.course.level,
                            language: "English",
                            duration: classroomPayload.course.duration ?? "~45 min",
                            objectives: classroomPayload.course.objectives
                        )
                    )
                    let _ = AICommandHandler.shared.handleOpenClassroom(commandPayload)
                }
                
                let aiMessage = LyoMessage(
                    id: UUID().uuidString,
                    content: validatedText,
                    isFromUser: false,
                    timestamp: Date(),
                    contentTypes: mappedContentTypes
                )
                conversationHistory.append(aiMessage)
                
                print("📝 LioChatService: Response was\(wasCommand ? "" : " not") a command. UI Content: \(uiContent?.count ?? 0) decoded")

                return LioChatResponse(
                    text: validatedText,
                    source: "backend_public_ai",
                    action: nil,
                    suggestions: nil,
                    meta: ["provider": source, "fallback": "unauthorized"],
                    contentTypes: mappedContentTypes
                )
            } catch {
                // If the public fallback also fails, continue to the normal fallback chain below.
                print("⚠️ Public fallback failed: \(error)")
            }
        }

        // In real mode, surface the failure instead of silently returning mock content.
        guard AppConfig.allowMockFallbacks else {
            throw LyoError.network(.serverError(500))
        }

        // Optional fallback chain (explicitly enabled via LYO_ALLOW_MOCKS=1)
        print("⚠️ Falling back to OpenAI/local because LYO_ALLOW_MOCKS=1")

        do {
            let systemPrompt = buildSystemPrompt(for: mode, context: context)
            let openAIResponse = try await OpenAIService.shared.sendMessage(
                message: text,
                conversationHistory: conversationHistory,
                systemPrompt: systemPrompt
            )

            let validatedText = validateNotCourseContent(openAIResponse)
            let aiMessage = LyoMessage(
                id: UUID().uuidString,
                content: validatedText,
                isFromUser: false,
                timestamp: Date()
            )
            conversationHistory.append(aiMessage)
            let action = detectAction(in: text, response: validatedText)
            return LioChatResponse(
                text: validatedText,
                source: "openai_backup",
                action: action,
                suggestions: nil,
                meta: ["mode": mode, "fallback": "openai"]
            )
        } catch {
            return generateLocalResponse(for: text, mode: mode)
        }
    }
    
    // MARK: - Fail-Safe Handlers
    
    private func handleQuickExplanation(text: String, topic: String, mode: String, context: [String: Any]?) async throws -> LioChatResponse {
        let backend = try await sendChatModuleMessage(
            message: text,
            modeHint: "quick_explainer",
            action: nil,
            contextHint: topic
        )

        let validated = validateNotCourseContent(backend.response)
        return LioChatResponse(
            text: validated,
            source: "quick_explain",
            action: nil,
            suggestions: backend.quickExplainer?.chips ?? ["Tell me more", "Create a course", "Quiz me"],
            meta: ["type": "quick_explain"]
        )
    }
    
    private func validateNotCourseContent(_ text: String) -> String {
       let courseIndicators = [
           "module 1", "module 2", "lesson 1", "lesson 2",
           "### module", "### lesson", "course outline",
           "**module", "**lesson", "week 1:", "day 1:",
           "learning path:", "curriculum:"
       ]
       
       let lowerText = text.lowercased()
       
       for indicator in courseIndicators {
           if lowerText.contains(indicator) {
               // Truncate at the first occurrence
               if let range = lowerText.range(of: indicator) {
                   // Map back to original text index
                   let originalIndex = text.index(text.startIndex, offsetBy: text.distance(from: lowerText.startIndex, to: range.lowerBound))
                   
                   var safeText = String(text[..<originalIndex])
                   // Ensure we don't return an empty string
                   if safeText.count < 10 {
                       safeText = "Here is a summary of the topic:"
                   }
                   
                   // User explicitly requested: Do not include response limited warning.
                   return safeText
               }
           }
       }
       return text
    }
    
    // MARK: - Build System Prompt
    
    private func buildSystemPrompt(for mode: String, context: [String: Any]?) -> String {
        let basePrompt = """
        You are **Lyo**, the AI assistant inside the **Lyo** learning app.
        Lyo is an AI-powered learning and life-long growth platform that should feel:
        * Friendly, modern, slightly playful (not like a boring school LMS)
        * Smart and "AI-powered" but not overwhelming
        * Useful for both students and life-learners

        The app has multiple main surfaces:
        1. **Chat Screen (this screen)** – conversational interface with Lyo.
        2. **AI Classroom** – a dedicated area where full courses, lessons, and structured learning flows live.
        3. **Stack** – a "today's stack" view of the user's active items (courses, tutors, chats, tasks, etc.), shown as cards.

        Your job in this chat:
        * Answer normal questions directly in chat.
        * Detect when the user wants a **course / class / structured learning plan**, and in that case:
          * Do NOT build the whole course in chat.
          * Instead, send a structured JSON "UI event" so the app can:
            1. Open the AI Classroom for that topic, and
            2. Add an item to the user's Stack.

        ## When to trigger the AI Classroom

        You must treat the user as requesting a **course / class / structured plan** when they clearly ask for:
        * "Create a course on X…"
        * "Make a full course about…"
        * "Create a study plan / learning plan for…"
        * "Teach me X from zero / from scratch."
        * "Start a class on…"
        * "I want to learn [topic]"

        ## Output format for classroom requests

        When the user clearly wants a course, respond with **only** this JSON (no extra text):

        ```json
        {
          "type": "OPEN_CLASSROOM",
          "payload": {
            "stack_item": {
              "category": "Course",
              "title": "<short course title>",
              "subtitle": "<one-line description>",
              "status": "active",
              "due": null
            },
            "course": {
              "title": "<short course title>",
              "topic": "<main topic>",
              "level": "<beginner|intermediate|advanced>",
              "language": "English",
              "duration": "<e.g. '6 lessons'>",
              "objectives": [
                "<objective 1>",
                "<objective 2>",
                "<objective 3>"
              ]
            }
          }
        }
        ```

        ## Chat mode

        When the user is asking a general question or having a conversation, respond naturally. Keep responses concise and helpful.
        """

        return basePrompt
    }

    /// Detects any implicit action requests in user text
    private func detectAction(in userText: String, response: String) -> LioChatAction? {
        let lowerText = userText.lowercased()
        
        // Detect course/classroom intent
        if lowerText.contains("create a course") ||
           lowerText.contains("teach me") ||
           lowerText.contains("start a class") {
            return LioChatAction(type: "suggest_classroom", parameters: nil)
        }
        
        return nil
    }

    /// Generates a local fallback response when all else fails
    private func generateLocalResponse(for text: String, mode: String) -> LioChatResponse {
        let fallbackResponses = [
            "I'm having trouble connecting right now. Let me try again in a moment.",
            "My apologies, I couldn't process that. Could you rephrase?",
            "I'm experiencing some connectivity issues. Please try again."
        ]
        
        return LioChatResponse(
            text: fallbackResponses.randomElement() ?? fallbackResponses[0],
            source: "local_fallback",
            action: nil,
            suggestions: ["Try again", "Help"],
            meta: ["mode": mode, "fallback": "local"]
        )
    }

    /// Converts difficulty score to level string
    private func difficultyToLevel(_ difficulty: Int) -> String {
        switch difficulty {
        case 0...3: return "beginner"
        case 4...6: return "intermediate"
        default: return "advanced"
        }
    }

    /// Converts UI content types
    private func convertToMessageContentType(_ uiContent: [A2UIContent]?) -> [MessageContentType]? {
        guard let content = uiContent, !content.isEmpty else { return nil }
        
        return content.compactMap { item -> MessageContentType? in
            switch item.type {
            case .text:
                return .text
            case .processing:
                return .processing(step: "Processing...", progress: nil)
            case .quiz:
                guard let quiz = item.quiz, let firstQ = quiz.questions.first else { return nil }
                let correctIndex = firstQ.options.firstIndex(of: firstQ.correctAnswer) ?? 0
                return .quiz(
                    question: firstQ.question,
                    options: firstQ.options,
                    correctIndex: correctIndex,
                    explanation: nil
                )
            default:
                return nil
            }
        }
    }
}
