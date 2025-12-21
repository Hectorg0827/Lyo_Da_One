import Foundation
import UIKit
import CoreLocation

// MARK: - Repository Protocols
/// Protocol-based repository layer for testability and dependency injection

// MARK: - Auth Repository Protocol
protocol AuthRepository {
    func login(email: String, password: String) async throws -> User
    func register(email: String, password: String, name: String) async throws -> User
    func logout() async throws
    func refreshToken() async throws -> String
    func getCurrentUser() async throws -> User
    func updateProfile(name: String?, avatar: String?) async throws -> User
}

// MARK: - AI Repository Protocol
protocol AIRepository {
    // Chat & Conversation
    func chat(message: String, provider: AIProvider?, context: ChatContext?) async throws -> ChatResponse
    func mentorConversation(message: String, context: ChatContext?, attachments: [String]?) async throws -> ChatResponse

    // Content Generation
    func generateContent(topic: String, level: SkillLevel, contentType: ContentType) async throws -> GeneratedContent
    func tutorSession(topic: String, question: String, level: String) async throws -> TutorSessionResponse

    // Quiz Generation
    func generateQuiz(topic: String, difficulty: QuizDifficulty, numQuestions: Int) async throws -> Quiz
    func verifyAnswer(question: String, answer: String, correctAnswer: String?) async throws -> AnswerVerification

    // Recommendations
    func getRecommendations(userId: String) async throws -> [Recommendation]
    func searchSimilar(query: String, limit: Int) async throws -> [SearchResult]

    // Streaming
    func streamSession(sessionId: String, callback: @escaping (StreamingResponseManager.StreamEvent) -> Void) async -> StreamingResponseManager
}

// MARK: - Learning Repository Protocol
protocol LearningRepository {
    // Sessions
    func createSession(userId: String, goal: String, variables: [String: Any]) async throws -> LearningSession
    func getSession(sessionId: String) async throws -> LearningSession
    func interruptSession(sessionId: String, message: String) async throws -> InterruptResponse
    func saveCheckpoint(sessionId: String, progress: LessonProgress) async throws

    // Courses & Lessons
    func getCourses() async throws -> [CourseDTO]
    func getCourse(courseId: String) async throws -> CourseDTO
    func getLesson(lessonId: String) async throws -> Lesson
    func completeLesson(lessonId: String, score: Int?) async throws -> RepoLessonCompletion
}

// MARK: - Vision Repository Protocol
protocol VisionRepository {
    func analyzeImage(_ image: UIImage, type: VisionAnalysisType) async throws -> VisionAnalysisResult
    func extractText(from image: UIImage) async throws -> OCRResult
    func solveHomework(_ image: UIImage, subject: String?) async throws -> HomeworkSolution
    func explainDiagram(_ image: UIImage) async throws -> DiagramExplanation
    func analyzeChart(_ image: UIImage) async throws -> ChartAnalysis
    func analyzeCode(_ image: UIImage) async throws -> CodeAnalysis
}

// MARK: - Social Repository Protocol
protocol SocialRepository {
    // Posts
    func getPosts(page: Int, limit: Int, algorithm: String?) async throws -> RepoFeedResponse
    func createPost(content: String, attachments: [String]?) async throws -> RepoPost
    func getPost(postId: String) async throws -> RepoPost
    func deletePost(postId: String) async throws

    // Interactions
    func likePost(postId: String) async throws
    func commentOnPost(postId: String, content: String) async throws -> Comment
    func getComments(postId: String) async throws -> [Comment]
}

// MARK: - Gamification Repository Protocol
protocol GamificationRepository {
    // XP & Progress
    func addXP(userId: String, activity: String, metadata: [String: Any]?) async throws -> XPResult
    func getLeaderboard(type: String, limit: Int) async throws -> [LeaderboardEntryDTO]
    func trackStreak(userId: String) async throws -> StreakResult

    // Achievements
    func getAchievements() async throws -> [Achievement]
    func claimAchievement(achievementId: String) async throws -> Achievement

    // Challenges
    func getChallenges() async throws -> ChallengesResponseDTO
    func completeChallenge(challengeId: String) async throws -> Challenge

    // Battles
    func getBattles() async throws -> [BattleDTO]
    func startBattle(opponentId: String, challengeId: String) async throws -> BattleDTO
    func acceptBattle(battleId: String) async throws -> BattleDTO
}

// MARK: - TTS Repository Protocol
protocol TTSRepository {
    func generate(text: String, voice: TTSVoice, speed: Double, withTimings: Bool) async throws -> TTSResult
    func batchGenerate(texts: [String], voice: TTSVoice) async throws -> [TTSResult]
    func getAudioURL(id: String) async throws -> URL
    func getTimings(id: String) async throws -> [WordTiming]
    func getVoices() async throws -> [Voice]
}

