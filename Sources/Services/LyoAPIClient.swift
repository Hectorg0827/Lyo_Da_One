import Foundation

// MARK: - API Response Types

struct HealthInfo: Codable {
    let status: String
    let version: String?
    let timestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case status
        case version
        case timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        // Handle various timestamp formats
        if let timestampString = try container.decodeIfPresent(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            timestamp = formatter.date(from: timestampString) ?? Date()
        } else {
            timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        }
    }
}

struct CreateEventRequest: Codable {
    let title: String
    let description: String
    let eventType: String
    let startTime: Date
    let endTime: Date?
    let location: String
    let maxAttendees: Int?
}

// MARK: - API Feed Responses

struct DiscoverFeedResponse: Codable {
    let items: [DiscoverItem]
}

struct CampusEventsResponse: Codable {
    let events: [CampusItem]
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed(String)
    case serverError(Int, String?)
    case networkError(String)
    case unauthorized
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unauthorized:
            return "Unauthorized - please log in"
        case .rateLimited:
            return "Too many requests - please wait"
        }
    }
}

// MARK: - Lyo API Client

final class LyoAPIClient {
    static let shared = LyoAPIClient()
    
    private let baseURL: String
    private let session: URLSession
    private let tokenManager = TokenManager.shared
    
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    init(session: URLSession? = nil, baseURL: String? = nil) {
        self.baseURL = baseURL ?? AppConfig.baseURL
        
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = AppConfig.requestTimeout
            config.timeoutIntervalForResource = AppConfig.uploadTimeout
            self.session = URLSession(configuration: config)
        }
    }
    
    // MARK: - Auth Helper
    
    private func getAuthToken() async -> String? {
        return await tokenManager.getToken()
    }
    
    // MARK: - Generic Request Helper
    
    private func request<T: Decodable>(
        method: String = "GET",
        path: String,
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if requiresAuth, let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try jsonDecoder.decode(T.self, from: data)
            } catch let decodingError {
                print("Decoding error for \(path): \(decodingError)")
                throw APIError.decodingFailed(decodingError.localizedDescription)
            }
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            // Try to parse error message
            var errorMessage: String?
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                errorMessage = detail
            }
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - Health Check
    
    func health() async throws -> HealthInfo {
        return try await request(path: "/health", requiresAuth: false)
    }
    
    // MARK: - Learning Endpoints (Real Backend)
    
    func fetchCourses() async throws -> [Course] {
        do {
            return try await request(path: "/api/v1/learning/courses", requiresAuth: false)
        } catch {
            print("⚠️ Failed to fetch courses: \(error). Using mocks.")
            return LyoAPIClient.mockCourses()
        }
    }
    
    func fetchCourse(id: String) async throws -> Course {
        return try await request(path: "/api/v1/learning/courses/\(id)", requiresAuth: false)
    }
    
    func fetchLessons(courseId: String) async throws -> [Lesson] {
        do {
            return try await request(path: "/api/v1/learning/courses/\(courseId)/lessons", requiresAuth: false)
        } catch {
            print("⚠️ Failed to fetch lessons: \(error). Using mocks.")
            return LyoAPIClient.mockLessons()
        }
    }
    
    func fetchLiveLesson(courseId: String, lessonId: String) async throws -> LiveLesson {
        // Optimistic Mock Check: Use local data for demo/mock IDs to avoid 404s
        if ["intro_1", "intro_2", "video_1"].contains(lessonId) || courseId.contains("demo") || courseId == "calculus_101" {
            print("🚀 Loading locally for demo lesson: \(lessonId)")
            return LyoAPIClient.mockLiveLesson(courseId: courseId, lessonId: lessonId)
        }
        
        do {
            return try await request(path: "/api/v1/learning/courses/\(courseId)/lessons/\(lessonId)/live", requiresAuth: false)
        } catch {
            print("⚠️ Failed to fetch live lesson: \(error). Falling back to mock.")
            return LyoAPIClient.mockLiveLesson(courseId: courseId, lessonId: lessonId)
        }
    }
    
    func fetchEnrollments() async throws -> [Enrollment] {
        do {
            return try await request(path: "/api/v1/learning/enrollments")
        } catch {
            print("⚠️ Failed to fetch enrollments: \(error). Using mocks.")
            return LyoAPIClient.mockEnrollments()
        }
    }
    
    // MARK: - Community Endpoints (Real Backend)
    
    func fetchCommunityEvents() async throws -> [CommunityEvent] {
        return try await request(path: "/api/v1/community/events")
    }
    
    func createCommunityEvent(_ request: CreateEventRequest) async throws -> CommunityEvent {
        let body = try jsonEncoder.encode(request)
        return try await self.request(method: "POST", path: "/api/v1/community/events", body: body)
    }
    
    func fetchCommunityEvent(id: String) async throws -> CommunityEvent {
        return try await request(path: "/api/v1/community/events/\(id)")
    }
    
    // MARK: - Tutor API
    
    func createTutorSession(courseId: String, lessonId: String) async throws -> TutorSession {
        let payload = TutorSessionCreate(courseId: courseId, lessonId: lessonId)
        let body = try jsonEncoder.encode(payload)
        return try await request(method: "POST", path: "/api/v1/tutor/sessions", body: body)
    }
    
    func fetchTutorMessages(sessionId: String) async throws -> [TutorMessage] {
        return try await request(path: "/api/v1/tutor/sessions/\(sessionId)/messages")
    }
    
    func sendTutorMessage(sessionId: String, content: String) async throws -> TutorMessage {
        let payload = TutorMessageCreate(sessionId: sessionId, content: content)
        let body = try jsonEncoder.encode(payload)
        return try await request(method: "POST", path: "/api/v1/tutor/messages", body: body)
    }
    
    func fetchStudyGroups() async throws -> [StudyGroup] {
        return try await request(path: "/api/v1/community/study-groups")
    }
    
    func joinStudyGroup(id: String) async throws -> StudyGroup {
        return try await request(method: "POST", path: "/api/v1/community/study-groups/\(id)/join")
    }
    
    func fetchCommunityQuestions() async throws -> [CommunityQuestion] {
        return try await request(path: "/api/v1/community/questions")
    }
    
    // MARK: - Gamification Endpoints (Real Backend)
    
    func fetchGamificationOverview() async throws -> GamificationOverview {
        return try await request(path: "/gamification/overview")
    }
    
    func fetchAchievements() async throws -> [Achievement] {
        return try await request(path: "/gamification/achievements")
    }
    
    func fetchMyAchievements() async throws -> [UserAchievement] {
        return try await request(path: "/gamification/my-achievements")
    }
    
    func fetchBadges() async throws -> [Badge] {
        return try await request(path: "/gamification/badges")
    }
    
    func fetchMyBadges() async throws -> [UserBadge] {
        return try await request(path: "/gamification/my-badges")
    }
    
    func fetchLeaderboard(type: String) async throws -> [LeaderboardEntry] {
        return try await request(path: "/gamification/leaderboards/\(type)")
    }
    
    func fetchStreaks() async throws -> [Streak] {
        return try await request(path: "/api/v1/gamification/streaks")
    }
    
    func fetchXPSummary() async throws -> XPSummary {
        return try await request(path: "/api/v1/gamification/xp/summary")
    }
    
    // MARK: - Posts & Social Feed (Real Backend)
    
    func fetchPublicFeed(limit: Int = 20, offset: Int = 0) async throws -> [RepoPost] {
        return try await request(path: "/api/v1/posts/feed/public?limit=\(limit)&offset=\(offset)")
    }
    
    func fetchMyFeed(limit: Int = 20, offset: Int = 0) async throws -> [RepoPost] {
        return try await request(path: "/api/v1/posts/feed?limit=\(limit)&offset=\(offset)")
    }
    
    func createPost(content: String, mediaURLs: [String]? = nil) async throws -> RepoPost {
        struct CreatePostRequest: Codable {
            let content: String
            let media_urls: [String]?
        }
        let body = try jsonEncoder.encode(CreatePostRequest(content: content, media_urls: mediaURLs))
        return try await request(method: "POST", path: "/api/v1/posts/posts", body: body)
    }
    
    func likePost(id: String) async throws -> RepoPost {
        return try await request(method: "POST", path: "/api/v1/posts/posts/\(id)/reactions")
    }
    
    // MARK: - Search Endpoints (Real Backend)
    
    func search(query: String, type: String? = nil) async throws -> SearchResults {
        var path = "/api/v1/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        if let type = type {
            path += "&type=\(type)"
        }
        return try await request(path: path)
    }
    
    func searchAutocomplete(query: String) async throws -> [String] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(path: "/api/v1/search/autocomplete?q=\(encodedQuery)")
    }
    
    func fetchTrendingSearches() async throws -> [String] {
        return try await request(path: "/api/v1/search/trending")
    }
    
    // MARK: - Notifications (Real Backend)
    
    func fetchNotifications() async throws -> [APINotification] {
        return try await request(path: "/api/v1/notifications")
    }
    
    func markNotificationRead(id: String) async throws {
        let _: EmptyAPIResponse = try await request(method: "POST", path: "/api/v1/notifications/\(id)/read")
    }
    
    func markAllNotificationsRead() async throws {
        let _: EmptyAPIResponse = try await request(method: "POST", path: "/api/v1/notifications/read-all")
    }
    
    func fetchUnreadCount() async throws -> UnreadCount {
        return try await request(path: "/api/v1/notifications/unread-count")
    }
    
    // MARK: - Stack Endpoints (Real Backend)
    
    func fetchStackItems() async throws -> [StackItem] {
        return try await request(path: "/api/v1/stack/items")
    }
    
    func createStackItem(_ item: CreateStackItemRequest) async throws -> StackItem {
        let body = try jsonEncoder.encode(item)
        return try await request(method: "POST", path: "/api/v1/stack/items", body: body)
    }
    
    func deleteStackItem(id: String) async throws {
        let _: EmptyAPIResponse = try await request(method: "DELETE", path: "/api/v1/stack/items/\(id)")
    }
    
    // MARK: - Messaging (Real Backend)
    
    func fetchConversations() async throws -> [APIConversation] {
        return try await request(path: "/api/v1/messages/conversations")
    }
    
    func fetchMessages(conversationId: String) async throws -> [APIMessage] {
        return try await request(path: "/api/v1/messages/conversations/\(conversationId)/messages")
    }
    
    func sendMessage(conversationId: String, content: String) async throws -> APIMessage {
        struct SendMessageRequest: Codable {
            let content: String
        }
        let body = try jsonEncoder.encode(SendMessageRequest(content: content))
        return try await request(method: "POST", path: "/api/v1/messages/conversations/\(conversationId)/messages", body: body)
    }
    
    // MARK: - Analytics (Real Backend)
    
    func trackEvent(name: String, properties: [String: Any]? = nil) async throws {
        struct EventRequest: Codable {
            let event_name: String
            let properties: [String: String]?
        }
        let stringProps = properties?.compactMapValues { "\($0)" }
        let body = try jsonEncoder.encode(EventRequest(event_name: name, properties: stringProps))
        let _: EmptyAPIResponse = try await request(method: "POST", path: "/api/v1/analytics/events", body: body)
    }
    
    func fetchActivitySummary() async throws -> ActivitySummary {
        return try await request(path: "/api/v1/analytics/activity-summary")
    }
    
    func fetchLearningInsights() async throws -> APILearningInsights {
        return try await request(path: "/api/v1/analytics/learning-insights")
    }
    
    // MARK: - Legacy Discover Feed (uses learning/courses + community)
    
    func fetchDiscoverFeed(category: String? = nil, limit: Int = 20) async throws -> [DiscoverItem] {
        // The backend doesn't have a dedicated discover endpoint
        // So we construct discover items from courses + events
        var discoverItems: [DiscoverItem] = []
        
        // Fetch courses and convert to discover items
        do {
            let courses: [Course] = try await request(path: "/api/v1/learning/courses", requiresAuth: false)
            for course in courses.prefix(limit / 2) {
                discoverItems.append(DiscoverItem(
                    id: "course_\(course.id)",
                    type: .courseSuggestion,
                    title: course.title,
                    subtitle: course.description,
                    tag: course.tags?.first,
                    estimatedMinutes: nil, // Course doesn't have duration field
                    courseId: course.id,
                    lessonId: nil
                ))
            }
        } catch {
            print("Failed to fetch courses for discover: \(error)")
        }
        
        // Fallback to mocks if we have no items (either request failed or returned empty)
        if discoverItems.isEmpty {
            print("⚠️ Using mock discover items due to backend failure or empty response")
            return LyoAPIClient.mockDiscoverItems()
        }
        
        return discoverItems
    }
    
    // MARK: - Legacy Campus Events (uses community/events)
    
    func fetchCampusEvents(
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Double = 1000,
        category: String? = nil
    ) async throws -> [CampusItem] {
        // Map community events to campus items
        do {
            let events: [CommunityEvent] = try await request(path: "/api/v1/community/events")
            
            let items = events.map { event in
                CampusItem(
                    id: event.id,
                    type: mapEventType(event.eventType),
                    title: event.title,
                    subtitle: event.description,
                    locationName: event.location ?? "Online",
                    coordinate: CampusCoordinate(
                        latitude: latitude ?? 37.7749,
                        longitude: longitude ?? -122.4194
                    ),
                    startTime: event.startTime,
                    endTime: event.endTime ?? event.startTime.addingTimeInterval(3600),
                    roomId: event.id,
                    hostName: event.hostName ?? "Unknown",
                    hostAvatarURL: nil,
                    attendeeCount: event.attendeeCount,
                    maxAttendees: event.maxAttendees,
                    tags: []
                )
            }
            
            if items.isEmpty {
                throw APIError.invalidResponse // Trigger fallback
            }
            return items
            
        } catch {
            print("⚠️ Failed to fetch campus events: \(error). Using mocks.")
            return LyoAPIClient.mockCampusEvents()
        }
    }
    
    private func mapEventType(_ type: String?) -> CampusItemType {
        switch type?.lowercased() {
        case "workshop": return .workshop
        case "study_group", "studygroup": return .studyGroup
        case "meetup": return .meetup
        case "office_hours", "office": return .office
        default: return .event
        }
    }
}

