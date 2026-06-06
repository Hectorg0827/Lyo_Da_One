//
//  CourseRuntimeView.swift
//  Lyo
//
//  The Main Player View for AI Courses.
//  Binds the LyoCourseRuntime to the UI.
//

import SwiftUI
import os

struct CourseRuntimeView: View {
    @StateObject var runtime: LyoCourseRuntime
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color("DeepBackground").ignoresSafeArea() // Use app theme color
            
            if runtime.isCourseComplete {
                CourseCompletionView()
            } else {
                VStack(spacing: 0) {
                    // 1. Progress / Navigation Bar
                    RuntimeHeaderView(
                        module: runtime.activeModule,
                        lesson: runtime.activeLesson,
                        progress: calculateProgress()
                    )
                    
                    // 2. The Artifact Stage
                    // We use ID to force transition animations when artifact changes
                    if let artifact = runtime.activeArtifact {
                        ArtifactRenderer(artifact: artifact, onComplete: { result in
                            runtime.completeCurrentArtifact(result: result)
                        })
                        .id(artifact.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else {
                        ProgressView("Loading Artifact...")
                    }
                    
                    // 3. Footer (if needed)
                }
            }
        }
    }
    
    func calculateProgress() -> Double {
        // Simple linear progress for MVP
        let total = Double(runtime.course.modules.flatMap { $0.lessons }.flatMap { $0.artifacts }.count)
        let done = Double(runtime.progress.completedArtifactCount)
        return total > 0 ? done / total : 0
    }
}

// MARK: - Subcomponents

