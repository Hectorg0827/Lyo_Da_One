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
        
        guard let url = URL(string: "\(baseURL)/api/v1/skills/soft-skills") else { return }
        
        var request = URLRequest(url: url)
        if let token = await TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            profile = try JSONDecoder().decode(SoftSkillsProfile.self, from: data)
        } catch {
            print("⚠️ Failed to fetch soft skills: \(error)")
        }
    }
}
