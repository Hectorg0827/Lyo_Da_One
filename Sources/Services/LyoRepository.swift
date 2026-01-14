import Foundation
import CoreLocation

class LyoRepository: ObservableObject {
    static let shared = LyoRepository()
    
    // Use centralized configuration
    private var baseURL: String { AppConfig.baseURL }
    
    private var authToken: String?
    private let tokenManager = TokenManager.shared
    
    private init() {}
    
    // MARK: - Auth
    
    func login(email: String, password: String) async throws -> User {
        let response: LoginResponse = try await NetworkClient.shared.request(Endpoints.Auth.login(email: email, password: password))
        
        self.authToken = response.accessToken
        
        // Persist token to KeyChain for auto-login across app restarts
        await tokenManager.setToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            await tokenManager.setRefreshToken(refreshToken)
        }
        await tokenManager.setUserId(String(response.user.id))
        if let tenantId = response.tenantId {
            await tokenManager.setTenantId(tenantId)
        }
        
        return response.user
    }

    func loginWithGoogle(idToken: String) async throws -> User {
        let response: LoginResponse = try await NetworkClient.shared.request(Endpoints.Auth.firebase(idToken: idToken))
        
        self.authToken = response.accessToken
        
        // Persist token to KeyChain for auto-login across app restarts
        await tokenManager.setToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            await tokenManager.setRefreshToken(refreshToken)
        }
        await tokenManager.setUserId(String(response.user.id))
        if let tenantId = response.tenantId {
            await tokenManager.setTenantId(tenantId)
        }
        
        return response.user
    }
    
    func register(email: String, password: String, name: String) async throws -> User {
        let response: LoginResponse = try await NetworkClient.shared.request(Endpoints.Auth.register(email: email, password: password, name: name))
        
        self.authToken = response.accessToken
        
        // Persist token to KeyChain for auto-login across app restarts
        await tokenManager.setToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            await tokenManager.setRefreshToken(refreshToken)
        }
        await tokenManager.setUserId(String(response.user.id))
        if let tenantId = response.tenantId {
            await tokenManager.setTenantId(tenantId)
        }
        
        return response.user
    }
    
    // MARK: - Leo AI Chat
    
    func sendLyoMessage(message: String, attachmentIds: [String]? = nil, context: ChatContext? = nil) async throws -> LyoChatResponse {
        return try await NetworkClient.shared.request(
            Endpoints.AI.mentorChat(message: message, attachments: attachmentIds, context: context)
        )
    }
    
    func getCourseCards() async throws -> [CourseCard] {
        return try await get(endpoint: "/api/v1/learning/courses")
    }

    func getChatCourses(topic: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> [ChatCourseRead] {
        var endpoint = "/api/v1/chat/courses?limit=\(limit)&offset=\(offset)"
        if let topic, !topic.isEmpty {
            let encoded = topic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? topic
            endpoint += "&topic=\(encoded)"
        }
        return try await get(endpoint: endpoint)
    }
    
    func uploadFile(url: URL) async throws -> MessageAttachment {
        let data = try Data(contentsOf: url)
        let filename = url.lastPathComponent
        let mimetype = mimeType(for: url)
        
        return try await NetworkClient.shared.upload(
            Endpoints.Files.upload,
            data: data,
            fileName: filename,
            mimeType: mimetype
        )
    }
    
    // MARK: - Generic Helpers
    
    private func get<T: Codable>(endpoint: String) async throws -> T {
        let dynamicEndpoint = DynamicEndpoint(urlString: endpoint, method: .get)
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
    
    private func post<T: Codable>(endpoint: String, body: [String: Any]? = nil) async throws -> T {
        let encodableBody = body.map { AnyEncodable(value: $0) }
        let dynamicEndpoint = DynamicEndpoint(urlString: endpoint, method: .post, body: encodableBody)
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
    
    private func put<T: Codable>(endpoint: String, body: [String: Any]? = nil) async throws -> T {
        let encodableBody = body.map { AnyEncodable(value: $0) }
        let dynamicEndpoint = DynamicEndpoint(urlString: endpoint, method: .put, body: encodableBody)
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
    
    private func delete<T: Codable>(endpoint: String) async throws -> T {
        let dynamicEndpoint = DynamicEndpoint(urlString: endpoint, method: .delete)
        return try await NetworkClient.shared.request(dynamicEndpoint)
    }
    
    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "doc", "docx": return "application/msword"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "mp4": return "video/mp4"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }
    
    // MARK: - Challenges / Gamification
    
    // Note: Backend doesn't have /gamification/challenges endpoint
    // We construct challenges from achievements + streaks
    func getChallenges() async throws -> ChallengesResponse {
        // Fetch achievements to build daily challenges
        let achievements: [Achievement] = try await get(endpoint: "/gamification/achievements")
        let streaks: UserStreaks = try await get(endpoint: "/gamification/streaks")
        
        // Convert first 3 achievements into daily challenges
        let dailyChallenges = achievements.prefix(3).map { achievement in
            Challenge(
                id: achievement.id,
                title: achievement.name,
                description: achievement.description,
                type: .daily,
                xpReward: achievement.xpReward,
                progress: 0,
                target: achievement.target,
                isCompleted: false,
                expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())
            )
        }
        
        // Use longest streak as weekly challenge basis if available
        let weeklyChallenge: Challenge? = streaks.streaks.first.map { streak in
            Challenge(
                id: "weekly_streak",
                title: "Weekly Streak Master",
                description: "Maintain your \(streak.type) streak for 7 days",
                type: .weekly,
                xpReward: 500,
                progress: Double(streak.currentCount),
                target: 7,
                isCompleted: streak.currentCount >= 7,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
            )
        }
        
        return ChallengesResponse(dailyChallenges: Array(dailyChallenges), weeklyChallenge: weeklyChallenge)
    }
    
    func completeChallenge(id: String) async throws -> Challenge {
        // Check achievement progress instead
        let _: EmptyResponse = try await post(endpoint: "/gamification/achievements/\(id)/check", body: [:])
        
        // Return a mock completed challenge
        return Challenge(
            id: id,
            title: "Challenge",
            description: "Completed",
            type: .daily,
            xpReward: 100,
            progress: 1,
            target: 1,
            isCompleted: true,
            expiresAt: nil
        )
    }
    
    // MARK: - XP
    
    func awardXP(amount: Int, activity: String, metadata: [String: String]? = nil) async throws -> XPAwardResponse {
        var body: [String: Any] = [
            "amount": amount,
            "activity": activity
        ]
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        return try await post(endpoint: "/gamification/xp/award", body: body)
    }
    
    func getXPSummary() async throws -> XPSummary {
        return try await get(endpoint: "/gamification/xp/summary")
    }
    
    // MARK: - Level
    
    func getUserLevel() async throws -> UserLevel {
        return try await get(endpoint: "/gamification/level")
    }
    
    // MARK: - Streaks
    
    func getStreakData() async throws -> StreakData {
        let streaks: UserStreaks = try await get(endpoint: "/gamification/streaks")
        // Convert to legacy StreakData format
        let currentStreak = streaks.streaks.first(where: { $0.type == "daily_login" })
        return StreakData(
            currentStreak: currentStreak?.currentCount ?? 0,
            longestStreak: currentStreak?.longestCount ?? 0,
            lastActivityDate: currentStreak?.lastUpdated ?? Date(),
            streakFreezeAvailable: false,
            weeklyProgress: Array(repeating: true, count: min(currentStreak?.currentCount ?? 0, 7))
        )
    }
    
    func updateStreak(type: String) async throws -> StreakUpdateResponse {
        return try await post(endpoint: "/gamification/streaks/\(type)/update", body: [:])
    }
    
    // MARK: - Leaderboard
    
    func getLeaderboard(type: String = "xp", limit: Int = 50) async throws -> [LeaderboardEntry] {
        return try await get(endpoint: "/gamification/leaderboards/\(type)?limit=\(limit)")
    }
    
    func getMyLeaderboardRank(type: String = "xp") async throws -> LeaderboardRank {
        return try await get(endpoint: "/gamification/leaderboards/\(type)/my-rank")
    }
    
    // MARK: - Achievements
    
    func getAchievements() async throws -> [Achievement] {
        return try await get(endpoint: "/gamification/achievements")
    }
    
    func getMyAchievements() async throws -> [UserAchievement] {
        return try await get(endpoint: "/gamification/my-achievements")
    }
    
    func checkAchievement(id: String) async throws -> AchievementProgress {
        return try await post(endpoint: "/gamification/achievements/\(id)/check", body: [:])
    }
    
    // MARK: - Badges
    
    func getMyBadges() async throws -> [UserBadge] {
        return try await get(endpoint: "/gamification/my-badges")
    }
    
    func equipBadge(id: String, equipped: Bool) async throws -> UserBadge {
        return try await put(endpoint: "/gamification/my-badges/\(id)", body: ["equipped": equipped])
    }
    
    // MARK: - Gamification Stats & Overview
    
    func getGamificationStats() async throws -> GamificationStats {
        return try await get(endpoint: "/gamification/stats")
    }
    
    func getGamificationOverview() async throws -> GamificationOverview {
        return try await get(endpoint: "/gamification/overview")
    }
    
    // MARK: - Battles (Local-only feature - backend doesn't support)
    
    func getBattles() async throws -> [Battle] {
        // Return empty array - battles are not supported by backend
        return []
    }
    
    func startBattle(opponentId: String, challengeId: String) async throws -> Battle {
        throw NetworkError.loginFailed("Battles feature not available")
    }
    
    func acceptBattle(id: String) async throws -> Battle {
        throw NetworkError.loginFailed("Battles feature not available")
    }
    
    func declineBattle(id: String) async throws {
        throw NetworkError.loginFailed("Battles feature not available")
    }
    
    // MARK: - Classroom
    
    func getClassroomSession(id: String) async throws -> ClassroomSession {
        return try await get(endpoint: "/learning/lessons/\(id)")
    }
    
    func createClassroomSession(lessonId: String) async throws -> ClassroomSession {
        let body = ["lesson_id": lessonId]
        return try await post(endpoint: "/learning/enrollments", body: body)
    }
    
    func saveClassroomProgress(sessionId: String, progress: LessonProgress) async throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let progressData = try encoder.encode(progress)
        let progressDict = try JSONSerialization.jsonObject(with: progressData) as? [String: Any]
        
        let _: EmptyResponse = try await post(endpoint: "/learning/lesson-completions", body: progressDict ?? [:])
    }
    
    // MARK: - Course Management
    
    func saveCourse(title: String, description: String, modules: [String]) async throws {
        // Mock implementation until backend endpoint is ready
        // In a real app, this would POST to /learning/courses
        print("💾 Saving course to repository: \(title)")
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
    }


    // MARK: - Stack

    func getStackItems(status: StackItemStatus? = nil) async throws -> [StackItem] {
        // Note: The backend endpoint /stack/ returns all items. Status filtering might need to happen client-side
        // or via query params if supported. For now, we fetch all.
        return try await NetworkClient.shared.request(Endpoints.Stack.getItems)
    }

    func createStackItem(request: CreateStackItemRequest) async throws -> StackItem {
        return try await NetworkClient.shared.request(Endpoints.Stack.createItem(item: request))
    }

    func updateStackItem(id: String, request: UpdateStackItemRequest) async throws -> StackItem {
        return try await NetworkClient.shared.request(Endpoints.Stack.updateItem(id: id, item: request))
    }

    // MARK: - Feed / Discover
    
    // Replaced legacy Feed endpoints with direct access to Courses and Events
    
    func getDiscoverCourses() async throws -> [Course] {
        return try await NetworkClient.shared.request(Endpoints.Learning.getCourses)
    }
    
    func getDiscoverEvents() async throws -> [EducationalEvent] {
        return try await NetworkClient.shared.request(Endpoints.Community.getEvents(filters: nil, location: nil))
    }

    // MARK: - Campus

    func getBeacons(latitude: Double, longitude: Double, radiusKm: Double = 10) async throws -> [Beacon] {
        return try await NetworkClient.shared.request(Endpoints.Community.getBeacons(lat: latitude, lng: longitude, radius: radiusKm))
    }

    func createQuestion(request: APICreateQuestionRequest) async throws -> APIQuestionResponse {
        return try await NetworkClient.shared.request(Endpoints.Community.createQuestion(question: request))
    }
    
    // MARK: - Community (User-specific)
    
    func getMyStudyGroups() async throws -> [StudyGroup] {
        return try await get(endpoint: "/api/v1/community/my-groups")
    }
    
    func getMyEvents() async throws -> [EducationalEvent] {
        return try await get(endpoint: "/api/v1/community/my-events")
    }
    
    func getCommunityStats() async throws -> CommunityStats {
        return try await get(endpoint: "/api/v1/community/stats")
    }
    
    func saveEventToStack(eventId: String) async throws {
        let _: EmptyResponse = try await post(endpoint: "/api/v1/community/events/\(eventId)/save", body: [:])
    }
    
    func attendEvent(eventId: String) async throws -> EducationalEvent {
        return try await post(endpoint: "/api/v1/community/events/\(eventId)/register", body: [:])
    }
    
    func leaveEvent(eventId: String) async throws {
        let _: EmptyResponse = try await delete(endpoint: "/api/v1/community/events/\(eventId)/unregister")
    }
    
    // MARK: - Course Social
    
    func likeCourse(courseId: String) async throws -> CourseLikeResponse {
        return try await NetworkClient.shared.request(Endpoints.CourseSocial.likeCourse(courseId: courseId))
    }
    
    func unlikeCourse(courseId: String) async throws {
        let _: EmptyResponse = try await NetworkClient.shared.request(Endpoints.CourseSocial.unlikeCourse(courseId: courseId))
    }
    
    func rateCourse(courseId: String, rating: Int) async throws -> CourseRatingResponse {
        return try await NetworkClient.shared.request(Endpoints.CourseSocial.rateCourse(courseId: courseId, rating: rating))
    }
    
    func getCourseSocialStats(courseId: String) async throws -> CourseSocialStats {
        return try await NetworkClient.shared.request(Endpoints.CourseSocial.getCourseSocialStats(courseId: courseId))
    }
    
    func getBulkCourseSocialStats(courseIds: [String]) async throws -> [String: CourseSocialStats] {
        return try await NetworkClient.shared.request(Endpoints.CourseSocial.getBulkCourseSocialStats(courseIds: courseIds))
    }
    
    // MARK: - Learning Progress
    
    func enrollInCourse(courseId: String) async throws -> EnrollmentResponse {
        return try await post(endpoint: "/learning/enrollments", body: ["course_id": courseId])
    }
    
    func markLessonComplete(lessonId: String, score: Int? = nil) async throws -> CompletionResponse {
        var body: [String: Any] = ["lesson_id": lessonId]
        if let score = score {
            body["score"] = score
        }
        return try await post(endpoint: "/learning/completions", body: body)
    }
    
    func getCourseProgress(courseId: String) async throws -> CourseProgress {
        return try await get(endpoint: "/learning/users/me/courses/\(courseId)/progress")
    }
    
    // MARK: - Helper for Endpoint requests
    
    // performRequest removed as we now use NetworkClient directly

}

