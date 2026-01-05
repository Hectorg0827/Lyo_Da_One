import Foundation

// MARK: - Challenge Models

struct Challenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let difficulty: Difficulty
    let xpReward: Int
    let timeLimit: Int? // in minutes
    var progress: Double
    let target: Int
    var isCompleted: Bool
    var expiresAt: Date?
    
    init(id: String, title: String, description: String, type: ChallengeType, difficulty: Difficulty = .medium, xpReward: Int, timeLimit: Int? = nil, progress: Double = 0, target: Int = 1, isCompleted: Bool = false, expiresAt: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.difficulty = difficulty
        self.xpReward = xpReward
        self.timeLimit = timeLimit
        self.progress = progress
        self.target = target
        self.isCompleted = isCompleted
        self.expiresAt = expiresAt
    }
    
    enum ChallengeType: String, Codable {
        case daily = "daily"
        case weekly = "weekly"
        case battle = "battle"
        case streak = "streak"
        case quiz = "quiz"
        case learning = "learning"
    }
    
    enum Difficulty: String, Codable {
        case easy
        case medium
        case hard
        case expert
        
        var color: String {
            switch self {
            case .easy: return "green"
            case .medium: return "orange"
            case .hard: return "red"
            case .expert: return "purple"
            }
        }
        
        var icon: String {
            switch self {
            case .easy: return "leaf.fill"
            case .medium: return "flame.fill"
            case .hard: return "bolt.fill"
            case .expert: return "crown.fill"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case type
        case difficulty
        case xpReward = "xp_reward"
        case timeLimit = "time_limit"
        case progress
        case target
        case isCompleted = "is_completed"
        case expiresAt = "expires_at"
    }
}

// MARK: - Streak

struct StreakData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let streakDates: [Date]
    let lastActivityDate: Date?
    let streakFreezeAvailable: Bool
    let weeklyProgress: [Bool]
    
    init(currentStreak: Int, longestStreak: Int, streakDates: [Date] = [], lastActivityDate: Date? = nil, streakFreezeAvailable: Bool = false, weeklyProgress: [Bool] = []) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.streakDates = streakDates
        self.lastActivityDate = lastActivityDate
        self.streakFreezeAvailable = streakFreezeAvailable
        self.weeklyProgress = weeklyProgress
    }
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case streakDates = "streak_dates"
        case lastActivityDate = "last_activity_date"
        case streakFreezeAvailable = "streak_freeze_available"
        case weeklyProgress = "weekly_progress"
    }
}

// Backend Streak Models
struct UserStreaks: Codable {
    let streaks: [StreakInfo]
}

struct StreakInfo: Codable {
    let type: String
    let currentCount: Int
    let longestCount: Int
    let lastUpdated: Date?
    
    enum CodingKeys: String, CodingKey {
        case type
        case currentCount = "current_count"
        case longestCount = "longest_count"
        case lastUpdated = "last_updated"
    }
}

struct StreakUpdateResponse: Codable {
    let type: String
    let currentCount: Int
    let longestCount: Int
    let updated: Bool
    
    enum CodingKeys: String, CodingKey {
        case type
        case currentCount = "current_count"
        case longestCount = "longest_count"
        case updated
    }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Identifiable, Codable {
    let id: String
    let rank: Int
    let userId: String
    let userName: String
    let avatarURL: String?
    let xp: Int
    let level: Int
    let badge: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case rank
        case userId = "user_id"
        case userName = "user_name"
        case avatarURL = "avatar_url"
        case xp
        case level
        case badge
    }
}

// MARK: - Battle

struct Battle: Identifiable, Codable {
    let id: String
    let opponentId: String
    let opponentName: String
    let opponentAvatar: String?
    let challengeId: String
    let status: BattleStatus
    let myScore: Int
    let opponentScore: Int
    let endsAt: Date?
    
    enum BattleStatus: String, Codable {
        case pending
        case active
        case completed
        case expired
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case opponentId = "opponent_id"
        case opponentName = "opponent_name"
        case opponentAvatar = "opponent_avatar"
        case challengeId = "challenge_id"
        case status
        case myScore = "my_score"
        case opponentScore = "opponent_score"
        case endsAt = "ends_at"
    }
}

// MARK: - Achievement

struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let xpReward: Int
    let target: Int
    var isUnlocked: Bool
    var unlockedAt: Date?
    let requirement: Int
    var progress: Int
    
    init(id: String, name: String, title: String? = nil, description: String, icon: String = "star.fill", category: AchievementCategory = .learning, xpReward: Int = 100, target: Int = 1, isUnlocked: Bool = false, unlockedAt: Date? = nil, requirement: Int = 1, progress: Int = 0) {
        self.id = id
        self.name = name
        self.title = title ?? name
        self.description = description
        self.icon = icon
        self.category = category
        self.xpReward = xpReward
        self.target = target
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
        self.requirement = requirement
        self.progress = progress
    }
    
    enum AchievementCategory: String, Codable {
        case learning
        case streak
        case battle
        case social
        case special
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case description
        case icon
        case category
        case xpReward = "xp_reward"
        case target
        case isUnlocked = "is_unlocked"
        case unlockedAt = "unlocked_at"
        case requirement
        case progress
    }
}

// MARK: - User Achievement (progress tracking)

struct UserAchievement: Identifiable, Codable {
    let id: String
    let achievementId: String
    let achievement: Achievement?
    let progress: Int
    let isCompleted: Bool
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case achievementId = "achievement_id"
        case achievement
        case progress
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
    }
}

struct AchievementProgress: Codable {
    let achievementId: String
    let currentProgress: Int
    let targetProgress: Int
    let isCompleted: Bool
    let justUnlocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case achievementId = "achievement_id"
        case currentProgress = "current_progress"
        case targetProgress = "target_progress"
        case isCompleted = "is_completed"
        case justUnlocked = "just_unlocked"
    }
}

// MARK: - XP Models

struct XPAwardResponse: Codable {
    let xpAwarded: Int
    let totalXP: Int
    let levelUp: Bool
    let newLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case xpAwarded = "xp_awarded"
        case totalXP = "total_xp"
        case levelUp = "level_up"
        case newLevel = "new_level"
    }
}

struct XPSummary: Codable {
    let totalXP: Int
    let currentLevel: Int
    let xpToNextLevel: Int
    let xpProgress: Double
    let recentActivity: [XPActivity]?
    
    enum CodingKeys: String, CodingKey {
        case totalXP = "total_xp"
        case currentLevel = "current_level"
        case xpToNextLevel = "xp_to_next_level"
        case xpProgress = "xp_progress"
        case recentActivity = "recent_activity"
    }
}

struct XPActivity: Codable {
    let activity: String
    let amount: Int
    let timestamp: Date
}

// MARK: - Level

struct UserLevel: Codable, Equatable {
    let level: Int
    let currentXP: Int
    let requiredXP: Int
    let progress: Double
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case level
        case currentXP = "current_xp"
        case requiredXP = "required_xp"
        case progress
        case title
    }
}

// MARK: - Leaderboard Rank

struct LeaderboardRank: Codable {
    let rank: Int
    let totalUsers: Int
    let percentile: Double
    let xp: Int
    
    enum CodingKeys: String, CodingKey {
        case rank
        case totalUsers = "total_users"
        case percentile
        case xp
    }
}

// MARK: - Badges

struct UserBadge: Identifiable, Codable {
    let id: String
    let badgeId: String
    let name: String
    let description: String
    let icon: String
    let rarity: BadgeRarity
    let isEquipped: Bool
    let earnedAt: Date
    
    enum BadgeRarity: String, Codable {
        case common
        case uncommon
        case rare
        case epic
        case legendary
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case badgeId = "badge_id"
        case name
        case description
        case icon
        case rarity
        case isEquipped = "is_equipped"
        case earnedAt = "earned_at"
    }
}

// MARK: - Gamification Stats & Overview

struct GamificationStats: Codable {
    let totalXP: Int
    let level: Int
    let rank: Int?
    let achievementsUnlocked: Int
    let totalAchievements: Int
    let badgesEarned: Int
    let currentStreak: Int
    let longestStreak: Int
    let lessonsCompleted: Int
    let quizzesTaken: Int
    
    enum CodingKeys: String, CodingKey {
        case totalXP = "total_xp"
        case level
        case rank
        case achievementsUnlocked = "achievements_unlocked"
        case totalAchievements = "total_achievements"
        case badgesEarned = "badges_earned"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lessonsCompleted = "lessons_completed"
        case quizzesTaken = "quizzes_taken"
    }
}

struct GamificationOverview: Codable {
    let xpSummary: XPSummary?
    let level: UserLevel?
    let streaks: UserStreaks?
    let recentAchievements: [Achievement]?
    let leaderboardRank: LeaderboardRank?
    
    enum CodingKeys: String, CodingKey {
        case xpSummary = "xp_summary"
        case level
        case streaks
        case recentAchievements = "recent_achievements"
        case leaderboardRank = "leaderboard_rank"
    }
}
