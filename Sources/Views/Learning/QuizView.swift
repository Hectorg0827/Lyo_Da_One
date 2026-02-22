import SwiftUI

// MARK: - Quiz View
struct QuizView: View {

    @StateObject private var viewModel: QuizViewModel
    @State private var showSettings = false
    
    init(quiz: Quiz? = nil) {
        let vm = QuizViewModel()
        if let quiz = quiz {
            vm.currentQuiz = quiz
        }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.currentQuiz == nil {
                    QuizSetupView(viewModel: viewModel)
                } else if viewModel.showResults {
                    QuizResultsView(viewModel: viewModel)
                } else {
                    QuizQuestionView(viewModel: viewModel)
                }
            }
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.currentQuiz != nil && !viewModel.showResults {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.restartQuiz()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
        }
    }
}

// MARK: - Quiz Setup View
struct QuizSetupView: View {
    @ObservedObject var viewModel: QuizViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Adaptive Quiz")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Test your knowledge and improve your skills")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Settings
                VStack(alignment: .leading, spacing: 20) {
                    // Topic Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.availableTopics, id: \.self) { topic in
                                    Button {
                                        viewModel.selectedTopic = topic
                                    } label: {
                                        Text(topic)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(viewModel.selectedTopic == topic ? .white : .blue)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(viewModel.selectedTopic == topic ? Color.blue : Color.blue.opacity(0.1))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }

                    // Difficulty Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Difficulty")
                                .font(.headline)

                            if viewModel.isAdaptive {
                                Text("(Adaptive)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }

                        HStack(spacing: 12) {
                            ForEach([QuizDifficulty.easy, .medium, .hard], id: \.self) { difficulty in
                                Button {
                                    viewModel.selectedDifficulty = difficulty
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: difficultyIcon(for: difficulty))
                                            .font(.title2)

                                        Text(difficulty.rawValue.capitalized)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(viewModel.selectedDifficulty == difficulty ? .white : .primary)
                                    .background(viewModel.selectedDifficulty == difficulty ? Color.blue : Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }

                    // Adaptive Mode Toggle
                    Toggle("Adaptive Difficulty", isOn: $viewModel.isAdaptive)
                        .font(.headline)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    // Number of Questions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Questions")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(viewModel.questionCountOptions, id: \.self) { count in
                                Button {
                                    viewModel.numberOfQuestions = count
                                } label: {
                                    Text("\(count)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(viewModel.numberOfQuestions == count ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.numberOfQuestions == count ? Color.blue : Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Start Button
                Button {
                    Task {
                        await viewModel.generateQuiz()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "play.fill")
                            Text("Start Quiz")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private func difficultyIcon(for difficulty: QuizDifficulty) -> String {
        switch difficulty {
        case .easy: return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard: return "bolt.fill"
        case .adaptive: return "sparkles"
        }
    }
}

// MARK: - Quiz Question View
struct QuizQuestionView: View {
    @ObservedObject var viewModel: QuizViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.totalQuestions)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if viewModel.timeRemaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                            Text(viewModel.formattedTimeRemaining)
                        }
                        .font(.subheadline)
                        .foregroundColor(viewModel.timeRemaining < 60 ? .red : .secondary)
                    }
                }

                ProgressView(value: viewModel.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let question = viewModel.currentQuestion {
                        // Question
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(question.type.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)

                                if viewModel.isAdaptive {
                                    Text("Difficulty: \(viewModel.selectedDifficulty.rawValue.capitalized)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }

                            Text(question.question)
                                .font(.title3)
                                .fontWeight(.semibold)

                            // Hint functionality disabled - QuizQuestion model doesn't have hint property
                            // if let hint = question.hint, viewModel.isSubmitted {
                            //     HStack(spacing: 8) {
                            //         Image(systemName: "lightbulb.fill")
                            //             .foregroundColor(.yellow)
                            //         Text(hint)
                            //             .font(.subheadline)
                            //             .foregroundColor(.secondary)
                            //     }
                            //     .padding()
                            //     .background(Color.yellow.opacity(0.1))
                            //     .cornerRadius(12)
                            // }
                        }

                        // Answer Options
                        VStack(spacing: 12) {
                            ForEach(Array((question.options ?? []).enumerated()), id: \.offset) { index, option in
                                AnswerOptionView(
                                    option: option,
                                    index: index,
                                    isSelected: viewModel.selectedAnswer == index,
                                    isSubmitted: viewModel.isSubmitted,
                                    isCorrect: viewModel.verificationResults[viewModel.currentQuestionIndex]?.isCorrect == true && viewModel.selectedAnswer == index,
                                    isWrong: viewModel.verificationResults[viewModel.currentQuestionIndex]?.isCorrect == false && viewModel.selectedAnswer == index
                                ) {
                                    viewModel.selectAnswer(index)
                                }
                            }
                        }

                        // Explanation (shown after submission)
                        if viewModel.isSubmitted,
                           let verification = viewModel.verificationResults[viewModel.currentQuestionIndex] {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: verification.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(verification.isCorrect ? .green : .red)
                                        .font(.title2)

                                    Text(verification.isCorrect ? "Correct!" : "Incorrect")
                                        .font(.headline)
                                        .foregroundColor(verification.isCorrect ? .green : .red)
                                }

                                Text(verification.explanation)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                // Suggestions feature disabled - AnswerVerification model doesn't have suggestions property
                                // if let suggestions = verification.suggestions, !suggestions.isEmpty {
                                //     VStack(alignment: .leading, spacing: 8) {
                                //         Text("Tips:")
                                //             .font(.subheadline)
                                //             .fontWeight(.semibold)
                                //
                                //         ForEach(suggestions, id: \.self) { suggestion in
                                //             HStack(alignment: .top, spacing: 8) {
                                //                 Image(systemName: "lightbulb.fill")
                                //                     .font(.caption)
                                //                     .foregroundColor(.blue)
                                //                 Text(suggestion)
                                //                     .font(.caption)
                                //                     .foregroundColor(.secondary)
                                //             }
                                //         }
                                //     }
                                // }
                            }
                            .padding()
                            .background(verification.isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Action Buttons
            HStack(spacing: 16) {
                if viewModel.currentQuestionIndex > 0 {
                    Button {
                        viewModel.previousQuestion()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                if !viewModel.isSubmitted {
                    Button {
                        Task {
                            await viewModel.submitAnswer()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Submit")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.selectedAnswer != nil ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.selectedAnswer == nil || viewModel.isLoading)
                } else {
                    Button {
                        viewModel.nextQuestion()
                    } label: {
                        HStack {
                            Text(viewModel.currentQuestionIndex < viewModel.totalQuestions - 1 ? "Next" : "Finish")
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Answer Option View
struct AnswerOptionView: View {
    let option: String
    let index: Int
    let isSelected: Bool
    let isSubmitted: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(optionLetter)
                    .font(.headline)
                    .foregroundColor(textColor)
                    .frame(width: 32, height: 32)
                    .background(circleColor)
                    .clipShape(Circle())

                Text(option)
                    .font(.body)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSubmitted {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : (isWrong ? "xmark.circle.fill" : ""))
                        .foregroundColor(isCorrect ? .green : .red)
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .disabled(isSubmitted)
    }

    private var optionLetter: String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return letters[index]
    }

    private var backgroundColor: Color {
        if isCorrect {
            return Color.green.opacity(0.1)
        } else if isWrong {
            return Color.red.opacity(0.1)
        } else if isSelected {
            return Color.blue.opacity(0.1)
        } else {
            return Color(.systemGray6)
        }
    }

    private var borderColor: Color {
        if isCorrect {
            return .green
        } else if isWrong {
            return .red
        } else if isSelected {
            return .blue
        } else {
            return .clear
        }
    }

    private var circleColor: Color {
        if isCorrect {
            return .green
        } else if isWrong {
            return .red
        } else if isSelected {
            return .blue
        } else {
            return Color(.systemGray5)
        }
    }

    private var textColor: Color {
        if isCorrect || isWrong || isSelected {
            return .white
        } else {
            return .primary
        }
    }
}

// MARK: - Quiz Results View
struct QuizResultsView: View {
    @ObservedObject var viewModel: QuizViewModel
    @State private var showReviewSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: viewModel.hasPassingScore ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(viewModel.hasPassingScore ? .green : .red)

                    Text(viewModel.hasPassingScore ? "Great Job!" : "Keep Practicing!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("You scored \(viewModel.score) out of \(viewModel.totalQuestions)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // Score Card
                VStack(spacing: 16) {
                    HStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("\(Int(viewModel.scorePercentage))%")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(scoreColor)

                            Text("Score")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()
                            .frame(height: 60)

                        VStack(spacing: 8) {
                            Text(viewModel.scoreGrade)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(scoreColor)

                            Text("Grade")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Stats
                    VStack(spacing: 12) {
                        StatRow(label: "Correct Answers", value: "\(viewModel.score)")
                        StatRow(label: "Wrong Answers", value: "\(viewModel.totalQuestions - viewModel.score)")
                        StatRow(label: "Total Time", value: viewModel.formattedTotalTime)
                        StatRow(label: "Average Time/Question", value: viewModel.averageTimePerQuestion)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        viewModel.restartQuiz()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }

                    Button {
                        showReviewSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Review Answers")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .sheet(isPresented: $showReviewSheet) {
                        QuizReviewSheet(viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private var scoreColor: Color {
        let percentage = viewModel.scorePercentage
        if percentage >= 80 { return .green }
        else if percentage >= 60 { return .orange }
        else { return .red }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct QuizView_Previews: PreviewProvider {
    static var previews: some View {
        QuizView()
    }
}

// MARK: - Quiz Review Sheet
struct QuizReviewSheet: View {
    @ObservedObject var viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let quiz = viewModel.currentQuiz {
                        ForEach(Array(quiz.questions.enumerated()), id: \.offset) { index, question in
                            VStack(alignment: .leading, spacing: 12) {
                                // Question header
                                HStack {
                                    Text("Q\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(viewModel.questionResults[index] == true ? Color.green : Color.red)
                                        .cornerRadius(6)

                                    Text(question.question)
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()

                                    Image(systemName: viewModel.questionResults[index] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(viewModel.questionResults[index] == true ? .green : .red)
                                }

                                // User's answer
                                if let userAnswer = viewModel.userAnswers[index] {
                                    HStack(spacing: 6) {
                                        Text("Your answer:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(userAnswer)
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(viewModel.questionResults[index] == true ? .green : .red)
                                    }
                                }

                                // Correct answer
                                HStack(spacing: 6) {
                                    Text("Correct:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(question.correctAnswer)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.green)
                                }

                                // AI explanation
                                if let verification = viewModel.verificationResults[index] {
                                    Text(verification.explanation)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Review Answers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