// MARK: - Supporting Types

struct LoginResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String?
    let tenantId: String?
    // Backend also sends these fields - must be optional to avoid decoding failure
    let expiresIn: Int?
    let isNewUser: Bool?
    let tokenType: String?
    
}

enum NetworkError: Error {
    case invalidResponse
    case decodingError
    case unauthorized
    case registrationFailed(String)
    case loginFailed(String)
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError:
            return "Failed to parse server response"
        case .unauthorized:
            return "Authentication required"
        case .registrationFailed(let message):
            return "Registration failed: \(message)"
        case .loginFailed(let message):
            return "Login failed: \(message)"
        }
    }
}

struct ChallengesResponse: Codable {
    let dailyChallenges: [Challenge]
    let weeklyChallenge: Challenge?
    
    enum CodingKeys: String, CodingKey {
        case dailyChallenges = "daily_challenges"
        case weeklyChallenge = "weekly_challenge"
    }
}

// MARK: - Content Repository Consolidation
// Imported from ContentRepository.swift due to build system issues

protocol ContentRepository {
    func getFeaturedContent() async throws -> [ContentItem]
    func getQuickWins() async throws -> [ContentItem]
    func getLearningPaths() async throws -> [ContentItem]
    func getTrendingMiniCourses() async throws -> [ContentItem]
    func getAllContent() async throws -> [ContentItem]
}

