//
//  A2UIQuizRenderers.swift
//  Lyo
//
//  Quiz and assessment renderer views for A2UI components
//

import SwiftUI

// MARK: - Quiz Renderers

struct A2UIQuizMCQRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    @State private var selectedIndex: Int? = nil
    @State private var hasSubmitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question
            Text(component.props.text ?? component.props.question ?? "")
                .font(.headline)
                .padding(.horizontal)

            // Options
            ForEach(Array((component.props.options ?? []).enumerated()), id: \.offset) { index, option in
                OptionButton(
                    text: option.text,
                    index: index,
                    isSelected: selectedIndex == index,
                    isCorrect: hasSubmitted ? isCorrectOption(option: option, index: index) : nil,
                    onTap: {
                        if !hasSubmitted {
                            selectedIndex = index
                        }
                    }
                )
            }

            // Submit Button
            if !hasSubmitted, selectedIndex != nil {
                Button("Submit Answer") {
                    hasSubmitted = true
                    // Trigger action
                    let action = A2UIAction(
                        id: "submit-\(component.id)",
                        trigger: .onSubmit,
                        type: .submitAnswer,
                        payload: ["answer": .int(selectedIndex ?? 0)],
                        debounceMs: nil,
                        hapticFeedback: nil
                    )
                    onAction?(action)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }

            // Explanation
            if hasSubmitted, let explanation = component.props.explanation {
                Text(explanation)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
    }

    private func isCorrectOption(option: A2UIQuizOption, index: Int) -> Bool? {
        if let answer = component.props.correctAnswer {
            switch answer {
            case .string(let value):
                return value == option.id || value == option.text
            case .int(let value):
                return value == index
            case .double(let value):
                return Int(value) == index
            default:
                return nil
            }
        }

        if let isCorrect = option.isCorrect {
            return isCorrect
        }

        return nil
    }
}

struct A2UIQuizMultiSelectRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    @State private var selectedIndices: Set<Int> = []
    @State private var hasSubmitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(component.props.text ?? "Multi-select Question")
                .font(.headline)
                .padding(.horizontal)

            Text("Select all correct answers:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ForEach(Array((component.props.options ?? []).enumerated()), id: \.offset) { index, option in
                MultiSelectButton(
                    text: option.text,
                    index: index,
                    isSelected: selectedIndices.contains(index),
                    isCorrect: hasSubmitted ? isCorrectOption(option: option, index: index) : nil,
                    onTap: {
                        if !hasSubmitted {
                            if selectedIndices.contains(index) {
                                selectedIndices.remove(index)
                            } else {
                                selectedIndices.insert(index)
                            }
                        }
                    }
                )
            }

            if !hasSubmitted, !selectedIndices.isEmpty {
                Button("Submit Answers") {
                    hasSubmitted = true
                    let action = A2UIAction(
                        id: "submit-\(component.id)",
                        trigger: .onSubmit,
                        type: .submitAnswer,
                        payload: ["answers": .array(Array(selectedIndices).map { .int($0) })],
                        debounceMs: nil,
                        hapticFeedback: nil
                    )
                    onAction?(action)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
    }

    private func isCorrectOption(option: A2UIQuizOption, index: Int) -> Bool? {
        if let answers = component.props.correctAnswers {
            for answer in answers {
                switch answer {
                case .string(let value):
                    if value == option.id || value == option.text { return true }
                case .int(let value):
                    if value == index { return true }
                case .double(let value):
                    if Int(value) == index { return true }
                default:
                    break
                }
            }
            return false
        }

        if let isCorrect = option.isCorrect {
            return isCorrect
        }

        return nil
    }
}

struct A2UIQuizTrueFalseRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    @State private var selectedAnswer: Bool? = nil
    @State private var hasSubmitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(component.props.text ?? "True or False?")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 20) {
                TrueFalseButton(
                    text: "True",
                    value: true,
                    isSelected: selectedAnswer == true,
                    isCorrect: hasSubmitted ? component.props.correctAnswer?.stringValue == "true" : nil,
                    onTap: {
                        if !hasSubmitted {
                            selectedAnswer = true
                        }
                    }
                )

                TrueFalseButton(
                    text: "False",
                    value: false,
                    isSelected: selectedAnswer == false,
                    isCorrect: hasSubmitted ? component.props.correctAnswer?.stringValue == "false" : nil,
                    onTap: {
                        if !hasSubmitted {
                            selectedAnswer = false
                        }
                    }
                )
            }
            .padding(.horizontal)

            if !hasSubmitted, selectedAnswer != nil {
                Button("Submit") {
                    hasSubmitted = true
                    let action = A2UIAction(
                        id: "submit-\(component.id)",
                        trigger: .onSubmit,
                        type: .submitAnswer,
                        payload: ["answer": .string(selectedAnswer == true ? "true" : "false")],
                        debounceMs: nil,
                        hapticFeedback: nil
                    )
                    onAction?(action)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Supporting Views

struct OptionButton: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let isCorrect: Bool?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                optionIndicator
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .padding(.horizontal)
        .disabled(isCorrect != nil) // Disabled after submission
    }

    @ViewBuilder
    private var optionIndicator: some View {
        if let correct = isCorrect {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(correct ? .green : .red)
        } else if isSelected {
            Image(systemName: "circle.fill")
                .foregroundColor(.blue)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.gray)
        }
    }

    private var backgroundColor: Color {
        if let correct = isCorrect {
            return correct ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        }
        return isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground)
    }

    private var borderColor: Color {
        if let correct = isCorrect {
            return correct ? .green : .red
        }
        return isSelected ? .blue : Color(.systemGray4)
    }
}

struct MultiSelectButton: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let isCorrect: Bool?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                checkboxIndicator
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var checkboxIndicator: some View {
        if let correct = isCorrect {
            if correct {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(.green)
            } else if isSelected {
                Image(systemName: "xmark.square.fill")
                    .foregroundColor(.red)
            } else {
                Image(systemName: "square")
                    .foregroundColor(.gray)
            }
        } else {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .blue : .gray)
        }
    }

    private var backgroundColor: Color {
        if let correct = isCorrect {
            return correct ? Color.green.opacity(0.1) : (isSelected ? Color.red.opacity(0.1) : Color(.systemBackground))
        }
        return isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground)
    }

    private var borderColor: Color {
        if let correct = isCorrect {
            return correct ? .green : (isSelected ? .red : Color(.systemGray4))
        }
        return isSelected ? .blue : Color(.systemGray4)
    }
}

struct TrueFalseButton: View {
    let text: String
    let value: Bool
    let isSelected: Bool
    let isCorrect: Bool?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: value ? "checkmark.circle" : "xmark.circle")
                    .font(.system(size: 30))
                    .foregroundColor(iconColor)
                Text(text)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private var iconColor: Color {
        if let correct = isCorrect {
            return correct ? .green : .red
        }
        return isSelected ? .blue : .gray
    }

    private var backgroundColor: Color {
        if let correct = isCorrect {
            return correct ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        }
        return isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground)
    }

    private var borderColor: Color {
        if let correct = isCorrect {
            return correct ? .green : .red
        }
        return isSelected ? .blue : Color(.systemGray4)
    }
}