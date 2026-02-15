import Foundation
import SwiftUI
import os

@MainActor
class ChallengesViewModel: ObservableObject {
    // MARK: - Published State
    @Published var dailyChallenges: [Challenge] = []
    @Published var weeklyChallenge: Challenge?
    @Published var streakData: StreakData?
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var achievements: [Achievement] = []
    @Published var myAchievements: [UserAchievement] = []
    @Published var selectedTab: ChallengeTab = .daily
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Gamification stats
    @Published var xpSummary: XPSummary?
    @Published var userLevel: UserLevel?
    @Published var myBadges: [UserBadge] = []
    @Published var gamificationStats: GamificationStats?
    @Published var myLeaderboardRank: LeaderboardRank?
    
    enum ChallengeTab: String, CaseIterable {
        case daily = "Daily"
        case leaderboard = "Leaderboard"
        case achievements = "Achievements"
        case stats = "Stats"
    }
    
    private let repository = LyoRepository.shared
    
    // MARK: - Load Data
    
    func loadChallenges() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load challenges (constructed from achievements + streaks)
            let challengesResponse = try await repository.getChallenges()
            self.dailyChallenges = challengesResponse.dailyChallenges
            self.weeklyChallenge = challengesResponse.weeklyChallenge
            
            // Load streak data
            self.streakData = try await repository.getStreakData()
            
            // Load leaderboard
            self.leaderboard = try await repository.getLeaderboard(type: "xp", limit: 50)
            
            // Load achievements
            self.achievements = try await repository.getAchievements()
            
            Log.social.info("Challenge data loaded successfully")
        } catch {
            Log.social.error("Failed to load challenge data: \(error.localizedDescription)")
            errorMessage = "Failed to load challenges. Using offline data."
            
            // Load mock data as fallback
            loadMockData()
        }
        
        isLoading = false
    }
    
    func loadGamificationData() async {
        do {
            // Load XP summary
            self.xpSummary = try await repository.getXPSummary()
            
            // Load user level
            self.userLevel = try await repository.getUserLevel()
            
            // Load my achievements with progress
            self.myAchievements = try await repository.getMyAchievements()
            
            // Load badges
            self.myBadges = try await repository.getMyBadges()
            
            // Load stats
            self.gamificationStats = try await repository.getGamificationStats()
            
            // Load my rank
            self.myLeaderboardRank = try await repository.getMyLeaderboardRank(type: "xp")
            
            Log.social.info("Gamification data loaded successfully")
        } catch {
            Log.social.warning("Failed to load gamification data: \(error.localizedDescription)")
        }
    }
    
    func updateStreak() async {
        do {
            let response = try await repository.updateStreak(type: "daily_login")
            Log.social.info("Streak updated: \(response.currentCount) days")
            
            // Refresh streak data
            self.streakData = try await repository.getStreakData()
        } catch {
            Log.social.warning("Failed to update streak: \(error.localizedDescription)")
        }
    }
    
    private func loadMockData() {
        // Mock daily challenges
        self.dailyChallenges = [
            Challenge(id: "1", title: "Complete 3 Lessons", description: "Finish any 3 lessons today", type: .daily, xpReward: 100, target: 3),
            Challenge(id: "2", title: "Quiz Master", description: "Score 80%+ on a quiz", type: .daily, xpReward: 75, target: 1),
            Challenge(id: "3", title: "Study Session", description: "Study for 30 minutes", type: .daily, xpReward: 50, target: 30)
        ]
        
        // Mock weekly challenge
        self.weeklyChallenge = Challenge(
            id: "weekly1",
            title: "Weekly Streak",
            description: "Log in 7 days in a row",
            type: .weekly,
            xpReward: 500,
            target: 7
        )
        
        // Mock streak
        self.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 12,
            lastActivityDate: Date()
        )
        
        // Mock leaderboard
        self.leaderboard = [
            LeaderboardEntry(id: "1", rank: 1, userId: "u1", userName: "Alice", avatarURL: nil, xp: 5000, level: 15, badge: "🏆"),
            LeaderboardEntry(id: "2", rank: 2, userId: "u2", userName: "Bob", avatarURL: nil, xp: 4500, level: 14, badge: "🥈"),
            LeaderboardEntry(id: "3", rank: 3, userId: "u3", userName: "Charlie", avatarURL: nil, xp: 4000, level: 13, badge: "🥉")
        ]
        
        // Mock achievements
        self.achievements = [
            Achievement(id: "a1", name: "First Steps", description: "Complete your first lesson", xpReward: 50, isUnlocked: true),
            Achievement(id: "a2", name: "Quiz Whiz", description: "Complete 10 quizzes", xpReward: 100, target: 10, progress: 5),
            Achievement(id: "a3", name: "Dedicated Learner", description: "Maintain a 7-day streak", xpReward: 200, target: 7)
        ]
    }
    
    // MARK: - Challenge Actions
    
    func startChallenge(_ challenge: Challenge) {
        Log.social.info("Starting challenge: \(challenge.title)")
        // Navigate to challenge detail or start directly
    }
    
    func completeChallenge(_ challenge: Challenge) async {
        do {
            let updatedChallenge = try await repository.completeChallenge(id: challenge.id)
            if let index = dailyChallenges.firstIndex(where: { $0.id == challenge.id }) {
                dailyChallenges[index] = updatedChallenge
            }
            
            // Award XP for completion
            let _ = try await repository.awardXP(amount: challenge.xpReward, activity: "challenge_complete", metadata: ["challenge_id": challenge.id])
            
            Log.social.info("Challenge completed: \(challenge.title)")
        } catch {
            Log.social.error("Error completing challenge: \(error.localizedDescription)")
            errorMessage = "Failed to complete challenge. Please try again."
        }
    }
    
    // MARK: - Badge Actions
    
    func equipBadge(_ badge: UserBadge) async {
        do {
            let updatedBadge = try await repository.equipBadge(id: badge.id, equipped: !badge.isEquipped)
            if let index = myBadges.firstIndex(where: { $0.id == badge.id }) {
                myBadges[index] = updatedBadge
            }
            Log.social.info("Badge \(badge.isEquipped ? "unequipped" : "equipped")")
        } catch {
            Log.social.error("Error updating badge: \(error.localizedDescription)")
        }
    }
}
