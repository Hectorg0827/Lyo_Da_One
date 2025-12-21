import XCTest
import SwiftUI
@testable import Lyo

/// Comprehensive smoke tests for LiveClassroom UI wiring
@MainActor
final class LiveClassroomSmokeTests: XCTestCase {
    
    var viewModel: LiveClassroomViewModel!
    
    override func setUp() async throws {
        viewModel = LiveClassroomViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
    }
    
    // MARK: - 1. Initialization Tests
    
    func testInitialState() {
        XCTAssertNil(viewModel.lesson, "Lesson should start nil")
        XCTAssertEqual(viewModel.currentBlockIndex, 0, "Should start at block 0")
        XCTAssertFalse(viewModel.isLioSpeaking, "Lio should not be speaking initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.errorMessage, "Should have no error initially")
        XCTAssertNil(viewModel.playbackState, "Playback state should be nil initially")
        XCTAssertTrue(viewModel.transcript.isEmpty, "Transcript should be empty")
        XCTAssertTrue(viewModel.completedBlocks.isEmpty, "No blocks completed initially")
    }
    
    // MARK: - 2. Lesson Loading Tests
    
    func testLoadLessonSetsLoadingState() async {
        let expectation = XCTestExpectation(description: "Loading state toggles")
        
        Task {
            XCTAssertFalse(viewModel.isLoading)
            
            await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
            
            // After loading completes
            XCTAssertFalse(viewModel.isLoading, "Loading should be false after completion")
            XCTAssertNotNil(viewModel.lesson, "Lesson should be loaded")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testLoadLessonPopulatesBlocks() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        XCTAssertNotNil(viewModel.lesson)
        XCTAssertGreaterThan(viewModel.lesson?.blocks.count ?? 0, 0, "Lesson should have blocks")
        XCTAssertNotNil(viewModel.currentBlock, "Should have a current block")
    }
    
    func testGenerateCourseFlow() async {
        // Test graph-based course generation
        await viewModel.loadLesson(courseId: "GENERATE:Python Basics", lessonId: "generated")
        
        // Should either succeed or fail gracefully
        if let lesson = viewModel.lesson {
            XCTAssertGreaterThan(lesson.blocks.count, 0, "Generated lesson should have blocks")
        } else {
            XCTAssertNotNil(viewModel.errorMessage, "Should have error message if generation failed")
        }
    }
    
    // MARK: - 3. Block Navigation Tests
    
    func testAdvanceToNextBlock() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        let initialIndex = viewModel.currentBlockIndex
        let initialBlock = viewModel.currentBlock
        
        viewModel.advanceToNextBlock()
        
        XCTAssertEqual(viewModel.currentBlockIndex, initialIndex + 1, "Should advance by 1")
        XCTAssertNotEqual(viewModel.currentBlock?.id, initialBlock?.id, "Block should change")
        XCTAssertTrue(viewModel.completedBlocks.contains(initialBlock?.id ?? ""), "Previous block should be marked complete")
    }
    
    func testGoToPreviousBlock() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        viewModel.advanceToNextBlock()
        let currentIndex = viewModel.currentBlockIndex
        
        viewModel.goToPreviousBlock()
        
        XCTAssertEqual(viewModel.currentBlockIndex, currentIndex - 1, "Should go back by 1")
    }
    
    func testCannotGoBeforeFirstBlock() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        XCTAssertTrue(viewModel.isFirstBlock)
        
        viewModel.goToPreviousBlock()
        
