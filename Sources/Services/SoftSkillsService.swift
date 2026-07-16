import Foundation
import os

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
    
    func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        let endpoint = Endpoints.Skills.softSkills
        
        do {
            profile = try await NetworkClient.shared.request(endpoint)
        } catch {
            Log.net.warning("Failed to fetch soft skills: \(error)")
        }
    }
}
