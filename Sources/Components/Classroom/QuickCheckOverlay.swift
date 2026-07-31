import SwiftUI

struct QuickCheckOverlay: View {
    @ObservedObject var viewModel: ClassroomViewModel
    @State private var selectedOption: String? = nil
    @State private var isAnswered = false
    @State private var timeRemaining: Int? = nil
    @State private var timer: Timer? = nil
    
    var body: some View {
        ZStack {
            // Full-bleed background
            Color("LyoSurface")
                .opacity(0.98)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                header
                
                Spacer()
                
                // Question content
                questionContent
                
                Spacer()
                
                // Options or interactive elements
                optionsView
                
                Spacer()
                
                // Bottom actions
                bottomActions
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundColor(Color("LyoAccent"))

            // Title
            Text("Quick Check")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Timer
            if let timeRemaining = timeRemaining {
                Text("\(timeRemaining)s")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(timeRemaining <= 5 ? .red : Color("LyoAccent"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color("LyoBackground"))
                    )
            }

            // Close — always available so this overlay can never trap the learner.
            // Closing without answering is treated the same as "I don't know": skip.
            Button {
                skip()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
            }
            .accessibilityLabel("Close, skip this question")
            .padding(.leading, 12)
        }
    }
    
    // MARK: - Question Content
    
    private var questionContent: some View {
        VStack(spacing: 20) {
            if let check = viewModel.currentQuickCheck {
                // Question text
                Text(check.question)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                
                // Check type badge
                Text(checkTypeName(check.type))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("LyoAccent"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .stroke(Color("LyoAccent"), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Options View
    
    @ViewBuilder
    private var optionsView: some View {
        if let check = viewModel.currentQuickCheck {
            switch check.type {
            case .multipleChoice, .trueFalse:
                multipleChoiceOptions(check: check)
            case .tapToOrder:
                tapToOrderOptions(check: check)
            case .labelDiagram:
                labelDiagramView(check: check)
            case .flashDecision:
                flashDecisionOptions(check: check)
            }
        }
    }
    
    // Multiple Choice Options
    private func multipleChoiceOptions(check: QuickCheck) -> some View {
        VStack(spacing: 16) {
            ForEach(check.options ?? [], id: \.self) { option in
                Button {
                    selectOption(option)
                } label: {
                    HStack {
                        Text(option)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        if selectedOption == option {
                            if isAnswered {
                                // Show result
                                Image(systemName: option == check.correctAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(option == check.correctAnswer ? .green : .red)
                            } else {
                                // Show selection
                                Circle()
                                    .fill(Color("LyoAccent"))
                                    .frame(width: 24, height: 24)
                            }
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                selectedOption == option
                                    ? Color("LyoAccent").opacity(0.2)
                                    : Color("LyoBackground").opacity(0.5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selectedOption == option
                                            ? Color("LyoAccent")
                                            : Color.white.opacity(0.2),
                                        lineWidth: 2
                                    )
                            )
                    )
                }
                .disabled(isAnswered)
            }
        }
    }
    
    // Tap to Order Options
    private func tapToOrderOptions(check: QuickCheck) -> some View {
        VStack(spacing: 12) {
            Text("Tap in the correct order")
                .font(.system(size: 16))
                .foregroundColor(Color("LyoTextSecondary"))
            
            // Simplified for now - show as grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(check.options ?? [], id: \.self) { option in
                    Button {
                        selectOption(option)
                    } label: {
                        Text(option)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("LyoBackground").opacity(0.5))
                            )
                    }
                    .disabled(isAnswered)
                }
            }
        }
    }
    
    // Label Diagram
    private func labelDiagramView(check: QuickCheck) -> some View {
        VStack(spacing: 16) {
            // Placeholder for diagram
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoBackground").opacity(0.5))
                .frame(height: 300)
                .overlay(
                    VStack {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 48))
                            .foregroundColor(Color("LyoAccent").opacity(0.5))
                        Text("Interactive Diagram")
                            .font(.system(size: 16))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                )
            
            // Options as labels to drag
            HStack(spacing: 12) {
                ForEach(check.options ?? [], id: \.self) { option in
                    Text(option)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color("LyoAccent").opacity(0.3))
                        )
                }
            }
        }
    }
    
    // Flash Decision
    private func flashDecisionOptions(check: QuickCheck) -> some View {
        HStack(spacing: 40) {
            ForEach(check.options ?? [], id: \.self) { option in
                Button {
                    selectOption(option)
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: option.lowercased() == "true" || option.lowercased() == "yes" ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.system(size: 48))
                        Text(option)
                            .font(.system(size: 22, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 140, height: 140)
                    .background(
                        Circle()
                            .fill(Color("LyoBackground").opacity(0.5))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            )
                    )
                }
                .disabled(isAnswered)
            }
        }
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        VStack(spacing: 16) {
            // Submit or continue button
            if !isAnswered {
                HStack(spacing: 12) {
                    // "I don't know" — a real skip, not scored as wrong, never
                    // forces the reteach walkthrough.
                    Button {
                        skip()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.forward.circle")
                            Text("I don't know")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color("LyoBackground"))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }

                    // "Ask for help" — routes to a real, question-specific
                    // explanation instead of a canned wrong-answer reteach.
                    Button {
                        askForHelp()
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Ask for help")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("LyoAccent"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color("LyoBackground"))
                                .overlay(
                                    Capsule()
                                        .stroke(Color("LyoAccent").opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                }

                // Submit button (if option selected)
                if selectedOption != nil {
                    Button {
                        submitAnswer()
                    } label: {
                        Text("Submit")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("LyoBackground"))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color("LyoAccent"))
                            )
                    }
                }
            } else {
                // Continue button (after answered)
                Button {
                    continueAfterCheck()
                } label: {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("LyoBackground"))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color("LyoAccent"))
                        )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkTypeName(_ type: QuickCheck.CheckType) -> String {
        switch type {
        case .multipleChoice: return "Multiple Choice"
        case .tapToOrder: return "Tap to Order"
        case .labelDiagram: return "Label Diagram"
        case .flashDecision: return "Quick Decision"
        case .trueFalse: return "True or False"
        }
    }
    
    private func selectOption(_ option: String) {
        guard !isAnswered else { return }
        selectedOption = option
    }
    
    private func submitAnswer() {
        guard let selected = selectedOption else { return }
        isAnswered = true
        timer?.invalidate()
        
        // Add haptic feedback
        if selected == viewModel.currentQuickCheck?.correctAnswer {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        viewModel.answerCheck(selected)
    }
    
    private func skip() {
        timer?.invalidate()
        viewModel.skipCheck()
    }

    private func askForHelp() {
        timer?.invalidate()
        viewModel.requestHelp()
    }
    
    private func continueAfterCheck() {
        viewModel.currentQuickCheck = nil
        viewModel.state = .playing
        
        // Auto-start narration if enabled
        if viewModel.settings.autoplayNarration {
            viewModel.startNarration()
        }
    }
    
    private func startTimer() {
        guard let timeLimit = viewModel.currentQuickCheck?.timeLimit else { return }
        
        timeRemaining = timeLimit
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let remaining = timeRemaining {
                if remaining > 0 {
                    timeRemaining = remaining - 1
                } else {
                    // Time's up - auto-submit the selected option, or skip
                    // (not scored as wrong) if nothing was selected.
                    timer?.invalidate()
                    if selectedOption != nil {
                        submitAnswer()
                    } else {
                        skip()
                    }
                }
            }
        }
    }
}
