import Foundation

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
    
    private var baseURL: String { AppConfig.baseURL }
    
    /// Fetch user context from backend Context Engine
    func fetchContext() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/api/v1/context/current") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = await TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return }
            
            currentContext = try JSONDecoder().decode(UserContext.self, from: data)
            print("🎭 User context loaded: \(currentContext?.persona ?? "unknown")")
        } catch {
            print("⚠️ Failed to fetch context: \(error)")
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
