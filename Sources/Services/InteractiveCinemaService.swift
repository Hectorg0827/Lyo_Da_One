import Foundation

// MARK: - Interactive Cinema Service
// This service interfaces with the backend's graph-based course system
// NOT the basic Gemini wrapper!

@MainActor
public final class InteractiveCinemaService: ObservableObject {
    public static let shared = InteractiveCinemaService()
    
    @Published public var isLoading: Bool = false
    @Published public var currentPlaybackState: PlaybackState?
    @Published public var error: String?
    
    private let baseURL: String
    private let session: URLSession
    private let tokenManager = TokenManager.shared
    
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
    
    private init() {
        self.baseURL = AppConfig.baseURL
        self.session = URLSession.shared
    }
    
    // MARK: - Course Discovery & Generation
    
    public func getAvailableCourses() async throws -> [GraphCourseItem] {
        let endpoint = "\(baseURL)/api/v1/classroom/courses"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CinemaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CinemaError.unauthorized
            }
            throw CinemaError.serverError(httpResponse.statusCode)
        }
        
        let courses = try jsonDecoder.decode([GraphCourseItem].self, from: data)
        return courses
    }
    
    public func generateGraphCourse(topic: String, level: String = "beginner") async throws -> GraphCourseItem {
        // Use the chat endpoint which intelligently handles course generation
        let endpoint = "\(baseURL)/api/v1/classroom/chat"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        print("📡 Generating graph course via chat: \(topic) at \(level) level")
        print("   Endpoint: \(endpoint)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            print("🔐 Using Firebase token (first 20 chars): \(String(token.prefix(20)))...")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ No Firebase token available - request will be unauthenticated")
        }
        
        // Format message to request course generation
        let message = "Create a complete interactive course on '\(topic)' suitable for \(level) learners. Include multiple lessons with explanations, examples, and practice questions."
        
        let requestBody: [String: Any] = [
            "message": message,
            "include_audio": false,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120 // Extended timeout for course generation
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CinemaError.invalidResponse
            }
            
            print("📡 Chat Response - Status: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("❌ Server Error Response: \(responseBody)")
                }
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw CinemaError.unauthorized
                }
                throw CinemaError.serverError(httpResponse.statusCode)
            }
            
            // Parse chat response to extract course information
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ Chat response received")

                func extractCourseId(from payload: [String: Any]) -> String? {
                    // Support both snake_case and camelCase keys depending on backend serialization.
                    if let id = payload["generated_course_id"] as? String { return id }
                    if let id = payload["generatedCourseId"] as? String { return id }
                    if let id = payload["course_id"] as? String { return id }
                    if let id = payload["courseId"] as? String { return id }

                    if let metadata = payload["metadata"] as? [String: Any] {
                        if let id = metadata["generated_course_id"] as? String { return id }
                        if let id = metadata["generatedCourseId"] as? String { return id }
                        if let id = metadata["course_id"] as? String { return id }
                        if let id = metadata["courseId"] as? String { return id }
                    }

                    if let actions = payload["actions"] as? [[String: Any]] {
                        for action in actions {
                            if let id = action["generated_course_id"] as? String { return id }
                            if let id = action["generatedCourseId"] as? String { return id }
                            if let id = action["course_id"] as? String { return id }
                            if let id = action["courseId"] as? String { return id }
                        }
                    }
                    return nil
                }

                if let courseId = extractCourseId(from: json) {
                    print("✅ Course generated with ID: \(courseId)")
                    let course = try await fetchCourseDetails(courseId: courseId)
                    return course
                }

                if let responseBody = String(data: data, encoding: .utf8) {
                    let maxChars = 4000
                    let truncated = responseBody.count > maxChars ? String(responseBody.prefix(maxChars)) + "…" : responseBody
                    print("⚠️ Chat response missing course ID. Keys: \(Array(json.keys).sorted())")
                    print("⚠️ Chat response body (truncated): \n\(truncated)")
                } else {
                    print("⚠️ Chat response missing course ID. Keys: \(Array(json.keys).sorted())")
                }
                throw CinemaError.decodingFailed("No course ID in response")
            }
            
            throw CinemaError.decodingFailed("Invalid JSON response format")
        } catch let error as URLError {
            print("⚠️ Network error: \(error.localizedDescription)")
            print("   Error code: \(error.code)")
            print("🔄 Falling back to Mock Graph Course (offline/unreachable)")
            return generateMockGraphCourse(topic: topic, level: level)
        } catch {
            // Only fall back to mocks in explicit demo mode.
            if AuthService.shared.isDemoMode {
                print("⚠️ Course generation failed in demo mode: \(error.localizedDescription)")
                print("🔄 Falling back to Mock Graph Course (demo mode)")
                return generateMockGraphCourse(topic: topic, level: level)
            }
            throw error
        }
    }
    
    // MARK: - Helper: Fetch Course Details
    
    private func fetchCourseDetails(courseId: String) async throws -> GraphCourseItem {
        let endpoint = "\(baseURL)/api/v1/classroom/courses/\(courseId)"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CinemaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CinemaError.unauthorized
            }
            throw CinemaError.serverError(httpResponse.statusCode)
        }
        
        let course = try jsonDecoder.decode(GraphCourseItem.self, from: data)
        print("✅ Successfully fetched course details: \(course.id)")
        return course
    }
    
    // MARK: - Playback
    
    private struct PlaybackAdvanceBody: Codable {
        let currentNodeId: String
    }

    private struct InteractionSubmitBody: Codable {
        let courseId: String
        let nodeId: String
        let answerId: String
        let timeTakenSeconds: Double
    }

    private struct RemediationRequestBody: Codable {
        let courseId: String
        let nodeId: String
        let userComplaint: String?
        let misconceptionTag: String?
    }

    public func startCourse(courseId: String) async throws -> PlaybackState {
        isLoading = true
        defer { isLoading = false }
        
        // Check for mock course
        if courseId.starts(with: "mock_") {
            print("🎬 Starting Mock Course: \(courseId)")
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            return getMockPlaybackState(courseId: courseId)
        }
        
        guard await tokenManager.getToken() != nil else {
            throw CinemaError.unauthorized
        }

        let endpoint = "\(baseURL)/api/v1/classroom/playback/courses/\(courseId)/start"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CinemaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CinemaError.unauthorized
            }
            throw CinemaError.serverError(httpResponse.statusCode)
        }
        
        let playbackState = try jsonDecoder.decode(PlaybackState.self, from: data)
        currentPlaybackState = playbackState
        return playbackState
    }
    
    public func advanceToNextNode(
        courseId: String,
        currentNodeId: String,
        timeSpentSeconds: Int = 0
    ) async throws -> PlaybackState {
        isLoading = true
        defer { isLoading = false }
        
        // Check for mock course
        if courseId.starts(with: "mock_") {
            print("⏩ Advancing Mock Course: \(courseId) -> Next Node")
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
            
            // Simple logic to determine next node ID
            let currentNum = Int(String(currentNodeId.last ?? "1")) ?? 1
            let nextNodeId = "node_\(currentNum + 1)"
            
            return getMockPlaybackState(courseId: courseId, nodeId: nextNodeId)
        }
        
        guard await tokenManager.getToken() != nil else {
            throw CinemaError.unauthorized
        }

        let endpoint = "\(baseURL)/api/v1/classroom/playback/courses/\(courseId)/advance?time_spent_seconds=\(timeSpentSeconds)"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try jsonEncoder.encode(
            PlaybackAdvanceBody(currentNodeId: currentNodeId)
        )
        
        let requestBody = ["current_node_id": currentNodeId]
        request.httpBody = try jsonEncoder.encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CinemaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CinemaError.unauthorized
            }
            throw CinemaError.serverError(httpResponse.statusCode)
        }
        
        let playbackState = try jsonDecoder.decode(PlaybackState.self, from: data)
        currentPlaybackState = playbackState
        return playbackState
    }
    
    public func submitInteraction(
        courseId: String,
        nodeId: String,
        answerId: String,
        timeTakenSeconds: Double = 0
    ) async throws -> InteractionResult {
        guard await tokenManager.getToken() != nil else {
            throw CinemaError.unauthorized
        }

        let endpoint = "\(baseURL)/api/v1/classroom/playback/interactions/submit"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try jsonEncoder.encode(
            InteractionSubmitBody(
                courseId: courseId,
                nodeId: nodeId,
                answerId: answerId,
                timeTakenSeconds: timeTakenSeconds
            )
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CinemaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CinemaError.unauthorized
            }
            throw CinemaError.serverError(httpResponse.statusCode)
        }
        
        let result = try jsonDecoder.decode(InteractionResult.self, from: data)
        
        // CLOSE THE LOOP: Trace knowledge in the Personalization Engine
        if let userId = await tokenManager.getUserId(),
           let currentNode = currentPlaybackState?.currentNode,
           currentNode.id == nodeId {
            
            let skillId = currentNode.conceptId ?? "general"
            let trace = KnowledgeTraceRequest(
                learnerId: userId,
                skillId: skillId,
                itemId: nodeId,
                correct: result.isCorrect,
                timeTakenSeconds: timeTakenSeconds
            )
            
            Task {
                do {
                    try await PersonalizationService.shared.traceKnowledge(trace: trace)
                    print("✅ Knowledge traced for skill: \(skillId)")
                } catch {
                    print("⚠️ Failed to trace knowledge: \(error)")
                }
            }
        }
        
        return result
    }
    
    public func getLookaheadNodes(
        courseId: String,
        count: Int = 3
    ) async throws -> [LearningNode] {
        guard await tokenManager.getToken() != nil else {
            throw CinemaError.unauthorized
        }

        let endpoint = "\(baseURL)/api/v1/classroom/playback/courses/\(courseId)/lookahead?count=\(count)"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CinemaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CinemaError.unauthorized
            }
            throw CinemaError.serverError(httpResponse.statusCode)
        }
        
        let nodes = try jsonDecoder.decode([LearningNode].self, from: data)
        return nodes
    }
    
    // MARK: - Remediation
    
    public func requestRemediation(
        courseId: String,
        nodeId: String,
        userComplaint: String?,
        misconceptionTag: String? = nil
    ) async throws -> RemediationResponse {
        guard await tokenManager.getToken() != nil else {
            throw CinemaError.unauthorized
        }

        let endpoint = "\(baseURL)/api/v1/classroom/playback/remediation/request"
        
        guard let url = URL(string: endpoint) else {
            throw CinemaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try jsonEncoder.encode(
            RemediationRequestBody(
                courseId: courseId,
                nodeId: nodeId,
                userComplaint: userComplaint,
                misconceptionTag: misconceptionTag
            )
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CinemaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CinemaError.unauthorized
            }
            throw CinemaError.serverError(httpResponse.statusCode)
        }
        
        let remediation = try jsonDecoder.decode(RemediationResponse.self, from: data)
        return remediation
    }
}