// MARK: - Community Repository Protocol
protocol CommunityRepository {
    // Study Groups
    func getStudyGroups(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [StudyGroup]
    func getStudyGroup(id: String) async throws -> StudyGroup
    func createStudyGroup(group: StudyGroup) async throws -> StudyGroup
    func joinStudyGroup(groupId: String) async throws -> StudyGroup
    func leaveStudyGroup(groupId: String) async throws

    // Events
    func getEvents(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [EducationalEvent]
    func getEvent(id: String) async throws -> EducationalEvent
    func createEvent(event: EducationalEvent) async throws -> EducationalEvent
    func registerForEvent(eventId: String) async throws -> EducationalEvent
    func unregisterFromEvent(eventId: String) async throws

    // Marketplace
    func getListings(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [MarketplaceListing]
    func getListing(id: String) async throws -> MarketplaceListing
    func createListing(listing: MarketplaceListing) async throws -> MarketplaceListing
    func updateListing(listingId: String, status: MarketplaceListing.ListingStatus) async throws -> MarketplaceListing
    func deleteListing(listingId: String) async throws

    // Institutions
    func getInstitutions(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [Institution]
    func getInstitution(id: String) async throws -> Institution
    func searchInstitutions(query: String, location: CLLocationCoordinate2D?) async throws -> [Institution]
}

// MARK: - Supporting Models

struct ChatResponse: Codable {
    let response: String
    let provider: String?
    let cost: Double?
    let tokens: Int?
    let cached: Bool?
    
    // New fields for Mentor Mode
    let responseMode: ResponseMode?
    let quickExplainer: QuickExplainerData?
    let courseProposal: CourseProposalData?
    
    // Handle both "response" and "content" from different backend endpoints
    enum CodingKeys: String, CodingKey {
        case response
        case content  // Alternative key from /api/v1/ai/generate
        case provider
        case primary_ai  // Alternative key
        case cost
        case cost_estimate  // Alternative key
        case tokens
        case tokens_used  // Alternative key
        case cached
        case responseMode = "response_mode"
        case quickExplainer = "quick_explainer"
        case courseProposal = "course_proposal"

        // Chat module (camelCase)
        case responseModeCamel = "responseMode"
        case quickExplainerCamel = "quickExplainer"
        case courseProposalCamel = "courseProposal"
        case cacheHitCamel = "cacheHit"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try "response" first, then "content"
        if let resp = try? container.decode(String.self, forKey: .response) {
            response = resp
        } else if let content = try? container.decode(String.self, forKey: .content) {
            response = content
        } else {
            response = ""
        }
        
        // Provider/cost/tokens are optional across endpoints
        if let providerValue = try? container.decode(String.self, forKey: .provider) {
            provider = providerValue
        } else if let primaryAI = try? container.decode(String.self, forKey: .primary_ai) {
            provider = primaryAI
        } else {
            provider = nil
        }

        if let costValue = try? container.decode(Double.self, forKey: .cost) {
            cost = costValue
        } else if let estimate = try? container.decode(Double.self, forKey: .cost_estimate) {
            cost = estimate
        } else {
            cost = nil
        }

        if let tokensValue = try? container.decode(Int.self, forKey: .tokens) {
            tokens = tokensValue
        } else if let used = try? container.decode(Int.self, forKey: .tokens_used) {
            tokens = used
        } else {
            tokens = nil
        }

        // cached can be either cached or cacheHit
        if let cachedValue = try? container.decode(Bool.self, forKey: .cached) {
            cached = cachedValue
        } else if let cacheHit = try? container.decode(Bool.self, forKey: .cacheHitCamel) {
            cached = cacheHit
        } else {
            cached = nil
        }

        // Mentor fields can be snake_case or camelCase
        responseMode = (try? container.decode(ResponseMode.self, forKey: .responseMode))
            ?? (try? container.decode(ResponseMode.self, forKey: .responseModeCamel))
        quickExplainer = (try? container.decode(QuickExplainerData.self, forKey: .quickExplainer))
            ?? (try? container.decode(QuickExplainerData.self, forKey: .quickExplainerCamel))
        courseProposal = (try? container.decode(CourseProposalData.self, forKey: .courseProposal))
            ?? (try? container.decode(CourseProposalData.self, forKey: .courseProposalCamel))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(response, forKey: .response)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(cost, forKey: .cost)
        try container.encodeIfPresent(tokens, forKey: .tokens)
        try container.encodeIfPresent(cached, forKey: .cached)
        try container.encodeIfPresent(responseMode, forKey: .responseMode)
        try container.encodeIfPresent(quickExplainer, forKey: .quickExplainer)
        try container.encodeIfPresent(courseProposal, forKey: .courseProposal)
    }
    
    init(response: String, provider: String?, cost: Double?, tokens: Int?, cached: Bool?, responseMode: ResponseMode? = nil, quickExplainer: QuickExplainerData? = nil, courseProposal: CourseProposalData? = nil) {
        self.response = response
        self.provider = provider
        self.cost = cost
        self.tokens = tokens
        self.cached = cached
        self.responseMode = responseMode
        self.quickExplainer = quickExplainer
        self.courseProposal = courseProposal
    }
}

struct ChatContextDTO: Codable {
    let courseId: String?
    let lessonId: String?
    let previousMessages: [String]?
    let userLevel: String?
}

struct GeneratedContent: Codable {
    let content: String
    let title: String?
    let summary: String?
    let keyPoints: [String]?
    let provider: String?
}

struct TutorSessionResponse: Codable {
    let sessionId: String
    let response: String
    let nextSteps: [String]?
    let resources: [String]?
}

struct Quiz: Codable {
    let id: String
    let topic: String
    let questions: [QuizQuestion]
    let difficulty: String
    let estimatedTime: Int?

    struct QuizQuestion: Codable {
        let id: String
        let question: String
        let options: [String]?
        let correctAnswer: String
        let explanation: String?
        let type: String // mcq, true_false, short_answer, etc.
    }
}

struct AnswerVerification: Codable {
    let isCorrect: Bool
    let explanation: String
    let correctAnswer: String?
    let score: Int?
}

struct Recommendation: Codable {
    let id: String
    let type: String // course, lesson, topic
    let title: String
    let reason: String
    let confidence: Double?
}

struct SearchResult: Codable {
    let id: String
    let title: String
    let description: String?
    let similarity: Double
    let type: String
}

struct LearningSession: Codable {
    let sessionId: String
    let userId: String
    let goal: String
    let status: String
    let progress: Int?
    let createdAt: Date
}

struct InterruptResponse: Codable {
    let response: String
    let sessionId: String
    let shouldPause: Bool?
}

struct CourseDTO: Codable {
    let id: String
    let title: String
    let description: String?
    let modules: [Module]?
    let difficulty: String?
    let estimatedHours: Int?

    struct Module: Codable {
        let id: String
        let title: String
        let lessons: [Lesson]?
    }
}

struct Lesson: Codable {
    let id: String
    let title: String
    let content: String?
    let duration: Int?
    let order: Int?
}

struct LessonProgressDTO: Codable {
    let lessonId: String
    let progress: Int // 0-100
    let timeSpent: Int // seconds
    let completed: Bool
}

struct RepoLessonCompletion: Codable {
    let lessonId: String
    let score: Int?
    let xpEarned: Int?
    let nextLesson: String?
}

struct RepoFeedResponse: Codable {
    let posts: [RepoPost]
    let nextPage: Int?
    let hasMore: Bool
}

struct RepoPost: Codable, Identifiable {
    let id: String
    let content: String
    let author: UserDTO
    let attachments: [String]?
    var likes: Int
    var comments: Int
    var isLiked: Bool
    let createdAt: Date
}

struct UserDTO: Codable {
    let id: String
    let name: String
    let email: String?
    let avatarURL: String?
    let level: Int?
    let xp: Int?
}

struct Comment: Codable, Identifiable {
    let id: String
    let postId: String
    let author: UserDTO
    let content: String
    let likes: Int
    let createdAt: Date
}

struct XPResult: Codable {
    let xpAwarded: Int
    let totalXP: Int
    let newLevel: Int?
    let leveledUp: Bool
}

struct LeaderboardEntryDTO: Codable {
    let rank: Int
    let user: UserDTO
    let xp: Int
    let streak: Int?
}

struct StreakResult: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: Date
    let xpBonus: Int?
}

struct AchievementDTO: Codable {
    let id: String
    let title: String
    let description: String
    let icon: String?
    let rarity: String
    let unlockedAt: Date?
    let progress: Int?
    let target: Int?
}

struct ChallengeDTO: Codable {
    let id: String
    let title: String
    let description: String
    let type: String // daily, weekly
    let xpReward: Int
    let progress: Int?
    let target: Int?
    let expiresAt: Date?
}

struct ChallengesResponseDTO: Codable {
    let dailyChallenges: [ChallengeDTO]
    let weeklyChallenge: ChallengeDTO?
}

struct BattleDTO: Codable {
    let id: String
    let challenger: UserDTO
    let opponent: UserDTO?
    let challenge: ChallengeDTO
    let status: String // pending, active, completed
    let challengerScore: Int?
    let opponentScore: Int?
    let winner: String?
    let expiresAt: Date?
}

struct TTSResult: Codable {
    let id: String
    let audioURL: String
    let timingsURL: String?
    let duration: Double?
    let cost: Double?
}

struct WordTiming: Codable {
    let word: String
    let startMs: Int
    let endMs: Int

    enum CodingKeys: String, CodingKey {
        case word
        case startMs = "start_ms"
        case endMs = "end_ms"
    }
}

struct Voice: Codable, Identifiable {
    let id: String
    let name: String
    let language: String
    let gender: String?
    let previewURL: String?
}
