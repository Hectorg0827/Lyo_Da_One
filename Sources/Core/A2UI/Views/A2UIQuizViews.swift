//
//  A2UIQuizViews.swift
//  Lyo
//
//  Quiz renderer views for A2UI
//

import SwiftUI

// MARK: - Quiz Views

struct A2UIQuizMCQView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        let options = props.options ?? []
        let correctOption = options.first { $0.isCorrect == true } ?? options.first
        let correctIndex = correctOption.flatMap { options.firstIndex(of: $0) } ?? 0
        
        PremiumQuizView(
            question: props.question ?? "Question",
            options: options.map { $0.text },
            correctIndex: correctIndex,
            explanation: props.explanation,
            onAnswerSubmitted: { index, _ in
                // Handle action if needed
            }
        )
    }
}

struct A2UIQuizMultiSelectView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var selectedOptions: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(props.question ?? "")
                .font(.headline)
            
            Text("Select all that apply")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(props.options ?? [], id: \.id) { option in
                Button {
                    if selectedOptions.contains(option.id) {
                        selectedOptions.remove(option.id)
                    } else {
                        selectedOptions.insert(option.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedOptions.contains(option.id) ? "checkmark.square.fill" : "square")
                        Text(option.text)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct A2UIQuizTrueFalseView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var answer: Bool?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(props.question ?? "")
                .font(.headline)
            
            HStack(spacing: 16) {
                Button {
                    answer = true
                } label: {
                    Text("True")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(answer == true ? Color.green.opacity(0.3) : Color(.systemGray6))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button {
                    answer = false
                } label: {
                    Text("False")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(answer == false ? Color.red.opacity(0.3) : Color(.systemGray6))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct A2UIQuizFillBlankView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var answers: [String: String] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(props.question ?? "Fill in the blanks")
                .font(.headline)
            
            ForEach(props.blanks ?? [], id: \.id) { blank in
                HStack {
                    Text("Blank \(blank.position + 1):")
                    TextField("Your answer", text: binding(for: blank.id))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
    }
    
    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { answers[id] ?? "" },
            set: { answers[id] = $0 }
        )
    }
}

struct A2UIQuizMatchingView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(props.question ?? "Match the items")
                .font(.headline)
            
            ForEach(props.matchingPairs ?? [], id: \.id) { pair in
                HStack {
                    Text(pair.left)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    Text(pair.right)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

struct A2UIQuizShortAnswerView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var answer = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(props.question ?? "")
                .font(.headline)
            
            TextEditor(text: $answer)
                .frame(minHeight: 100)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            if let hint = props.hint {
                Text("💡 Hint: \(hint)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct A2UIQuizCodeView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var code = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(props.question ?? "Write your code")
                .font(.headline)
            
            if let template = props.codeTemplate {
                Text("Template:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(template)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Text("Your solution:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            if let lang = props.codeLanguage {
                Text("Language: \(lang)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct A2UIQuizGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(props.question ?? props.title ?? "Quiz")
                .font(.headline)
            
            if let body = props.body {
                Text(body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