struct RuntimeHeaderView: View {
    let module: LyoModule?
    let lesson: LyoLesson?
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)
                .tint(.purple)
                .padding(.horizontal)
            
            if let mod = module, let les = lesson {
                VStack(alignment: .leading) {
                    Text(mod.title.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(les.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

struct CourseCompletionView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉")
                .font(.system(size: 80))
            Text("Course Complete!")
                .font(.title)
                .bold()
            
            Button("Finish") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Artifact Renderer Factory

struct ArtifactRenderer: View {
    let artifact: LyoArtifact
    let onComplete: (ArtifactResult?) -> Void
    
    var body: some View {
        Group {
            switch artifact.type {
            case .conceptExplainer:
                ConceptExplainerView(artifact: artifact, onNext: {
                    onComplete(ArtifactResult(
                        artifactId: artifact.id,
                        completedAt: Date(),
                        timeSpentSeconds: 0,
                        score: nil,
                        interactionData: nil
                    ))
                })
                
            case .quiz:
                QuizArtifactView(artifact: artifact, onComplete: { score in
                    onComplete(ArtifactResult(
                        artifactId: artifact.id,
                        completedAt: Date(),
                        timeSpentSeconds: 0,
                        score: score,
                        interactionData: nil
                    ))
                })
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        // Trigger decoding on appear
                    }
                }
                
            case .flashcards:
                FlashcardsArtifactView(artifact: artifact, onFinish: {
                    onComplete(nil)
                })
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        // Trigger decoding on appear
                    }
                }
                
            case .notes:
                NotesArtifactView(artifact: artifact, onComplete: {
                    onComplete(nil)
                })
                
            default:
                // Fallback for types not yet implemented
                VStack {
                    Text("Support for \(artifact.type.rawValue) coming soon.")
                    Button("Skip") { onComplete(nil) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Artifact Implementations (Real Content Rendering)

// ============================================================================
// MARK: - BULLETPROOF CONTENT DECODER
// ============================================================================

/// Safely decodes AnyCodable content with multiple fallback strategies
struct ContentDecoder {
    
    /// Decode concept explainer with guaranteed content (never fails)
    static func decodeConceptExplainer(from artifact: LyoArtifact) -> ConceptExplainerPayload {
        // Strategy 1: Direct dictionary decode
        if let dict = artifact.content.value as? [String: Any] {
            return ConceptExplainerPayload(
                markdown: extractString(dict, keys: ["markdown", "body", "content", "text"]) ?? "Content loading...",
                hook: extractString(dict, keys: ["hook", "intro", "teaser"]),
                visualPrompt: extractString(dict, keys: ["visualPrompt", "visual_prompt", "image_prompt", "visual"]),
                keyTakeaways: extractStringArray(dict, keys: ["keyTakeaways", "key_takeaways", "takeaways"]) ?? []
            )
        }
        
        // Strategy 2: JSON string decode
        if let jsonString = artifact.content.value as? String {
            if let data = jsonString.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return ConceptExplainerPayload(
                    markdown: extractString(dict, keys: ["markdown", "body"]) ?? jsonString,
                    hook: extractString(dict, keys: ["hook"]),
                    visualPrompt: extractString(dict, keys: ["visualPrompt", "visual_prompt", "image_prompt", "visual"]),
                    keyTakeaways: extractStringArray(dict, keys: ["keyTakeaways", "key_takeaways"]) ?? []
                )
            }
            // If it's just plain text, use it as markdown
            return ConceptExplainerPayload(markdown: jsonString, hook: nil, visualPrompt: nil, keyTakeaways: [])
        }
        
        // Strategy 3: Blocks array decode (backend format)
        if let dict = artifact.content.value as? [String: Any],
           let blocks = dict["blocks"] as? [[String: Any]] {
            let bodyParts = blocks.compactMap { block -> String? in
                if let content = block["content"] as? String {
                    return content
                }
                return nil
            }
            return ConceptExplainerPayload(
                markdown: bodyParts.joined(separator: "\n\n"),
                hook: extractString(dict, keys: ["title", "hook"]),
                visualPrompt: extractString(dict, keys: ["visualPrompt", "visual_prompt", "image_prompt", "visual"]),
                keyTakeaways: []
            )
        }
        
        // Fallback: Minimal content
        Log.ui.warning("ContentDecoder: Using fallback for concept_explainer")
        return ConceptExplainerPayload(
            markdown: "## Loading...\n\nContent is being prepared. Please wait or refresh.",
            hook: nil,
            visualPrompt: nil,
            keyTakeaways: []
        )
    }
    
    /// Decode flashcards with guaranteed content
    static func decodeFlashcards(from artifact: LyoArtifact) -> LyoFlashcardsPayload {
        // Strategy 1: Direct decode with cards array
        if let dict = artifact.content.value as? [String: Any],
           let cardsArray = dict["cards"] as? [[String: Any]] {
            let cards = cardsArray.map { cardDict -> LyoFlashcard in
                LyoFlashcard(
                    front: extractString(cardDict, keys: ["front", "question", "term"]) ?? "?",
                    back: extractString(cardDict, keys: ["back", "answer", "definition"]) ?? "?",
                    hint: extractString(cardDict, keys: ["hint", "clue"])
                )
            }
            return LyoFlashcardsPayload(
                topic: extractString(dict, keys: ["topic", "title"]) ?? "Flashcards",
                cards: cards.isEmpty ? defaultFlashcards() : cards
            )
        }
        
        // Strategy 2: Array at root
        if let cardsArray = artifact.content.value as? [[String: Any]] {
            let cards = cardsArray.map { cardDict -> LyoFlashcard in
                LyoFlashcard(
                    front: extractString(cardDict, keys: ["front"]) ?? "?",
                    back: extractString(cardDict, keys: ["back"]) ?? "?",
                    hint: extractString(cardDict, keys: ["hint"])
                )
            }
            return LyoFlashcardsPayload(topic: "Flashcards", cards: cards)
        }
        
        // Fallback
        Log.ui.warning("ContentDecoder: Using fallback for flashcards")
        return LyoFlashcardsPayload(topic: "Flashcards", cards: defaultFlashcards())
    }
    
    /// Decode quiz with guaranteed content
    static func decodeQuiz(from artifact: LyoArtifact) -> LyoQuizArtifactPayload {
        // Strategy 1: Direct decode with questions array
        if let dict = artifact.content.value as? [String: Any],
           let questionsArray = dict["questions"] as? [[String: Any]] {
            let questions = questionsArray.compactMap { qDict -> LyoQuizQuestion? in
                guard let questionText = extractString(qDict, keys: ["text", "question"]) else { return nil }
                
                // Parse options
                var options: [LyoQuizOption] = []
                if let optionsArray = qDict["options"] as? [[String: Any]] {
                    options = optionsArray.map { optDict in
                        LyoQuizOption(
                            id: extractString(optDict, keys: ["id"]) ?? UUID().uuidString,
                            text: extractString(optDict, keys: ["text"]) ?? "?"
                        )
                    }
                } else if let optionStrings = qDict["options"] as? [String] {
                    options = optionStrings.enumerated().map { idx, text in
                        LyoQuizOption(id: "\(idx)", text: text)
                    }
                }
                
                let correctId = extractString(qDict, keys: ["correct_option_id", "correctOptionId", "correct"]) ?? options.first?.id ?? "0"
                
                return LyoQuizQuestion(
                    id: extractString(qDict, keys: ["id"]) ?? UUID().uuidString,
                    text: questionText,
                    type: extractString(qDict, keys: ["type", "question_type", "format"]) ?? "single_choice",
                    options: options,
                    correctOptionId: correctId,
                    explanation: extractString(qDict, keys: ["explanation", "feedback"])
                )
            }
            
            return LyoQuizArtifactPayload(
                questions: questions.isEmpty ? defaultQuizQuestions() : questions
            )
        }
        
        // Fallback
        Log.ui.warning("ContentDecoder: Using fallback for quiz")
        return LyoQuizArtifactPayload(questions: defaultQuizQuestions())
    }
    
    // MARK: - Helpers
    
    private static func extractString(_ dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    private static func extractStringArray(_ dict: [String: Any], keys: [String]) -> [String]? {
        for key in keys {
            if let value = dict[key] as? [String], !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    private static func defaultFlashcards() -> [LyoFlashcard] {
        [
            LyoFlashcard(front: "Key Concept", back: "The main idea of this lesson", hint: "Think fundamentals"),
            LyoFlashcard(front: "Application", back: "How to use this in practice", hint: "Real world"),
            LyoFlashcard(front: "Remember", back: "The most important takeaway", hint: "Core learning")
        ]
    }
    
    private static func defaultQuizQuestions() -> [LyoQuizQuestion] {
        [
            LyoQuizQuestion(
                id: "q_fallback_1",
                text: "Did you understand the main concept?",
                type: "single_choice",
                options: [
                    LyoQuizOption(id: "a", text: "Yes, completely"),
                    LyoQuizOption(id: "b", text: "Mostly"),
                    LyoQuizOption(id: "c", text: "Need to review"),
                    LyoQuizOption(id: "d", text: "Not yet")
                ],
                correctOptionId: "a",
                explanation: "Great! If you're unsure, review the lesson again."
            )
        ]
    }
}

// ============================================================================
// MARK: - UPDATED ARTIFACT VIEWS (Using ContentDecoder)
// ============================================================================

struct ConceptExplainerView: View {
    let artifact: LyoArtifact
    let onNext: () -> Void
    
    private var payload: ConceptExplainerPayload {
        ContentDecoder.decodeConceptExplainer(from: artifact)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hook / Hook Statement
                if let hook = payload.hook, !hook.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Focus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(hook)
                            .font(.subheadline)
                            .italic()
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Markdown Content (Simple rendering - no full MD parser)
                MarkdownView(markdown: payload.markdown)
                
                // Key Takeaways
                if !payload.keyTakeaways.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Key Takeaways")
                            .font(.headline)
                        
                        ForEach(payload.keyTakeaways, id: \.self) { takeaway in
                            HStack(alignment: .top, spacing: 10) {
                                Text("✓")
                                    .foregroundStyle(.green)
                                    .font(.headline)
                                Text(takeaway)
                                    .font(.body)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: onNext) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

// Simple Markdown renderer (basic - handles headers, bold, lists)
struct MarkdownView: View {
    let markdown: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdownLines(), id: \.self) { line in
                MarkdownLineView(line: line)
            }
        }
    }
    
    private func parseMarkdownLines() -> [String] {
        markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}

struct MarkdownLineView: View {
    let line: String
    
    var body: some View {
        if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2)))
                .font(.title2)
                .bold()
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.headline)
                .bold()
        } else if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4)))
                .font(.subheadline)
                .bold()
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.headline)
                Text(parseInlineFormatting(String(line.dropFirst(2))))
                    .font(.body)
            }
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("")
                .frame(height: 4)
        } else {
            Text(parseInlineFormatting(line))
                .font(.body)
                .lineLimit(nil)
        }
    }
    
    private func parseInlineFormatting(_ text: String) -> String {
        // Simple: replace **text** with bold (but Text doesn't support rich inline, so just strip markers)
        let bold = text.replacingOccurrences(of: "**", with: "")
        return bold.replacingOccurrences(of: "__", with: "")
    }
}