// MARK: - Data Models

public struct GraphCourseItem: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let subject: String
    public let gradeBand: String
    public let entryNodeId: String?
    public let estimatedMinutes: Int
    public let totalNodes: Int
    public let createdAt: Date?
    
    public init(id: String, title: String, description: String, subject: String, gradeBand: String, entryNodeId: String?, estimatedMinutes: Int, totalNodes: Int, createdAt: Date?) {
        self.id = id
        self.title = title
        self.description = description
        self.subject = subject
        self.gradeBand = gradeBand
        self.entryNodeId = entryNodeId
        self.estimatedMinutes = estimatedMinutes
        self.totalNodes = totalNodes
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, subject
        case gradeBand = "grade_band"
        case entryNodeId = "entry_node_id"
        case estimatedMinutes = "estimated_minutes"
        case totalNodes = "total_nodes"
        case createdAt = "created_at"
    }
}

public struct PlaybackState: Codable {
    public let courseId: String
    public let currentNodeId: String
    public let currentNode: LearningNodeWithAssets
    public let nextNodes: [LearningNode]
    public let completedNodes: [String]
    public let progressPercent: Double
    public let totalTimeSeconds: Int
    public let canGoBack: Bool
    public let isAtInteraction: Bool
    
    public init(courseId: String, currentNodeId: String, currentNode: LearningNodeWithAssets, nextNodes: [LearningNode], completedNodes: [String], progressPercent: Double, totalTimeSeconds: Int, canGoBack: Bool, isAtInteraction: Bool) {
        self.courseId = courseId
        self.currentNodeId = currentNodeId
        self.currentNode = currentNode
        self.nextNodes = nextNodes
        self.completedNodes = completedNodes
        self.progressPercent = progressPercent
        self.totalTimeSeconds = totalTimeSeconds
        self.canGoBack = canGoBack
        self.isAtInteraction = isAtInteraction
    }
    
    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case currentNodeId = "current_node_id"
        case currentNode = "current_node"
        case nextNodes = "next_nodes"
        case completedNodes = "completed_nodes"
        case progressPercent = "progress_percent"
        case totalTimeSeconds = "total_time_seconds"
        case canGoBack = "can_go_back"
        case isAtInteraction = "is_at_interaction"
    }
}

