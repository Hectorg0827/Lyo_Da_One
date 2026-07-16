import SwiftUI

struct QuizOverlayView: View {
    let quiz: QuizMoment
    let onComplete: (Bool) -> Void // Success
    
    @State private var selectedOption: Int?
    @State private var showFeedback = false
    @State private var isCorrect = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Think Fast!")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.yellow)
                    .padding(.top)
                
                Text(quiz.question)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach(0..<quiz.options.count, id: \.self) { index in
                        Button(action: {
                            submitAnswer(index)
                        }) {
                            HStack {
                                Text(quiz.options[index])
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.white)
                                Spacer()
                                if showFeedback && index == selectedOption {
                                    Image(systemName: index == quiz.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(index == quiz.correctIndex ? .green : .red)
                                }
                            }
                            .padding()
                            .background(buttonBackground(for: index))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(showFeedback)
                    }
                }
                .padding(.horizontal)
                
                if showFeedback {
                    VStack(spacing: 8) {
                        Text(isCorrect ? "Correct! +10 XP" : "Not quite.")
                            .font(.headline)
                            .foregroundColor(isCorrect ? .green : .red)
                        
                        Text(quiz.explanation)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Continue") {
                            onComplete(isCorrect)
                        }
                        .padding(.top, 8)
                        .buttonStyle(.plain)
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding(.vertical, 40)
        }
    }
    
    private func submitAnswer(_ index: Int) {
        selectedOption = index
        isCorrect = (index == quiz.correctIndex)
        withAnimation {
            showFeedback = true
        }
        
        if isCorrect {
            HapticManager.shared.success()
        } else {
            HapticManager.shared.error()
        }
    }
    
    private func buttonBackground(for index: Int) -> Color {
        if showFeedback {
            if index == quiz.correctIndex { return Color.green.opacity(0.3) }
            if index == selectedOption && !isCorrect { return Color.red.opacity(0.3) }
        }
        return Color.white.opacity(0.1)
    }
}