struct QuizArtifactView: View {
    let artifact: LyoArtifact
    let onComplete: (Double) -> Void
    
    @State private var currentQuestionIndex: Int = 0
    @State private var selectedAnswers: [String: String] = [:]
    @State private var showResults = false
    
    private var payload: LyoQuizArtifactPayload {
        ContentDecoder.decodeQuiz(from: artifact)
    }
    
    var body: some View {
        ZStack {
            if showResults {
                RuntimeQuizResultsView(
                    payload: payload,
                    selectedAnswers: selectedAnswers,
                    onDone: { score in
                        onComplete(score)
                    }
                )
            } else if currentQuestionIndex < payload.questions.count {
                let question = payload.questions[currentQuestionIndex]
                RuntimeQuizQuestionView(
                    question: question,
                    onSelectAnswer: { optionId in
                        selectedAnswers[question.id] = optionId
                    },
                    onNext: {
                        if currentQuestionIndex < payload.questions.count - 1 {
                            currentQuestionIndex += 1
                        } else {
                            showResults = true
                        }
                    }
                )
            } else {
                // Edge case: no questions
                VStack {
                    Text("Quiz complete!")
                    Button("Continue") { onComplete(1.0) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct RuntimeQuizQuestionView: View {
    let question: LyoQuizQuestion
    let onSelectAnswer: (String) -> Void
    let onNext: () -> Void
    
    @State private var selectedOption: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Question Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Question")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(question.text)
                        .font(.headline)
                }
                
                // Options
                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        Button(action: {
                            selectedOption = option.id
                            onSelectAnswer(option.id)
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: selectedOption == option.id ? "checkmark.circle.fill" : "circle")
                                    .font(.headline)
                                    .foregroundStyle(selectedOption == option.id ? .blue : .gray)
                                Text(option.text)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // Next Button
                Button(action: onNext) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(selectedOption != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(selectedOption == nil)
            }
            .padding()
        }
    }
}

struct RuntimeQuizResultsView: View {
    let payload: LyoQuizArtifactPayload
    let selectedAnswers: [String: String]
    let onDone: (Double) -> Void
    
    var score: Double {
        let correct = payload.questions.filter { q in
            selectedAnswers[q.id] == q.correctOptionId
        }.count
        return Double(correct) / Double(payload.questions.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                // Score Card
                VStack(spacing: 12) {
                    Text("Quiz Complete!")
                        .font(.title2)
                        .bold()
                    
                    Text("\(Int(score * 100))%")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(score >= 0.8 ? .green : score >= 0.5 ? .orange : .red)
                    
                    Text("\(payload.questions.filter { selectedAnswers[$0.id] == $0.correctOptionId }.count) of \(payload.questions.count) correct")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(12)
                
                // Review Answers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Review")
                        .font(.headline)
                    
                    ForEach(payload.questions) { q in
                        let selectedId = selectedAnswers[q.id]
                        let isCorrect = selectedId == q.correctOptionId
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(isCorrect ? .green : .red)
                                Text(q.text)
                                    .font(.subheadline)
                                    .bold()
                            }
                            
                            if let explanation = q.explanation {
                                Text(explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                Button(action: { onDone(score) }) {
                    Text("Finish")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct FlashcardsArtifactView: View {
    let artifact: LyoArtifact
    let onFinish: () -> Void
    
    @State private var currentCardIndex: Int = 0
    @State private var isFlipped: Bool = false
    
    private var payload: LyoFlashcardsPayload {
        ContentDecoder.decodeFlashcards(from: artifact)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(payload.topic)
                    .font(.headline)
                ProgressView(value: Double(currentCardIndex + 1), total: Double(payload.cards.count))
                    .tint(.purple)
                Text("Card \(currentCardIndex + 1) of \(payload.cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            Spacer()
            
            // Flashcard
            if currentCardIndex < payload.cards.count {
                let card = payload.cards[currentCardIndex]
                RuntimeFlashcardView(
                    front: card.front,
                    back: card.back,
                    hint: card.hint,
                    isFlipped: isFlipped
                )
                .onTapGesture {
                    withAnimation {
                        isFlipped.toggle()
                    }
                }
            }
            
            Spacer()
            
            // Navigation
            HStack(spacing: 12) {
                Button(action: {
                    if currentCardIndex > 0 {
                        currentCardIndex -= 1
                        isFlipped = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .disabled(currentCardIndex == 0)
                
                Button(action: {
                    if currentCardIndex < payload.cards.count - 1 {
                        currentCardIndex += 1
                        isFlipped = false
                    } else {
                        onFinish()
                    }
                }) {
                    Text(currentCardIndex == payload.cards.count - 1 ? "Finish" : "Next")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

struct RuntimeFlashcardView: View {
    let front: String
    let back: String
    let hint: String?
    let isFlipped: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 8)
            
            VStack(alignment: .center, spacing: 16) {
                Text(isFlipped ? "Answer" : "Question")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 20)
                
                Spacer()
                
                Text(isFlipped ? back : front)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(20)
                
                if !isFlipped, let hint = hint {
                    Divider()
                    Text("💡 \(hint)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(12)
                }
                
                Spacer()
                
                Text(isFlipped ? "Tap to reveal question" : "Tap to reveal answer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
            .padding(24)
        }
        .frame(height: 300)
        .padding()
    }
}
