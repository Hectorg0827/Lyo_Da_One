
import Foundation

// MARK: - SaaS Response Models

struct OrganizationResponse: Codable {
    let id: Int
    let name: String
    let slug: String
    let planTier: String
    let isActive: Bool
    let contactEmail: String?
    let monthlyApiCalls: Int
    let monthlyAiTokens: Int
    let rateLimitPerMinute: Int
    let aiCallsPerDay: Int
    
    // Derived helpers
    var isPro: Bool { planTier == "pro" || planTier == "enterprise" }
}

struct UsageStatsResponse: Codable {
    let organizationId: Int
    let periodStart: Date
    let periodEnd: Date
    let totalRequests: Int
    let totalTokens: Int
    let estimatedCostUsd: Double
}

struct APIKeyCreatedResponse: Codable {
    let apiKey: String
    let keyInfo: APIKeyInfo
}

struct APIKeyInfo: Codable, Identifiable {
    let id: Int
    let keyPrefix: String
    let name: String
    let isActive: Bool
    let lastUsedAt: Date?
    let totalRequests: Int
}

// MARK: - SaaS Service

actor SaaSService {
    static let shared = SaaSService()
    private init() {}
    
    // MARK: - Fetch Organization
    
    func getOrganization() async throws -> OrganizationResponse {
        let endpoint = Endpoint(
            path: "/tenants/me",
            method: .GET,
            requiresAuth: true
        )
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Fetch Usage Stats
    
    func getUsageStats() async throws -> UsageStatsResponse {
        let endpoint = Endpoint(
            path: "/tenants/usage",
            method: .GET,
            requiresAuth: true
        )
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - API Key Management
    
    func listAPIKeys() async throws -> [APIKeyInfo] {
        let endpoint = Endpoint(
            path: "/tenants/api-keys",
            method: .GET,
            requiresAuth: true
        )
        return try await NetworkClient.shared.request(endpoint)
    }
    
    func createAPIKey(name: String) async throws -> String {
        struct CreateKeyRequest: Codable {
            let name: String
            let description: String?
        }
        
        let payload = CreateKeyRequest(name: name, description: "Created via iOS App")
        
        let endpoint = Endpoint(
            path: "/tenants/api-keys",
            method: .POST,
            body: try? JSONEncoder.lyoEncoder.encode(payload),
            requiresAuth: true
        )
        
        let response: APIKeyCreatedResponse = try await NetworkClient.shared.request(endpoint)
        return response.apiKey
    }
    
    func revokeAPIKey(id: Int) async throws {
        let endpoint = Endpoint(
            path: "/tenants/api-keys/\(id)",
            method: .DELETE,
            requiresAuth: true
        )
        let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
    }
}

// Helper for empty responses
struct EmptyResponse: Codable {}
