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
        profile = SoftSkillsProfile(
            criticalThinking: SkillScore(score: 0, trend: "stable", evidence: []),
            communication: SkillScore(score: 0, trend: "stable", evidence: []),
            grit: SkillScore(score: 0, trend: "stable", evidence: []),
            creativity: SkillScore(score: 0, trend: "stable", evidence: []),
            collaboration: SkillScore(score: 0, trend: "stable", evidence: []),
            lastUpdated: Date()
        )
    }
}
