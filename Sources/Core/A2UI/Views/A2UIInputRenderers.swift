//
//  A2UIInputRenderers.swift
//  Lyo
//
//  Renderers for input-based A2UI components like Fill-in-the-Blank and Short Answer quizzes
//

import SwiftUI

struct A2UIQuizFillBlankRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?
    
    @State private var userAnswer: String = ""
    @State private var isSubmitted: Bool = false
    @State private var isCorrect: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question Text
            if let questionText = component.props.question ?? component.props.title {
                Text(.init(questionText)) // Render markdown if present
                    .font(.headline)
                    .foregroundColor(Color(hex: component.props.foregroundColor ?? "#FFFFFF"))
            }

            // Input Field
            TextField(component.props.placeholder ?? "Type your answer...", text: $userAnswer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 8)
                .disabled(isSubmitted)
            
            // Submit Button
            if !isSubmitted {
                Button(action: submitAnswer) {
                    Text("Check Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                // Feedback
                HStack {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                    Text(isCorrect ? "Correct!" : "Not quite.")
                        .font(.headline)
                        .foregroundColor(isCorrect ? .green : .red)
                    Spacer()
                }
                
                // Explanation
                if let explanation = component.props.explanation, !explanation.isEmpty {
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color(hex: component.props.backgroundColor ?? "#1C1C1E"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSubmitted ? (isCorrect ? Color.green : Color.red) : Color.clear, lineWidth: 2)
        )
    }
    
    private func submitAnswer() {
        guard !userAnswer.isEmpty else { return }
        
        // Simple case-insensitive comparison
        let expectedAnswer: String
        if let answerObj = component.props.correctAnswer, let correctString = answerObj.stringValue {
             expectedAnswer = correctString
        } else if let blanks = component.props.blanks, let firstBlank = blanks.first {
             expectedAnswer = firstBlank.answer
        } else {
             // Fallback if structure is malformed
             expectedAnswer = ""
        }
        
        isCorrect = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == expectedAnswer.lowercased()
        
        withAnimation {
            isSubmitted = true
        }
        
        // Trigger generic action for backend processing if needed
        if let actionId = component.props.actionId ?? component.actions?.first?.id {
            onAction?(A2UIAction(
                id: actionId,
                trigger: .onSubmit,
                type: .submitAnswer,
                payload: ["answer": .string(userAnswer), "is_correct": .bool(isCorrect)]
            ))
        }
    }
}

struct A2UIQuizShortAnswerRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?
    
    @State private var userAnswer: String = ""
    @State private var isSubmitted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let questionText = component.props.question ?? component.props.title {
                Text(.init(questionText))
                    .font(.headline)
                    .foregroundColor(Color(hex: component.props.foregroundColor ?? "#FFFFFF"))
            }

            TextEditor(text: $userAnswer)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .disabled(isSubmitted)
            
            if !isSubmitted {
                Button(action: submitAnswer) {
                    Text("Submit Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Text("Answer submitted for review.")
                    .font(.headline)
                    .foregroundColor(.green)
                
                if let explanation = component.props.explanation, !explanation.isEmpty {
                    Text("Sample Answer:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(hex: component.props.backgroundColor ?? "#1C1C1E"))
        .cornerRadius(12)
    }
    
    private func submitAnswer() {
        guard !userAnswer.isEmpty else { return }
        
        withAnimation {
            isSubmitted = true
        }
        
        if let actionId = component.props.actionId ?? component.actions?.first?.id {
            onAction?(A2UIAction(
                id: actionId,
                trigger: .onSubmit,
                type: .submitAnswer,
                payload: ["answer": .string(userAnswer)]
            ))
        }
    }
}
