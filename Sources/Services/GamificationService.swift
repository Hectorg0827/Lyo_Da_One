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

    // MARK: - Mastery-honest XP

    /// Awards XP proportional to the actual mastery gained on a skill
    /// (backend Deep Knowledge Tracing delta), not time-on-screen.
    /// Wrong answers earn a small effort award — attempts are how gaps close.
    func awardMasteryXP(skill: String, oldMastery: Double, newMastery: Double, correct: Bool) {
        let delta = newMastery - oldMastery
        if delta > 0 {
            let amount = min(max(Int((delta * 200).rounded()), 5), 50)
            awardXP(amount: amount, reason: "Mastery gained: \(skill)")
        } else if !correct {
            awardXP(amount: 5, reason: "Effort: \(skill)")
        }
        recordQuestProgress(skill: skill, correct: correct)
    }

    // MARK: - Weekly Weakness Quest

    /// A quest generated from the learner's own weaknesses: answer `goal`
    /// checkpoints correctly in those skills this week.
    struct WeeklyQuest: Codable, Equatable {
        var skills: [String]
        var goal: Int
        var progress: Int
        var weekStart: Date
        var completed: Bool

        var title: String { "Close your gaps" }
        var subtitle: String {
            "Answer \(goal) checkpoints on \(skills.prefix(2).joined(separator: " or ")) correctly"
        }
    }

    @Published private(set) var weeklyQuest: WeeklyQuest? = GamificationService.loadQuest()

    private static let questKey = "user_weekly_quest"
    private static func loadQuest() -> WeeklyQuest? {
        guard let data = UserDefaults.standard.data(forKey: questKey) else { return nil }
        return try? JSONDecoder().decode(WeeklyQuest.self, from: data)
    }

    private func saveQuest() {
        if let quest = weeklyQuest, let data = try? JSONEncoder().encode(quest) {
            UserDefaults.standard.set(data, forKey: Self.questKey)
        }
    }

    /// (Re)generates the quest from the mastery profile at the start of each
    /// week. Keeps the current quest mid-week so progress is never wiped.
    func refreshWeeklyQuest(weaknesses: [String]) {
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()

        if let quest = weeklyQuest,
            calendar.isDate(quest.weekStart, inSameDayAs: thisWeekStart) {
            return  // current week's quest is already running
        }

        let targets = weaknesses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
        guard !targets.isEmpty else { return }

        weeklyQuest = WeeklyQuest(
            skills: Array(targets), goal: 5, progress: 0,
            weekStart: thisWeekStart, completed: false
        )
        saveQuest()
        Log.gamification.info("🎯 Weekly quest generated: \(Array(targets).joined(separator: ", "))")
    }

    /// Advances the quest when the learner answers correctly in a target skill.
    private func recordQuestProgress(skill: String, correct: Bool) {
        guard correct, var quest = weeklyQuest, !quest.completed,
            quest.skills.contains(where: { skill.localizedCaseInsensitiveContains($0) || $0.localizedCaseInsensitiveContains(skill) })
        else { return }

        quest.progress += 1
        if quest.progress >= quest.goal {
            quest.completed = true
            awardXP(amount: 150, reason: "Quest complete: \(quest.title)")
        }
        weeklyQuest = quest
        saveQuest()
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
