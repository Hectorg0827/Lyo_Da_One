import SwiftUI

public struct SmartBlockQuizCard: View {
    let data: QuizData
    var onAnswerSubmitted: ((Int, Bool) -> Void)? = nil
    
    @State private var selectedOption: Int? = nil
    @State private var hasSubmitted = false
    @State private var showExplanation = false
    
    public init(data: QuizData, onAnswerSubmitted: ((Int, Bool) -> Void)? = nil) {
        self.data = data
        self.onAnswerSubmitted = onAnswerSubmitted
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                Text("QUIZ")
                    .font(DesignTokens.Typography.labelSmall.bold())
                    .foregroundColor(DesignTokens.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignTokens.Colors.accent.opacity(0.1))
                    .cornerRadius(DesignTokens.Radius.sm)
                
                if let diff = data.difficulty {
                    Text(diff.uppercased())
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                
                Spacer()
                
                if let hint = data.hint, !hasSubmitted {
                    Button {
                        // Action for hint (e.g. show alert or expand)
                    } label: {
                        Image(systemName: "lightbulb")
                            .foregroundColor(DesignTokens.Colors.warning)
                    }
                }
            }
            
            // Question
            Text(data.question)
                .font(DesignTokens.Typography.titleSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Options
            VStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(0..<data.options.count, id: \.self) { index in
                    OptionRow(
                        text: data.options[index],
                        isSelected: selectedOption == index,
                        isCorrect: data.correct == index,
                        showResult: hasSubmitted,
                        action: {
                            if !hasSubmitted {
                                withAnimation(DesignTokens.Animation.quick) {
                                    selectedOption = index
                                }
                            }
                        }
                    )
                }
            }
            
            // Action Button
            if !hasSubmitted {
                Button {
                    withAnimation(DesignTokens.Animation.standard) {
                        hasSubmitted = true
                        showExplanation = true
                        if let selected = selectedOption {
                            onAnswerSubmitted?(selected, selected == data.correct)
                        }
                    }
                } label: {
                    Text("Check Answer")
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedOption != nil 
                            ? DesignTokens.Colors.accent 
                            : DesignTokens.Colors.textTertiary.opacity(0.3)
                        )
                        .cornerRadius(DesignTokens.Radius.md)
                }
                .disabled(selectedOption == nil)
                .padding(.top, 8)
            }
            
            // Explanation
            if showExplanation {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedOption == data.correct ? "Correct!" : "Not quite.")
                        .font(DesignTokens.Typography.labelLarge.bold())
                        .foregroundColor(selectedOption == data.correct ? DesignTokens.Colors.success : DesignTokens.Colors.danger)
                    
                    Text(data.explanation)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.Colors.surfaceHighlight.opacity(0.5))
                .cornerRadius(DesignTokens.Radius.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            ZStack {
                DesignTokens.Colors.surfaceElevated
                if hasSubmitted {
                    PulsingTrimOverlay(cornerRadius: DesignTokens.Radius.lg)
                        .opacity(selectedOption == data.correct ? 0.3 : 0)
                }
            }
        )
        .cornerRadius(DesignTokens.Radius.lg)
        .applyShadow(DesignTokens.Shadow.md)
    }
}

private struct OptionRow: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(textColor)
                
                Spacer()
                
                if showResult {
                    Image(systemName: resultIcon)
                        .foregroundColor(resultColor)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
    }
    
    private var backgroundColor: Color {
        if showResult {
            if isSelected {
                return isCorrect ? DesignTokens.Colors.success.opacity(0.1) : DesignTokens.Colors.danger.opacity(0.1)
            }
            if isCorrect {
                return DesignTokens.Colors.success.opacity(0.05)
            }
        }
        return isSelected ? DesignTokens.Colors.accent.opacity(0.1) : DesignTokens.Colors.surfaceHighlight
    }
    
    private var borderColor: Color {
        if showResult {
            if isSelected {
                return isCorrect ? DesignTokens.Colors.success : DesignTokens.Colors.danger
            }
            if isCorrect {
                return DesignTokens.Colors.success.opacity(0.5)
            }
        }
        return isSelected ? DesignTokens.Colors.accent : Color.clear
    }
    
    private var textColor: Color {
        if showResult {
            if isSelected {
                return isCorrect ? DesignTokens.Colors.success : DesignTokens.Colors.danger
            }
            if isCorrect {
                return DesignTokens.Colors.success
            }
        }
        return .white
    }
    
    private var resultIcon: String {
        if isCorrect { return "checkmark.circle.fill" }
        return "xmark.circle.fill"
    }
    
    private var resultColor: Color {
        isCorrect ? DesignTokens.Colors.success : DesignTokens.Colors.danger
    }
}
