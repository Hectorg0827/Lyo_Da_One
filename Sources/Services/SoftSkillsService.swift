import Foundation

struct SoftSkillsProfile: Codable {
    let criticalThinking: SkillScore
    let communication: SkillScore
    let grit: SkillScore
    let creativity: SkillScore
    let collaboration: SkillScore
    let lastUpdated: Date
}

struct SkillScore: Codable {
    let score: Double           // 0-100
    let trend: String           // "improving", "stable", "declining"
    let evidence: [String]      // Recent behaviors that contributed
}

@MainActor
final class SoftSkillsService: ObservableObject {
    static let shared = SoftSkillsService()
    
    @Published var profile: SoftSkillsProfile?
    @Published var isLoading = false
    
    private var baseURL: String { AppConfig.baseURL }
    
    func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/skills/soft-skills",
            method: .get,
            requiresAuth: true
        )
        
        do {
            profile = try await NetworkClient.shared.request(endpoint)
        } catch {
            print("⚠️ Failed to fetch soft skills: \(error)")
        }
    }
}