public struct LearningNode: Codable, Identifiable {
    public let id: String
    public let nodeType: String
    public let title: String
    public let content: [String: AnyCodable]
    public let orderIndex: Int
    public let conceptId: String?
    public let skillType: String?
    
    public init(id: String, nodeType: String, title: String, content: [String: AnyCodable], orderIndex: Int, conceptId: String? = nil, skillType: String? = nil) {
        self.id = id
        self.nodeType = nodeType
        self.title = title
        self.content = content
        self.orderIndex = orderIndex
        self.conceptId = conceptId
        self.skillType = skillType
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case nodeType = "node_type"
        case title, content
        case orderIndex = "order_index"
        case conceptId = "concept_id"
        case skillType = "skill_type"
    }
}

public struct LearningNodeWithAssets: Codable {
    public let id: String
    public let nodeType: String
    public let title: String
    public let content: [String: AnyCodable]
    public let orderIndex: Int
    public let conceptId: String?
    public let skillType: String?
    public let assets: NodeAssets?
    
    public init(id: String, nodeType: String, title: String, content: [String: AnyCodable], orderIndex: Int, conceptId: String? = nil, skillType: String? = nil, assets: NodeAssets?) {
        self.id = id
        self.nodeType = nodeType
        self.title = title
        self.content = content
        self.orderIndex = orderIndex
        self.conceptId = conceptId
        self.skillType = skillType
        self.assets = assets
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case nodeType = "node_type"
        case title, content
        case orderIndex = "order_index"
        case conceptId = "concept_id"
        case skillType = "skill_type"
        case assets
    }
}

