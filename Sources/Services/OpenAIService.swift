//
//  OpenAIService.swift
//  Lyo
//
//  Real AI chat integration using OpenAI API
//

import Foundation
import os

// Note: This service uses models from Models/LyoChat.swift (LyoMessage, SuggestionChip)

@MainActor
class OpenAIService {
    static let shared = OpenAIService()
    
    // Backend is the single source of truth for AI (keys live server-side).
    private let baseURL = AppConfig.baseURL
    private let tokenManager = TokenManager.shared
    private var useMockMode: Bool { baseURL.isEmpty }
    
    private init() {
        if useMockMode {
            Log.ai.warning("Leo AI: Running in MOCK mode (no backend URL)")
        } else {
            Log.ai.info("Leo AI: Using Backend AI")
        }
    }
    
    // MARK: - Chat Completion
    
    func sendMessage(
        message: String,
        conversationHistory: [LyoMessage] = [],
        systemPrompt: String? = nil
    ) async throws -> String {
        if useMockMode {
            guard AppConfig.allowMockFallbacks else {
                throw OpenAIError.invalidURL
            }
            return try await getMockResponse(for: message, history: conversationHistory)
        }

        do {
            return try await sendBackendMessage(
                message: message,
                conversationHistory: conversationHistory,
                systemPrompt: systemPrompt
            )
        } catch {
            // Backend unavailable or response unexpected.
            if AppConfig.allowMockFallbacks {
                Log.ai.warning("Backend AI failed: \(error.localizedDescription). Falling back to mock because LYO_ALLOW_MOCKS=1")
                return try await getMockResponse(for: message, history: conversationHistory)
            }
            throw error
        }
    }

    // MARK: - Backend AI

    private struct BackendClassroomChatResponse: Codable {
        let content: String?
        let response: String?
    }

    private func sendBackendMessage(
        message: String,
        conversationHistory: [LyoMessage],
        systemPrompt: String?
    ) async throws -> String {
        let cleanMessage = message

        // Build conversation history for multi-turn context
        let historyPayload: [[String: String]] = conversationHistory.suffix(8).map { msg in
            [
                "role": msg.isFromUser ? "user" : "assistant",
                "content": msg.content
            ]
        }

        let endpoint = Endpoints.Classroom.classroomChat(
            message: cleanMessage,
            conversationHistory: historyPayload,
            systemPrompt: systemPrompt
        )

        let chat: BackendClassroomChatResponse = try await NetworkClient.shared.request(endpoint)

        let text = chat.content ?? chat.response ?? ""
        if text.isEmpty {
            throw OpenAIError.emptyResponse
        }
        return text
    }
    
    // MARK: - Generate Smart Suggestions
    
    func generateSuggestions(basedOn conversationHistory: [LyoMessage]) async throws -> [SuggestionChip] {
        // Get last few messages for context
        let recentMessages = conversationHistory.suffix(5)
        let context = recentMessages.map { $0.content }.joined(separator: "\n")
        
        let prompt = """
        Based on this learning conversation, suggest 4 helpful follow-up questions or actions the student might want.
        Keep each suggestion brief (3-7 words). Make them specific and actionable.
        
        Conversation context:
        \(context)
        
        Return ONLY a JSON array of strings, no other text:
        ["suggestion 1", "suggestion 2", "suggestion 3", "suggestion 4"]
        """
        
        let response = try await sendMessage(
            message: prompt,
            conversationHistory: [],
            systemPrompt: "You are a helpful assistant that generates learning suggestions in JSON format."
        )
        
        // Parse JSON response
        if let data = response.data(using: .utf8),
           let suggestions = try? JSONDecoder().decode([String].self, from: data) {
            return suggestions.enumerated().map { index, text in
                SuggestionChip(
                    id: "ai_\(UUID().uuidString)",
                    text: text,
                    icon: ["lightbulb", "questionmark.circle", "book", "brain"][index % 4],
                    actionType: "follow_up",
                    context: nil
                )
            }
        }
        
        // Fallback suggestions if parsing fails
        return generateFallbackSuggestions(basedOn: context)
    }
    
