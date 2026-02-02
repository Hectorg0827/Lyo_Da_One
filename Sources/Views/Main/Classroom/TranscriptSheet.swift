import SwiftUI

// MARK: - Transcript Sheet

struct TranscriptSheet: View {
    let transcript: [TranscriptMessage]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(transcript) { turn in
                            TranscriptBubble(turn: turn)
                                .id(turn.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    // Scroll to bottom
                    if let lastTurn = transcript.last {
                        proxy.scrollTo(lastTurn.id, anchor: .bottom)
                    }
                }
                .onChange(of: transcript.count) {
                    if let lastTurn = transcript.last {
                        withAnimation {
                            proxy.scrollTo(lastTurn.id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Transcript Bubble

struct TranscriptBubble: View {
    let turn: TranscriptMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if turn.isUser {
                Spacer(minLength: 60)
            }
            
            if !turn.isUser {
                // Lio avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("L")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: turn.isUser ? .trailing : .leading, spacing: 4) {
                Text(turn.text)
                    .font(.body)
                    .foregroundColor(turn.isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        turn.isUser
                            ? AnyShapeStyle(DesignSystem.Colors.fallbackPrimary)
                            : AnyShapeStyle(Color(.systemGray5))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(formatTime(turn.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if turn.isUser {
                // User avatar
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            }
            
            if !turn.isUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Ask Question Sheet

struct AskQuestionSheet: View {
    @Binding var question: String
    let isProcessing: Bool
    let onSubmit: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Ask Lio")
                        .font(.title2.bold())
                    
                    Text("Type your question about the lesson")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Question")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $question)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isFocused)
                }
                .padding(.horizontal)
                
                // Suggestion chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick prompts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            QuickPromptChip(text: "Can you explain that again?") {
                                question = "Can you explain that again?"
                            }
                            QuickPromptChip(text: "Give me an example") {
                                question = "Can you give me a real-world example?"
                            }
                            QuickPromptChip(text: "Why is this important?") {
                                question = "Why is this concept important?"
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Submit button
                Button(action: {
                    onSubmit(question)
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Ask")
                            Image(systemName: "arrow.up.circle.fill")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing
                            ? Color.gray
                            : DesignSystem.Colors.fallbackPrimary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Quick Prompt Chip

struct QuickPromptChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Previews

#Preview("Transcript Sheet") {
    TranscriptSheet(transcript: [
        TranscriptMessage(isUser: false, text: "Welcome to this lesson! Today we'll explore the fundamentals."),
        TranscriptMessage(isUser: true, text: "Sounds good!"),
        TranscriptMessage(isUser: false, text: "Great! Let's start with the basics..."),
        TranscriptMessage(isUser: true, text: "I'm confused"),
        TranscriptMessage(isUser: false, text: "No worries! Let me explain that differently...")
    ])
}

#Preview("Ask Question Sheet") {
    AskQuestionSheet(
        question: .constant(""),
        isProcessing: false
    ) { _ in }
}
