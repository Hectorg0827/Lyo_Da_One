import SwiftUI

struct ChatQuizDeckView: View {
    let deck: ChatQuizDeck
    var onAction: ((String) -> Void)? = nil

    @State private var hasStarted = false
    @State private var currentIndex = 0
    @State private var selectedIndex: Int?
    @State private var hasSubmitted = false
    @State private var score = 0
    @State private var answers: [String: Bool] = [:]
    @State private var confidenceByQuestion: [String: Int] = [:]

    private var isFinished: Bool {
        hasStarted && currentIndex >= deck.questions.count
    }

    private var currentQuestion: ChatQuizQuestion? {
        guard deck.questions.indices.contains(currentIndex) else { return nil }
        return deck.questions[currentIndex]
    }

    var body: some View {
        Group {
            if !hasStarted {
                introCard
            } else if isFinished {
                resultCard
            } else if let question = currentQuestion {
                questionCard(question)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.mode.displayName.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.78))
                        .tracking(0.8)
                    Text(deck.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.14), in: Circle())
            }

            Text(deck.intro)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                quizPill("\(deck.questions.count) questions", icon: "list.number")
                quizPill(deck.difficulty, icon: "slider.horizontal.3")
                quizPill("+\(deck.xpReward) XP", icon: "bolt.fill")
            }

            Button {
                HapticManager.shared.playMediumImpact()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    hasStarted = true
                }
            } label: {
                Label("Start Quiz", systemImage: "play.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "111827"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white, in: Capsule())
            }

            HStack(spacing: 10) {
                secondaryButton("Make Harder", icon: "flame.fill")
                secondaryButton("Study First", icon: "book.fill")
            }
        }
        .padding(20)
        .background(introBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private func questionCard(_ question: ChatQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("\(currentIndex + 1) of \(deck.questions.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12), in: Capsule())
                ProgressView(value: Double(currentIndex + 1), total: Double(max(deck.questions.count, 1)))
                    .tint(Color(hex: "8B5CF6"))
                Spacer()
            }

            if let comment = question.classmateComment, !comment.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(classmateName)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color(hex: "F59E0B"))
                    Text(comment)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text(question.question)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    answerButton(choice: choice, index: index, question: question)
                }
            }

            if question.asksConfidence && selectedIndex != nil && !hasSubmitted {
                confidencePicker(questionId: question.id)
            }

            if hasSubmitted {
                feedbackView(question)
            } else {
                Button {
                    submit(question)
                } label: {
                    Text("Lock Answer")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedIndex == nil ? Color.white.opacity(0.12) : Color(hex: "4F46E5"), in: Capsule())
                }
                .disabled(selectedIndex == nil)
                .opacity(selectedIndex == nil ? 0.65 : 1)
            }
        }
        .padding(20)
        .background(Color(hex: "0B1020"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var resultCard: some View {
        let total = max(deck.questions.count, 1)
        let earnedXP = Int((Double(score) / Double(total)) * Double(deck.xpReward))
        let needsPractice = score < total

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quiz Complete")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color(hex: "A78BFA"))
                    Text("\(score)/\(total)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    resultBadge("+\(earnedXP) XP")
                    resultBadge(needsPractice ? "Needs Practice" : "Mastered")
                }
            }

            Text(resultSummary(needsPractice: needsPractice))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(deck.nextActions, id: \.self) { action in
                    Button {
                        HapticManager.shared.playLightImpact()
                        onAction?(action)
                    } label: {
                        HStack {
                            Text(action)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(13)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }

            Button {
                reset()
            } label: {
                Label("Retake Quiz", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "111827"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white, in: Capsule())
            }
        }
        .padding(20)
        .background(Color(hex: "0B1020"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func answerButton(choice: String, index: Int, question: ChatQuizQuestion) -> some View {
        let isSelected = selectedIndex == index
        let isCorrect = index == question.correctIndex
        let shouldShowCorrect = hasSubmitted && isCorrect
        let shouldShowWrong = hasSubmitted && isSelected && !isCorrect

        return Button {
            guard !hasSubmitted else { return }
            HapticManager.shared.playSelection()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedIndex = index
            }
        } label: {
            HStack(spacing: 12) {
                Text(String(UnicodeScalar(65 + index)!))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(optionAccent(isSelected: isSelected, correct: shouldShowCorrect, wrong: shouldShowWrong), in: Circle())
                Text(choice)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if shouldShowCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
                } else if shouldShowWrong {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.red)
                }
            }
            .padding(13)
            .background(optionBackground(isSelected: isSelected, correct: shouldShowCorrect, wrong: shouldShowWrong), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(optionStroke(isSelected: isSelected, correct: shouldShowCorrect, wrong: shouldShowWrong), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func feedbackView(_ question: ChatQuizQuestion) -> some View {
        let correct = selectedIndex == question.correctIndex
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(correct ? Color.green : Color.red)
                Text(correct ? question.correctReaction : question.incorrectReaction)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(question.explanation)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
            Text(question.whyItMatters)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "A78BFA"))

            Button {
                nextQuestion()
            } label: {
                Text(currentIndex == deck.questions.count - 1 ? "See Results" : "Continue")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(hex: "4F46E5"), in: Capsule())
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func confidencePicker(questionId: String) -> some View {
        HStack(spacing: 8) {
            confidenceButton("Guessed", value: 1, questionId: questionId)
            confidenceButton("Kind of sure", value: 2, questionId: questionId)
            confidenceButton("Confident", value: 3, questionId: questionId)
        }
    }

    private func confidenceButton(_ label: String, value: Int, questionId: String) -> some View {
        let selected = confidenceByQuestion[questionId] == value
        return Button {
            confidenceByQuestion[questionId] = value
            HapticManager.shared.playSelection()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(selected ? Color(hex: "111827") : .white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selected ? Color.white : Color.white.opacity(0.08), in: Capsule())
        }
    }

    private func quizPill(_ label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(0.86))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func secondaryButton(_ label: String, icon: String) -> some View {
        Button {
            HapticManager.shared.playLightImpact()
            onAction?(label)
        } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.10), in: Capsule())
        }
    }

    private func resultBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12), in: Capsule())
    }

    private var introBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED"), Color(hex: "0F172A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconName: String {
        switch deck.mode {
        case .quickCheck: return "bolt.circle.fill"
        case .classroomChallenge: return "person.3.fill"
        case .reviewMistakes: return "arrow.counterclockwise.circle.fill"
        case .confidenceQuiz: return "gauge.with.dots.needle.67percent"
        case .bossRound: return "crown.fill"
        }
    }

    private var classmateName: String {
        deck.mode == .classroomChallenge ? "Rio" : "Lyo"
    }

    private func optionAccent(isSelected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return .green }
        if wrong { return .red }
        return isSelected ? Color(hex: "4F46E5") : Color.white.opacity(0.14)
    }

    private func optionBackground(isSelected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return Color.green.opacity(0.16) }
        if wrong { return Color.red.opacity(0.16) }
        return isSelected ? Color(hex: "4F46E5").opacity(0.20) : Color.white.opacity(0.055)
    }

    private func optionStroke(isSelected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return Color.green.opacity(0.55) }
        if wrong { return Color.red.opacity(0.55) }
        return isSelected ? Color(hex: "8B5CF6") : Color.white.opacity(0.08)
    }

    private func submit(_ question: ChatQuizQuestion) {
        guard let selected = selectedIndex else { return }
        let correct = selected == question.correctIndex
        answers[question.id] = correct
        if correct { score += 1; HapticManager.shared.playSuccess() } else { HapticManager.shared.playError() }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            hasSubmitted = true
        }
    }

    private func nextQuestion() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            currentIndex += 1
            selectedIndex = nil
            hasSubmitted = false
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            hasStarted = false
            currentIndex = 0
            selectedIndex = nil
            hasSubmitted = false
            score = 0
            answers = [:]
            confidenceByQuestion = [:]
        }
    }

    private func resultSummary(needsPractice: Bool) -> String {
        if needsPractice {
            return "You have the core idea, but a few answers show where Lyo should target review next. The best move is to review mistakes, then do one short practice round."
        }
        return "Strong round. You answered consistently and can move into a harder challenge or save this topic as mastered."
    }
}
