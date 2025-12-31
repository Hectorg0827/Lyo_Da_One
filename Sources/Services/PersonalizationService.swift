import Foundation

public class PersonalizationService {
    public static let shared = PersonalizationService()
    
    private init() {}
    
    public func getNextAction(
        lessonId: String? = nil,
        currentSkill: String? = nil
    ) async throws -> NextActionResponse {
        let learnerId = await TokenManager.shared.getUserId() ?? "unknown"
        
        let requestBody: [String: Any] = [
            "learner_id": learnerId,
            "lesson_id": lessonId as Any,
            "current_skill": currentSkill as Any
        ]
        
        // Filter nil values
        let cleanBody = requestBody.compactMapValues { $0 }
        
        // Use AnyEncodable wrapper for the body
        let encodableBody = cleanBody.mapValues { AnyEncodable(value: $0) }
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/ai/recommendations/next-action",
            method: .post,
            body: encodableBody
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    public func updateState(update: PersonalizationStateUpdate) async throws {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/ai/recommendations/state",
            method: .post,
            body: update
        )
        
        do {
            let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
        } catch {
            print("⚠️ Failed to update affect state: \(error.localizedDescription)")
        }
    }
    
    public func traceKnowledge(trace: KnowledgeTraceRequest) async throws {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/ai/recommendations/trace",
            method: .post,
            body: trace
        )
        
        let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
    }
    
    public func getMasteryProfile() async throws -> MasteryProfile {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/ai/recommendations/profile",
            method: .get
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
}
