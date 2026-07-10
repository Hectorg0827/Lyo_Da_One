//
//  InteractiveQuizBubbleView.swift
//  Lyo
//
//  Created for Dynamic Chat
//

import SwiftUI

struct InteractiveQuizBubbleView: View {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String?
    let onAnswerSelected: (Int) -> Void
    
    @State private var selectedIndex: Int?
    @State private var hasSubmitted = false
    @State private var showExplanation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(.white)
                Text("QUICK QUIZ")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(1)
            }
            
            // Question
            Text(question)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Options
            VStack(spacing: 12) {
                ForEach(0..<options.count, id: \.self) { index in
                    QuizOptionButton(
                        text: options[index],
                        state: getOptionState(for: index),
                        action: {
                            handleSelection(index)
                        }
                    )
                }
            }
            
            // Feedback / Explanation
            if showExplanation, let explanation = explanation {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .overlay(Color.white.opacity(0.2))
                    
                    HStack {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isCorrect ? .green : .red)
                        Text(isCorrect ? "Correct!" : "Nice try!")
                            .fontWeight(.bold)
                            .foregroundStyle(isCorrect ? .green : .red)
                    }
                    
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isCorrect ? Color.green.opacity(0.5) : (hasSubmitted ? Color.red.opacity(0.5) : Color.white.opacity(0.1)),
                    lineWidth: 1
                )
        )
    }
    
    private var isCorrect: Bool {
        return selectedIndex == correctIndex
    }
    
    private func getOptionState(for index: Int) -> QuizOptionState {
        if !hasSubmitted {
            return selectedIndex == index ? .selected : .default
        }
        
        if index == correctIndex {
            return .correct
        }
        
        if index == selectedIndex && index != correctIndex {
            return .wrong
        }
        
        return .disabled
    }
    
    private func handleSelection(_ index: Int) {
        guard !hasSubmitted else { return }
        
        withAnimation(.spring()) {
            selectedIndex = index
            hasSubmitted = true
            showExplanation = true
        }
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(index == correctIndex ? .success : .error)
        
        // Callback
        onAnswerSelected(index)
    }
}

enum QuizOptionState {
    case `default`, selected, correct, wrong, disabled
}

struct QuizOptionButton: View {
    let text: String
    let state: QuizOptionState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .disabled(state == .disabled || state == .correct || state == .wrong)
        .scaleEffect(state == .selected ? 0.98 : 1.0)
    }
    
    var backgroundColor: Color {
        switch state {
        case .default: return Color.white.opacity(0.05)
        case .selected: return Color.blue.opacity(0.2)
        case .correct: return Color.green.opacity(0.2)
        case .wrong: return Color.red.opacity(0.2)
        case .disabled: return Color.black.opacity(0.03) // Dim other options
        }
    }
    
    var borderColor: Color {
        switch state {
        case .default: return Color.white.opacity(0.1)
        case .selected: return Color.blue
        case .correct: return Color.green
        case .wrong: return Color.red
        case .disabled: return Color.clear
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        InteractiveQuizBubbleView(
            question: "Which keyword is used to declare a constant in Swift?",
            options: ["var", "let", "const", "final"],
            correctIndex: 1,
            explanation: "'let' is used for constants, while 'var' is for variables.",
            onAnswerSelected: { _ in }
        )
        .padding()
    }
}
