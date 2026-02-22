import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isDemoMode: Bool = false
    
    private let repository = LyoRepository.shared
    
    func login(email: String, password: String) async throws {
        let user = try await repository.login(email: email, password: password)
        self.currentUser = user
        self.isAuthenticated = true
        self.isDemoMode = false
    }
    
    func register(email: String, password: String, name: String) async throws {
        let user = try await repository.register(email: email, password: password, name: name)
        self.currentUser = user
        self.isAuthenticated = true
        self.isDemoMode = false
    }
    
    func enterDemoMode() {
        // Create a mock demo user
        let demoUser = User(
            id: -1,
            email: "demo@lyo.app",
            name: "Demo User",
            avatarURL: nil,
            createdAt: Date(),
            level: 5,
            xp: 2500,
            streak: 7,
            totalLessonsCompleted: 15,
            achievements: ["first-lesson", "week-streak", "quiz-master"]
        )
        
        self.currentUser = demoUser
        self.isAuthenticated = true
        self.isDemoMode = true
    }
    
    func signOut() {
        self.currentUser = nil
        self.isAuthenticated = false
        self.isDemoMode = false
    }
    
    // Legacy method for compatibility
    func signIn(username: String? = nil, password: String? = nil) {
        enterDemoMode()
    }
}