class DefaultContentRepository: ContentRepository {
    
    // MARK: - Mock Data Store
    
    private let allContent: [ContentItem]
    
    init() {
        self.allContent = DefaultContentRepository.generateDayOneContent()
    }
    
    func getFeaturedContent() async throws -> [ContentItem] {
        // Return Top 3 Anchor Courses
        return allContent.filter { $0.type == .anchorCourse }.prefix(3).map { $0 }
    }
    
    func getQuickWins() async throws -> [ContentItem] {
        // Return random selection of Micro-Lessons
        return allContent.filter { $0.type == .microLesson }.shuffled().prefix(10).map { $0 }
    }
    
    func getLearningPaths() async throws -> [ContentItem] {
        return allContent.filter { $0.type == .learningPath }
    }
    
    func getTrendingMiniCourses() async throws -> [ContentItem] {
        return allContent.filter { $0.type == .miniCourse }.prefix(6).map { $0 }
    }
    
    func getAllContent() async throws -> [ContentItem] {
        return allContent
    }
    
    // MARK: - Day-One Content Generation
    
    private static func generateDayOneContent() -> [ContentItem] {
        var items: [ContentItem] = []
        
        let lyoAuthor = ContentAuthor(name: "Lyo Team", avatar: "LyoAvatar", role: "AI Coach")
        let industryAuthor = ContentAuthor(name: "Expert Network", avatar: "person.circle.fill", role: "Guest")
        
        // 1. Anchor Courses (10 items)
        let anchorTitles = [
            "AI Literacy for Everyone", "Prompting for Real Life & Work", "AI for Students",
            "Excel for Business", "SQL Basics", "Python for Beginners",
            "Cybersecurity Basics", "Digital Marketing Foundations", "UX/UI Foundations", "Entrepreneurship 101"
        ]
        
        for (i, title) in anchorTitles.enumerated() {
            items.append(ContentItem(
                id: "anchor_\(i)",
                type: .anchorCourse,
                title: title,
                description: "Master the fundamentals of \(title) with this comprehensive, cinematic course designed for rapid mastery.",
                coverImage: "course_cover_\(i % 5)",
                duration: 18000, // 5 hours
                author: lyoAuthor,
                tags: ["Featured", "Career"],
                level: .beginner,
                stats: ContentStats(views: Int.random(in: 1000...5000), likes: Int.random(in: 100...500), rating: 4.8)
            ))
        }
        
        // 2. Mini-Courses (Selection of 6 for trending)
        let miniTitles = [
            "Resume + LinkedIn with AI", "Interview Prep with AI", "Budgeting & Finance",
            "Notion Productivity", "Public Speaking", "TikTok Growth"
        ]
        
        for (i, title) in miniTitles.enumerated() {
            items.append(ContentItem(
                id: "mini_\(i)",
                type: .miniCourse,
                title: title,
                description: "A fast-paced, 2-hour deep dive into \(title). Get actionable skills you can use today.",
                coverImage: "mini_cover_\(i % 3)",
                duration: 7200, // 2 hours
                author: industryAuthor,
                tags: ["Skill", "Fast"],
                level: .intermediate,
                stats: ContentStats(views: Int.random(in: 500...2000), likes: Int.random(in: 50...200), rating: 4.7)
            ))
        }
        
        // 3. Micro-Lessons (Selection of 10 for Quick Wins)
        let microTitles = [
            "5 Excel Shortcuts", "Write Better Emails", "Negotiate Your Salary",
            "Focus Techniques", "Secure Your Password", "Python 'Hello World'",
            "Design Rule of Thirds", "SEO Basics", "Networking 101", "Stress Management"
        ]
        
        for (i, title) in microTitles.enumerated() {
            items.append(ContentItem(
                id: "micro_\(i)",
                type: .microLesson,
                title: title,
                description: "Learn \(title) in under 5 minutes.",
                coverImage: "micro_cover_\(i % 3)",
                duration: 180, // 3 mins
                author: lyoAuthor,
                tags: ["Quick Win", "Daily"],
                level: .allLevels,
                stats: ContentStats(views: Int.random(in: 200...800), likes: Int.random(in: 20...100), rating: 4.9)
            ))
        }
        
        // 4. Learning Paths
        items.append(ContentItem(
            id: "path_1",
            type: .learningPath,
            title: "7-Day AI Starter Path",
            description: "Go from zero to AI hero in one week. Curated lessons to build confidence.",
            coverImage: "path_cover_ai",
            duration: 0, // Computed
            author: lyoAuthor,
            tags: ["Path", "AI"],
            level: .beginner,
            stats: ContentStats(views: 800, likes: 120, rating: 4.9),
            childContentIds: ["micro_0", "micro_1", "anchor_0"]
        ))
        
        items.append(ContentItem(
            id: "path_2",
            type: .learningPath,
            title: "10-Day Excel Boost",
            description: "Transform your spreadsheet skills with daily challenges.",
            coverImage: "path_cover_excel",
            duration: 0,
            author: industryAuthor,
            tags: ["Path", "Business"],
            level: .intermediate,
            stats: ContentStats(views: 600, likes: 90, rating: 4.8),
            childContentIds: ["micro_0", "anchor_3"]
        ))
        
        return items
    }
}