public struct NodeAssets: Codable {
    public let audioUrl: String?
    public let imageUrl: String?
    public let duration: Double?
    
    public init(audioUrl: String?, imageUrl: String?, duration: Double?) {
        self.audioUrl = audioUrl
        self.imageUrl = imageUrl
        self.duration = duration
    }
    
    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case imageUrl = "image_url"
        case duration
    }
}

public struct InteractionResult: Codable {
    public let isCorrect: Bool
    public let feedback: String
    public let explanation: String?
    public let nextNode: LearningNode?
    public let masteryUpdated: Bool
    public let celebrationTriggered: Bool?
    
    public init(isCorrect: Bool, feedback: String, explanation: String?, nextNode: LearningNode?, masteryUpdated: Bool, celebrationTriggered: Bool?) {
        self.isCorrect = isCorrect
        self.feedback = feedback
        self.explanation = explanation
        self.nextNode = nextNode
        self.masteryUpdated = masteryUpdated
        self.celebrationTriggered = celebrationTriggered
    }
    
    enum CodingKeys: String, CodingKey {
        case isCorrect = "is_correct"
        case feedback, explanation
        case nextNode = "next_node"
        case masteryUpdated = "mastery_updated"
        case celebrationTriggered = "celebration_triggered"
    }
}

public struct RemediationResponse: Codable {
    public let remediationNodeId: String
    public let explanation: String
    public let newAnalogy: String
    public let visualPrompt: String?
    
    public init(remediationNodeId: String, explanation: String, newAnalogy: String, visualPrompt: String?) {
        self.remediationNodeId = remediationNodeId
        self.explanation = explanation
        self.newAnalogy = newAnalogy
        self.visualPrompt = visualPrompt
    }
    
    enum CodingKeys: String, CodingKey {
        case remediationNodeId = "remediation_node_id"
        case explanation
        case newAnalogy = "new_analogy"
        case visualPrompt = "visual_prompt"
    }
}

    // MARK: - Mock Data Generation
    
    private func generateMockGraphCourse(topic: String, level: String) -> GraphCourseItem {
        return GraphCourseItem(
            id: "mock_graph_\(UUID().uuidString.prefix(8))",
            title: "Mastering \(topic)",
            description: "A comprehensive interactive course on \(topic).",
            subject: topic,
            gradeBand: level,
            entryNodeId: "node_1",
            estimatedMinutes: 45,
            totalNodes: 5,
            createdAt: Date()
        )
    }
    
    private func getMockPlaybackState(courseId: String, nodeId: String = "node_1") -> PlaybackState {
        let isFirstNode = nodeId == "node_1"
        let isLastNode = nodeId == "node_5"
        
        let currentNode = LearningNodeWithAssets(
            id: nodeId,
            nodeType: "explanation",
            title: isFirstNode ? "Introduction" : "Concept \(nodeId.last ?? "1")",
            content: ["text": AnyCodable("This is a mock lesson content for \(nodeId).")],
            orderIndex: isFirstNode ? 1 : 2,
            assets: NodeAssets(audioUrl: nil, imageUrl: "LyoThinking", duration: 10.0)
        )
        
        let nextNodes = isLastNode ? [] : [
            LearningNode(
                id: "node_\((Int(String(nodeId.last ?? "1")) ?? 1) + 1)",
                nodeType: "explanation",
                title: "Next Concept",
                content: [:],
                orderIndex: (Int(String(nodeId.last ?? "1")) ?? 1) + 1
            )
        ]
        
        return PlaybackState(
            courseId: courseId,
            currentNodeId: nodeId,
            currentNode: currentNode,
            nextNodes: nextNodes,
            completedNodes: isFirstNode ? [] : ["node_1"],
            progressPercent: isFirstNode ? 0.0 : (isLastNode ? 1.0 : 0.5),
            totalTimeSeconds: isFirstNode ? 0 : 300,
            canGoBack: !isFirstNode,
            isAtInteraction: false
        )
    }

    // MARK: - Errors

    public enum CinemaError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingFailed(String)
    case networkError(String)
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error (\(code))"
        case .decodingFailed(let message):
            return "Failed to decode: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unauthorized:
            return "Unauthorized - please log in"
        }
    }
}

// MARK: - Helper: AnyCodable for dynamic JSON

public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
