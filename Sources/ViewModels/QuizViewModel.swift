import Foundation
import SwiftUI
import Combine

// MARK: - Type Aliases
typealias Question = Quiz.QuizQuestion

// MARK: - Quiz ViewModel
@MainActor
class QuizViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentQuiz: Quiz?
    @Published var currentQuestionIndex = 0
    @Published var selectedAnswer: Int?
    @Published var isSubmitted = false
    @Published var userAnswers: [Int: String] = [:] // questionIndex: answer
    @Published var questionResults: [Int: Bool] = [:] // questionIndex: isCorrect
    @Published var verificationResults: [Int: AnswerVerification] = [:]

    @Published var isLoading = false
    @Published var error: LyoError?
    @Published var showResults = false

    @Published var timeRemaining: TimeInterval = 0
    @Published var totalTimeSpent: TimeInterval = 0

    // MARK: - Quiz Configuration

    @Published var selectedTopic = "Math"
    @Published var selectedDifficulty: QuizDifficulty = .medium
    @Published var numberOfQuestions = 5
    @Published var isAdaptive = true

    // MARK: - Private Properties

    private let repository: AIRepository
    private var timer: Timer?
    private var questionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: AIRepository = DefaultAIRepository()) {
        self.repository = repository
    }

    // MARK: - Quiz Generation

    func generateQuiz() async {
        isLoading = true
        error = nil
        reset()

        do {
            currentQuiz = try await repository.generateQuiz(
                topic: selectedTopic,
                difficulty: selectedDifficulty,
                numQuestions: numberOfQuestions
            )

            questionStartTime = Date()
            startTimer()

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Question Navigation

    func selectAnswer(_ index: Int) {
        guard !isSubmitted else { return }
        selectedAnswer = index
    }

    func submitAnswer() async {
        guard let answer = selectedAnswer,
              let quiz = currentQuiz,
              currentQuestionIndex < quiz.questions.count else {
            return
        }

        isSubmitted = true
        isLoading = true

        let question = quiz.questions[currentQuestionIndex]
        let selectedOption = question.options?[answer] ?? String(answer)

        // Store answer
        userAnswers[currentQuestionIndex] = selectedOption

        // Calculate time spent on this question
        if let startTime = questionStartTime {
            let timeSpent = Date().timeIntervalSince(startTime)
            totalTimeSpent += timeSpent
        }

        // Verify answer with AI
        do {
            let verification = try await repository.verifyAnswer(
                question: question.question,
                answer: selectedOption,
                correctAnswer: question.correctAnswer
            )

            verificationResults[currentQuestionIndex] = verification
            questionResults[currentQuestionIndex] = verification.isCorrect

            // If adaptive mode is enabled, adjust difficulty based on performance
            if isAdaptive {
                await adjustDifficulty(basedOn: verification.isCorrect)
            }

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func nextQuestion() {
        if currentQuestionIndex < (currentQuiz?.questions.count ?? 0) - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            isSubmitted = false
            questionStartTime = Date()
        } else {
            showResults = true
            stopTimer()
        }
    }

    func previousQuestion() {
        guard currentQuestionIndex > 0 else { return }
        currentQuestionIndex -= 1
        selectedAnswer = nil
        isSubmitted = false
    }

    // MARK: - Adaptive Difficulty

    private func adjustDifficulty(basedOn isCorrect: Bool) async {
        guard isAdaptive else { return }

        // Calculate current performance
        let correctCount = questionResults.values.filter { $0 }.count
        let totalAnswered = questionResults.count
        let successRate = Double(correctCount) / Double(totalAnswered)

        var newDifficulty = selectedDifficulty

        // Adjust difficulty based on performance
        if successRate >= 0.8 && selectedDifficulty != .hard {
            // Performing well, increase difficulty
            newDifficulty = selectedDifficulty == .easy ? .medium : .hard
        } else if successRate <= 0.4 && selectedDifficulty != .easy {
            // Struggling, decrease difficulty
            newDifficulty = selectedDifficulty == .hard ? .medium : .easy
        }

        if newDifficulty != selectedDifficulty {
            selectedDifficulty = newDifficulty
            print("Difficulty adjusted to: \(newDifficulty.rawValue)")
        }
    }

    // MARK: - Timer
    // TODO: Timer functionality requires timeLimit property in Quiz model

    private func startTimer() {
        // Timer functionality disabled - Quiz model doesn't have timeLimit property
        // guard let quiz = currentQuiz, quiz.timeLimit > 0 else { return }
        //
        // timeRemaining = quiz.timeLimit
        // timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        //     Task { @MainActor in
        //         guard let self = self else { return }
        //         self.timeRemaining -= 1
        //
        //         if self.timeRemaining <= 0 {
        //             self.stopTimer()
        //             await self.handleTimeUp()
        //         }
        //     }
        // }
    }

    nonisolated private func stopTimer() {
        Task { @MainActor in
            timer?.invalidate()
            timer = nil
        }
    }

    private func handleTimeUp() async {
        showResults = true
        // error = .business(.unknownError("Time's up!"))
    }

    // MARK: - Results

    func restartQuiz() {
        reset()
        Task {
            await generateQuiz()
        }
    }

    private func reset() {
        currentQuiz = nil
        currentQuestionIndex = 0
        selectedAnswer = nil
        isSubmitted = false
        userAnswers.removeAll()
        questionResults.removeAll()
        verificationResults.removeAll()
        showResults = false
        timeRemaining = 0
        totalTimeSpent = 0
        stopTimer()
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let lyoError = error as? LyoError {
            self.error = lyoError
        } else {
            self.error = .network(.serverError(500))
        }
    }

    // MARK: - Computed Properties

    var currentQuestion: Question? {
        guard let quiz = currentQuiz,
              currentQuestionIndex < quiz.questions.count else {
            return nil
        }
        return quiz.questions[currentQuestionIndex]
    }

    var progress: Double {
        guard let quiz = currentQuiz, !quiz.questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(quiz.questions.count)
    }

    var score: Int {
        let correct = questionResults.values.filter { $0 }.count
        return correct
    }

    var totalQuestions: Int {
        currentQuiz?.questions.count ?? 0
    }

    var scorePercentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(score) / Double(totalQuestions) * 100
    }

    var scoreGrade: String {
        let percentage = scorePercentage
        if percentage >= 90 { return "A" }
        else if percentage >= 80 { return "B" }
        else if percentage >= 70 { return "C" }
        else if percentage >= 60 { return "D" }
        else { return "F" }
    }

    var formattedTimeRemaining: String {
        formatTime(timeRemaining)
    }

    var formattedTotalTime: String {
        formatTime(totalTimeSpent)
    }

    var averageTimePerQuestion: String {
        guard totalQuestions > 0 else { return "0:00" }
        let average = totalTimeSpent / Double(totalQuestions)
        return formatTime(average)
    }

    var hasPassingScore: Bool {
        scorePercentage >= 70
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var availableTopics: [String] {
        ["Math", "Science", "History", "English", "Programming", "Geography"]
    }

    var difficultyOptions: [QuizDifficulty] {
        [.easy, .medium, .hard, .adaptive]
    }

    var questionCountOptions: [Int] {
        [5, 10, 15, 20]
    }

    // MARK: - Cleanup

    deinit {
        stopTimer()
    }
}
