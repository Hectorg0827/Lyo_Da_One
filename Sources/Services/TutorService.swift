//
//  TutorService.swift
//  Lyo
//
//  Service for AI Tutor endpoints (multi-agent v2)
//

import Foundation

// MARK: - Request Models

struct TutorAskRequest: Codable {
    let question: String
    let lessonContext: LessonContext?
    let userHistory: [String]?
    
    enum CodingKeys: String, CodingKey {
        case question
        case lessonContext = "lesson_context"
        case userHistory = "user_history"
    }
}

struct LessonContext: Codable {
    let lessonId: String
    let lessonTitle: String
    let currentTopic: String?
    let completedTopics: [String]?
    
    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case lessonTitle = "lesson_title"
        case currentTopic = "current_topic"
        case completedTopics = "completed_topics"
    }
}

struct ExplainRequest: Codable {
    let concept: String
    let difficulty: String  // "beginner", "intermediate", "advanced"
    let context: String?
}

struct HintRequest: Codable {
    let exerciseId: String
    let userAttempt: String?
    let attemptCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case userAttempt = "user_attempt"
        case attemptCount = "attempt_count"
    }
}

// MARK: - Response Models

struct TutorResponse: Codable {
    let answer: String
    let followUpQuestions: [String]?
    let suggestedResources: [String]?
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case answer
        case followUpQuestions = "follow_up_questions"
        case suggestedResources = "suggested_resources"
        case confidence
    }
}

struct ExplanationResponse: Codable {
    let explanation: String
    let examples: [String]?
    let visualAids: [String]?
    let keyPoints: [String]?
    
    enum CodingKeys: String, CodingKey {
        case explanation
        case examples
        case visualAids = "visual_aids"
        case keyPoints = "key_points"
    }
}

struct HintResponse: Codable {
    let hint: String
    let progressFeedback: String?
    let shouldRevealAnswer: Bool
    
    enum CodingKeys: String, CodingKey {
        case hint
        case progressFeedback = "progress_feedback"
        case shouldRevealAnswer = "should_reveal_answer"
    }
}

// MARK: - Tutor Service

@MainActor
final class TutorService: ObservableObject {
    static let shared = TutorService()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private var baseURL: String { AppConfig.baseURL }
    private let tokenManager = TokenManager.shared
    
    private init() {
        print("🎓 TutorService initialized - multi-agent v2 AI tutor")
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
    
    // MARK: - Public Methods
    
    /// Ask the AI tutor a question with optional lesson context
    func askQuestion(
        question: String,
        lessonContext: LessonContext? = nil,
        userHistory: [String]? = nil
    ) async throws -> TutorResponse {
        let request = TutorAskRequest(
            question: question,
            lessonContext: lessonContext,
            userHistory: userHistory
        )
        
        let endpoint = "\(baseURL)/api/v2/tutor/ask"
        return try await post(endpoint: endpoint, body: request)
    }
    
    /// Get an explanation of a concept
    func explainConcept(
        concept: String,
        difficulty: String = "intermediate",
        context: String? = nil
    ) async throws -> ExplanationResponse {
        let request = ExplainRequest(
            concept: concept,
            difficulty: difficulty,
            context: context
        )
        
        let endpoint = "\(baseURL)/api/v2/tutor/explain"
        return try await post(endpoint: endpoint, body: request)
    }
    
    /// Get a hint for an exercise
    func getHint(
        exerciseId: String,
        userAttempt: String? = nil,
        attemptCount: Int? = nil
    ) async throws -> HintResponse {
        let request = HintRequest(
            exerciseId: exerciseId,
            userAttempt: userAttempt,
            attemptCount: attemptCount
        )
        
        let endpoint = "\(baseURL)/api/v2/tutor/hint"
        return try await post(endpoint: endpoint, body: request)
    }
    
    // MARK: - Network Helpers
    
    private func post<T: Encodable, R: Codable>(endpoint: String, body: T) async throws -> R {
        isLoading = true
        defer { isLoading = false }
        
        let dynamicEndpoint = DynamicEndpoint(
            urlString: endpoint,
            method: .post,
            body: body,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
}
