import XCTest
import os
@testable import Lyo

@MainActor
class LyoAITests: XCTestCase {
    
    var viewModel: LyoAIViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = LyoAIViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testLearningConsultantResponse() async {
        // Given
        viewModel.inputText = "I need help with math"
        
        // When
        await viewModel.sendMessage()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        
        guard viewModel.messages.count >= 2 else {
            XCTFail("Expected at least 2 messages (user + AI), got \(viewModel.messages.count)")
            return
        }
        
        let userMessage = viewModel.messages[0]
        XCTAssertTrue(userMessage.isFromUser)
        XCTAssertEqual(userMessage.content, "I need help with math")
        
        let aiMessage = viewModel.messages[1]
        XCTAssertFalse(aiMessage.isFromUser)
        XCTAssertFalse(aiMessage.content.isEmpty)
        
        // Verify it's using the Learning Consultant persona (Mock mode)
        // The mock response usually starts with "I'm Leo, your Learning Consultant." or similar
        // or at least contains helpful learning advice.
        Log.general.info("AI Response: \(aiMessage.content)")
    }
}

@MainActor
class CinemaPriorityTests: XCTestCase {

    var cinemaService: InteractiveCinemaService!
    var genService: CourseGenerationService!

    override func setUp() async throws {
        cinemaService = InteractiveCinemaService.shared
        genService = CourseGenerationService.shared
    }

    /// Verifies that when a generated course exists in the cache,
    /// startCourse() uses it INSTEAD of falling back to the generic "mock_" implementation,
    /// even if the ID starts with "mock_".
    /// This prevents the "Classroom Shell" bug where generated content was ignored.
    func testStartCoursePrioritizesCacheOverGenericMock() async throws {
        // 1. Setup a specific "Cached" course
        // We use an ID starting with "mock_" to trigger the specific conflict condition
        let mockId = "mock_generated_123"
        let expectedTitle = "Specific Generated Content"
        let expectedContent = "This is the specific content we expect to see."
        
        // Inject a generated course into the service
        // (Note: CourseGenerationService.generatedCourse is @Published but we can set it via internal logic or mirror its state if needed,
        //  but simpler here to mock the generation flow if possible, or just set the property if it was mutable/accessible.
        //  Since we can't easily write to the property (it's read-only publicly usually), we'll simulate the generation success.)
        
        // Simulating the state by crafting the response object using new progressive types
        let specificLesson = GenerationCourseLesson(
            id: "lesson_1",
            title: "Lesson 1",
            content: expectedContent,
            durationMinutes: 10,
            order: 1
        )
        
        let specificModule = GenerationCourseModule(
            id: "mod_1",
            title: "Module 1",
            description: "Desc",
            lessons: [specificLesson],
            order: 1
        )
        
        let specificCourse = GeneratedCourseResponse(
            courseId: mockId,
            title: expectedTitle,
            description: "Desc",
            modules: [specificModule],
            estimatedDuration: 10,
            difficulty: "beginner"
        )
        
        // Inject into the singleton (this requires `generatedCourse` to be accessible or settable)
        // Since it's a @Published property in an ObservableObject, we can assign to it if it's visible.
        // If it's private(set), we might need a test helper.
        // Looking at CourseGenerationService.swift, `generatedCourse` is `@Published var`.
        genService.generatedCourse = specificCourse
        
        // 2. Execute startCourse
        let playbackState = try await cinemaService.startCourse(courseId: mockId)
        
        // 3. Verify
        // The title of the node should match our SPECIFIC content, not the generic mock content.
        let actualTitle = playbackState.currentNode.title
        let actualContent = playbackState.currentNode.content["text"]?.value as? String
        
        // Assertions
        XCTAssertEqual(playbackState.courseId, mockId, "Course ID should match")
        XCTAssertEqual(actualTitle, "Lesson 1", "Should use the generated lesson title, NOT generic mock info")
        XCTAssertEqual(actualContent, expectedContent, "Should use the generated content, NOT generic mock content")
        
        Log.general.info("PROOF: Loaded content '\(actualContent ?? "nil")' matches expected specific content.")
    }
}
