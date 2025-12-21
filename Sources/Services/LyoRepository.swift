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
        let endpoint = "\(baseURL)/auth/login"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            debugPrintFailedResponse(response: response, data: data)
            throw NetworkError.invalidResponse
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = loginResponse.token
        
        // Persist token to KeyChain for auto-login across app restarts
        await tokenManager.setToken(loginResponse.token)
        if let refreshToken = loginResponse.refreshToken {
            await tokenManager.setRefreshToken(refreshToken)
        }
        await tokenManager.setUserId(String(loginResponse.user.id))
        
        return loginResponse.user
    }

    func loginWithGoogle(idToken: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/firebase"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["id_token": idToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            debugPrintFailedResponse(response: response, data: data)
            
            // Try to parse error message
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorData["detail"] {
                throw NetworkError.loginFailed(detail)
            }
            
            throw NetworkError.invalidResponse
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = loginResponse.token
        
        // Persist token to KeyChain for auto-login across app restarts
        await tokenManager.setToken(loginResponse.token)
        if let refreshToken = loginResponse.refreshToken {
            await tokenManager.setRefreshToken(refreshToken)
        }
        await tokenManager.setUserId(String(loginResponse.user.id))
        
        return loginResponse.user
    }
    
    func register(email: String, password: String, name: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/register"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // GCP API requires: email, username, password, confirm_password
        // Optional: first_name, last_name
        // Extract username from email (before @) and sanitize
        // Username can only contain letters, numbers, underscores, and hyphens
        let emailPrefix = email.components(separatedBy: "@").first ?? email
        let username = emailPrefix
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "+", with: "_")
        
        // Split name into first_name and last_name if provided
        let nameParts = name.split(separator: " ", maxSplits: 1)
        let firstName = nameParts.first.map(String.init)
        let lastName = nameParts.count > 1 ? String(nameParts[1]) : nil
        
        var body: [String: Any] = [
            "email": email,
            "username": username,
            "password": password,
            "confirm_password": password
        ]
        
        // Add optional fields if present
        if let firstName = firstName {
            body["first_name"] = firstName
        }
        if let lastName = lastName {
            body["last_name"] = lastName
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorData["detail"] {
                throw NetworkError.registrationFailed(detail)
            }
            debugPrintFailedResponse(response: response, data: data)
            throw NetworkError.invalidResponse
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = loginResponse.token
        
        // Persist token to KeyChain for auto-login across app restarts
        await tokenManager.setToken(loginResponse.token)
        if let refreshToken = loginResponse.refreshToken {
            await tokenManager.setRefreshToken(refreshToken)
        }
        await tokenManager.setUserId(String(loginResponse.user.id))
        
        return loginResponse.user
    }
    
    // MARK: - Leo AI Chat
    
    func sendLyoMessage(message: String, attachmentIds: [String]? = nil, context: ChatContext? = nil) async throws -> LyoChatResponse {
        let endpoint = "\(baseURL)/ai/mentor/conversation"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let chatRequest = LyoChatRequest(
            message: message,
            context: context,
            attachments: attachmentIds
        )
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            debugPrintFailedResponse(response: response, data: data)
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LyoChatResponse.self, from: data)
    }
    
    func getCourseCards() async throws -> [CourseCard] {
        // Allow passing a full URL safely
        return try await get(endpoint: "/learning/courses")
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
        let endpoint = "\(baseURL)/files/upload"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        let filename = url.lastPathComponent
        let data = try Data(contentsOf: url)
        let mimetype = mimeType(for: url)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            debugPrintFailedResponse(response: response, data: responseData)
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode(MessageAttachment.self, from: responseData)
    }
    
    // MARK: - Generic Helpers
    
    /// Get auth token, restoring from KeyChain if needed
    private func getAuthToken() async -> String? {
        if authToken == nil {
            // Try to restore from KeyChain
            authToken = await tokenManager.getToken()
        }
        return authToken
    }
    
    private func makeURL(_ endpoint: String) -> URL {
        if endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://") {
            return URL(string: endpoint)!
        } else {
            return URL(string: baseURL + endpoint)!
        }
    }
    
    private func get<T: Decodable>(endpoint: String) async throws -> T {
        var request = URLRequest(url: makeURL(endpoint))
        request.httpMethod = "GET"
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            debugPrintFailedResponse(response: response, data: data)
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func post<T: Decodable>(endpoint: String, body: [String: Any]? = nil) async throws -> T {
        var request = URLRequest(url: makeURL(endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else {
            // Ensure we send a valid JSON body when Content-Type is application/json
            request.httpBody = "{}".data(using: .utf8)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to surface useful error messages, especially for 4xx/422
            if let message = extractErrorMessage(from: data) {
                // Reuse an existing error case to carry the server message
                throw NetworkError.loginFailed("HTTP \(httpResponse.statusCode): \(message)")
            }
            debugPrintFailedResponse(response: response, data: data)
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func put<T: Decodable>(endpoint: String, body: [String: Any]? = nil) async throws -> T {
        var request = URLRequest(url: makeURL(endpoint))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else {
            request.httpBody = "{}".data(using: .utf8)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let message = extractErrorMessage(from: data) {
                throw NetworkError.loginFailed("HTTP \(httpResponse.statusCode): \(message)")
            }
            debugPrintFailedResponse(response: response, data: data)
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func delete<T: Decodable>(endpoint: String) async throws -> T {
        var request = URLRequest(url: makeURL(endpoint))
        request.httpMethod = "DELETE"
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let message = extractErrorMessage(from: data) {
                throw NetworkError.loginFailed("HTTP \(httpResponse.statusCode): \(message)")
            }
            debugPrintFailedResponse(response: response, data: data)
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
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
    
    private func extractErrorMessage(from data: Data) -> String? {
        // Try common shapes: {"detail":"..."} or FastAPI-style {"detail":[{...}]}
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = dict["detail"] as? String {
                return detail
            }
            if let details = dict["detail"] as? [[String: Any]],
               let first = details.first,
               let msg = first["msg"] as? String {
                return msg
            }
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        return nil
    }
    
    private func debugPrintFailedResponse(response: URLResponse?, data: Data) {
        if let http = response as? HTTPURLResponse {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            print("❌ HTTP \(http.statusCode) – Response body: \(body)")
        } else {
            print("❌ Invalid response object")
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
        let endpoint = Endpoints.Stack.getItems
        let request = try endpoint.buildURLRequest()
        return try await performRequest(request)
    }

    func createStackItem(request: CreateStackItemRequest) async throws -> StackItem {
        let endpoint = Endpoints.Stack.createItem(item: request)
        let urlRequest = try endpoint.buildURLRequest()
        return try await performRequest(urlRequest)
    }

    func updateStackItem(id: String, request: UpdateStackItemRequest) async throws -> StackItem {
        let endpoint = Endpoints.Stack.updateItem(id: id, item: request)
        let urlRequest = try endpoint.buildURLRequest()
        return try await performRequest(urlRequest)
    }

    // MARK: - Feed / Discover
    
    // Replaced legacy Feed endpoints with direct access to Courses and Events
    
    func getDiscoverCourses() async throws -> [Course] {
        let endpoint = Endpoints.Learning.getCourses
        let request = try endpoint.buildURLRequest()
        return try await performRequest(request)
    }
    
    func getDiscoverEvents() async throws -> [EducationalEvent] {
        let endpoint = Endpoints.Community.getEvents(filters: nil as CommunityFilter?, location: nil as CLLocationCoordinate2D?)
        let request = try endpoint.buildURLRequest()
        return try await performRequest(request)
    }

    // MARK: - Campus

    func getBeacons(latitude: Double, longitude: Double, radiusKm: Double = 10) async throws -> [Beacon] {
        let endpoint = Endpoints.Community.getBeacons(lat: latitude, lng: longitude, radius: radiusKm)
        let request = try endpoint.buildURLRequest()
        return try await performRequest(request)
    }

    func createQuestion(request: CreateQuestionRequest) async throws -> QuestionResponse {
        let endpoint = Endpoints.Community.createQuestion(question: request)
        let urlRequest = try endpoint.buildURLRequest()
        return try await performRequest(urlRequest)
    }
    
    // MARK: - Community (User-specific)
    
    func getMyStudyGroups() async throws -> [StudyGroup] {
        return try await get(endpoint: "/community/my-groups")
    }
    
    func getMyEvents() async throws -> [EducationalEvent] {
        return try await get(endpoint: "/community/my-events")
    }
    
    func getCommunityStats() async throws -> CommunityStats {
        return try await get(endpoint: "/community/stats")
    }
    
    func saveEventToStack(eventId: String) async throws {
        let _: EmptyResponse = try await post(endpoint: "/community/events/\(eventId)/save", body: [:])
    }
    
    func attendEvent(eventId: String) async throws -> EducationalEvent {
        return try await post(endpoint: "/community/events/\(eventId)/attend", body: [:])
    }
    
    func leaveEvent(eventId: String) async throws {
        let _: EmptyResponse = try await delete(endpoint: "/community/events/\(eventId)/attend")
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
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        var signedRequest = request
        if let token = await getAuthToken() {
            signedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            debugPrintFailedResponse(response: response, data: data)
            if let message = extractErrorMessage(from: data) {
                throw NetworkError.loginFailed("HTTP \(httpResponse.statusCode): \(message)")
            }
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Supporting Types

struct LoginResponse: Codable {
    let user: User
    let token: String
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case user
        case token = "access_token"
        case refreshToken = "refresh_token"
    }
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
        // Use known backend path structure
        return try await get(endpoint: "/api/v1/posts/feed?\(query)")
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
