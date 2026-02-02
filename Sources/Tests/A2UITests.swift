import XCTest
@testable import Lyo

// Mock Client
class MockNetworkClient: NetworkRequestable {
    var nextResponse: Any?
    
    func request<T>(_ endpoint: Endpoint, cachePolicy: CachePolicy) async throws -> T where T : Decodable, T : Encodable {
        if let response = nextResponse as? T {
            return response
        }
        fatalError("Mock response not set or type mismatch. Expected \(T.self), got \(type(of: nextResponse))")
    }
}

@MainActor
class A2UITests: XCTestCase {
    
    func testA2UIQuizFlow() async throws {
        // 1. Setup Service with Mock
        let mockClient = MockNetworkClient()
        let service = LioChatService(networkClient: mockClient)
        
        // 2. Prepare Mock Data (Quiz)
        let quizContent = A2UIContent(
            type: .quiz,
            courseRoadmap: nil,
            quiz: A2UIQuiz(
                title: "Test Quiz",
                questions: [
                    A2UIQuestion(
                        question: "What is A?",
                        options: ["A", "B"],
                        correctAnswer: "A"
                    )
                ]
            ),
            title: nil,
            topics: nil,
            cards: nil,
            modules: nil,
            totalModules: nil,
            completedModules: nil,
            suggestions: nil,
            cinematic: nil,
            layout: nil
        )
        
        let response = ChatResponse(
            response: "Here is a quiz",
            provider: "mock",
            contentTypes: [quizContent]
        )
        
        mockClient.nextResponse = response
        
        // 3. Execute
        let lioResponse = try await service.sendMessage(text: "Give me a quiz", mode: "tutor")
        
        // 4. Verify Mapping
        XCTAssertNotNil(lioResponse.contentTypes, "Content types should not be nil")
        XCTAssertEqual(lioResponse.contentTypes?.count, 1)
        
        if case .quiz(let q, let options, let correctIndex, _) = lioResponse.contentTypes!.first! {
            XCTAssertEqual(q, "What is A?")
            XCTAssertEqual(options, ["A", "B"])
            XCTAssertEqual(correctIndex, 0)
        } else {
            XCTFail("Expected quiz content type")
        }
    }
    
    func testA2UIRoadmapFlow() async throws {
        // 1. Setup Service with Mock
        let mockClient = MockNetworkClient()
        let service = LioChatService(networkClient: mockClient)
        
        // 2. Prepare Mock Data (Roadmap)
        let roadmapContent = A2UIContent(
            type: .courseRoadmap,
            courseRoadmap: A2UICourseRoadmap(
                title: "Python Basics",
                topic: "Python",
                level: "Beginner",
                modules: [
                    A2UIModule(
                        title: "Intro",
                        description: "Setup",
                        lessons: [
                            A2UILesson(title: "Install", duration: "10m")
                        ]
                    )
                ]
            ),
            quiz: nil,
            title: nil,
            topics: nil,
            cards: nil,
            modules: nil,
            totalModules: nil,
            completedModules: nil,
            suggestions: nil,
            cinematic: nil,
            layout: nil
        )
        
        let response = ChatResponse(
            response: "Here is a roadmap",
            provider: "mock",
            contentTypes: [roadmapContent]
        )
        
        mockClient.nextResponse = response
        
        // 3. Execute
        let lioResponse = try await service.sendMessage(text: "Create a roadmap", mode: "tutor")
        
        // 4. Verify Mapping
        XCTAssertNotNil(lioResponse.contentTypes, "Content types should not be nil")
        XCTAssertEqual(lioResponse.contentTypes?.count, 1)
        
        if case .courseRoadmap(let title, let modules, _, _) = lioResponse.contentTypes!.first! {
            XCTAssertEqual(title, "Python Basics")
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.first?.title, "Intro")
            // Verify duration mapping logic (lessons count)
            XCTAssertEqual(modules.first?.duration, "1 lessons")
        } else {
            XCTFail("Expected courseRoadmap content type")
        }
    }
}