// MARK: - SocialRepository Conformance
extension LyoRepository: SocialRepository {
    func getPosts(page: Int, limit: Int, algorithm: String?) async throws -> RepoFeedResponse {
        var query = "limit=\(limit)&offset=\((page - 1) * limit)"
        if let alg = algorithm { query += "&algorithm=\(alg)" }
        // FIXED: Backend endpoint is /api/v1/feed NOT /api/v1/posts/feed
        return try await get(endpoint: "/api/v1/feed?\(query)")
    }
    
    func createPost(content: String, attachments: [String]?) async throws -> RepoPost {
        let body: [String: Any] = [
            "content": content,
            "media_urls": attachments ?? []
        ]
        return try await post(endpoint: "/api/v1/posts/posts", body: body)
    }
    
    func getPost(postId: String) async throws -> RepoPost {
        return try await get(endpoint: "/api/v1/posts/posts/\(postId)")
    }
    
    func deletePost(postId: String) async throws {
        let _: EmptyResponse = try await delete(endpoint: "/api/v1/posts/posts/\(postId)")
    }
    
    func likePost(postId: String) async throws {
        let _: EmptyResponse = try await post(endpoint: "/api/v1/posts/posts/\(postId)/reactions", body: [:])
    }
    
    func commentOnPost(postId: String, content: String) async throws -> Comment {
        return try await post(endpoint: "/api/v1/posts/posts/\(postId)/comments", body: ["content": content])
    }
    
