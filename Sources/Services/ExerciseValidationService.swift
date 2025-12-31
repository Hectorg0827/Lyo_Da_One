//
//  ExerciseValidationService.swift
//  Lyo
//
//  Service for exercise validation endpoints (multi-agent v2)
//

import Foundation

// MARK: - Request Models

struct ExerciseValidationRequest: Codable {
    let exerciseId: String
    let userAnswer: String
    let attemptCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case userAnswer = "user_answer"
        case attemptCount = "attempt_count"
    }
}

struct CodeValidationRequest: Codable {
    let code: String
    let language: String
    let expectedOutput: String?
    let testCases: [TestCase]?
    
    enum CodingKeys: String, CodingKey {
        case code
        case language
        case expectedOutput = "expected_output"
        case testCases = "test_cases"
    }
}

struct TestCase: Codable {
    let input: String
    let expectedOutput: String
    
    enum CodingKeys: String, CodingKey {
        case input
        case expectedOutput = "expected_output"
    }
}

// MARK: - Response Models

struct ValidationResponse: Codable {
    let isCorrect: Bool
    let feedback: String
    let explanation: String?
    let score: Double?
    let hints: [String]?
    
    enum CodingKeys: String, CodingKey {
        case isCorrect = "is_correct"
        case feedback
        case explanation
        case score
        case hints
    }
}

struct CodeValidationResponse: Codable {
    let isCorrect: Bool
    let output: String?
    let errors: [String]?
    let feedback: String
    let suggestions: [String]?
    let passedTests: Int?
    let totalTests: Int?
    
    enum CodingKeys: String, CodingKey {
        case isCorrect = "is_correct"
        case output
        case errors
        case feedback
        case suggestions
        case passedTests = "passed_tests"
        case totalTests = "total_tests"
    }
}

// MARK: - Exercise Validation Service

@MainActor
final class ExerciseValidationService: ObservableObject {
    static let shared = ExerciseValidationService()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private var baseURL: String { AppConfig.baseURL }
    private let tokenManager = TokenManager.shared
    
    private init() {
        print("✅ ExerciseValidationService initialized - multi-agent v2 validation")
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
    
    /// Validate a user's answer to an exercise
    func validateExercise(
        exerciseId: String,
        userAnswer: String,
        attemptCount: Int? = nil
    ) async throws -> ValidationResponse {
        let request = ExerciseValidationRequest(
            exerciseId: exerciseId,
            userAnswer: userAnswer,
            attemptCount: attemptCount
        )
        
        let endpoint = "\(baseURL)/api/v2/exercises/validate"
        return try await post(endpoint: endpoint, body: request)
    }
    
    /// Validate code with optional test cases
    func validateCode(
        code: String,
        language: String,
        expectedOutput: String? = nil,
        testCases: [TestCase]? = nil
    ) async throws -> CodeValidationResponse {
        let request = CodeValidationRequest(
            code: code,
            language: language,
            expectedOutput: expectedOutput,
            testCases: testCases
        )
        
        let endpoint = "\(baseURL)/api/v2/exercises/validate/code"
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