    private func generateFallbackSuggestions(basedOn context: String) -> [SuggestionChip] {
        let lowercased = context.lowercased()
        
        if lowercased.contains("course") || lowercased.contains("learn") {
            return [
                SuggestionChip(id: "1", text: "Create a study plan", icon: "calendar", actionType: "plan", context: nil),
                SuggestionChip(id: "2", text: "Quiz me on this", icon: "questionmark.circle", actionType: "quiz", context: nil),
                SuggestionChip(id: "3", text: "Show examples", icon: "lightbulb", actionType: "examples", context: nil),
                SuggestionChip(id: "4", text: "Break it down more", icon: "list.bullet", actionType: "explain", context: nil)
            ]
        } else if lowercased.contains("quiz") || lowercased.contains("test") {
            return [
                SuggestionChip(id: "1", text: "Generate practice questions", icon: "questionmark.circle", actionType: "quiz", context: nil),
                SuggestionChip(id: "2", text: "Explain the answer", icon: "lightbulb", actionType: "explain", context: nil),
                SuggestionChip(id: "3", text: "Try a harder one", icon: "arrow.up.circle", actionType: "harder", context: nil),
                SuggestionChip(id: "4", text: "Review key concepts", icon: "book", actionType: "review", context: nil)
            ]
        } else {
            return [
                SuggestionChip(id: "1", text: "Tell me more", icon: "text.bubble", actionType: "more", context: nil),
                SuggestionChip(id: "2", text: "Give an example", icon: "lightbulb.fill", actionType: "example", context: nil),
                SuggestionChip(id: "3", text: "Create a course", icon: "plus.circle", actionType: "course", context: nil),
                SuggestionChip(id: "4", text: "Practice with quiz", icon: "brain", actionType: "quiz", context: nil)
            ]
        }
    }
    
    // MARK: - Course Generation Helper
    
    func generateCourseOutline(topic: String) async throws -> String {
        let prompt = """
        Create a structured learning course outline for: \(topic)
        
        Include:
        - Course overview (1 sentence)
        - 5-7 main modules with brief descriptions
        - Estimated time for each module
        - Key learning outcomes
        
        Make it practical and actionable for self-paced learning.
        """
        
        return try await sendMessage(message: prompt, systemPrompt: "You are an expert curriculum designer.")
    }
    
    // MARK: - Quiz Generation
    
    func generateQuiz(topic: String) async throws -> String {
        let prompt = """
        Create a short quiz (3 questions) about: \(topic)
        
        Format:
        Question 1: [Question]
        A) [Option]
        B) [Option]
        C) [Option]
        Answer: [Correct Letter] - [Explanation]
        
        (Repeat for 3 questions)
        """
        
        return try await sendMessage(message: prompt, systemPrompt: "You are a teacher creating practice quizzes.")
    }
    
    // MARK: - Structured Quiz Generation
    
