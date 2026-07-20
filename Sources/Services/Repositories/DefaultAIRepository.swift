import Foundation

// MARK: - Default AI Repository
/// Production implementation of AIRepository using NetworkClient
class DefaultAIRepository: AIRepository {

    private let networkClient = NetworkClient.shared
    private let logger = NetworkLogger()

    init() {}

    // MARK: - Chat & Conversation

    func chat(message: String, provider: AIProvider? = nil, context: ChatContext? = nil) async throws -> ChatResponse {
        let response: ChatResponse = try await networkClient.request(
            Endpoints.AI.chat(message: message, provider: provider, context: context),
            cachePolicy: .reloadIgnoringCache // Don't cache AI responses
        )

        logger.log("✅ AI Chat complete: \(response.provider ?? "auto") - \(response.tokens ?? 0) tokens")
        return response
    }

    func mentorConversation(message: String, context: ChatContext? = nil, attachments: [String]? = nil) async throws -> ChatResponse {
        let response: ChatResponse = try await networkClient.request(
            Endpoints.AI.mentorConversation(message: message, context: context, attachments: attachments),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Mentor conversation complete")
        return response
    }

    // MARK: - Content Generation

    func generateContent(topic: String, level: SkillLevel, contentType: ContentType) async throws -> GeneratedContent {
        let response: GeneratedContent = try await networkClient.request(
            Endpoints.AI.generateContent(topic: topic, level: level, contentType: contentType),
            cachePolicy: .default // Cache for 5 minutes
        )

        logger.log("✅ Content generated: \(topic) - \(contentType.rawValue)")
        return response
    }

    func tutorSession(topic: String, question: String, level: String) async throws -> TutorSessionResponse {
        let response: TutorSessionResponse = try await networkClient.request(
            Endpoints.AI.tutorSession(topic: topic, question: question, level: level),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Tutor session created: \(response.sessionId)")
        return response
    }

    // MARK: - Quiz Generation

    func generateQuiz(topic: String, difficulty: QuizDifficulty, numQuestions: Int) async throws -> Quiz {
        let response: Quiz = try await networkClient.request(
            Endpoints.AI.generateQuiz(topic: topic, difficulty: difficulty, numQuestions: numQuestions),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Quiz generated: \(response.questions.count) questions")
        return response
    }

    func verifyAnswer(question: String, answer: String, correctAnswer: String? = nil) async throws -> AnswerVerification {
        let response: AnswerVerification = try await networkClient.request(
            Endpoints.AI.verifyAnswer(question: question, answer: answer, correctAnswer: correctAnswer),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Answer verified: \(response.isCorrect ? "Correct" : "Incorrect")")
        return response
    }

    // MARK: - Recommendations

    func getRecommendations(userId: String) async throws -> [Recommendation] {
        struct RecommendationsResponse: Codable {
            let recommendations: [Recommendation]
        }

        let response: RecommendationsResponse = try await networkClient.request(
            Endpoints.AI.recommend(userId: userId),
            cachePolicy: .default // Cache for 5 minutes
        )

        logger.log("✅ Recommendations fetched: \(response.recommendations.count)")
        return response.recommendations
    }

    func searchSimilar(query: String, limit: Int = 10) async throws -> [SearchResult] {
        struct SearchResponse: Codable {
            let results: [SearchResult]
        }

        let response: SearchResponse = try await networkClient.request(
            Endpoints.AI.embeddings(query: query, limit: limit),
            cachePolicy: .default
        )

        logger.log("✅ Similar content found: \(response.results.count)")
        return response.results
    }

    // MARK: - Streaming

    func streamSession(sessionId: String, callback: @escaping (StreamingResponseManager.StreamEvent) -> Void) async -> StreamingResponseManager {
        logger.log("🌊 Starting stream for session: \(sessionId)")
        return await networkClient.streamSession(sessionId: sessionId, callback: callback)
    }
}

// MARK: - Mock AI Repository (for testing/preview)
class MockAIRepository: AIRepository {

    func chat(message: String, provider: AIProvider?, context: ChatContext?) async throws -> ChatResponse {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        return ChatResponse(
            response: "This is a mock response to: \(message)",
            provider: "mock",
            cost: 0.001,
            tokens: 100,
            cached: false
        )
    }

    func mentorConversation(message: String, context: ChatContext?, attachments: [String]?) async throws -> ChatResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        return ChatResponse(
            response: "Mentor mock response",
            provider: "mock",
            cost: 0.001,
            tokens: 100,
            cached: false
        )
    }

    func generateContent(topic: String, level: SkillLevel, contentType: ContentType) async throws -> GeneratedContent {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
        return GeneratedContent(
            content: "Mock content for \(topic)",
            title: topic,
            summary: "This is a summary",
            keyPoints: ["Point 1", "Point 2", "Point 3"],
            provider: "mock"
        )
    }

    func tutorSession(topic: String, question: String, level: String) async throws -> TutorSessionResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        return TutorSessionResponse(
            sessionId: UUID().uuidString,
            response: "Mock tutor response",
            nextSteps: ["Step 1", "Step 2"],
            resources: ["Resource 1"]
        )
    }

    func generateQuiz(topic: String, difficulty: QuizDifficulty, numQuestions: Int) async throws -> Quiz {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return Quiz(
            id: UUID().uuidString,
            topic: topic,
            questions: [
                Quiz.QuizQuestion(
                    id: "1",
                    question: "What is 2 + 2?",
                    options: ["3", "4", "5", "6"],
                    correctAnswer: "4",
                    explanation: "2 plus 2 equals 4",
                    type: "mcq"
                )
            ],
            difficulty: difficulty.rawValue,
            estimatedTime: 5
        )
    }

    func verifyAnswer(question: String, answer: String, correctAnswer: String?) async throws -> AnswerVerification {
        try await Task.sleep(nanoseconds: 300_000_000)
        return AnswerVerification(
            isCorrect: true,
            explanation: "That's correct!",
            correctAnswer: answer,
            score: 100
        )
    }

    func getRecommendations(userId: String) async throws -> [Recommendation] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return [
            Recommendation(
                id: "1",
                type: "course",
                title: "Python Basics",
                reason: "Based on your interest in programming",
                confidence: 0.9
            ),
            Recommendation(
                id: "2",
                type: "course",
                title: "Data Structures",
                reason: "Next step in your learning path",
                confidence: 0.85
            )
        ]
    }

    func searchSimilar(query: String, limit: Int) async throws -> [SearchResult] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return [
            SearchResult(
                id: "1",
                title: "Similar Topic 1",
                description: "This is similar to your search",
                similarity: 0.95,
                type: "lesson"
            )
        ]
    }

    func streamSession(sessionId: String, callback: @escaping (StreamingResponseManager.StreamEvent) -> Void) async -> StreamingResponseManager {
        // Simulate streaming
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            callback(.blockEmit(content: "Mock ", blockType: "text"))

            try? await Task.sleep(nanoseconds: 300_000_000)
            callback(.blockEmit(content: "streaming ", blockType: "text"))

            try? await Task.sleep(nanoseconds: 300_000_000)
            callback(.blockEmit(content: "response", blockType: "text"))

            try? await Task.sleep(nanoseconds: 500_000_000)
            callback(.progress(percent: 100, message: "Complete"))

            try? await Task.sleep(nanoseconds: 200_000_000)
            callback(.sessionDone)
        }

        return StreamingResponseManager()
    }
}
