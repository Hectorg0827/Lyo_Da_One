import Foundation
import os

struct UserContext: Codable {
    let persona: String          // "student", "professional", "hobbyist"
    let timeOfDay: String        // "morning", "afternoon", "evening"
    let focusArea: String?       // detected from behavior
    let suggestedStyle: String   // "exam_prep", "roi_focused", "exploratory"
    let confidence: Double
}

@MainActor
final class UserContextService: ObservableObject {
    static let shared = UserContextService()
    
    @Published var currentContext: UserContext?
    @Published var isLoading: Bool = false
    
    /// Fetch user context from backend Context Engine
    func fetchContext() async {
        isLoading = true
        defer { isLoading = false }
        
        let endpoint = Endpoints.UserContext.current
        
        do {
            currentContext = try await NetworkClient.shared.request(endpoint)
            Log.net.info("🎭 User context loaded: \(self.currentContext?.persona ?? "unknown")")
        } catch {
            Log.net.warning("Failed to fetch context: \(error)")
        }
    }
    
    /// Get adaptive greeting based on context
    var adaptiveGreeting: String {
        guard let ctx = currentContext else { return "Welcome back!" }
        
        switch (ctx.persona, ctx.timeOfDay) {
        case ("student", "morning"):
            return "Good morning! Ready for some focused study? 📚"
        case ("student", "evening"):
            return "Evening study session? Let's make it count! 🌙"
        case ("professional", _):
            return "Welcome back! Let's build skills that matter. 💼"
        case ("hobbyist", _):
            return "Hey there! Ready to explore something new? 🚀"
        default:
            return "Welcome back to Lyo!"
        }
    }
    
    /// Get suggested content style
    var contentStyle: ContentStyle {
        guard let ctx = currentContext else { return .balanced }
        
        switch ctx.suggestedStyle {
        case "exam_prep": return .examFocused
        case "roi_focused": return .professional
        case "exploratory": return .exploratory
        default: return .balanced
        }
    }
}

enum ContentStyle {
    case examFocused      // More quizzes, flashcards
    case professional     // ROI examples, time-efficient
    case exploratory      // Deep dives, curiosity-driven
    case balanced
}
