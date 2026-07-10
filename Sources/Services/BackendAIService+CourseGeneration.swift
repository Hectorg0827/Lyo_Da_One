//
//  BackendAIService+CourseGeneration.swift
//  Lyo
//
//  Extension for course generation helpers
//

import Foundation

extension BackendAIService {
    /// POST request with JSON dictionary (for flexible payloads)
    func postJSONDict<R: Codable>(endpoint: String, body: [String: Any]) async throws -> R {
        // Validate dictionary before serialization
        guard JSONSerialization.isValidJSONObject(body) else {
            throw BackendAIError.invalidPayload("Invalid JSON payload: \(body)")
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let dynamicEndpoint = DynamicEndpoint(
                urlString: endpoint,
                method: .post,
                body: DataWrapper(data: jsonData),
                requiresAuth: true
            )
            return try await NetworkClient.shared.request(dynamicEndpoint)
        } catch {
            // Log and map errors
            Log.ai.error("Failed to send POST request: \(error.localizedDescription)")
            if let lyoError = error as? LyoError {
                switch lyoError {
                case .network(.unauthorized): 
                    throw BackendAIError.unauthorized
                case .rateLimitExceeded: 
                    throw BackendAIError.rateLimited
                case .validation(let validationError):
                    let msg = validationError.detail.map { "\($0.msg)" }.joined(separator: ", ")
                    throw BackendAIError.serverError(msg)
                case .network(.serverError(let code)):
                    throw BackendAIError.serverError("Server error: \(code)")
                default:
                    throw BackendAIError.networkError(error.localizedDescription)
                }
            }
            throw error
        }
    }
}