    func generateStructuredQuiz(topic: String) async throws -> Quiz {
        let prompt = """
        Create a quiz about: \(topic)
        
        Return a JSON object matching this structure:
        {
            "id": "quiz_uuid",
            "topic": "\(topic)",
            "difficulty": "Intermediate",
            "estimatedTime": 5,
            "questions": [
                {
                    "id": "q1",
                    "question": "Question text?",
                    "options": ["Option A", "Option B", "Option C", "Option D"],
                    "correctAnswer": "Option A", // Must match one of the options exactly
                    "explanation": "Why this is correct",
                    "type": "mcq"
                }
            ]
        }
        
        Create 3-5 multiple choice questions.
        IMPORTANT: Return ONLY valid JSON. No markdown formatting.
        """
        
        let jsonString = try await sendMessage(
            message: prompt,
            systemPrompt: "You are a quiz generator that outputs strict JSON."
        )
        
        // Clean up potential markdown code blocks
        let cleanJson = jsonString.replacingOccurrences(of: "```json", with: "")
                                .replacingOccurrences(of: "```", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanJson.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        
        return try JSONDecoder().decode(Quiz.self, from: data)
    }
    
    // MARK: - Mock Mode (Fallback)
    
    private func getMockResponse(for message: String, history: [LyoMessage]) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        let lowercased = message.lowercased()
        
        // Context-aware responses based on conversation history
        let hasHistory = !history.isEmpty
        
        if lowercased.contains("hello") || lowercased.contains("hi") || lowercased.contains("hey") {
            if hasHistory {
                return "Hey again! 👋 How can I help you continue your learning journey?"
            } else {
                return "Hello! I'm Leo, your AI learning mentor! 🦁✨\n\nI'm here to help you learn anything you want - from programming and math to languages and creative skills. I can:\n\n• Create personalized learning paths 📚\n• Explain complex concepts simply 💡\n• Generate practice questions 🎯\n• Track your progress 📈\n\nWhat would you like to learn today?"
            }
        }
        
        if lowercased.contains("python") {
            return "Python is an excellent choice! 🐍 It's perfect for beginners and powerful for pros.\n\n**Here's a quick learning path:**\n\n1. **Basics** (Week 1-2)\n   • Variables and data types\n   • Control flow (if/else, loops)\n   • Functions\n\n2. **Data Structures** (Week 3)\n   • Lists, tuples, dictionaries\n   • List comprehensions\n\n3. **Projects** (Week 4+)\n   • Build a calculator\n   • Create a to-do app\n   • Make a simple game\n\nWould you like me to create a full course for you?"
        }
        
        if lowercased.contains("javascript") || lowercased.contains("js") {
            return "JavaScript is the language of the web! 🌐\n\n**Essential JavaScript Path:**\n\n• **Fundamentals**: Variables, functions, arrays\n• **DOM**: Manipulate web pages\n• **Async**: Promises and async/await\n• **Modern JS**: ES6+ features\n• **Projects**: Interactive websites\n\nI can help you master each of these! Want to start with a specific topic?"
        }
        
        if lowercased.contains("swift") || lowercased.contains("ios") {
            return "Swift and iOS development! 📱 Great for building iPhone apps.\n\n**iOS Learning Track:**\n\n1. Swift basics and syntax\n2. SwiftUI fundamentals\n3. Data management\n4. Networking and APIs\n5. Publishing to App Store\n\nI can guide you through building your first app. What kind of app interests you?"
        }
        
        if lowercased.contains("course") || lowercased.contains("learn") || lowercased.contains("study") {
            return "I'd love to help you create a personalized learning course! 📚✨\n\nTell me:\n• What subject interests you?\n• What's your current level (beginner/intermediate/advanced)?\n• How much time can you dedicate per week?\n• What's your learning goal?\n\nI'll design a structured path with modules, exercises, and milestones!"
        }
        
        if lowercased.contains("quiz") || lowercased.contains("test") || lowercased.contains("practice") {
            return "Let's practice! 🎯\n\nI can create quizzes on any topic you've been learning. This helps reinforce concepts and identify areas to review.\n\nWhat subject should we quiz you on? Or would you like me to generate questions based on our conversation so far?"
        }
        
        if lowercased.contains("math") || lowercased.contains("algebra") || lowercased.contains("calculus") {
            return "Math is the foundation of so many skills! 🧮\n\n**Math Learning Path:**\n\n• **Algebra**: Equations, functions, graphs\n• **Geometry**: Shapes, angles, proofs\n• **Calculus**: Derivatives, integrals\n• **Statistics**: Data analysis, probability\n\nWhich area interests you most? I can explain concepts, work through examples, and create practice problems!"
        }
        
        if lowercased.contains("help") || lowercased.contains("what can you") {
            return "I'm your AI learning companion! 🦁 Here's what I can do:\n\n**📚 Learning**\n• Create custom courses\n• Explain complex topics simply\n• Recommend learning paths\n\n**🎯 Practice**\n• Generate quizzes and challenges\n• Provide instant feedback\n• Track your progress\n\n**💡 Guidance**\n• Answer questions\n• Suggest next steps\n• Keep you motivated\n\nJust tell me what you want to learn, and let's get started!"
        }
        
        if lowercased.contains("beginner") || lowercased.contains("intermediate") || lowercased.contains("advanced") {
            return "Got it! Knowing your level helps me tailor the content. \n\nWhat is your primary goal for learning this? (e.g., for a new job, school project, or just for fun?)"
        }
        
        if lowercased.contains("job") || lowercased.contains("career") || lowercased.contains("work") {
            return "That's a great motivation! Career-focused learning is very effective.\n\nDo you prefer learning through hands-on projects, reading theory, or interactive quizzes?"
        }
        
        if lowercased.contains("school") || lowercased.contains("university") || lowercased.contains("exam") {
            return "Understood. We'll focus on academic mastery and exam preparation.\n\nDo you prefer detailed explanations or practice problems?"
        }
        
        if lowercased.contains("hobby") || lowercased.contains("fun") || lowercased.contains("interest") {
            return "Learning for fun is the best! We can keep it relaxed and project-based.\n\nWhat kind of project would you be excited to build or create?"
        }
        
        if lowercased.contains("project") || lowercased.contains("hands-on") || lowercased.contains("build") {
            return "Perfect! Project-based learning is the best way to retain information.\n\nI can generate a personalized curriculum for you now. Shall I go ahead and create a learning path?"
        }
        
        if lowercased.contains("yes") || lowercased.contains("sure") || lowercased.contains("create") {
            return "Great! I'm generating your personalized learning path now... 🚀\n\n(In a real app, this would trigger the course generation engine based on the gathered requirements.)"
        }
        
        if lowercased.contains("thank") {
            return "You're very welcome! 😊\n\nI'm always here to help you learn and grow. Feel free to ask me anything - there are no silly questions in learning!\n\nReady to continue, or want to explore something new? 🚀"
        }
        
        // Default intelligent response
        return "That's interesting! 🤔\n\nI'd love to help you explore this further. Could you tell me more about:\n\n• What specifically you'd like to learn?\n• Your experience level with this topic?\n• What you hope to achieve?\n\nThe more I know about your goals, the better I can tailor the learning experience for you! 🎯"
    }
}


// MARK: - Models

enum OpenAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case emptyResponse
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiError(let code):
            return "AI service error (code: \(code))"
        case .emptyResponse:
            return "AI returned empty response"
        case .missingAPIKey:
            return "OpenAI API key not configured"
        }
    }
}

struct OpenAIChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}
