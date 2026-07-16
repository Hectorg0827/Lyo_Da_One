import XCTest
@testable import Lyo

/// Tests for QuizViewModel timer and state management
@MainActor
final class QuizViewModelTests: XCTestCase {
    
    var viewModel: QuizViewModel!
    
    override func setUp() async throws {
        viewModel = QuizViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
    }
    
    // MARK: - Initial State
    
    func testInitialState() {
        XCTAssertNil(viewModel.currentQuiz)
        XCTAssertEqual(viewModel.currentQuestionIndex, 0)
        XCTAssertNil(viewModel.selectedAnswer)
        XCTAssertFalse(viewModel.isSubmitted)
        XCTAssertTrue(viewModel.userAnswers.isEmpty)
        XCTAssertTrue(viewModel.questionResults.isEmpty)
        XCTAssertFalse(viewModel.showResults)
        XCTAssertEqual(viewModel.timeRemaining, 0)
    }
    
    // MARK: - Score Calculation
    
    func testScoreCalculation() {
        // Simulate results
        viewModel.questionResults = [0: true, 1: true, 2: false, 3: true, 4: false]
        
        XCTAssertEqual(viewModel.score, 3, "3 out of 5 correct")
    }
    
    func testScorePercentage() {
        let quiz = makeQuiz(questionCount: 10, timeLimit: nil)
        viewModel.currentQuiz = quiz
        viewModel.questionResults = [0: true, 1: true, 2: true, 3: true, 4: true,
                                      5: false, 6: false, 7: false, 8: false, 9: false]
        
        XCTAssertEqual(viewModel.scorePercentage, 50.0)
    }
    
    func testScoreGrade() {
        let quiz = makeQuiz(questionCount: 10, timeLimit: nil)
        viewModel.currentQuiz = quiz
        
        // 90%+ = A
        viewModel.questionResults = Dictionary(uniqueKeysWithValues: (0..<10).map { ($0, $0 < 9) })
        XCTAssertEqual(viewModel.scoreGrade, "A")
        
        // 70-79% = C
        viewModel.questionResults = Dictionary(uniqueKeysWithValues: (0..<10).map { ($0, $0 < 7) })
        XCTAssertEqual(viewModel.scoreGrade, "C")
    }
    
    func testPassingScore() {
        let quiz = makeQuiz(questionCount: 10, timeLimit: nil)
        viewModel.currentQuiz = quiz
        
        // 70% passes
        viewModel.questionResults = Dictionary(uniqueKeysWithValues: (0..<10).map { ($0, $0 < 7) })
        XCTAssertTrue(viewModel.hasPassingScore)
        
        // 60% fails
        viewModel.questionResults = Dictionary(uniqueKeysWithValues: (0..<10).map { ($0, $0 < 6) })
        XCTAssertFalse(viewModel.hasPassingScore)
    }
    
    // MARK: - Question Navigation
    
    func testSelectAnswer() {
        viewModel.currentQuiz = makeQuiz(questionCount: 5, timeLimit: nil)
        
        viewModel.selectAnswer(2)
        XCTAssertEqual(viewModel.selectedAnswer, 2)
    }
    
    func testSelectAnswerBlockedAfterSubmit() {
        viewModel.currentQuiz = makeQuiz(questionCount: 5, timeLimit: nil)
        viewModel.isSubmitted = true
        
        viewModel.selectAnswer(2)
        XCTAssertNil(viewModel.selectedAnswer, "Cannot select after submission")
    }
    
    func testNextQuestion() {
        viewModel.currentQuiz = makeQuiz(questionCount: 5, timeLimit: nil)
        viewModel.currentQuestionIndex = 0
        
        viewModel.nextQuestion()
        XCTAssertEqual(viewModel.currentQuestionIndex, 1)
        XCTAssertNil(viewModel.selectedAnswer)
        XCTAssertFalse(viewModel.isSubmitted)
    }
    
    func testNextQuestionAtLastShowsResults() {
        let quiz = makeQuiz(questionCount: 3, timeLimit: nil)
        viewModel.currentQuiz = quiz
        viewModel.currentQuestionIndex = 2
        
        viewModel.nextQuestion()
        XCTAssertTrue(viewModel.showResults)
    }
    
    func testPreviousQuestion() {
        viewModel.currentQuiz = makeQuiz(questionCount: 5, timeLimit: nil)
        viewModel.currentQuestionIndex = 2
        
        viewModel.previousQuestion()
        XCTAssertEqual(viewModel.currentQuestionIndex, 1)
    }
    
    func testPreviousQuestionAtFirstStaysAtZero() {
        viewModel.currentQuiz = makeQuiz(questionCount: 5, timeLimit: nil)
        viewModel.currentQuestionIndex = 0
        
        viewModel.previousQuestion()
        XCTAssertEqual(viewModel.currentQuestionIndex, 0)
    }
    
    // MARK: - Progress
    
    func testProgress() {
        viewModel.currentQuiz = makeQuiz(questionCount: 4, timeLimit: nil)
        viewModel.currentQuestionIndex = 1
        
        XCTAssertEqual(viewModel.progress, 0.5, accuracy: 0.01)
    }
    
    // MARK: - Time Formatting
    
    func testFormattedTime() {
        viewModel.totalTimeSpent = 125 // 2 min 5 sec
        XCTAssertEqual(viewModel.formattedTotalTime, "2:05")
    }
    
    // MARK: - Configuration
    
    func testAvailableTopics() {
        XCTAssertFalse(viewModel.availableTopics.isEmpty)
        XCTAssertTrue(viewModel.availableTopics.contains("Math"))
    }
    
    func testQuestionCountOptions() {
        XCTAssertEqual(viewModel.questionCountOptions, [5, 10, 15, 20])
    }
    
    // MARK: - Quiz with TimeLimit
    
    func testQuizTimeLimitProperty() {
        let quiz = makeQuiz(questionCount: 5, timeLimit: 300)
        XCTAssertEqual(quiz.timeLimit, 300)
    }
    
    func testQuizWithoutTimeLimit() {
        let quiz = makeQuiz(questionCount: 5, timeLimit: nil)
        XCTAssertNil(quiz.timeLimit)
    }
    
    // MARK: - Helpers
    
    private func makeQuiz(questionCount: Int, timeLimit: TimeInterval?) -> Quiz {
        let questions = (0..<questionCount).map { i in
            Quiz.QuizQuestion(
                id: "q\(i)",
                question: "Question \(i)?",
                options: ["A", "B", "C", "D"],
                correctAnswer: "A",
                explanation: "Because A",
                type: "mcq"
            )
        }
        return Quiz(
            id: "test-quiz",
            topic: "Math",
            questions: questions,
            difficulty: "medium",
            estimatedTime: questionCount * 60,
            timeLimit: timeLimit
        )
    }
}
