//
//  PremiumQuizView.swift
//  Lyo
//
//  Unified Quiz component for MCQ, True/False, and assessment
//  Handles state, validation, and feedback animations
//

import SwiftUI

struct PremiumQuizView: View {
    let question: String
    let options: [String]
    let correctIndex: Int
    var explanation: String? = nil
    var onAnswerSubmitted: ((Int, Bool) -> Void)? = nil
    
    @State private var selectedIndex: Int? = nil
    @State private var hasSubmitted: Bool = false
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.blue)
                    Text("QUIZ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.15))
                .clipShape(Capsule())
                
                Spacer()
                
                if hasSubmitted {
                    let isCorrect = selectedIndex == correctIndex
                    HStack(spacing: 6) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(isCorrect ? "CORRECT" : "INCORRECT")
                            .font(.system(size: 11, weight: .black))
                    }
                    .foregroundColor(isCorrect ? .green : .red)
                }
            }
            
            // Question
            Text(question)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .offset(x: shakeOffset)
            
            // Options
            VStack(spacing: 12) {
                ForEach(0..<options.count, id: \.self) { index in
                    PremiumOptionRow(
                        text: options[index],
                        isSelected: selectedIndex == index,
                        isCorrect: index == correctIndex,
                        isWrong: hasSubmitted && selectedIndex == index && index != correctIndex,
                        showResult: hasSubmitted,
                        onTap: {
                            if !hasSubmitted {
                                selectOption(index)
                            }
                        }
                    )
                }
            }
            
            // Explanation
            if hasSubmitted, let explanation = explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("Explanation")
                            .font(.subheadline.bold())
                    }
                    
                    Text(explanation)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Submit Button
            if !hasSubmitted {
                Button(action: submit) {
                    Text("Submit Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedIndex != nil ? 
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(selectedIndex == nil)
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func selectOption(_ index: Int) {
        selectedIndex = index
        HapticManager.shared.playSelection()
    }
    
    private func submit() {
        guard let selected = selectedIndex else { return }
        
        withAnimation(.spring()) {
            hasSubmitted = true
        }
        
        let isCorrect = selected == correctIndex
        if isCorrect {
            HapticManager.shared.playSuccess()
        } else {
            HapticManager.shared.playError()
            shake()
        }
        
        onAnswerSubmitted?(selected, isCorrect)
    }
    
    private func shake() {
        for i in 0...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.linear(duration: 0.05)) {
                    shakeOffset = i % 2 == 0 ? 5 : -5
                }
                if i == 5 {
                    withAnimation(.linear(duration: 0.05)) {
                        shakeOffset = 0
                    }
                }
            }
        }
    }
}

// MARK: - Option Row

struct PremiumOptionRow: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let showResult: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Radio Indicator
                ZStack {
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected || (showResult && isCorrect) {
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: 14, height: 14)
                    }
                }
                
                Text(text)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(textColor)
                
                Spacer()
                
                if showResult {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isWrong {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.05), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if showResult {
            if isCorrect { return Color.green.opacity(0.15) }
            if isWrong { return Color.red.opacity(0.15) }
        }
        if isSelected { return Color.blue.opacity(0.1) }
        return Color.white.opacity(0.04)
    }
    
    private var borderColor: Color {
        if showResult {
            if isCorrect { return .green }
            if isWrong { return .red }
        }
        if isSelected { return .blue }
        return Color.white.opacity(0.2)
    }
    
    private var indicatorColor: Color {
        if showResult {
            if isCorrect { return .green }
            if isWrong { return .red }
        }
        return .blue
    }
    
    private var textColor: Color {
        if showResult {
            if isCorrect { return .green }
            if isWrong { return .red }
        }
        if isSelected { return .white }
        return .white.opacity(0.7)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PremiumQuizView(
            question: "Which collection type in Swift stores unique values with no defined order?",
            options: ["Array", "Dictionary", "Set", "Tuple"],
            correctIndex: 2,
            explanation: "A Set stores distinct values of the same type in a collection with no defined ordering. You use a set instead of an array when the order of items is not important, or when you need to ensure that an item only appears once."
        )
        .padding()
    }
}