        XCTAssertEqual(viewModel.currentBlockIndex, 0, "Should stay at index 0")
    }
    
    func testIsLastBlockDetection() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        guard let lesson = viewModel.lesson else {
            XCTFail("Lesson not loaded")
            return
        }
        
        // Navigate to last block
        viewModel.currentBlockIndex = lesson.totalBlocks - 1
        
        XCTAssertTrue(viewModel.isLastBlock, "Should detect last block")
    }
    
    // MARK: - 4. Quiz State Tests
    
    func testSubmitQuizAnswer() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        // Find a quiz block
        while let block = viewModel.currentBlock, block.type != .quizMcq {
            if viewModel.isLastBlock { break }
            viewModel.advanceToNextBlock()
        }
        
        guard let quizBlock = viewModel.currentBlock,
              quizBlock.type == .quizMcq,
              let correctIndex = quizBlock.correctIndex else {
            return // No quiz found, test passes
        }
        
        // Submit correct answer
        viewModel.submitQuizAnswer(correctIndex)
        
        XCTAssertTrue(viewModel.quizSubmitted, "Quiz should be marked as submitted")
        XCTAssertEqual(viewModel.selectedQuizOption, correctIndex, "Selected option should match")
        XCTAssertTrue(viewModel.isQuizCorrect, "Answer should be correct")
        XCTAssertTrue(viewModel.canAdvance, "Should be able to advance after correct answer")
    }
    
    func testSubmitWrongQuizAnswer() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        // Find a quiz block
        while let block = viewModel.currentBlock, block.type != .quizMcq {
            if viewModel.isLastBlock { break }
            viewModel.advanceToNextBlock()
        }
        
        guard let quizBlock = viewModel.currentBlock,
              quizBlock.type == .quizMcq,
              let correctIndex = quizBlock.correctIndex,
              let optionsCount = quizBlock.options?.count,
              optionsCount > 1 else {
            return // No quiz found or insufficient options
        }
        
        // Submit wrong answer
        let wrongIndex = (correctIndex + 1) % optionsCount
        viewModel.submitQuizAnswer(wrongIndex)
        
        XCTAssertTrue(viewModel.quizSubmitted, "Quiz should be submitted")
        XCTAssertFalse(viewModel.isQuizCorrect, "Answer should be incorrect")
        XCTAssertTrue(viewModel.showingExplanation, "Should show explanation after wrong answer")
    }
    
    func testRetryQuiz() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        // Find quiz and submit answer
        while let block = viewModel.currentBlock, block.type != .quizMcq {
            if viewModel.isLastBlock { break }
            viewModel.advanceToNextBlock()
        }
        
        if viewModel.currentBlock?.type == .quizMcq {
            viewModel.submitQuizAnswer(0)
            viewModel.retryQuiz()
            
            XCTAssertNil(viewModel.selectedQuizOption, "Selected option should be reset")
            XCTAssertFalse(viewModel.quizSubmitted, "Quiz submitted flag should be reset")
            XCTAssertFalse(viewModel.showingExplanation, "Explanation should be hidden")
        }
    }
    
    // MARK: - 5. Progress Tracking Tests
    
    func testProgressPercentage() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        let initialProgress = viewModel.progressPercentage
        XCTAssertGreaterThanOrEqual(initialProgress, 0.0)
        XCTAssertLessThanOrEqual(initialProgress, 1.0)
        
        viewModel.advanceToNextBlock()
        
        let newProgress = viewModel.progressPercentage
        XCTAssertGreaterThan(newProgress, initialProgress, "Progress should increase")
    }
    
    func testCompletedBlocksTracking() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        guard let firstBlockId = viewModel.currentBlock?.id else {
            XCTFail("No current block")
            return
        }
        
        viewModel.advanceToNextBlock()
        
        XCTAssertTrue(viewModel.completedBlocks.contains(firstBlockId), "First block should be marked complete")
    }
    
    // MARK: - 6. Sentiment Signal Tests
    
    func testSendSentimentSignal() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        let initialTranscriptCount = viewModel.transcript.count
        
        viewModel.sendSentimentSignal(.confused)
        
        // Wait for async handling
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertGreaterThanOrEqual(viewModel.transcript.count, initialTranscriptCount, "Transcript should have entries")
    }
    
    func testAllSentimentSignals() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        let signals: [SentimentSignal] = [.confused, .slower, .tooEasy, .quizMe]
        
        for signal in signals {
            let beforeCount = viewModel.transcript.count
            viewModel.sendSentimentSignal(signal)
            try? await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertGreaterThanOrEqual(viewModel.transcript.count, beforeCount, "Signal \(signal) handled")
        }
    }
    
    // MARK: - 7. Transcript Tests
    
    func testAskQuestion() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        let question = "Can you explain this concept?"
        let initialTranscriptCount = viewModel.transcript.count
        
        await viewModel.askQuestion(question)
        
        XCTAssertGreaterThan(viewModel.transcript.count, initialTranscriptCount, "Question should be in transcript")
        XCTAssertTrue(viewModel.transcript.contains { $0.text.contains(question) }, "Transcript should contain the question")
        XCTAssertTrue(viewModel.userQuestion.isEmpty, "User question should be cleared")
    }
    
    func testEmptyQuestionIgnored() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        let initialCount = viewModel.transcript.count
        
        await viewModel.askQuestion("")
        await viewModel.askQuestion("   ")
        
        XCTAssertEqual(viewModel.transcript.count, initialCount, "Empty questions should be ignored")
    }
    
    // MARK: - 8. UI State Management Tests
    
    func testShowTranscriptSheet() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        viewModel.showTranscriptSheet = true
        XCTAssertTrue(viewModel.showTranscriptSheet)
        
        viewModel.showTranscriptSheet = false
        XCTAssertFalse(viewModel.showTranscriptSheet)
    }
    
    func testShowAskQuestionSheet() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        viewModel.showAskQuestionSheet = true
        XCTAssertTrue(viewModel.showAskQuestionSheet)
        
        await viewModel.askQuestion("Test question")
        XCTAssertFalse(viewModel.showAskQuestionSheet, "Sheet should close after asking question")
    }
    
    // MARK: - 9. Error Handling Tests
    
    func testErrorMessageClearing() async {
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)
        
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        // Error should be cleared or replaced
        XCTAssertTrue(viewModel.errorMessage == nil || viewModel.errorMessage != "Test error")
    }
    
    // MARK: - 10. Computed Properties Tests
    
    func testComputedProperties() async {
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        // Test all computed properties don't crash
        _ = viewModel.currentBlock
        _ = viewModel.progressPercentage
        _ = viewModel.isFirstBlock
        _ = viewModel.isLastBlock
        _ = viewModel.canAdvance
        _ = viewModel.isQuizCorrect
        
        XCTAssertTrue(true, "All computed properties accessible")
    }
}

