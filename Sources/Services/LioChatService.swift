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
    
    enum CodingKeys: String, CodingKey {
        case text
        case source
        case action
        case suggestions
        case meta
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
    private init() {}
    
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
        modeHint: String?,
        action: String?,
        contextHint: String?
    ) async throws -> ChatResponse {
        
        let payload = ChatModuleRequest(
            message: message,
            modeHint: modeHint,
            action: action,
            conversationId: nil,
            sessionId: nil,
            conversationHistory: chatHistoryPayload(),
            context: contextHint,
            includeCtas: true,
            includeChips: true
        )
        
        let endpoint = Endpoint(
            path: "/chat",
            method: .POST,
            body: try? jsonEncoder.encode(payload),
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Proactive Greeting
    
    func getProactiveGreeting() async throws -> LioGreetingResponse {
        let endpoint = Endpoint(
            path: "/chat/greeting",
            method: .GET,
            requiresAuth: true
        )
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Send Message (Hybrid: Backend -> OpenAI -> Local)
    
    func sendMessage(
        text: String,
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
            // Use the real backend course planner so a real course is created/saved.
            // Backend will return courseProposal + generatedCourseId when applicable.
            let backend = try await sendChatModuleMessage(
                message: text,
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
        do {
            print("🧠 LioChatService: Attempting backend chat module...")
            let backend = try await sendChatModuleMessage(
                message: text,
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

            return LioChatResponse(
                text: validatedText,
                source: "backend_chat",
                action: nil,
                suggestions: backend.quickExplainer?.chips,
                meta: ["provider": backend.provider ?? "chat"]
            )
        } catch {
            print("⚠️ LioChatService: Backend chat failed (\(error)).")

            // In real mode, surface the failure instead of silently returning mock content.
            guard AppConfig.allowMockFallbacks else {
                throw error
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
        You are Lio, an enthusiastic and supportive AI learning companion in the Lyo app. 
        You have a warm, encouraging personality. Use emojis occasionally to keep things engaging.
        Keep responses concise but helpful (2-4 paragraphs max).
        
        """
        
        switch mode {
        case "focus":
            return basePrompt + """
            You're in Focus Mode - helping the user concentrate on their learning goals.
            - Help them stay on track with their current course or study session
            - Provide explanations, examples, and practice questions
            - Encourage progress and celebrate achievements
            - Suggest next steps in their learning journey
            """
        case "discover":
            return basePrompt + """
            You're in Discover Mode - helping the user explore new topics.
            - Suggest interesting courses and learning paths
            - Share fun facts and connections between topics
            - Spark curiosity and recommend related subjects
            - Help them find their next learning adventure
            """
        case "campus":
            return basePrompt + """
            You're in Campus Mode - helping with campus life and events.
            - Share information about campus events and activities
            - Help find study groups and collaboration opportunities
            - Provide guidance on campus resources
            - Connect users with relevant communities
            """
        case "collab":
            return basePrompt + """
            You're in Collab Mode - helping with group learning and collaboration.
            - Facilitate study group discussions
            - Help coordinate group projects
            - Suggest collaborative learning activities
            - Support peer-to-peer learning
            """
        default:
            return basePrompt + """
            Help the user with whatever they need - learning, questions, or guidance.
            Be friendly, supportive, and helpful.
            """
        }
    }
    
    // MARK: - Detect Actions
    
    private func detectAction(in userMessage: String, response: String) -> LioChatAction? {
        let lower = userMessage.lowercased()
        
        // Detect learning intent - user wants to learn a topic
        if detectLearningIntent(in: lower) {
            let topic = extractTopic(from: userMessage)
            return LioChatAction(
                type: "generate_course",
                parameters: ["topic": topic, "source": "learning_intent"]
            )
        }
        
        // Detect explicit course creation request
        if lower.contains("create") && (lower.contains("course") || lower.contains("curriculum")) {
            let topic = extractTopic(from: userMessage)
            return LioChatAction(
                type: "generate_course",
                parameters: ["topic": topic, "source": "explicit_request"]
            )
        }
        
        // Detect quiz intent
        if lower.contains("quiz") || lower.contains("test me") {
            return LioChatAction(type: "start_quiz", parameters: nil)
        }
        
        // Detect tutor session intent
        if lower.contains("tutor") || lower.contains("explain") {
            return LioChatAction(type: "start_tutor", parameters: nil)
        }
        
        return nil
    }
    
    // MARK: - Learning Intent Detection
    
    private func detectLearningIntent(in text: String) -> Bool {
        let learningPhrases = [
            "want to learn",
            "teach me",
            "help me learn",
            "i want to study",
            "show me how to",
            "can you teach",
            "help me understand",
            "i'd like to learn",
            "learn about",
            "study for",
            "prepare for",
            "get better at",
            "improve my",
            "master"
        ]
        
        return learningPhrases.contains { text.contains($0) }
    }
    
    // MARK: - Topic Extraction
    
    private func extractTopic(from message: String) -> String {
        let lower = message.lowercased()
        
        // Common patterns to remove
        let patternsToRemove = [
            "i want to learn",
            "teach me",
            "help me learn",
            "i'd like to learn",
            "can you teach me",
            "help me understand",
            "show me how to",
            "learn about",
            "create a course on",
            "create a course about",
            "make a course on",
            "please",
            "could you",
            "would you",
            "i need to"
        ]
        
        var cleaned = lower
        for pattern in patternsToRemove {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
        }
        
        // Clean up and capitalize
        let topic = cleaned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize first letter of each word
        return topic.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    // MARK: - Clear History
    
    func clearHistory() {
        conversationHistory.removeAll()
    }
    
    // MARK: - Fallback Local Response
    
    func generateLocalResponse(for message: String, mode: String) -> LioChatResponse {
        let lower = message.lowercased()
        
        // Smart local responses based on keywords
        if lower.contains("hello") || lower.contains("hi") || lower.contains("hey") {
            return LioChatResponse(
                text: "Hey there! 👋 I'm Lio, your AI learning companion. What would you like to explore today?",
                source: "local",
                action: nil,
                suggestions: ["Create a course", "Help me study", "Quiz me"],
                meta: nil
            )
        }
        
        if lower.contains("course") || lower.contains("learn") {
            return LioChatResponse(
                text: "I'd love to help you learn! 📚 What topic interests you? I can create a personalized learning path, explain concepts, or quiz you on what you know.",
                source: "local",
                action: nil,
                suggestions: ["Python basics", "History of Art", "Calculus"],
                meta: nil
            )
        }
        
        if lower.contains("quiz") || lower.contains("test") {
            return LioChatResponse(
                text: "Ready for a challenge! 🎯 What subject should I quiz you on? I can create practice questions to help reinforce your learning.",
                source: "local",
                action: nil,
                suggestions: ["Math Quiz", "Science Quiz", "History Quiz"],
                meta: nil
            )
        }
        
        if lower.contains("math") {
            return LioChatResponse(
                text: "Math is fascinating! 🧮 Whether it's algebra, calculus, or statistics - I'm here to help. What specific topic would you like to explore?",
                source: "local",
                action: nil,
                suggestions: ["Algebra", "Calculus", "Statistics"],
                meta: nil
            )
        }
        
        if lower.contains("code") || lower.contains("programming") || lower.contains("python") || lower.contains("swift") {
            return LioChatResponse(
                text: "Coding is a superpower! 💻 I can help you learn programming concepts, debug code, or build projects. What language or concept interests you?",
                source: "local",
                action: nil,
                suggestions: ["Python", "Swift", "JavaScript"],
                meta: nil
            )
        }
        
        if lower.contains("help") {
            return LioChatResponse(
                text: "I'm here to help! 🌟 I can:\n• Create personalized courses\n• Explain complex topics\n• Generate practice quizzes\n• Answer your questions\n\nWhat would you like to do?",
                source: "local",
                action: nil,
                suggestions: ["Start a course", "Quick explanation", "Quiz"],
                meta: nil
            )
        }
        
        if lower.contains("thank") {
            return LioChatResponse(
                text: "You're welcome! 😊 I'm always here to help you learn and grow. What else can I help you with?",
                source: "local",
                action: nil,
                suggestions: nil,
                meta: nil
            )
        }
        
        // Mode-specific fallbacks
        let modeResponses: [String: [String]] = [
            "focus": [
                "I'm here to help you focus on your learning goals! What topic are you working on? 📚",
                "Let's make progress together! What would you like to learn about today? 🎯",
                "Ready to dive deep! Tell me what subject you'd like to explore. 💡"
            ],
            "discover": [
                "Looking to discover something new? I can suggest courses based on your interests! 🔍",
                "There's so much to explore! What subjects spark your curiosity? ✨",
                "Let me help you find your next learning adventure! What interests you? 🚀"
            ],
            "campus": [
                "Want to know what's happening around campus? I can help you find events and study groups! 🏫",
                "I can guide you to campus resources and activities. What are you looking for? 📍",
                "Campus life is exciting! Let me help you discover events and connect with others. 🎉"
            ],
            "collab": [
                "Collaboration makes learning better! Looking to join a study group? 👥",
                "Working together is powerful! How can I help your team today? 🤝",
                "Let's connect you with others learning similar topics! What are you studying? 📖"
            ]
        ]
        
        let responses = modeResponses[mode] ?? modeResponses["focus"]!
        let randomResponse = responses.randomElement() ?? "I'm here to support your learning journey. What can I help you with today?"
        
        return LioChatResponse(
            text: randomResponse,
            source: "local",
            action: nil,
            suggestions: nil,
            meta: ["fallback": "true"]
        )
    }
}

// MARK: - Errors

enum LioChatError: LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please log in to chat with Lio"
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .serverError(let message):
            return message
        case .networkError(let message):
            return message
        }
    }
}

// MARK: - Wizard Response Extension

extension WizardResponse {
    func toLioChatResponse() -> LioChatResponse {
        var action: LioChatAction? = nil
        
        // If the wizard is complete or has specific actions, map them
        if self.shouldStartCourseGeneration {
            let topic = self.courseGenerationTopic ?? self.outline?.title ?? "Course"
            action = LioChatAction(
                type: "generate_course",
                parameters: ["topic": topic]
            )
        }
        
        return LioChatResponse(
            text: self.message,
            source: "course_wizard",
            action: action,
            suggestions: self.chips,
            meta: ["wizard_step": "active"]
        )
    }
}
