import Foundation
import Combine
import OSLog

// MARK: - Gamification Models

struct UserProgress: Codable {
    var totalXP: Int
    var currentLevel: Int
    var currentStreak: Int
    var lastActivityDate: Date?
    var masteries: [String] // IDs of mastered topics
}

struct XPTransaction: Identifiable {
    let id = UUID()
    let amount: Int
    let reason: String
    let date: Date
}

// MARK: - Gamification Service

@MainActor
final class GamificationService: ObservableObject {
    static let shared = GamificationService()
    
    // Published State
    @Published var progress: UserProgress
    @Published var recentTransactions: [XPTransaction] = []
    
    // Constants
    private let xpPerLevel = 1000
    
    private init() {
        // Load from disk
        if let data = UserDefaults.standard.data(forKey: "user_gamification_progress"),
           let savedProgress = try? JSONDecoder().decode(UserProgress.self, from: data) {
            self.progress = savedProgress
        } else {
            self.progress = UserProgress(totalXP: 0, currentLevel: 1, currentStreak: 0, lastActivityDate: nil, masteries: [])
        }
    }
    
    // MARK: - Public Actions
    
    /// Award XP for an action
    func awardXP(amount: Int, reason: String) {
        // Update XP
        progress.totalXP += amount
        
        // Check for Level Up
        let newLevel = (progress.totalXP / xpPerLevel) + 1
        if newLevel > progress.currentLevel {
            progress.currentLevel = newLevel
            Log.gamification.info("🎉 Level Up! New Level: \(newLevel)")
        }
        
        // Update Streak
        updateStreak()
        
        // Log transaction
        let transaction = XPTransaction(amount: amount, reason: reason, date: Date())
        recentTransactions.insert(transaction, at: 0)
        if recentTransactions.count > 10 { recentTransactions.removeLast() }
        
        saveProgress()
        Log.gamification.info("⭐️ Awarded \(amount) XP for: \(reason). Total: \(self.progress.totalXP)")
    }
    
    /// Mark a topic as mastered
    func masterTopic(_ topic: String) {
        if !progress.masteries.contains(topic) {
            progress.masteries.append(topic)
            awardXP(amount: 100, reason: "Mastered Topic: \(topic)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func updateStreak() {
        let now = Date()
        
        guard let lastDate = progress.lastActivityDate else {
            // First activity ever
            progress.currentStreak = 1
            progress.lastActivityDate = now
            return
        }
        
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastDate) {
            // Already active today, update time but keep streak
            progress.lastActivityDate = now
        } else if calendar.isDateInYesterday(lastDate) {
            // Active yesterday, increment streak
            progress.currentStreak += 1
            progress.lastActivityDate = now
        } else {
            // Missed a day (or more), reset streak
            progress.currentStreak = 1
            progress.lastActivityDate = now
        }
    }
    
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: "user_gamification_progress")
        }
    }
}