// MARK: - Mock Data Fallback Extension

extension LyoAPIClient {
    
    /// Generate mock discover items when backend is unavailable
    static func mockDiscoverItems() -> [DiscoverItem] {
        return [
            DiscoverItem(
                id: "disc_1",
                type: .courseSuggestion,
                title: "Introduction to Python",
                subtitle: "Perfect for beginners",
                tag: "Trending",
                estimatedMinutes: 45,
                courseId: "python_101",
                lessonId: "intro_1",
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1526379095098-d400fd0bf935?w=800&q=80"),
                aiInsight: "This course matches your goal to learn backend development. 85% of students rated it 5 stars."
            ),
            DiscoverItem(
                id: "disc_2",
                type: .videoSnippet,
                title: "Machine Learning Basics",
                subtitle: "Quick overview of ML concepts",
                tag: "New",
                estimatedMinutes: 12,
                courseId: "ml_basics",
                lessonId: "video_1",
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1555949963-aa79dcee981c?w=800&q=80"),
                videoURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
                aiInsight: "Based on your interest in AI, this 12-minute overview is a perfect quick start."
            ),
            DiscoverItem(
                id: "disc_3",
                type: .pathSuggestion,
                title: "Data Science Career Path",
                subtitle: "Complete learning roadmap",
                tag: "Featured",
                estimatedMinutes: 180,
                courseId: "data_science_path",
                lessonId: nil,
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&q=80"),
                aiInsight: "This path covers 90% of the skills required for Data Scientist roles at top tech companies."
            ),
            DiscoverItem(
                id: "disc_4",
                type: .eventSuggestion,
                title: "Live Coding Workshop",
                subtitle: "Today at 3:00 PM",
                tag: "Live",
                estimatedMinutes: 60,
                courseId: nil,
                lessonId: nil,
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=800&q=80"),
                aiInsight: "Attending live events increases learning retention by 40%. Join 15 others!"
            ),
            DiscoverItem(
                id: "disc_5",
                type: .courseSuggestion,
                title: "Advanced Swift Programming",
                subtitle: "Master iOS development",
                tag: "Popular",
                estimatedMinutes: 90,
                courseId: "swift_advanced",
                lessonId: "intro_1",
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1599658880436-c61792e70672?w=800&q=80"),
                aiInsight: "You've completed 'Swift Basics'. This is the natural next step to advance your skills."
            )
        ]
    }
    
