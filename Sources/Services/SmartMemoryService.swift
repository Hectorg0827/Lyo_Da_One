import Foundation

struct LearningMemory: Codable {
    let struggles: [StruggleItem]
    let masteredConcepts: [String]
    let preferences: LearningPreferences
    let lastSessionSummary: String?
}

struct StruggleItem: Codable, Identifiable {
    let id: String
    let topic: String
    let firstOccurred: Date
    let frequency: Int
    let resolved: Bool
}

struct LearningPreferences: Codable {
    let preferredLessonLength: Int     // minutes
    let bestTimeOfDay: String?
    let learningPace: String           // "fast", "moderate", "thorough"
    let preferredExampleTypes: [String]
}

@MainActor
final class SmartMemoryService: ObservableObject {
    static let shared = SmartMemoryService()
    
    @Published var memory: LearningMemory?
    @Published var proactiveHint: String?
    
    private var baseURL: String { AppConfig.baseURL }
    
    /// Fetch user's learning memory from backend
    func fetchMemory() async {
        guard let url = URL(string: "\(baseURL)/api/v1/memory/summary") else { return }
        
        var request = URLRequest(url: url)
        if let token = await TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            memory = try JSONDecoder().decode(LearningMemory.self, from: data)
            generateProactiveHint()
        } catch {
            print("⚠️ Failed to fetch memory: \(error)")
        }
    }
    
    /// Generate a proactive hint based on past struggles
    private func generateProactiveHint() {
        guard let memory = memory,
              let recentStruggle = memory.struggles.first(where: { !$0.resolved }) else {
            proactiveHint = nil
            return
        }
        
        proactiveHint = "💡 You struggled with \(recentStruggle.topic) before. Want a quick refresher?"
    }
    
    /// Get context injection for AI prompts
    func getMemoryContext() -> String? {
        guard let memory = memory else { return nil }
        
        var context = "User Learning Context:\n"
        
        if !memory.struggles.isEmpty {
            let struggles = memory.struggles.prefix(3).map { $0.topic }.joined(separator: ", ")
            context += "- Past struggles: \(struggles)\n"
        }
        
        if !memory.masteredConcepts.isEmpty {
            let mastered = memory.masteredConcepts.prefix(3).joined(separator: ", ")
            context += "- Mastered: \(mastered)\n"
        }
        
        context += "- Preferred pace: \(memory.preferences.learningPace)\n"
        
        return context
    }
}
