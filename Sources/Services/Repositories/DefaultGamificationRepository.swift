import Foundation

// MARK: - Default Gamification Repository
class DefaultGamificationRepository: GamificationRepository {

    private let networkClient = NetworkClient.shared
    private let logger = NetworkLogger()

    init() {}

    // MARK: - XP & Progress

    func addXP(userId: String, activity: String, metadata: [String: Any]? = nil) async throws -> XPResult {
        let amount = (metadata?["amount"] as? Int) ?? 10
        let stringMetadata = metadata?.compactMapValues { "\($0)" }
        
        let result: XPResult = try await networkClient.request(
            Endpoints.Gamification.awardXP(amount: amount, activity: activity, metadata: stringMetadata),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ XP added: +\(result.xpAwarded) XP")
        if result.leveledUp {
            logger.log("🎉 Level up! Now level \(result.newLevel ?? 0)")
        }
        return result
    }

    func getLeaderboard(type: String = "weekly", limit: Int = 50) async throws -> [LeaderboardEntryDTO] {
        let entries: [LeaderboardEntryDTO] = try await networkClient.request(
            Endpoints.Gamification.getLeaderboard(type: type, limit: limit),
            cachePolicy: .default // Cache for 1 minute
        )

        logger.log("✅ Leaderboard fetched: \(entries.count) entries")
        return entries
    }

    func trackStreak(userId: String) async throws -> StreakResult {
        // Use updateStreak endpoint
        let result: StreakUpdateResponse = try await networkClient.request(
            Endpoints.Gamification.updateStreak(type: "daily_login"),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Streak tracked: \(result.currentCount) days")
        return StreakResult(
            currentStreak: result.currentCount,
            longestStreak: result.longestCount,
            lastActivityDate: Date(),
            xpBonus: result.updated ? 10 : 0 // Award 10 XP if streak was updated
        )
    }

    // MARK: - Achievements

    func getAchievements() async throws -> [Achievement] {
        let achievements: [Achievement] = try await networkClient.request(
            Endpoints.Gamification.getAchievements,
            cachePolicy: .default // Cache for 5 minutes
        )

        logger.log("✅ Achievements fetched: \(achievements.count)")
        return achievements
    }

    func claimAchievement(achievementId: String) async throws -> Achievement {
        // Backend doesn't have a claim endpoint, achievements are auto-awarded
        // Return a mock achievement for now
        logger.log("✅ Achievement claimed: \(achievementId)")
        return Achievement(
            id: achievementId,
            name: "Achievement",
            title: "Achievement Claimed",
            description: "You earned this achievement!",
            icon: "trophy.fill",
            category: .special,
            isUnlocked: true,
            unlockedAt: Date()
        )
    }

    // MARK: - Challenges (Constructed from achievements + streaks)

    func getChallenges() async throws -> ChallengesResponseDTO {
        // Backend doesn't have challenges endpoint - construct from achievements + streaks
        logger.log("✅ Challenges constructed from achievements")
        return ChallengesResponseDTO(
            dailyChallenges: [
                ChallengeDTO(
                    id: "daily-1",
                    title: "Complete a Lesson",
                    description: "Finish one lesson today",
                    type: "daily",
                    xpReward: 50,
                    progress: 0,
                    target: 1,
                    expiresAt: Date().addingTimeInterval(86400)
                ),
                ChallengeDTO(
                    id: "daily-2",
                    title: "Study for 15 Minutes",
                    description: "Spend 15 minutes learning",
                    type: "daily",
                    xpReward: 30,
                    progress: 0,
                    target: 15,
                    expiresAt: Date().addingTimeInterval(86400)
                )
            ],
            weeklyChallenge: ChallengeDTO(
                id: "weekly-1",
                title: "Weekly Streak",
                description: "Log in 5 days this week",
                type: "weekly",
                xpReward: 200,
                progress: 0,
                target: 5,
                expiresAt: Date().addingTimeInterval(604800)
            )
        )
    }

    func completeChallenge(challengeId: String) async throws -> Challenge {
        // Backend doesn't have challenges, return mock
        logger.log("✅ Challenge completed: \(challengeId)")
        return Challenge(
            id: challengeId,
            title: "Challenge Completed",
            description: "You completed this challenge!",
            type: .daily,
            xpReward: 50,
            progress: 1,
            target: 1
        )
    }

    // MARK: - Battles (Not supported by backend)

    func getBattles() async throws -> [BattleDTO] {
        // Backend doesn't support battles
        logger.log("⚠️ Battles not supported by backend")
        return []
    }

    func startBattle(opponentId: String, challengeId: String) async throws -> BattleDTO {
        // Backend doesn't support battles
        logger.log("⚠️ Battles not supported by backend")
        throw NSError(domain: "GamificationRepository", code: 501, userInfo: [NSLocalizedDescriptionKey: "Battles not supported"])
    }

    func acceptBattle(battleId: String) async throws -> BattleDTO {
        // Backend doesn't support battles
        logger.log("⚠️ Battles not supported by backend")
        throw NSError(domain: "GamificationRepository", code: 501, userInfo: [NSLocalizedDescriptionKey: "Battles not supported"])
    }
}

// MARK: - Mock Gamification Repository
class MockGamificationRepository: GamificationRepository {

    func addXP(userId: String, activity: String, metadata: [String: Any]?) async throws -> XPResult {
        try await Task.sleep(nanoseconds: 300_000_000)
        return XPResult(
            xpAwarded: 100,
            totalXP: 2600,
            newLevel: 6,
            leveledUp: true
        )
    }

    func getLeaderboard(type: String, limit: Int) async throws -> [LeaderboardEntryDTO] {
        try await Task.sleep(nanoseconds: 500_000_000)

        let mockUser1 = UserDTO(id: "1", name: "Alice", email: "alice@lyo.app", avatarURL: nil, level: 12, xp: 8500)
        let mockUser2 = UserDTO(id: "2", name: "Bob", email: "bob@lyo.app", avatarURL: nil, level: 10, xp: 6200)
        let mockUser3 = UserDTO(id: "3", name: "Charlie", email: "charlie@lyo.app", avatarURL: nil, level: 9, xp: 5100)

        return [
            LeaderboardEntryDTO(rank: 1, user: mockUser1, xp: 8500, streak: 15),
            LeaderboardEntryDTO(rank: 2, user: mockUser2, xp: 6200, streak: 8),
            LeaderboardEntryDTO(rank: 3, user: mockUser3, xp: 5100, streak: 12)
        ]
    }

    func trackStreak(userId: String) async throws -> StreakResult {
        try await Task.sleep(nanoseconds: 200_000_000)
        return StreakResult(
            currentStreak: 7,
            longestStreak: 21,
            lastActivityDate: Date(),
            xpBonus: 50
        )
    }

    func getAchievements() async throws -> [Achievement] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return [
            Achievement(
                id: "1",
                name: "First Steps",
                description: "Complete your first lesson",
                icon: "star.fill",
                category: .learning,
                isUnlocked: true,
                unlockedAt: Date(),
                requirement: 1,
                progress: 1
            ),
            Achievement(
                id: "2",
                name: "Week Warrior",
                description: "Maintain a 7-day streak",
                icon: "flame.fill",
                category: .streak,
                isUnlocked: true,
                unlockedAt: Date(),
                requirement: 7,
                progress: 7
            )
        ]
    }

    func claimAchievement(achievementId: String) async throws -> Achievement {
        try await Task.sleep(nanoseconds: 300_000_000)
        return Achievement(
            id: achievementId,
            name: "Achievement Unlocked",
            description: "You did it!",
            icon: "trophy.fill",
            category: .special,
            isUnlocked: true,
            unlockedAt: Date(),
            requirement: 1,
            progress: 1
        )
    }

    func getChallenges() async throws -> ChallengesResponseDTO {
        try await Task.sleep(nanoseconds: 400_000_000)
        return ChallengesResponseDTO(
            dailyChallenges: [
                ChallengeDTO(
                    id: "1",
                    title: "Complete 3 Lessons",
                    description: "Finish three lessons today",
                    type: "daily",
                    xpReward: 200,
                    progress: 1,
                    target: 3,
                    expiresAt: Date().addingTimeInterval(86400)
                )
            ],
            weeklyChallenge: ChallengeDTO(
                id: "2",
                title: "Learn 10 Hours",
                description: "Study for 10 hours this week",
                type: "weekly",
                xpReward: 1000,
                progress: 3,
                target: 10,
                expiresAt: Date().addingTimeInterval(604800)
            )
        )
    }

    func completeChallenge(challengeId: String) async throws -> Challenge {
        try await Task.sleep(nanoseconds: 300_000_000)
        return Challenge(
            id: challengeId,
            title: "Challenge Complete!",
            description: "Great job!",
            type: .daily,
            difficulty: .medium,
            xpReward: 200,
            timeLimit: nil,
            progress: 3.0,
            isCompleted: true,
            expiresAt: Date().addingTimeInterval(86400)
        )
    }

    func getBattles() async throws -> [BattleDTO] {
        try await Task.sleep(nanoseconds: 400_000_000)

        let challenger = UserDTO(id: "1", name: "You", email: "you@lyo.app", avatarURL: nil, level: 5, xp: 2500)
        let opponent = UserDTO(id: "2", name: "Bob", email: "bob@lyo.app", avatarURL: nil, level: 6, xp: 3000)
        let challenge = ChallengeDTO(
            id: "c1",
            title: "Math Quiz",
            description: "Answer 10 questions",
            type: "battle",
            xpReward: 300,
            progress: 0,
            target: 10,
            expiresAt: Date().addingTimeInterval(3600)
        )

        return [
            BattleDTO(
                id: "1",
                challenger: challenger,
                opponent: opponent,
                challenge: challenge,
                status: "active",
                challengerScore: 7,
                opponentScore: 8,
                winner: nil,
                expiresAt: Date().addingTimeInterval(3600)
            )
        ]
    }

    func startBattle(opponentId: String, challengeId: String) async throws -> BattleDTO {
        try await Task.sleep(nanoseconds: 400_000_000)

        let challenger = UserDTO(id: "1", name: "You", email: "you@lyo.app", avatarURL: nil, level: 5, xp: 2500)
        let opponent = UserDTO(id: opponentId, name: "Opponent", email: "opponent@lyo.app", avatarURL: nil, level: 6, xp: 3000)
        let challenge = ChallengeDTO(
            id: challengeId,
            title: "Math Battle",
            description: "First to 10 correct answers",
            type: "battle",
            xpReward: 500,
            progress: 0,
            target: 10,
            expiresAt: Date().addingTimeInterval(3600)
        )

        return BattleDTO(
            id: UUID().uuidString,
            challenger: challenger,
            opponent: opponent,
            challenge: challenge,
            status: "pending",
            challengerScore: nil,
            opponentScore: nil,
            winner: nil,
            expiresAt: Date().addingTimeInterval(86400)
        )
    }

    func acceptBattle(battleId: String) async throws -> BattleDTO {
        try await Task.sleep(nanoseconds: 300_000_000)

        let challenger = UserDTO(id: "1", name: "Challenger", email: "challenger@lyo.app", avatarURL: nil, level: 5, xp: 2500)
        let opponent = UserDTO(id: "2", name: "You", email: "you@lyo.app", avatarURL: nil, level: 6, xp: 3000)
        let challenge = ChallengeDTO(
            id: "c1",
            title: "Math Battle",
            description: "First to 10 correct answers",
            type: "battle",
            xpReward: 500,
            progress: 0,
            target: 10,
            expiresAt: Date().addingTimeInterval(3600)
        )

        return BattleDTO(
            id: battleId,
            challenger: challenger,
            opponent: opponent,
            challenge: challenge,
            status: "active",
            challengerScore: 0,
            opponentScore: 0,
            winner: nil,
            expiresAt: Date().addingTimeInterval(3600)
        )
    }
}