    func getComments(postId: String) async throws -> [Comment] {
        return try await get(endpoint: "/api/v1/posts/posts/\(postId)/comments")
    }
}

// MARK: - Dynamic Endpoint Support

// DynamicEndpoint is now defined in Sources/Core/Networking/Endpoint.swift
// Removed duplicate definition to avoid ambiguity

struct AnyEncodable: Encodable {
    let value: Any

    init(value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let number as Int: try container.encode(number)
        case let number as Double: try container.encode(number)
        case let string as String: try container.encode(string)
        case let bool as Bool: try container.encode(bool)
        case let array as [Any]: try container.encode(array.map { AnyEncodable(value: $0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyEncodable(value: $0) })
        default: try container.encodeNil()
        }
    }
}

// MARK: - Course Social Response Models

struct CourseLikeResponse: Codable {
    let totalLikes: Int
    let userHasLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case totalLikes = "total_likes"
        case userHasLiked = "user_has_liked"
    }
}

struct CourseRatingResponse: Codable {
    let averageRating: Double
    let totalRatings: Int
    let userRating: Int?
    
    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case totalRatings = "total_ratings"
        case userRating = "user_rating"
    }
}

struct CourseSocialStats: Codable {
    let likes: Int
    let rating: Double
    let ratingCount: Int
    let userHasLiked: Bool
    let userRating: Int?
    
    enum CodingKeys: String, CodingKey {
        case likes
        case rating
        case ratingCount = "rating_count"
        case userHasLiked = "user_has_liked"
        case userRating = "user_rating"
    }
}
