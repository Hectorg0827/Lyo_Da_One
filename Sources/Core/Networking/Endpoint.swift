import Foundation
import CoreLocation

// MARK: - Endpoint Protocol

/// Protocol defining a network endpoint
protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Encodable? { get }
    var queryItems: [URLQueryItem]? { get }
    var cacheKey: String { get }
    var cacheTTL: TimeInterval { get }
    var requiresAuth: Bool { get } // Whether this endpoint requires authentication
}

// MARK: - Default Implementation

extension Endpoint {
    var baseURL: String { AppConfig.baseURL }
    var headers: [String: String]? { nil }
    var body: Encodable? { nil }
    var queryItems: [URLQueryItem]? { nil }
    var cacheKey: String { "\(method.rawValue):\(path)" }
    var cacheTTL: TimeInterval { 300 } // 5 minutes default
    var requiresAuth: Bool { true } // Most endpoints require auth by default

    func buildURLRequest() throws -> URLRequest {
        guard var urlComponents = URLComponents(string: baseURL + path) else {
            throw LyoError.network(.invalidURL)
        }

        // Add query parameters
        if let queryItems = queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw LyoError.network(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body
        if let body = body {
            request.httpBody = try JSONEncoder.lyoEncoder.encode(body)
        }

        return request
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Cache Policy

enum CachePolicy {
    case `default`              // Use cache if available and not expired
    case reloadIgnoringCache    // Always fetch from network
    case cacheOnly              // Use cache even if expired, fail if not available
}

// MARK: - Endpoints Implementation

enum Endpoints {



    // MARK: - Authentication
    enum Auth: Endpoint {
        case login(email: String, password: String)
        case register(email: String, password: String, name: String)
        case refresh(refreshToken: String)
        case logout
        case profile
        case updateProfile(name: String?, avatar: String?)
        case firebase(idToken: String)

        var path: String {
            switch self {
            case .login: return "/auth/login"
            case .register: return "/auth/register"
            case .refresh: return "/auth/refresh"
            case .logout: return "/auth/logout"
            case .profile: return "/auth/me"
            case .updateProfile: return "/auth/profile"
            case .firebase: return "/auth/firebase"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .login, .register, .refresh, .logout, .firebase: return .post
            case .profile: return .get
            case .updateProfile: return .put
            }
        }

        var body: Encodable? {
            switch self {
            case .login(let email, let password):
                return ["email": email, "password": password]

            case .register(let email, let password, let name):
                // Extract username from email and sanitize to only letters, numbers, underscores, hyphens
                let rawUsername = email.components(separatedBy: "@").first ?? email
                var username = rawUsername.replacingOccurrences(of: ".", with: "_")
                    .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
                
                // Ensure username is at least 3 characters
                while username.count < 3 {
                    username += "0"
                }
                
                let nameParts = name.split(separator: " ", maxSplits: 1)
                return [
                    "email": email,
                    "username": String(username),
                    "password": password,
                    "confirm_password": password,
                    "first_name": nameParts.first.map(String.init) ?? "",
                    "last_name": nameParts.count > 1 ? String(nameParts[1]) : ""
                ]

            case .refresh(let token):
                return ["refresh_token": token]

            case .updateProfile(let name, let avatar):
                struct ProfileUpdate: Encodable {
                    let name: String?
                    let avatar_url: String?
                }
                return ProfileUpdate(name: name, avatar_url: avatar)

            case .firebase(let idToken):
                return ["id_token": idToken]

            default:
                return nil
            }
        }

        var cacheTTL: TimeInterval {
            switch self {
            case .profile: return 300 // 5 minutes
            default: return 0 // Don't cache auth requests
            }
        }
        
        var requiresAuth: Bool {
            switch self {
            case .login, .register, .refresh, .firebase:
                return false // These endpoints don't require auth token
            case .logout, .profile, .updateProfile:
                return true // These require an existing session
            }
        }
    }
    
    // MARK: - Memory
    enum Memory: Endpoint {
        case getSummary
        
        var path: String {
            switch self {
            case .getSummary: return "/api/v1/memory/summary"
            }
        }
        
        var method: HTTPMethod { .get }
        
        var cacheTTL: TimeInterval { 300 } // 5 minutes
    }

    // MARK: - Chat Module (v1 Chat API)
    enum ChatModule: Endpoint {
        case sendMessage(payload: Data)
        case getGreeting
        case getCourses
        
        var path: String {
            switch self {
            case .sendMessage:
                return "/api/v1/chat"
            case .getGreeting:
                return "/api/v1/chat/greeting"
            case .getCourses:
                return "/api/v1/chat/courses"
            }
        }
        
        var method: HTTPMethod {
            switch self {
            case .sendMessage:
                return .post
            case .getGreeting, .getCourses:
                return .get
            }
        }
        
        var body: Encodable? {
            switch self {
            case .sendMessage(let payload):
                return DataWrapper(data: payload)
            default:
                return nil
            }
        }
        
        var requiresAuth: Bool { true }
        
        var cacheTTL: TimeInterval {
            switch self {
            case .sendMessage:
                return 0  // Never cache chat messages - each response is unique
            case .getGreeting:
                return 60  // Cache greeting for 1 minute
            case .getCourses:
                return 300  // Cache courses list for 5 minutes
            }
        }
    }
    // MARK: - Classroom (Interactive Cinema)
    enum Classroom: Endpoint {
        case getCourses
        case generateCourse(message: String)
        case getCourse(id: String)
        case startCourse(id: String)
        case advance(courseId: String, currentNodeId: String, timeSpent: Int)
        case submitInteraction(courseId: String, nodeId: String, answerId: String, timeTaken: Double)
        case getLookahead(courseId: String, count: Int)
        case requestRemediation(courseId: String, nodeId: String, complaint: String?, tag: String?)

        var path: String {
            switch self {
            case .getCourses: return "/api/v1/classroom/courses"
            case .generateCourse: return "/api/v1/classroom/chat"
            case .getCourse(let id): return "/api/v1/classroom/courses/\(id)"
            case .startCourse(let id): return "/api/v1/classroom/playback/courses/\(id)/start"
            case .advance(let id, _, _): return "/api/v1/classroom/playback/courses/\(id)/advance"
            case .submitInteraction: return "/api/v1/classroom/playback/interactions/submit"
            case .getLookahead(let id, _): return "/api/v1/classroom/playback/courses/\(id)/lookahead"
            case .requestRemediation: return "/api/v1/classroom/playback/remediation/request"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getCourses, .getCourse, .getLookahead: return .get
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .generateCourse(let message):
                struct GenerateCourseRequest: Encodable {
                    let message: String
                    let include_audio: Bool
                    let stream: Bool
                }
                return GenerateCourseRequest(message: message, include_audio: false, stream: false)
            case .advance(_, let nodeId, _):
                // Note: The original code sent both a JSON body AND a query param.
                // We'll stick to the body as it's more standard for POST.
                // If the backend strictly needs the query param, we'll need to add it to queryItems.
                return ["current_node_id": nodeId]
            case .submitInteraction(let courseId, let nodeId, let answerId, let timeTaken):
                struct SubmitInteractionRequest: Encodable {
                    let course_id: String
                    let node_id: String
                    let answer_id: String
                    let time_taken_seconds: Double
                }
                return SubmitInteractionRequest(
                    course_id: courseId,
                    node_id: nodeId,
                    answer_id: answerId,
                    time_taken_seconds: timeTaken
                )
            case .requestRemediation(let courseId, let nodeId, let complaint, let tag):
                var body: [String: Any] = [
                    "course_id": courseId,
                    "node_id": nodeId
                ]
                if let complaint = complaint { body["user_complaint"] = complaint }
                if let tag = tag { body["misconception_tag"] = tag }
                return EndpointAnyCodable(body)
            default: return nil
            }
        }

        var queryItems: [URLQueryItem]? {
            switch self {
            case .advance(_, _, let timeSpent):
                return [URLQueryItem(name: "time_spent_seconds", value: "\(timeSpent)")]
            case .getLookahead(_, let count):
                return [URLQueryItem(name: "count", value: "\(count)")]
            default: return nil
            }
        }
        
        var cacheTTL: TimeInterval { 0 }
    }

    // MARK: - AI Services
    enum AI: Endpoint {
        case chat(message: String, provider: AIProvider?, context: ChatContext?)
        case generateContent(topic: String, level: SkillLevel, contentType: ContentType)
        case tutorSession(topic: String, question: String, level: String)
        case generateQuiz(topic: String, difficulty: QuizDifficulty, numQuestions: Int)
        case verifyAnswer(question: String, answer: String, correctAnswer: String?)
        case recommend(userId: String)
        case embeddings(query: String, limit: Int)
        case mentorConversation(message: String, context: ChatContext?, attachments: [String]?)
        case mentorChat(message: String, attachments: [String]?, context: ChatContext?)
        case generateCourseStream(topic: String, level: String, outcomes: [String], teachingStyle: String)
        case chatStream(message: String, context: [String: String]?)

        var path: String {
            switch self {
            // Use the lightweight conversational endpoint for chat
            case .chat: return "/api/v1/ai/chat"
            case .chatStream: return "/api/v1/ai/chat/stream"
            case .generateContent: return "/api/v1/ai/generate"
            case .tutorSession: return "/api/v1/ai/generate"
            case .generateQuiz: return "/api/v1/ai/generate"
            case .verifyAnswer: return "/api/v1/ai/generate"
            case .recommend(_): return "/api/v1/ai/recommendations"
            case .embeddings: return "/api/v1/ai/generate"
            case .mentorConversation: return "/api/v1/ai/generate"
            case .mentorChat: return "/ai/mentor/conversation"
            case .generateCourseStream: return "/api/content/generate-course/stream"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .recommend: return .get
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .chat(let message, let provider, let context):
                // Format for /api/v1/ai/chat endpoint (conversational)
                struct AIChatRequest: Encodable {
                    let message: String
                    let stream: Bool
                    let provider: String
                    let context: [String: String]?
                }
                
                let providerId = provider == .openai ? "openai" : "gemini"
                
                var contextDict: [String: String] = [:]
                if let ctx = context {
                    if let courseId = ctx.courseId { contextDict["course_id"] = courseId }
                    if let lessonId = ctx.lessonId { contextDict["lesson_id"] = lessonId }
                }
                
                return AIChatRequest(
                    message: message,
                    stream: false, // Default to non-streaming for LioChatService interactions
                    provider: providerId,
                    context: contextDict.isEmpty ? nil : contextDict
                )

            case .generateContent(let topic, let level, let type):
                struct AIGenerateRequest: Encodable {
                    let prompt: String
                    let task_type: String
                    let max_tokens: Int
                    let temperature: Double
                }
                return AIGenerateRequest(
                    prompt: "Generate \(type.rawValue) content about: \(topic) for \(level.rawValue) level students",
                    task_type: "CONTENT_GENERATION",
                    max_tokens: 2000,
                    temperature: 0.7
                )

            case .tutorSession(let topic, let question, let level):
                struct AIGenerateRequest: Encodable {
                    let prompt: String
                    let task_type: String
                    let max_tokens: Int
                    let temperature: Double
                    let context: [String: String]
                }
                return AIGenerateRequest(
                    prompt: "Topic: \(topic)\nQuestion: \(question)",
                    task_type: "EDUCATIONAL_EXPLANATION",
                    max_tokens: 1500,
                    temperature: 0.7,
                    context: ["level": level, "mode": "tutor"]
                )

            case .generateQuiz(let topic, let difficulty, let num):
                struct AIGenerateRequest: Encodable {
                    let prompt: String
                    let task_type: String
                    let max_tokens: Int
                    let temperature: Double
                    let context: [String: String]
                }
                return AIGenerateRequest(
                    prompt: "Generate a quiz with \(num) questions about \(topic) at \(difficulty.rawValue) difficulty level. Format response as JSON with structure: {\"questions\": [{\"question\": \"...\", \"options\": [\"A\", \"B\", \"C\", \"D\"], \"correct_answer\": \"...\", \"explanation\": \"...\"}]}",
                    task_type: "QUIZ_GENERATION",
                    max_tokens: 3000,
                    temperature: 0.7,
                    context: ["topic": topic, "difficulty": difficulty.rawValue, "num_questions": "\(num)"]
                )

            case .verifyAnswer(let question, let answer, let correct):
                struct VerifyRequest: Encodable {
                    let question: String
                    let answer: String
                    let explain: Bool
                    let correct_answer: String?
                }
                return VerifyRequest(question: question, answer: answer, explain: true, correct_answer: correct)

            case .embeddings(let query, let limit):
                struct EmbeddingsRequest: Encodable {
                    let query: String
                    let limit: Int
                    let use_cache: Bool
                }
                return EmbeddingsRequest(query: query, limit: limit, use_cache: true)

            case .mentorConversation(let message, let context, let attachments):
                struct AIGenerateRequest: Encodable {
                    let prompt: String
                    let task_type: String
                    let max_tokens: Int
                    let temperature: Double
                    let context: [String: String]?
                }
                var contextDict: [String: String]? = nil
                if context != nil || attachments != nil {
                    contextDict = [:]
                    contextDict?["mode"] = "mentor"
                    if let ctx = context {
                        if let courseId = ctx.courseId {
                            contextDict?["course_id"] = courseId
                        }
                        if let lessonId = ctx.lessonId {
                            contextDict?["lesson_id"] = lessonId
                        }
                    }
                    if let atts = attachments, !atts.isEmpty {
                        contextDict?["attachments"] = atts.joined(separator: ",")
                    }
                }
                return AIGenerateRequest(
                    prompt: message,
                    task_type: "EDUCATIONAL_EXPLANATION",
                    max_tokens: 2000,
                    temperature: 0.7,
                    context: contextDict
                )

            case .mentorChat(let message, let attachments, let context):
                return LyoChatRequest(
                    message: message,
                    context: context,
                    attachments: attachments
                )

            case .generateCourseStream(let topic, let level, let outcomes, let style):
                struct GenerateCourseStreamRequest: Encodable {
                    let topic: String
                    let level: String
                    let outcomes: [String]
                    let teaching_style: String
                }
                return GenerateCourseStreamRequest(
                    topic: topic,
                    level: level,
                    outcomes: outcomes,
                    teaching_style: style
                )

            case .chatStream(let message, let context):
                // Matches backend ChatRequest schema: message, conversationHistory, context (String)
                struct ChatStreamRequest: Encodable {
                    let message: String
                    let context: String?  // Backend expects string, not dictionary
                }
                // Convert context dictionary to a string representation
                let contextString = context?.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                return ChatStreamRequest(
                    message: message,
                    context: contextString
                )

            default:
                return nil
            }
        }

        var cacheTTL: TimeInterval {
            // Cache recommendations for 10 minutes
            if case .recommend = self { return 600 }
            // Don't cache AI responses by default (they should be unique)
            return 0
        }
    }

    // MARK: - Adaptive Learning
    enum Learning: Endpoint {
        case createSession(userId: String, goal: String, variables: [String: String])
        case getSession(sessionId: String)
        case interruptSession(sessionId: String, message: String)
        case saveCheckpoint(sessionId: String, progress: LessonProgress)
        case getCourses
        case getCourse(courseId: String)
        case getLesson(lessonId: String)
        case completeLesson(lessonId: String, score: Int?)

        var path: String {
            switch self {
            case .createSession: return "/api/v1/gen-curriculum/generate"
            case .getSession(let id): return "/api/v1/gen-curriculum/\(id)"
            case .interruptSession(_, _): return "/api/v1/ai-study/chat"
            case .saveCheckpoint(_, _): return "/api/v1/analytics/event"
            case .getCourses: return "/api/v1/learning/courses"
            case .getCourse(let id): return "/api/v1/learning/courses/\(id)"
            case .getLesson(let id): return "/api/v1/learning/lessons/\(id)"
            case .completeLesson(_, _): return "/api/v1/analytics/event"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getCourses, .getCourse, .getSession, .getLesson: return .get
            case .saveCheckpoint: return .put
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .createSession(let userId, let goal, let variables):
                struct SessionRequest: Encodable {
                    let user_id: String
                    let goal: String
                    let locale: String
                    let variables: [String: String]
                }
                return SessionRequest(user_id: userId, goal: goal, locale: "en-US", variables: variables)

            case .interruptSession(_, let message):
                return ["message": message]

            case .saveCheckpoint(_, let progress):
                return progress

            case .completeLesson(_, let score):
                if let score = score {
                    return ["score": score]
                }
                return nil

            default:
                return nil
            }
        }

        var cacheTTL: TimeInterval {
            switch self {
            case .getCourses, .getCourse: return 600 // 10 minutes
            case .getLesson: return 300 // 5 minutes
            default: return 0
            }
        }
    }

    // MARK: - Vision Analysis
    enum Vision: Endpoint {
        case analyze(analysisType: VisionAnalysisType)
        case solve
        case ocr

        var path: String {
            switch self {
            case .analyze: return "/api/vision/analyze"
            case .solve: return "/api/vision/solve"
            case .ocr: return "/api/vision/ocr"
            }
        }

        var method: HTTPMethod { .post }

        // Note: Vision endpoints use multipart/form-data, handled separately in upload()
        var cacheTTL: TimeInterval { 0 } // Don't cache vision analysis
    }

    // MARK: - TTS
    enum TTS: Endpoint {
        case generate(text: String, voice: TTSVoice, speed: Double, withTimings: Bool)
        case batch(texts: [String], voice: TTSVoice)
        case getAudio(id: String)
        case getTimings(id: String)
        case voices

        var path: String {
            switch self {
            case .generate: return "/api/tts/generate"
            case .batch: return "/api/tts/batch"
            case .getAudio(let id): return "/api/tts/audio/\(id)"
            case .getTimings(let id): return "/api/tts/timings/\(id)"
            case .voices: return "/api/tts/voices"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .voices, .getAudio, .getTimings: return .get
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .generate(let text, let voice, let speed, let withTimings):
                struct TTSRequest: Encodable {
                    let text: String
                    let voice: String
                    let speed: Double
                    let with_timings: Bool
                }
                return TTSRequest(text: text, voice: voice.rawValue, speed: speed, with_timings: withTimings)

            case .batch(let texts, let voice):
                struct TTSBatchRequest: Encodable {
                    let texts: [String]
                    let voice: String
                }
                return TTSBatchRequest(texts: texts, voice: voice.rawValue)

            default:
                return nil
            }
        }

        var cacheTTL: TimeInterval {
            switch self {
            case .voices: return 3600 // 1 hour
            case .getAudio, .getTimings: return 7200 // 2 hours
            default: return 0
            }
        }
    }

    // MARK: - Course Generation V2
    enum CourseGenerationV2: Endpoint {
        case stream(topic: String, options: CourseGenerationOptions)
        
        var path: String { "/api/v2/courses/stream" }
        var method: HTTPMethod { .post }
        var body: Encodable? {
            switch self {
            case .stream(let topic, let options):
                struct StreamRequest: Encodable {
                    let topic: String
                    let quality_tier: String
                    let enable_code_examples: Bool
                    let enable_practice_exercises: Bool
                    let enable_final_quiz: Bool
                    let enable_multimedia_suggestions: Bool
                    let qa_strictness: String
                    let target_language: String
                    let max_budget_usd: Double?
                }
                return StreamRequest(
                    topic: topic,
                    quality_tier: options.qualityTier.rawValue,
                    enable_code_examples: options.includeCodeExamples,
                    enable_practice_exercises: options.includePracticeExercises,
                    enable_final_quiz: options.includeFinalQuiz,
                    enable_multimedia_suggestions: options.includeMultimediaSuggestions,
                    qa_strictness: options.qaStrictness,
                    target_language: options.targetLanguage,
                    max_budget_usd: options.maxBudgetUSD
                )
            }
        }
        var cacheTTL: TimeInterval { 0 }
    }

    // MARK: - Files
    enum Files: Endpoint {
        case upload
        
        var path: String { "/api/v1/files/upload" }
        var method: HTTPMethod { .post }
        var body: Encodable? { nil }
        var cacheTTL: TimeInterval { 0 }
    }

    // MARK: - Stack
    enum Stack: Endpoint {
        case getItems
        case createItem(item: CreateStackItemRequest)
        case updateItem(id: String, item: UpdateStackItemRequest)
        case deleteItem(id: String)

        var path: String {
            switch self {
            case .getItems: return "/stack/items"
            case .createItem: return "/stack/items"
            case .updateItem(let id, _): return "/stack/items/\(id)"
            case .deleteItem(let id): return "/stack/items/\(id)"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getItems: return .get
            case .createItem: return .post
            case .updateItem: return .patch
            case .deleteItem: return .delete
            }
        }

        var body: Encodable? {
            switch self {
            case .createItem(let item): return item
            case .updateItem(_, let item): return item
            default: return nil
            }
        }
        
        var cacheTTL: TimeInterval { 0 }
    }

    // MARK: - Gamification
    enum Gamification: Endpoint {
        // XP
        case awardXP(amount: Int, activity: String, metadata: [String: String]?)
        case getXPSummary
        
        // Level
        case getUserLevel
        
        // Leaderboard
        case getLeaderboard(type: String, limit: Int)
        case getMyRank(type: String)
        
        // Streaks
        case getStreaks
        case updateStreak(type: String)
        
        // Achievements
        case getAchievements
        case getMyAchievements
        case checkAchievement(achievementId: String)
        
        // Badges
        case getMyBadges
        case equipBadge(badgeId: String, equipped: Bool)
        
        // Stats & Overview
        case getGamificationStats
        case getGamificationOverview

        var path: String {
            switch self {
            // XP
            case .awardXP: return "/gamification/xp/award"
            case .getXPSummary: return "/gamification/xp/summary"
            
            // Level
            case .getUserLevel: return "/gamification/level"
            
            // Leaderboard
            case .getLeaderboard(let type, _): return "/gamification/leaderboards/\(type)"
            case .getMyRank(let type): return "/gamification/leaderboards/\(type)/my-rank"
            
            // Streaks
            case .getStreaks: return "/gamification/streaks"
            case .updateStreak(let type): return "/gamification/streaks/\(type)/update"
            
            // Achievements
            case .getAchievements: return "/gamification/achievements"
            case .getMyAchievements: return "/gamification/my-achievements"
            case .checkAchievement(let id): return "/gamification/achievements/\(id)/check"
            
            // Badges
            case .getMyBadges: return "/gamification/my-badges"
            case .equipBadge(let id, _): return "/gamification/my-badges/\(id)"
            
            // Stats & Overview
            case .getGamificationStats: return "/gamification/stats"
            case .getGamificationOverview: return "/gamification/overview"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getXPSummary, .getUserLevel, .getLeaderboard, .getMyRank,
                 .getStreaks, .getAchievements, .getMyAchievements,
                 .getMyBadges, .getGamificationStats, .getGamificationOverview:
                return .get
            case .equipBadge:
                return .put
            default:
                return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .awardXP(let amount, let activity, let metadata):
                struct XPRequest: Encodable {
                    let amount: Int
                    let activity: String
                    let metadata: [String: String]?
                }
                return XPRequest(amount: amount, activity: activity, metadata: metadata)

            case .equipBadge(_, let equipped):
                return ["equipped": equipped]

            default:
                return nil
            }
        }

        var queryItems: [URLQueryItem]? {
            switch self {
            case .getLeaderboard(_, let limit):
                return [
                    URLQueryItem(name: "limit", value: "\(limit)")
                ]
            default:
                return nil
            }
        }

        var cacheTTL: TimeInterval {
            switch self {
            case .getLeaderboard, .getMyRank: return 60 // 1 minute
            case .getAchievements, .getMyAchievements: return 300 // 5 minutes
            case .getGamificationStats, .getGamificationOverview: return 120 // 2 minutes
            case .getStreaks: return 60
            default: return 0
            }
        }
    }

    // MARK: - Course Social
    enum CourseSocial: Endpoint {
        case likeCourse(courseId: String)
        case unlikeCourse(courseId: String)
        case rateCourse(courseId: String, rating: Int)
        case getCourseSocialStats(courseId: String)
        case getBulkCourseSocialStats(courseIds: [String])

        var path: String {
            switch self {
            case .likeCourse(let id): return "/api/v1/courses/\(id)/like"
            case .unlikeCourse(let id): return "/api/v1/courses/\(id)/like"
            case .rateCourse(let id, _): return "/api/v1/courses/\(id)/rating"
            case .getCourseSocialStats(let id): return "/api/v1/courses/\(id)/social-stats"
            case .getBulkCourseSocialStats: return "/api/v1/courses/bulk-social-stats"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .likeCourse, .rateCourse, .getBulkCourseSocialStats: return .post
            case .unlikeCourse: return .delete
            case .getCourseSocialStats: return .get
            }
        }

        var body: Encodable? {
            switch self {
            case .rateCourse(_, let rating):
                return ["rating": rating]
            case .getBulkCourseSocialStats(let courseIds):
                return ["course_ids": courseIds]
            default:
                return nil
            }
        }

        var cacheTTL: TimeInterval {
            switch self {
            case .getCourseSocialStats: return 60 // 1 minute
            case .getBulkCourseSocialStats: return 60
            default: return 0
            }
        }
    }

    // MARK: - Community Hub
    enum Community: Endpoint {
        // Study Groups
        case getStudyGroups(filters: CommunityFilter?, location: CLLocationCoordinate2D?)
        case getStudyGroup(id: String)
        case createStudyGroup(group: StudyGroup)
        case joinStudyGroup(groupId: String)
        case leaveStudyGroup(groupId: String)
        case getUserGroups // NEW

        // Events
        case getEvents(filters: CommunityFilter?, location: CLLocationCoordinate2D?)
        case getEvent(id: String)
        case createEvent(event: EducationalEvent)
        case registerForEvent(eventId: String)
        case unregisterFromEvent(eventId: String)
        case getUserEvents // NEW

        // Marketplace
        case getListings(filters: CommunityFilter?, location: CLLocationCoordinate2D?)
        case getListing(id: String)
        case createListing(listing: MarketplaceListing)
        case updateListing(listingId: String, status: MarketplaceListing.ListingStatus)
        case deleteListing(listingId: String)

        // Beacons & Questions
        case getBeacons(lat: Double, lng: Double, radius: Double)
        case createQuestion(question: APICreateQuestionRequest)
        case answerQuestion(id: String, answer: String)
        
        // Institutions
        case getInstitutions(filters: CommunityFilter?, location: CLLocationCoordinate2D?)
        case getInstitution(id: String)
        case searchInstitutions(query: String, location: CLLocationCoordinate2D?)
        
        // Private Lessons & Bookings (NEW)
        case getPrivateLesson(id: Int)
        case getAvailableSlots(lessonId: Int, date: Date)
        case createBooking(request: APIBookingRequest)
        case getUserBookings
        case cancelBooking(bookingId: String)
        
        // Reviews (NEW)
        case getReviews(targetType: String, targetId: String)
        case submitReview(request: APIReviewRequest)
        case getReviewStats(targetType: String, targetId: String)

        var path: String {
            switch self {
            // Study Groups
            case .getStudyGroups: return "/api/v1/community/study-groups"
            case .getStudyGroup(let id): return "/api/v1/community/study-groups/\(id)"
            case .createStudyGroup: return "/api/v1/community/study-groups"
            case .joinStudyGroup(let id): return "/api/v1/community/study-groups/\(id)/join"
            case .leaveStudyGroup(let id): return "/api/v1/community/study-groups/\(id)/leave"
            case .getUserGroups: return "/api/v1/community/study-groups/my"

            // Events
            case .getEvents: return "/api/v1/community/events"
            case .getEvent(let id): return "/api/v1/community/events/\(id)"
            case .createEvent: return "/api/v1/community/events"
            case .registerForEvent(let id): return "/api/v1/community/events/\(id)/register"
            case .unregisterFromEvent(let id): return "/api/v1/community/events/\(id)/unregister"
            case .getUserEvents: return "/api/v1/community/events/my"

            // Marketplace
            case .getListings: return "/api/v1/community/marketplace"
            case .getListing(let id): return "/api/v1/community/marketplace/\(id)"
            case .createListing: return "/api/v1/community/marketplace"
            case .updateListing(let id, _): return "/api/v1/community/marketplace/\(id)"
            case .deleteListing(let id): return "/api/v1/community/marketplace/\(id)"

            // Beacons & Questions
            case .getBeacons: return "/api/v1/community/beacons"
            case .createQuestion: return "/api/v1/community/questions"
            case .answerQuestion(let id, _): return "/api/v1/community/questions/\(id)/answers"

            // Institutions
            case .getInstitutions: return "/api/v1/community/institutions"
            case .getInstitution(let id): return "/api/v1/community/institutions/\(id)"
            case .searchInstitutions: return "/api/v1/community/institutions/search"
            
            // Private Lessons & Bookings
            case .getPrivateLesson(let id): return "/api/v1/community/lessons/\(id)"
            case .getAvailableSlots(let id, _): return "/api/v1/community/lessons/\(id)/slots"
            case .createBooking: return "/api/v1/community/bookings"
            case .getUserBookings: return "/api/v1/community/bookings/my"
            case .cancelBooking(let id): return "/api/v1/community/bookings/\(id)"
            
            // Reviews
            case .getReviews(let type, let id): return "/api/v1/community/reviews/\(type)/\(id)"
            case .submitReview: return "/api/v1/community/reviews"
            case .getReviewStats(let type, let id): return "/api/v1/community/reviews/\(type)/\(id)/stats"
            }
        }

        var method: HTTPMethod {
            switch self {
             case .getStudyGroups, .getStudyGroup, .getEvents, .getEvent,
                  .getListings, .getListing, .getInstitutions, .getInstitution, .searchInstitutions,
                  .getBeacons,
                  .getPrivateLesson, .getAvailableSlots, .getUserBookings,
                  .getReviews, .getReviewStats,
                  .getUserGroups, .getUserEvents:
                 return .get

            case .createStudyGroup, .joinStudyGroup,
                 .createEvent, .registerForEvent,
                 .createListing, .createQuestion, .answerQuestion,
                 .createBooking, .submitReview:
                return .post
            
            case .leaveStudyGroup, .unregisterFromEvent, .cancelBooking:
                return .delete

            case .updateListing:
                return .put

            case .deleteListing:
                return .delete
            }
        }

        var body: Encodable? {
            switch self {
            case .createStudyGroup(let group):
                return group

            case .createEvent(let event):
                return event
                
            case .createQuestion(let question):
                return question
                
            case .answerQuestion(_, let answer):
                return ["answer": answer]

            case .createListing(let listing):
                return listing

            case .updateListing(_, let status):
                return ["status": status.rawValue]
                
            case .createBooking(let request):
                return request
                
            case .submitReview(let request):
                return request

            default:
                return nil
            }
        }

        var queryItems: [URLQueryItem]? {
            var items: [URLQueryItem] = []

            switch self {
            case .getStudyGroups(let filters, let location),
                 .getEvents(let filters, let location),
                 .getListings(let filters, let location),
                 .getInstitutions(let filters, let location):

                if let filters = filters {
                    items.append(URLQueryItem(name: "filter", value: filters.id))
                }

                if let location = location {
                    items.append(URLQueryItem(name: "lat", value: "\(location.latitude)"))
                    items.append(URLQueryItem(name: "lng", value: "\(location.longitude)"))
                }

            case .searchInstitutions(let query, let location):
                items.append(URLQueryItem(name: "q", value: query))

                if let location = location {
                    items.append(URLQueryItem(name: "lat", value: "\(location.latitude)"))
                    items.append(URLQueryItem(name: "lng", value: "\(location.longitude)"))
                }
                
            case .getBeacons(let lat, let lng, let radius):
                items.append(URLQueryItem(name: "lat", value: "\(lat)"))
                items.append(URLQueryItem(name: "lng", value: "\(lng)"))
                items.append(URLQueryItem(name: "radius_km", value: "\(radius)"))
                items.append(URLQueryItem(name: "include_events", value: "true"))
                items.append(URLQueryItem(name: "include_users", value: "true"))
                items.append(URLQueryItem(name: "include_questions", value: "true"))
            
            case .getAvailableSlots(_, let date):
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate] // YYYY-MM-DD
                items.append(URLQueryItem(name: "date", value: formatter.string(from: date)))

            default:
                break
            }

            return items.isEmpty ? nil : items
        }

        var cacheTTL: TimeInterval {
            switch self {
            case .getStudyGroups, .getEvents, .getListings, .getInstitutions:
                return 60 // 1 minute for lists
            case .getStudyGroup, .getEvent, .getListing, .getInstitution,
                 .getPrivateLesson, .getReviewStats:
                return 300 // 5 minutes for details
            case .searchInstitutions:
                return 180 // 3 minutes for search
            default:
                return 0
            }
        }
    }
    
    // MARK: - Push Notifications
    enum Push: Endpoint {
        case registerDevice(token: String, type: String, info: [String: String]?, appVersion: String?, osVersion: String?)
        case listDevices
        case unregisterDevice(deviceId: String)
        case testPush(title: String, body: String)
        case getPreferences
        case updatePreferences(preferences: NotificationPreferences)

        var path: String {
            switch self {
            case .registerDevice: return "/api/v1/push/devices/register"
            case .listDevices: return "/api/v1/push/devices"
            case .unregisterDevice(let id): return "/api/v1/push/devices/\(id)"
            case .testPush: return "/api/v1/push/test"
            case .getPreferences, .updatePreferences: return "/api/v1/push/preferences"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .listDevices, .getPreferences: return .get
            case .registerDevice, .testPush: return .post
            case .updatePreferences: return .put
            case .unregisterDevice: return .delete
            }
        }

        var body: Encodable? {
            switch self {
            case .registerDevice(let token, let type, let info, let appVersion, let osVersion):
                struct RegisterDeviceRequest: Encodable {
                    let device_token: String
                    let device_type: String
                    let info: [String: String]?
                    let app_version: String?
                    let os_version: String?
                }
                return RegisterDeviceRequest(
                    device_token: token,
                    device_type: type,
                    info: info,
                    app_version: appVersion,
                    os_version: osVersion
                )
                
            case .testPush(let title, let body):
                return ["title": title, "body": body]
                
            case .updatePreferences(let prefs):
                return prefs
                
            default: return nil
            }
        }
    }

    // MARK: - Analytics
    enum Analytics: Endpoint {
        case startSession(deviceInfo: [String: String]?)
        case trackEvent(name: String, category: String, properties: [String: String]?, sessionId: String?)
        case trackScreenView(screenName: String, sessionId: String?, properties: [String: String]?)
        case trackLearningProgress(contentId: String, progress: Double, timeSpent: Int, sessionId: String?)
        case trackAIInteraction(interactionType: String, sessionId: String?)
        case getUserStats(days: Int)
        case getLearningInsights

        var path: String {
            switch self {
            case .startSession: return "/analytics/sessions"
            case .trackEvent: return "/analytics/events"
            case .trackScreenView: return "/analytics/screens"
            case .trackLearningProgress: return "/analytics/progress"
            case .trackAIInteraction: return "/analytics/ai-interactions"
            case .getUserStats: return "/analytics/stats"
            case .getLearningInsights: return "/analytics/insights"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getUserStats, .getLearningInsights: return .get
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .startSession(let deviceInfo):
                return ["device_info": deviceInfo]
            case .trackEvent(let name, let category, let properties, let sessionId):
                struct EventRequest: Encodable {
                    let name: String
                    let category: String
                    let properties: [String: String]?
                    let session_id: String?
                }
                return EventRequest(name: name, category: category, properties: properties, session_id: sessionId)
            case .trackScreenView(let screenName, let sessionId, let properties):
                struct ScreenRequest: Encodable {
                    let screen_name: String
                    let session_id: String?
                    let properties: [String: String]?
                }
                return ScreenRequest(screen_name: screenName, session_id: sessionId, properties: properties)
            case .trackLearningProgress(let contentId, let progress, let timeSpent, let sessionId):
                struct ProgressRequest: Encodable {
                    let content_id: String
                    let progress: Double
                    let time_spent: Int
                    let session_id: String?
                }
                return ProgressRequest(content_id: contentId, progress: progress, time_spent: timeSpent, session_id: sessionId)
            case .trackAIInteraction(let interactionType, let sessionId):
                struct AIInteractionRequest: Encodable {
                    let interaction_type: String
                    let session_id: String?
                }
                return AIInteractionRequest(interaction_type: interactionType, session_id: sessionId)
            default: return nil
            }
        }
        
        var queryItems: [URLQueryItem]? {
            switch self {
            case .getUserStats(let days):
                return [URLQueryItem(name: "days", value: "\(days)")]
            default: return nil
            }
        }
    }

    // MARK: - Storage
    enum Storage: Endpoint {
        case getPresignedUrl(filename: String, contentType: String, folder: String)
        case deleteAvatar
        case getUsage
        case deleteFile(blobName: String)

        var path: String {
            switch self {
            case .getPresignedUrl: return "/storage/presigned-url"
            case .deleteAvatar: return "/storage/avatar"
            case .getUsage: return "/storage/usage"
            case .deleteFile(let blobName): return "/storage/files/\(blobName)"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getPresignedUrl: return .post
            case .deleteAvatar, .deleteFile: return .delete
            case .getUsage: return .get
            }
        }

        var body: Encodable? {
            switch self {
            case .getPresignedUrl(let filename, let contentType, let folder):
                struct PresignedRequest: Encodable {
                    let filename: String
                    let content_type: String
                    let folder: String
                }
                return PresignedRequest(filename: filename, content_type: contentType, folder: folder)
            default: return nil
            }
        }
    }

    // MARK: - Notifications
    enum Notifications: Endpoint {
        case getNotifications(unreadOnly: Bool, category: String?, limit: Int, offset: Int)
        case getUnreadCount
        case markRead(notificationId: Int)
        case markAllRead(category: String?)
        case deleteNotification(notificationId: Int, archive: Bool)

        var path: String {
            switch self {
            case .getNotifications: return "/notifications"
            case .getUnreadCount: return "/notifications/unread-count"
            case .markRead(let id): return "/notifications/\(id)/read"
            case .markAllRead: return "/notifications/read-all"
            case .deleteNotification(let id, _): return "/notifications/\(id)"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getNotifications, .getUnreadCount: return .get
            case .markRead, .markAllRead: return .post
            case .deleteNotification: return .delete
            }
        }

        var queryItems: [URLQueryItem]? {
            switch self {
            case .getNotifications(let unreadOnly, let category, let limit, let offset):
                var items = [
                    URLQueryItem(name: "unread_only", value: "\(unreadOnly)"),
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
                if let category = category {
                    items.append(URLQueryItem(name: "category", value: category))
                }
                return items
            case .markAllRead(let category):
                if let category = category {
                    return [URLQueryItem(name: "category", value: category)]
                }
                return nil
            case .deleteNotification(_, let archive):
                return [URLQueryItem(name: "archive", value: "\(archive)")]
            default: return nil
            }
        }
    }

    // MARK: - Search
    enum Search: Endpoint {
        case autocomplete(query: String, limit: Int)
        case search(query: String, type: String, limit: Int, offset: Int)
        case searchUsers(query: String, limit: Int, offset: Int)
        case getTrending(limit: Int)
        case getRecentSearches(limit: Int)
        case clearRecentSearches

        var path: String {
            switch self {
            case .autocomplete: return "/search/autocomplete"
            case .search: return "/search"
            case .searchUsers: return "/search/users"
            case .getTrending: return "/search/trending"
            case .getRecentSearches: return "/search/recent"
            case .clearRecentSearches: return "/search/recent"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .clearRecentSearches: return .delete
            default: return .get
            }
        }

        var queryItems: [URLQueryItem]? {
            switch self {
            case .autocomplete(let query, let limit):
                return [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "limit", value: "\(limit)")
                ]
            case .search(let query, let type, let limit, let offset):
                return [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "type", value: type),
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
            case .searchUsers(let query, let limit, let offset):
                return [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
            case .getTrending(let limit), .getRecentSearches(let limit):
                return [URLQueryItem(name: "limit", value: "\(limit)")]
            default: return nil
            }
        }
    }

    // MARK: - Messaging
    enum Messaging: Endpoint {
        case getConversations(limit: Int, offset: Int)
        case getConversation(conversationId: String)
        case getMessages(conversationId: String, limit: Int, before: String?)
        case sendMessage(conversationId: String, content: String, mediaUrl: String?, mediaType: String?, replyToId: String?)
        case createConversation(participantIds: [Int], name: String?, isGroup: Bool)
        case markRead(conversationId: String, messageId: String)
        case addReaction(conversationId: String, messageId: String, emoji: String)
        case getUnreadCount
        case leaveConversation(conversationId: String)

        var path: String {
            switch self {
            case .getConversations: return "/messaging/conversations"
            case .getConversation(let id): return "/messaging/conversations/\(id)"
            case .getMessages(let id, _, _): return "/messaging/conversations/\(id)/messages"
            case .sendMessage(let id, _, _, _, _): return "/messaging/conversations/\(id)/messages"
            case .createConversation: return "/messaging/conversations"
            case .markRead(let cid, let mid): return "/messaging/conversations/\(cid)/messages/\(mid)/read"
            case .addReaction(let cid, let mid, _): return "/messaging/conversations/\(cid)/messages/\(mid)/reactions"
            case .getUnreadCount: return "/messaging/unread-count"
            case .leaveConversation(let id): return "/messaging/conversations/\(id)/leave"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getConversations, .getConversation, .getMessages, .getUnreadCount: return .get
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .sendMessage(_, let content, let mediaUrl, let mediaType, let replyToId):
                struct SendMessageRequest: Encodable {
                    let content: String
                    let media_url: String?
                    let media_type: String?
                    let reply_to_id: String?
                }
                return SendMessageRequest(content: content, media_url: mediaUrl, media_type: mediaType, reply_to_id: replyToId)
            case .createConversation(let participantIds, let name, let isGroup):
                struct CreateConversationRequest: Encodable {
                    let participant_ids: [Int]
                    let name: String?
                    let is_group: Bool
                }
                return CreateConversationRequest(participant_ids: participantIds, name: name, is_group: isGroup)
            case .addReaction(_, _, let emoji):
                return ["emoji": emoji]
            default: return nil
            }
        }

        var queryItems: [URLQueryItem]? {
            switch self {
            case .getConversations(let limit, let offset):
                return [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
            case .getMessages(_, let limit, let before):
                var items = [URLQueryItem(name: "limit", value: "\(limit)")]
                if let before = before {
                    items.append(URLQueryItem(name: "before", value: before))
                }
                return items
            default: return nil
            }
        }
    }

    // MARK: - Social
    enum Social: Endpoint {
        case getFeed(page: Int, perPage: Int)
        case createPost(content: String?, postType: String, imageUrl: String?, videoUrl: String?, linkUrl: String?, isPublic: Bool)
        case getPost(postId: Int)
        case deletePost(postId: Int)
        case reactToPost(postId: Int, reactionType: String)
        case removeReaction(postId: Int)
        case getComments(postId: Int, limit: Int, offset: Int)
        case addComment(postId: Int, content: String, parentId: Int?)
        case deleteComment(postId: Int, commentId: Int)
        case followUser(userId: Int)
        case unfollowUser(userId: Int)
        case getFollowers(userId: Int, limit: Int, offset: Int)
        case getFollowing(userId: Int, limit: Int, offset: Int)
        case getUserStats(userId: Int)

        var path: String {
            switch self {
            case .getFeed: return "/api/v1/feed"
            case .createPost: return "/api/v1/posts"
            case .getPost(let id): return "/api/v1/posts/\(id)"
            case .deletePost(let id): return "/api/v1/posts/\(id)"
            case .reactToPost(let id, _): return "/api/v1/posts/\(id)/reactions"
            case .removeReaction(let id): return "/api/v1/posts/\(id)/reactions"
            case .getComments(let id, _, _): return "/api/v1/posts/\(id)/comments"
            case .addComment(let id, _, _): return "/api/v1/posts/\(id)/comments"
            case .deleteComment(let pid, let cid): return "/api/v1/posts/\(pid)/comments/\(cid)"
            case .followUser(_): return "/api/v1/follow"
            case .unfollowUser(let id): return "/api/v1/follow/\(id)"
            case .getFollowers(let id, _, _): return "/api/v1/users/\(id)/followers"
            case .getFollowing(let id, _, _): return "/api/v1/users/\(id)/following"
            case .getUserStats(let id): return "/api/v1/users/\(id)/stats"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getFeed, .getPost, .getComments, .getFollowers, .getFollowing, .getUserStats: return .get
            case .deletePost, .removeReaction, .deleteComment, .unfollowUser: return .delete
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .createPost(let content, let postType, let imageUrl, let videoUrl, let linkUrl, let isPublic):
                struct CreatePostRequest: Encodable {
                    let content: String?
                    let post_type: String
                    let image_url: String?
                    let video_url: String?
                    let link_url: String?
                    let is_public: Bool
                }
                return CreatePostRequest(content: content, post_type: postType, image_url: imageUrl, video_url: videoUrl, link_url: linkUrl, is_public: isPublic)
            case .reactToPost(_, let reactionType):
                return ["reaction_type": reactionType]
            case .addComment(_, let content, let parentId):
                struct CommentRequest: Encodable {
                    let content: String
                    let parent_id: Int?
                }
                return CommentRequest(content: content, parent_id: parentId)
            default: return nil
            }
        }

        var queryItems: [URLQueryItem]? {
            switch self {
            case .getFeed(let page, let perPage):
                return [
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "per_page", value: "\(perPage)")
                ]
            case .getComments(_, let limit, let offset),
                 .getFollowers(_, let limit, let offset),
                 .getFollowing(_, let limit, let offset):
                return [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
            default: return nil
            }
        }
    }

    // MARK: - Monetization
    enum Monetization: Endpoint {
        case getStatus
        case getPlans
        case createCheckoutSession(planId: String)
        case verifyAppleReceipt(receiptData: String)
        case verifyGooglePurchase(packageName: String, productId: String, purchaseToken: String)
        case getEnergy
        case consumeEnergy(amount: Int, action: String)
        case cancelSubscription

        var path: String {
            switch self {
            case .getStatus: return "/monetization/status"
            case .getPlans: return "/monetization/plans"
            case .createCheckoutSession: return "/monetization/checkout"
            case .verifyAppleReceipt: return "/monetization/verify/apple"
            case .verifyGooglePurchase: return "/monetization/verify/google"
            case .getEnergy: return "/monetization/energy"
            case .consumeEnergy: return "/monetization/energy/consume"
            case .cancelSubscription: return "/monetization/subscription"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .getStatus, .getPlans, .getEnergy: return .get
            case .cancelSubscription: return .delete
            default: return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .createCheckoutSession(let planId):
                return ["plan_id": planId]
            case .verifyAppleReceipt(let receiptData):
                return ["receipt_data": receiptData]
            case .verifyGooglePurchase(let packageName, let productId, let purchaseToken):
                return [
                    "package_name": packageName,
                    "product_id": productId,
                    "purchase_token": purchaseToken
                ]
            case .consumeEnergy(let amount, let action):
                struct Body: Encodable {
                    let amount: Int
                    let action: String
                }
                return Body(amount: amount, action: action)
            default: return nil
            }
        }
    }
}

// MARK: - Supporting Enums

enum AIProvider: String, Codable {
    case gemini
    case openai
}

enum SkillLevel: String, Codable {
    case beginner
    case intermediate
    case advanced
}

enum ContentType: String, Codable {
    case lesson
    case summary
    case examples
    case exercises
}

enum QuizDifficulty: String, Codable {
    case easy
    case medium
    case hard
    case adaptive
}

enum VisionAnalysisType: String, Codable {
    case general
    case diagram
    case chart
    case ocr
    case problemSolving = "problem_solving"
    case code
    case educational
}

enum TTSVoice: String, Codable {
    case alloy
    case echo
    case fable
    case onyx
    case nova
    case shimmer
}

// MARK: - Notification Settings Update
struct NotificationSettingsUpdate: Codable {
    let pushEnabled: Bool
    let emailEnabled: Bool
    let learningReminders: Bool
    let socialNotifications: Bool
    let achievementNotifications: Bool
    let communityUpdates: Bool
    
    enum CodingKeys: String, CodingKey {
        case pushEnabled = "push_enabled"
        case emailEnabled = "email_enabled"
        case learningReminders = "learning_reminders"
        case socialNotifications = "social_notifications"
        case achievementNotifications = "achievement_notifications"
        case communityUpdates = "community_updates"
    }
}

// MARK: - Helper Extension

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder.lyoEncoder.encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "EncodingError", code: 0, userInfo: nil)
        }
        return dictionary
    }
}