    /// Generate mock campus events when backend is unavailable
    static func mockCampusEvents() -> [CampusItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            CampusItem(
                id: "campus_1",
                type: .event,
                title: "AI Study Group",
                subtitle: "Weekly AI & ML discussion",
                locationName: "Tech Building Room 204",
                coordinate: CampusCoordinate(latitude: 37.7749, longitude: -122.4194),
                startTime: calendar.date(byAdding: .hour, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                roomId: "collab-ai-study",
                hostName: "AI Club",
                hostAvatarURL: nil,
                attendeeCount: 15,
                maxAttendees: 25,
                tags: ["AI", "Machine Learning", "Study Group"]
            ),
            CampusItem(
                id: "campus_2",
                type: .workshop,
                title: "Resume Workshop",
                subtitle: "Career Services event",
                locationName: "Career Center",
                coordinate: CampusCoordinate(latitude: 37.7752, longitude: -122.4180),
                startTime: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 26, to: now) ?? now,
                roomId: nil,
                hostName: "Career Services",
                hostAvatarURL: nil,
                attendeeCount: 30,
                maxAttendees: 50,
                tags: ["Career", "Professional Development"]
            ),
            CampusItem(
                id: "campus_3",
                type: .meetup,
                title: "iOS Developers Meetup",
                subtitle: "Monthly developer gathering",
                locationName: "Student Union",
                coordinate: CampusCoordinate(latitude: 37.7745, longitude: -122.4200),
                startTime: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 50, to: now) ?? now,
                roomId: "collab-ios-dev",
                hostName: "iOS Dev Club",
                hostAvatarURL: nil,
                attendeeCount: 25,
                maxAttendees: 40,
                tags: ["iOS", "Swift", "Development"]
            ),
            CampusItem(
                id: "campus_4",
                type: .studyGroup,
                title: "Calculus III Study Session",
                subtitle: "Exam prep",
                locationName: "Library 3rd Floor",
                coordinate: CampusCoordinate(latitude: 37.7755, longitude: -122.4190),
                startTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 4, to: now) ?? now,
                roomId: "collab-calc-study",
                hostName: "Math Club",
                hostAvatarURL: nil,
                attendeeCount: 8,
                maxAttendees: 12,
                tags: ["Math", "Calculus", "Exam Prep"]
            ),
            CampusItem(
                id: "campus_5",
                type: .office,
                title: "Prof. Smith Office Hours",
                subtitle: "Computer Science",
                locationName: "CS Building 301",
                coordinate: CampusCoordinate(latitude: 37.7748, longitude: -122.4185),
                startTime: calendar.date(byAdding: .hour, value: 3, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 5, to: now) ?? now,
                roomId: nil,
                hostName: "Prof. John Smith",
                hostAvatarURL: nil,
                attendeeCount: 0,
                maxAttendees: 5,
                tags: ["Computer Science", "Office Hours"]
            )
        ]
    }
    
    /// Generate a mock live lesson when backend is unavailable
    static func mockLiveLesson(courseId: String, lessonId: String) -> LiveLesson {
        return LiveLesson(
            courseId: courseId,
            lessonId: lessonId,
            title: "Introduction to Programming Concepts",
            subtitle: "Learn the fundamentals",
            blocks: [
                LessonBlock(
                    type: .explain,
                    title: "What is Programming?",
                    body: "Programming is the process of creating instructions for computers to follow. Think of it like writing a recipe - you're telling the computer exactly what steps to take."
                ),
                LessonBlock(
                    type: .image,
                    title: "The Programming Workflow",
                    body: "Here's how programmers typically work:",
                    assetURL: nil
                ),
                LessonBlock(
                    type: .example,
                    title: "Your First Code",
                    body: "Let's look at a simple example:\n\n```python\nprint(\"Hello, World!\")\n```\n\nThis code tells the computer to display the text 'Hello, World!' on the screen."
                ),
                LessonBlock(
                    type: .quizMcq,
                    title: "Quick Check",
                    body: "What does the print() function do?",
                    options: [
                        "Sends a document to a printer",
                        "Displays text on the screen",
                        "Saves a file",
                        "Deletes text"
                    ],
                    correctIndex: 1,
                    explanation: "The print() function displays text or data on the screen. It's one of the most basic and commonly used functions in programming!"
                ),
                LessonBlock(
                    type: .summary,
                    title: "Key Takeaways",
                    body: "In this lesson, you learned:\n\n• Programming is writing instructions for computers\n• Code follows a specific syntax (rules)\n• The print() function displays output\n\nGreat job completing your first lesson!"
                )
            ],
            estimatedDuration: 15
        )
    }
    
    /// Generate mock courses when backend is unavailable
    static func mockCourses() -> [Course] {
        return [
            Course(
                id: "python_101",
                title: "Introduction to Python",
                description: "Learn the basics of Python programming.",
                shortDescription: "Python basics",
                instructorId: 1,
                difficultyLevel: "beginner",
                category: "Programming",
                tags: ["Python", "Coding"],
                thumbnailURL: "https://images.unsplash.com/photo-1526379095098-d400fd0bf935?w=800&q=80",
                isPublished: true,
                isFeatured: true,
                lessonCount: 10,
                enrollmentCount: 100,
                estimatedDurationHours: 5,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "swift_advanced",
                title: "Advanced Swift",
                description: "Master iOS development with Swift.",
                shortDescription: "Advanced iOS",
                instructorId: 1,
                difficultyLevel: "advanced",
                category: "Programming",
                tags: ["Swift", "iOS"],
                thumbnailURL: "https://images.unsplash.com/photo-1599658880436-c61792e70672?w=800&q=80",
                isPublished: true,
                isFeatured: false,
                lessonCount: 15,
                enrollmentCount: 50,
                estimatedDurationHours: 8,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "ml_basics",
                title: "Machine Learning Basics",
                description: "Quick overview of ML concepts.",
                shortDescription: "ML intro",
                instructorId: 1,
                difficultyLevel: "intermediate",
                category: "Data Science",
                tags: ["AI", "ML"],
                thumbnailURL: "https://images.unsplash.com/photo-1555949963-aa79dcee981c?w=800&q=80",
                isPublished: true,
                isFeatured: true,
                lessonCount: 8,
                enrollmentCount: 75,
                estimatedDurationHours: 6,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    /// Generate mock lessons when backend is unavailable
    static func mockLessons() -> [Lesson] {
        return [
            Lesson(
                id: "intro_1",
                title: "Getting Started",
                content: "Welcome to the course!",
                duration: 15,
                order: 1
            ),
            Lesson(
                id: "intro_2",
                title: "Basic Concepts",
                content: "Understanding the fundamentals.",
                duration: 20,
                order: 2
            ),
            Lesson(
                id: "video_1",
                title: "Video Lecture",
                content: "Watch this video.",
                duration: 10,
                order: 3
            )
        ]
    }
    
    /// Generate mock enrollments when backend is unavailable
    static func mockEnrollments() -> [Enrollment] {
        return [
            Enrollment(
                id: "enr_1",
                userId: "demo-user",
                courseId: "python_101",
                enrolledAt: Date(),
                status: "active",
                progress: 0.3
            ),
            Enrollment(
                id: "enr_2",
                userId: "demo-user",
                courseId: "swift_advanced",
                enrolledAt: Date().addingTimeInterval(-86400 * 10),
                status: "active",
                progress: 0.7
            )
        ]
    }
    
    // MARK: - Social API Methods
    // Note: These methods are stubbed until backend social endpoints are available
    
    // Stories
    func createStory(_ request: CreateStoryRequest) async throws -> Story {
        let body = try jsonEncoder.encode(request)
        return try await self.request(method: "POST", path: "/api/v1/stories", body: body)
    }
    
    func fetchStories() async throws -> StoriesResponse {
        return try await self.request(path: "/api/v1/stories")
    }
    
    func deleteStory(storyId: String) async throws {
        let _: EmptyAPIResponse = try await request(method: "DELETE", path: "/api/v1/stories/\(storyId)")
    }
    
    func markStorySeen(storyId: String) async throws {
        let _: EmptyAPIResponse = try await request(method: "POST", path: "/api/v1/stories/\(storyId)/seen")
    }
    
    // Discoveries
    func createDiscovery(_ request: CreateDiscoveryRequest) async throws -> Discovery {
        let body = try jsonEncoder.encode(request)
        return try await self.request(method: "POST", path: "/api/v1/discoveries", body: body)
    }
    
    func fetchMyDiscoveries() async throws -> [Discovery] {
        return try await self.request(path: "/api/v1/discoveries/me")
    }
    
    func fetchSavedDiscoveries() async throws -> [Discovery] {
        return try await self.request(path: "/api/v1/discoveries/saved")
    }
    
    func saveDiscovery(discoveryId: String) async throws {
        let _: EmptyAPIResponse = try await request(method: "POST", path: "/api/v1/discoveries/\(discoveryId)/save")
    }
    
    func unsaveDiscovery(discoveryId: String) async throws {
        let _: EmptyAPIResponse = try await request(method: "DELETE", path: "/api/v1/discoveries/\(discoveryId)/save")
    }
    
    func fetchDiscoveriesFeed(limit: Int = 20, offset: Int = 0) async throws -> DiscoveriesResponse {
        return try await self.request(path: "/api/v1/discoveries/feed?limit=\(limit)&offset=\(offset)")
    }
    
    // Posts
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        // TODO: Implement when backend endpoint is available
        throw APIError.serverError(501, "Not implemented")
    }
    
    func fetchPostsFeed(limit: Int = 20, offset: Int = 0) async throws -> PostsResponse {
        // TODO: Implement when backend endpoint is available
        return PostsResponse(posts: [], total: 0, hasMore: false)
    }
    
    func deletePost(postId: String) async throws {
        // TODO: Implement when backend endpoint is available
    }
    
    func likePost(postId: String) async throws {
        // TODO: Implement when backend endpoint is available
    }
    
    func unlikePost(postId: String) async throws {
        // TODO: Implement when backend endpoint is available
    }
}
