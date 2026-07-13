import Foundation
import os

public class PersonalizationService {
    public static let shared = PersonalizationService()
    
    private init() {}
    
    public func getNextAction(
        lessonId: String? = nil,
        currentSkill: String? = nil
    ) async throws -> NextActionResponse {
        // Backend: GET /api/v1/personalization/next?lesson_id=&current_skill=
        // (learner_id is derived server-side from the auth token)
        var components = URLComponents(string: "/api/v1/personalization/next")!
        var queryItems: [URLQueryItem] = []
        if let lessonId { queryItems.append(URLQueryItem(name: "lesson_id", value: lessonId)) }
        if let currentSkill { queryItems.append(URLQueryItem(name: "current_skill", value: currentSkill)) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        let endpoint = DynamicEndpoint(
            urlString: components.string ?? "/api/v1/personalization/next",
            method: .get
        )

        return try await NetworkClient.shared.request(endpoint)
    }
    
    public func updateState(update: PersonalizationStateUpdate) async throws {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/personalization/state",
            method: .patch,
            body: update
        )
        
        do {
            let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
        } catch {
            Log.net.warning("Failed to update affect state: \(error.localizedDescription)")
        }
    }
    
    public func traceKnowledge(trace: KnowledgeTraceRequest) async throws {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/personalization/trace",
            method: .post,
            body: trace
        )

        let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
    }

    public func getMasteryProfile() async throws -> MasteryProfile {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/personalization/mastery",
            method: .get
        )

        return try await NetworkClient.shared.request(endpoint)
    }
}