// MARK: - Data Wrapper for Raw Body Data
/// Wrapper that allows passing pre-encoded Data as an Encodable body
struct DataWrapper: Encodable {
    let data: Data
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // The data is already JSON-encoded, so we decode and re-encode
        // to maintain proper JSON structure
        if let json = try? JSONSerialization.jsonObject(with: data) {
            if let dict = json as? [String: Any] {
                try container.encode(dict.mapValues { EndpointAnyCodable($0) })
            }
        }
    }
}

/// Helper for encoding Any values (scoped to endpoints to avoid conflicts)
private struct EndpointAnyCodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { EndpointAnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { EndpointAnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Dynamic Endpoint Support

struct DynamicEndpoint: Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]?
    let customBaseURL: String?
    let requiresAuth: Bool
    
    var baseURL: String { customBaseURL ?? AppConfig.baseURL }
    
    init(urlString: String, method: HTTPMethod, body: Encodable? = nil, requiresAuth: Bool = true) {
        self.method = method
        self.body = body
        self.requiresAuth = requiresAuth
        
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            if let components = URLComponents(string: urlString) {
                self.customBaseURL = "\(components.scheme!)://\(components.host!)\(components.port.map { ":\($0)" } ?? "")"
                self.path = components.path
                self.queryItems = components.queryItems
            } else {
                self.customBaseURL = nil
                self.path = urlString
                self.queryItems = nil
            }
        } else {
            self.customBaseURL = nil
            if let components = URLComponents(string: urlString) {
                self.path = components.path
                self.queryItems = components.queryItems
            } else {
                self.path = urlString
                self.queryItems = nil
            }
        }
    }
    
    // Dynamic endpoints shouldn't be cached by default as we don't know their nature
    var cacheTTL: TimeInterval { 0 }
}

