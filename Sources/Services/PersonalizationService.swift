import Foundation

public class PersonalizationService {
    public static let shared = PersonalizationService()
    
    private let baseURL = AppConfig.baseURL
    private let tokenManager = TokenManager.shared
    
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
    private init() {}
    
    public func getNextAction(
        lessonId: String? = nil,
        currentSkill: String? = nil
    ) async throws -> NextActionResponse {
        var components = URLComponents(string: baseURL + "/api/v1/personalization/next")
        var queryItems: [URLQueryItem] = []
        
        if let lessonId = lessonId {
            queryItems.append(URLQueryItem(name: "lesson_id", value: lessonId))
        }
        if let currentSkill = currentSkill {
            queryItems.append(URLQueryItem(name: "current_skill", value: currentSkill))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try jsonDecoder.decode(NextActionResponse.self, from: data)
    }
    
    public func updateState(update: PersonalizationStateUpdate) async throws {
        guard let url = URL(string: baseURL + "/api/v1/personalization/state") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(update)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    public func traceKnowledge(trace: KnowledgeTraceRequest) async throws {
        guard let url = URL(string: baseURL + "/api/v1/personalization/trace") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(trace)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    public func getMasteryProfile() async throws -> MasteryProfile {
        guard let url = URL(string: baseURL + "/api/v1/personalization/mastery") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try jsonDecoder.decode(MasteryProfile.self, from: data)
    }
}
