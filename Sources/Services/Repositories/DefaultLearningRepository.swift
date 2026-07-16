import Foundation

// MARK: - Default Learning Repository
class DefaultLearningRepository: LearningRepository {

    private let networkClient = NetworkClient.shared
    private let logger = NetworkLogger()

    init() {}

    // MARK: - Sessions

    func createSession(userId: String, goal: String, variables: [String: Any]) async throws -> LearningSession {
        // Convert [String: Any] to [String: String] for endpoint
        let stringVariables = variables.mapValues { "\($0)" }
        let session: LearningSession = try await networkClient.request(
            Endpoints.Learning.createSession(userId: userId, goal: goal, variables: stringVariables),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Learning session created: \(session.sessionId)")
        return session
    }

    func getSession(sessionId: String) async throws -> LearningSession {
        let session: LearningSession = try await networkClient.request(
            Endpoints.Learning.getSession(sessionId: sessionId),
            cachePolicy: .default
        )

        logger.log("✅ Session fetched: \(session.sessionId)")
        return session
    }

    func interruptSession(sessionId: String, message: String) async throws -> InterruptResponse {
        let response: InterruptResponse = try await networkClient.request(
            Endpoints.Learning.interruptSession(sessionId: sessionId, message: message),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Session interrupted with clarification")
        return response
    }

    func saveCheckpoint(sessionId: String, progress: LessonProgress) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await networkClient.request(
            Endpoints.Learning.saveCheckpoint(sessionId: sessionId, progress: progress),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Progress saved: \(Int(progress.overallProgress * 100))%")
    }

    // MARK: - Courses & Lessons

    func getCourses() async throws -> [CourseDTO] {
        let courses: [CourseDTO] = try await networkClient.request(
            Endpoints.Learning.getCourses,
            cachePolicy: .default // Cache for 5 minutes
        )

        logger.log("✅ Courses fetched: \(courses.count)")
        return courses
    }

    func getCourse(courseId: String) async throws -> CourseDTO {
        let course: CourseDTO = try await networkClient.request(
            Endpoints.Learning.getCourse(courseId: courseId),
            cachePolicy: .default
        )

        logger.log("✅ Course fetched: \(course.title)")
        return course
    }

    func getLesson(lessonId: String) async throws -> Lesson {
        let lesson: Lesson = try await networkClient.request(
            Endpoints.Learning.getLesson(lessonId: lessonId),
            cachePolicy: .default
        )

        logger.log("✅ Lesson fetched: \(lesson.title)")
        return lesson
    }

    func completeLesson(lessonId: String, score: Int?) async throws -> RepoLessonCompletion {
        let completion: RepoLessonCompletion = try await networkClient.request(
            Endpoints.Learning.completeLesson(lessonId: lessonId, score: score),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Lesson completed: +\(completion.xpEarned ?? 0) XP")
        return completion
    }
}

// MARK: - Mock Learning Repository
class MockLearningRepository: LearningRepository {

    func createSession(userId: String, goal: String, variables: [String: Any]) async throws -> LearningSession {
        try await Task.sleep(nanoseconds: 500_000_000)
        return LearningSession(
            sessionId: UUID().uuidString,
            userId: userId,
            goal: goal,
            status: "active",
            progress: 0,
            createdAt: Date()
        )
    }

    func getSession(sessionId: String) async throws -> LearningSession {
        try await Task.sleep(nanoseconds: 300_000_000)
        return LearningSession(
            sessionId: sessionId,
            userId: "user123",
            goal: "Learn Python",
            status: "active",
            progress: 45,
            createdAt: Date()
        )
    }

    func interruptSession(sessionId: String, message: String) async throws -> InterruptResponse {
        try await Task.sleep(nanoseconds: 400_000_000)
        return InterruptResponse(
            response: "Let me clarify that for you...",
            sessionId: sessionId,
            shouldPause: true
        )
    }

    func saveCheckpoint(sessionId: String, progress: LessonProgress) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    func getCourses() async throws -> [CourseDTO] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return [
            CourseDTO(
                id: "1",
                title: "Python Basics",
                description: "Learn Python from scratch",
                modules: nil,
                difficulty: "beginner",
                estimatedHours: 10
            ),
            CourseDTO(
                id: "2",
                title: "Data Structures",
                description: "Master data structures and algorithms",
                modules: nil,
                difficulty: "intermediate",
                estimatedHours: 20
            )
        ]
    }

    func getCourse(courseId: String) async throws -> CourseDTO {
        try await Task.sleep(nanoseconds: 400_000_000)
        return CourseDTO(
            id: courseId,
            title: "Python Basics",
            description: "Learn Python from scratch",
            modules: [
                CourseDTO.Module(
                    id: "m1",
                    title: "Variables & Data Types",
                    lessons: nil
                )
            ],
            difficulty: "beginner",
            estimatedHours: 10
        )
    }

    func getLesson(lessonId: String) async throws -> Lesson {
        try await Task.sleep(nanoseconds: 300_000_000)
        return Lesson(
            id: lessonId,
            title: "Introduction to Variables",
            content: "Variables are containers for storing data...",
            duration: 10,
            order: 1
        )
    }

    func completeLesson(lessonId: String, score: Int?) async throws -> RepoLessonCompletion {
        try await Task.sleep(nanoseconds: 300_000_000)
        return RepoLessonCompletion(
            lessonId: lessonId,
            score: score,
            xpEarned: 100,
            nextLesson: "lesson2"
        )
    }
}
