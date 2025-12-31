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
        // Serialize dictionary to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        // Use DynamicEndpoint with DataWrapper
        // Note: DynamicEndpoint handles full URLs or paths. If endpoint is full URL, it parses it.
        let dynamicEndpoint = DynamicEndpoint(
            urlString: endpoint,
            method: .post,
            body: DataWrapper(data: jsonData),
            requiresAuth: true
        )
        
        do {
            return try await NetworkClient.shared.request(dynamicEndpoint)
        } catch {
            // Map NetworkClient errors to BackendAIError
            if let lyoError = error as? LyoError {
                switch lyoError {
                case .network(.unauthorized): 
                    throw BackendAIError.unauthorized
                case .rateLimitExceeded: 
                    throw BackendAIError.rateLimited
                case .validation(let validationError):
                    // Flatten validation errors into a string
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