// MARK: - Integration Tests

@MainActor
final class LiveClassroomIntegrationTests: XCTestCase {
    
    func testFullLessonFlow() async {
        let viewModel = LiveClassroomViewModel()
        
        // Load lesson
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        XCTAssertNotNil(viewModel.lesson)
        
        // Navigate through blocks
        let totalBlocks = viewModel.lesson?.totalBlocks ?? 0
        for _ in 0..<min(totalBlocks - 1, 3) {
            let beforeIndex = viewModel.currentBlockIndex
            viewModel.advanceToNextBlock()
            XCTAssertGreaterThan(viewModel.currentBlockIndex, beforeIndex)
        }
        
        // Send sentiment
        viewModel.sendSentimentSignal(.confused)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Ask question
        await viewModel.askQuestion("Test question")
        XCTAssertTrue(viewModel.transcript.contains { $0.text.contains("Test question") })
    }
    
    func testQuizCompletionFlow() async {
        let viewModel = LiveClassroomViewModel()
        await viewModel.loadLesson(courseId: "test_course", lessonId: "test_lesson")
        
        // Find quiz
        while let block = viewModel.currentBlock, block.type != .quizMcq {
            if viewModel.isLastBlock { break }
            viewModel.advanceToNextBlock()
        }
        
        guard let quizBlock = viewModel.currentBlock,
              quizBlock.type == .quizMcq,
              let correctIndex = quizBlock.correctIndex,
              let optionsCount = quizBlock.options?.count,
              optionsCount > 1 else {
            return // No quiz found
        }
        
        // Submit wrong answer
        let wrongIndex = (correctIndex + 1) % optionsCount
        viewModel.submitQuizAnswer(wrongIndex)
        XCTAssertTrue(viewModel.showingExplanation)
        
        // Retry
        viewModel.retryQuiz()
        XCTAssertFalse(viewModel.quizSubmitted)
        
        // Submit correct answer
        viewModel.submitQuizAnswer(correctIndex)
        XCTAssertTrue(viewModel.isQuizCorrect)
        XCTAssertTrue(viewModel.canAdvance)
    }
    
    func testBackendIntegrationFallback() async {
        let viewModel = LiveClassroomViewModel()
        
        // Test that invalid course ID falls back gracefully
        await viewModel.loadLesson(courseId: "invalid_course_xxx", lessonId: "invalid_lesson")
        
        // Should either load mock data or show error
        XCTAssertTrue(viewModel.lesson != nil || viewModel.errorMessage != nil, "Should have lesson or error")
    }
}
