
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

// MARK: - SaaS Endpoints

enum SaaSEndpoint: Endpoint {
    case getOrganization
    case getUsageStats
    case listAPIKeys
    case createAPIKey(name: String, description: String?)
    case revokeAPIKey(id: Int)
    
    var path: String {
        switch self {
        case .getOrganization:
            return "/tenants/me"
        case .getUsageStats:
            return "/tenants/usage"
        case .listAPIKeys, .createAPIKey:
            return "/tenants/api-keys"
        case .revokeAPIKey(let id):
            return "/tenants/api-keys/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getOrganization, .getUsageStats, .listAPIKeys:
            return .get
        case .createAPIKey:
            return .post
        case .revokeAPIKey:
            return .delete
        }
    }
    
    var body: Encodable? {
        switch self {
        case .createAPIKey(let name, let description):
            return ["name": name, "description": description ?? "Created via iOS App"]
        default:
            return nil
        }
    }
    
    var requiresAuth: Bool { true }
}

// MARK: - SaaS Service

actor SaaSService {
    static let shared = SaaSService()
    private init() {}
    
    // MARK: - Fetch Organization
    
    func getOrganization() async throws -> OrganizationResponse {
        return try await NetworkClient.shared.request(SaaSEndpoint.getOrganization)
    }
    
    // MARK: - Fetch Usage Stats
    
    func getUsageStats() async throws -> UsageStatsResponse {
        return try await NetworkClient.shared.request(SaaSEndpoint.getUsageStats)
    }
    
    // MARK: - API Key Management
    
    func listAPIKeys() async throws -> [APIKeyInfo] {
        return try await NetworkClient.shared.request(SaaSEndpoint.listAPIKeys)
    }
    
    func createAPIKey(name: String) async throws -> String {
        let response: APIKeyCreatedResponse = try await NetworkClient.shared.request(
            SaaSEndpoint.createAPIKey(name: name, description: nil)
        )
        return response.apiKey
    }
    
    func revokeAPIKey(id: Int) async throws {
        let _: SaaSEmptyResponse = try await NetworkClient.shared.request(SaaSEndpoint.revokeAPIKey(id: id))
    }
}

// Helper for empty responses (scoped to SaaS to avoid conflicts)
private struct SaaSEmptyResponse: Codable {}
