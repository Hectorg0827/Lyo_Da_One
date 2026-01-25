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
    
    private init() {}
    
    // MARK: - Course Discovery & Generation
    
    public func getAvailableCourses() async throws -> [GraphCourseItem] {
        return try await NetworkClient.shared.request(Endpoints.Classroom.getCourses)
    }
    
    public func generateGraphCourse(topic: String, level: String = "beginner") async throws -> GraphCourseItem {
        print("📡 Generating graph course: \(topic) at \(level) level")
        
        // Start course generation immediately (blocks until complete or fallback)
        let generatedCourse = try await CourseGenerationService.shared.generateCourse(
            topic: topic,
            level: level,
            outcomes: [
                "Understand core concepts of \(topic)",
                "Apply knowledge through practice",
                "Build confidence in \(topic)"
            ],
            teachingStyle: "interactive"
        )
        
        print("✅ Course generation completed: \(generatedCourse.title) with \(generatedCourse.modules.count) modules")
        
        // Return course item using the SAME ID from generated course
        let courseItem = GraphCourseItem(
            id: generatedCourse.courseId,
            title: generatedCourse.title,
            description: generatedCourse.description,
            subject: topic,
            gradeBand: level,
            entryNodeId: generatedCourse.modules.first?.lessons.first?.id,
            estimatedMinutes: generatedCourse.estimatedDuration,
            totalNodes: generatedCourse.modules.flatMap { $0.lessons }.count,
            createdAt: Date()
        )
        
        return courseItem
    }
    
    private func extractCourseId(from payload: [String: AnyCodable]) -> String? {
        if let id = payload["generated_course_id"]?.value as? String { return id }
        if let id = payload["generatedCourseId"]?.value as? String { return id }
        if let id = payload["course_id"]?.value as? String { return id }
        if let id = payload["courseId"]?.value as? String { return id }
        
        // Handle nested metadata if needed
        if let metadata = payload["metadata"]?.value as? [String: Any] {
            if let id = metadata["generated_course_id"] as? String { return id }
            if let id = metadata["generatedCourseId"] as? String { return id }
            if let id = metadata["course_id"] as? String { return id }
            if let id = metadata["courseId"] as? String { return id }
        }
        
        return nil
    }
    
    // MARK: - Helper: Fetch Course Details
    
    private func fetchCourseDetails(courseId: String) async throws -> GraphCourseItem {
        let course: GraphCourseItem = try await NetworkClient.shared.request(Endpoints.Classroom.getCourse(id: courseId))
        print("✅ Successfully fetched course details: \(course.id)")
        return course
    }
    
    // MARK: - Playback
    
    public func startCourse(courseId: String) async throws -> PlaybackState {
        print("▶️ starting course with ID: \(courseId)")
        isLoading = true
        defer { isLoading = false }
        
        // FIRST: Check if course was just generated - it's in the cache
        if let generatedCourse = CourseGenerationService.shared.generatedCourse {
            print("📦 Checking cache - Cached ID: \(generatedCourse.courseId) vs Requested ID: \(courseId)")
            
            if generatedCourse.courseId == courseId {
                print("✅ Found generated course in cache: \(generatedCourse.title)")
                print("   Modules: \(generatedCourse.modules.count)")
                if let first = generatedCourse.modules.first?.lessons.first {
                     print("   First Lesson Content Length: \(first.content.count)")
                }
                return convertGeneratedCourseToPlayback(course: generatedCourse, courseId: courseId)
            } else {
                print("⚠️ Cached course ID mismatch.")
            }
        } else {
            print("⚠️ No generated course in cache.")
        }
        
        // SECOND: Check for mock course (testing only)
        if courseId.starts(with: "mock_") {
            print("🎬 Starting Mock Course (no generated course found - fallback to generic): \(courseId)")
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            return getMockPlaybackState(courseId: courseId)
        }
        
        // THIRD: Check for Shell Course (Optimistic UI)
        if courseId.starts(with: "temp_") {
            print("🎬 Starting Shell Course (Optimistic UI): \(courseId)")
            // Return a loading/intro state
            return createWelcomePlaybackState(courseId: courseId)
        }
        
        // LAST: Fetch from backend
        print("🌐 Fetching course from backend: \(courseId)")
        let playbackState: PlaybackState = try await NetworkClient.shared.request(Endpoints.Classroom.startCourse(id: courseId))
        currentPlaybackState = playbackState
        return playbackState
    }
    
    // Generate playback state from CourseGenerationService
    private func generatePlaybackState(courseId: String) async throws -> PlaybackState {
        // Poll for course generation completion (max 10 seconds)
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            // Check if course is ready
            if let generatedCourse = CourseGenerationService.shared.generatedCourse,
               !generatedCourse.modules.isEmpty {
                print("✅ Course ready after \(attempts) attempts, converting to playback...")
                return convertGeneratedCourseToPlayback(course: generatedCourse, courseId: courseId)
            }
            
            // Wait 1 second before next check
            try await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
            print("⏳ Waiting for course generation... attempt \(attempts)/\(maxAttempts)")
        }
        
        // Fallback: create a welcome node if generation took too long
        print("⚠️ Course generation timed out, showing welcome screen...")
        return createWelcomePlaybackState(courseId: courseId)
    }
    
    private func convertGeneratedCourseToPlayback(course: GeneratedCourseResponse, courseId: String) -> PlaybackState {
        print("🔄 Converting course '\(course.title)' to playback - Modules: \(course.modules.count)")
        
        guard !course.modules.isEmpty else {
            print("⚠️ No modules in generated course!")
            return createWelcomePlaybackState(courseId: courseId)
        }
        
        let firstModule = course.modules[0]
        print("📚 First module: '\(firstModule.title)' - Lessons: \(firstModule.lessons.count)")
        
        guard !firstModule.lessons.isEmpty else {
            print("⚠️ No lessons in first module!")
            return createWelcomePlaybackState(courseId: courseId)
        }
        
        let firstLesson = firstModule.lessons[0]
        print("✅ Starting with lesson: '\(firstLesson.title)'")
        
        // Create main content node
        var contentDict: [String: AnyCodable] = [:]
        contentDict["text"] = AnyCodable(firstLesson.content)
        contentDict["title"] = AnyCodable(firstLesson.title)
        
        let currentNode = LearningNodeWithAssets(
            id: firstLesson.id,
            nodeType: "explain",
            title: firstLesson.title,
            content: contentDict,
            orderIndex: 1,
            conceptId: nil,
            skillType: nil,
            assets: nil  // Fixed: was [:] which is wrong type
        )
        
        // Create next nodes from remaining lessons
        let nextNodes: [LearningNode] = firstModule.lessons.dropFirst().prefix(3).enumerated().map { index, lesson in
            var lessonContent: [String: AnyCodable] = [:]
            lessonContent["text"] = AnyCodable(lesson.content)
            lessonContent["title"] = AnyCodable(lesson.title)
            
            return LearningNode(
                id: lesson.id,
                nodeType: "explain",
                title: lesson.title,
                content: lessonContent,
                orderIndex: index + 2
            )
        }
        
        return PlaybackState(
            courseId: courseId,
            currentNodeId: firstLesson.id,
            currentNode: currentNode,
            nextNodes: nextNodes,
            completedNodes: [],
            progressPercent: 0.0,
            totalTimeSeconds: 0,
            canGoBack: false,
            isAtInteraction: false
        )
    }
    
    private func createWelcomePlaybackState(courseId: String) -> PlaybackState {
        var contentDict: [String: AnyCodable] = [:]
        contentDict["text"] = AnyCodable("Welcome! Your course is being prepared. This will just take a moment...")
        contentDict["title"] = AnyCodable("Getting Ready")
        
        let welcomeNode = LearningNodeWithAssets(
            id: "welcome_1",
            nodeType: "explain",
            title: "Welcome",
            content: contentDict,
            orderIndex: 1,
            conceptId: nil,
            skillType: nil,
            assets: nil  // Fixed: was [:] which is wrong type
        )
        
        return PlaybackState(
            courseId: courseId,
            currentNodeId: "welcome_1",
            currentNode: welcomeNode,
            nextNodes: [],
            completedNodes: [],
            progressPercent: 0.0,
            totalTimeSeconds: 0,
            canGoBack: false,
            isAtInteraction: false
        )
    }
    
    private func createCompletionPlaybackState(courseId: String) -> PlaybackState {
        var contentDict: [String: AnyCodable] = [:]
        contentDict["text"] = AnyCodable("🎉 Congratulations! You've completed this course. Great work!")
        contentDict["title"] = AnyCodable("Course Complete")
        
        let completionNode = LearningNodeWithAssets(
            id: "completion_1",
            nodeType: "summary",
            title: "Course Complete!",
            content: contentDict,
            orderIndex: 999,
            conceptId: nil,
            skillType: nil,
            assets: nil
        )
        
        return PlaybackState(
            courseId: courseId,
            currentNodeId: "completion_1",
            currentNode: completionNode,
            nextNodes: [],
            completedNodes: [],
            progressPercent: 1.0,
            totalTimeSeconds: 0,
            canGoBack: true,
            isAtInteraction: false
        )
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
            let currentNum = Int(String(currentNodeId.last ?? "1")) ?? 1
            let nextNodeId = "node_\(currentNum + 1)"
            return getMockPlaybackState(courseId: courseId, nodeId: nextNodeId)
        }
        
        // Check for generated course
        if courseId.starts(with: "gen_") {
            print("⏩ Advancing Generated Course: \(courseId) -> Next Node")
            guard let generatedCourse = CourseGenerationService.shared.generatedCourse else {
                throw CourseGenerationError.noContent
            }
            
            // Find current node index
            var currentIndex = -1
            var allNodes: [GenerationCourseLesson] = []
            
            for module in generatedCourse.modules {
                for lesson in module.lessons {
                    allNodes.append(lesson)
                    if lesson.id == currentNodeId {
                        currentIndex = allNodes.count - 1
                    }
                }
            }
            
            // Get next node
            guard currentIndex >= 0 && currentIndex < allNodes.count - 1 else {
                // At the end, return completion state
                return createCompletionPlaybackState(courseId: courseId)
            }
            
            let nextLesson = allNodes[currentIndex + 1]
            
            // Create playback state for next node
            var contentDict: [String: AnyCodable] = [:]
            contentDict["text"] = AnyCodable(nextLesson.content)
            contentDict["title"] = AnyCodable(nextLesson.title)
            
            let currentNode = LearningNodeWithAssets(
                id: nextLesson.id,
                nodeType: "explain",
                title: nextLesson.title,
                content: contentDict,
                orderIndex: currentIndex + 2,
                conceptId: nil,
                skillType: nil,
                assets: nil
            )
            
            // Create next nodes list (up to 3 upcoming lessons)
            let nextNodes: [LearningNode] = allNodes.dropFirst(currentIndex + 2).prefix(3).enumerated().map { index, lesson in
                var lessonContent: [String: AnyCodable] = [:]
                lessonContent["text"] = AnyCodable(lesson.content)
                lessonContent["title"] = AnyCodable(lesson.title)
                
                return LearningNode(
                    id: lesson.id,
                    nodeType: "explain",
                    title: lesson.title,
                    content: lessonContent,
                    orderIndex: currentIndex + 3 + index
                )
            }
            
            let completedNodes = Array(allNodes.prefix(currentIndex + 1).map { $0.id })
            let progressPercent = Double(currentIndex + 1) / Double(allNodes.count)
            
            return PlaybackState(
                courseId: courseId,
                currentNodeId: nextLesson.id,
                currentNode: currentNode,
                nextNodes: nextNodes,
                completedNodes: completedNodes,
                progressPercent: progressPercent,
                totalTimeSeconds: timeSpentSeconds,
                canGoBack: true,
                isAtInteraction: false
            )
        }
        
        let playbackState: PlaybackState = try await NetworkClient.shared.request(
            Endpoints.Classroom.advance(courseId: courseId, currentNodeId: currentNodeId, timeSpent: timeSpentSeconds)
        )
        currentPlaybackState = playbackState
        return playbackState
    }
    
    public func submitInteraction(
        courseId: String,
        nodeId: String,
        answerId: String,
        timeTakenSeconds: Double = 0
    ) async throws -> InteractionResult {
        
        let result: InteractionResult = try await NetworkClient.shared.request(
            Endpoints.Classroom.submitInteraction(courseId: courseId, nodeId: nodeId, answerId: answerId, timeTaken: timeTakenSeconds)
        )
        
        // CLOSE THE LOOP: Trace knowledge in the Personalization Engine
        if let userId = await TokenManager.shared.getUserId(),
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
        return try await NetworkClient.shared.request(Endpoints.Classroom.getLookahead(courseId: courseId, count: count))
    }
    
    // MARK: - Remediation
    
    public func requestRemediation(
        courseId: String,
        nodeId: String,
        userComplaint: String?,
        misconceptionTag: String? = nil
    ) async throws -> RemediationResponse {
        return try await NetworkClient.shared.request(
            Endpoints.Classroom.requestRemediation(courseId: courseId, nodeId: nodeId, complaint: userComplaint, tag: misconceptionTag)
        )
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


