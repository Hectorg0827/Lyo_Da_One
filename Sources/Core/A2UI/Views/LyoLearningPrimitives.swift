//
//  LyoLearningPrimitives.swift
//  Lyo
//
//  v2 renderers for learning primitives:
//  quiz, quizResult, course, flashcard, plan, tracker, assignment, document
//

import SwiftUI

// MARK: - Quiz Primitive

/// Renders quiz variants: mcq, multi-select, true-false, fill-blank, matching, short-answer
struct LyoQuizPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "mcq" }

    @State private var selectedIndex: Int? = nil
    @State private var selectedIndices: Set<Int> = []
    @State private var textAnswer: String = ""
    @State private var hasSubmitted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question text
            Text(component.content?.text ?? component.content?.title ?? "Question")
                .font(.headline)

            if let hint = component.content?.hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, -8)
            }

            // Answer area
            answerArea

            // Submit
            if !hasSubmitted {
                Button("Submit Answer") {
                    hasSubmitted = true
                    onAction?(LyoCommand(action: "quiz.submit", payload: submissionPayload))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    @ViewBuilder
    private var answerArea: some View {
        switch variant {
        case "true-false":
            trueFalseArea

        case "multi-select":
            multiSelectArea

        case "fill-blank":
            TextField(component.content?.placeholder ?? "Type your answer…", text: $textAnswer)
                .textFieldStyle(.roundedBorder)

        case "short-answer":
            TextEditor(text: $textAnswer)
                .frame(minHeight: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

        default: // "mcq"
            mcqArea
        }
    }

    private var mcqArea: some View {
        VStack(spacing: 8) {
            if let children = component.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    optionRow(
                        text: child.content?.text ?? child.content?.label ?? "Option \(index + 1)",
                        index: index,
                        isSelected: selectedIndex == index
                    ) {
                        if !hasSubmitted { selectedIndex = index }
                    }
                }
            }
        }
    }

    private var trueFalseArea: some View {
        HStack(spacing: 12) {
            ForEach(["True", "False"], id: \.self) { option in
                let idx = option == "True" ? 0 : 1
                Button {
                    if !hasSubmitted { selectedIndex = idx }
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedIndex == idx ? Color.blue.opacity(0.15) : Color(.systemGray6))
                        .foregroundStyle(selectedIndex == idx ? .blue : .primary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedIndex == idx ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var multiSelectArea: some View {
        VStack(spacing: 8) {
            if let children = component.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    let isSelected = selectedIndices.contains(index)
                    optionRow(
                        text: child.content?.text ?? child.content?.label ?? "Option \(index + 1)",
                        index: index,
                        isSelected: isSelected,
                        icon: isSelected ? "checkmark.square.fill" : "square"
                    ) {
                        if !hasSubmitted {
                            if isSelected { selectedIndices.remove(index) }
                            else { selectedIndices.insert(index) }
                        }
                    }
                }
            }
        }
    }

    private func optionRow(text: String, index: Int, isSelected: Bool, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon ?? (isSelected ? "largecircle.fill.circle" : "circle"))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var canSubmit: Bool {
        switch variant {
        case "fill-blank", "short-answer":
            return !textAnswer.isEmpty
        case "multi-select":
            return !selectedIndices.isEmpty
        default:
            return selectedIndex != nil
        }
    }

    private var submissionPayload: [String: AnyCodableValue]? {
        switch variant {
        case "fill-blank", "short-answer":
            return ["answer": .string(textAnswer)]
        case "multi-select":
            return ["answers": .array(selectedIndices.sorted().map { .int($0) })]
        default:
            return selectedIndex.map { ["answer": .int($0)] }
        }
    }
}

// MARK: - Quiz Result Primitive

/// Renders quiz result variants: correct, incorrect, summary, explanation
struct LyoQuizResultPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "summary" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                resultIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.content?.title ?? resultTitle)
                        .font(.headline)
                    if let subtitle = component.content?.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let body = component.content?.body {
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Children for detailed explanations
            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context)
                }
            }
        }
        .padding()
        .background(resultBackground)
        .cornerRadius(12)
    }

    private var resultIcon: some View {
        Image(systemName: variant == "correct" ? "checkmark.circle.fill"
              : variant == "incorrect" ? "xmark.circle.fill"
              : "chart.bar.fill")
            .font(.title2)
            .foregroundStyle(variant == "correct" ? .green
                           : variant == "incorrect" ? .red
                           : .blue)
    }

    private var resultTitle: String {
        switch variant {
        case "correct":    return "Correct!"
        case "incorrect":  return "Incorrect"
        case "explanation": return "Explanation"
        default:           return "Results"
        }
    }

    private var resultBackground: Color {
        switch variant {
        case "correct":   return Color.green.opacity(0.08)
        case "incorrect": return Color.red.opacity(0.08)
        default:          return Color(.systemGray6)
        }
    }
}

// MARK: - Course Primitive

/// Renders course variants: overview, module, lesson, outline, roadmap
struct LyoCoursePrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "overview" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch variant {
            case "module":
                moduleView
            case "lesson":
                lessonView
            case "outline":
                outlineView
            case "roadmap":
                roadmapView
            default: // "overview"
                overviewView
            }
        }
    }

    private var overviewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero header
            if let title = component.content?.title {
                Text(title)
                    .font(.title.weight(.bold))
            }
            if let subtitle = component.content?.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Children (modules / sections)
            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                }
            }
        }
        .padding()
    }

    private var moduleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = component.content?.icon {
                    Image(systemName: icon)
                        .foregroundStyle(.blue)
                }
                Text(component.content?.title ?? "Module")
                    .font(.headline)
                Spacer()
            }

            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var lessonView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: component.content?.icon ?? "book")
                        .font(.caption)
                        .foregroundStyle(.blue)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(component.content?.title ?? "Lesson")
                    .font(.subheadline.weight(.medium))
                if let subtitle = component.content?.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onAction?(LyoCommand(action: "lesson.open", payload: nil))
        }
    }

    private var outlineView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(component.content?.title ?? "Course Outline")
                .font(.headline)
                .padding(.bottom, 8)

            if let children = component.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                    }
                }
            }
        }
    }

    private var roadmapView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let children = component.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    HStack(alignment: .top, spacing: 12) {
                        // Timeline dot + line
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index == 0 ? Color.blue : Color(.systemGray4))
                                .frame(width: 12, height: 12)
                            if index < children.count - 1 {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 2)
                                    .frame(minHeight: 40)
                            }
                        }
                        .frame(width: 12)

                        // Content
                        LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Flashcard Primitive

/// Renders flashcard variants: single, deck
struct LyoFlashcardPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    @State private var isFlipped = false

    var body: some View {
        VStack(spacing: 16) {
            // Card face
            VStack(spacing: 12) {
                Text(isFlipped
                     ? (component.content?.body ?? "Answer")
                     : (component.content?.title ?? component.content?.text ?? "Question"))
                    .font(isFlipped ? .body : .title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 160)
                    .padding()

                Text(isFlipped ? "Answer" : "Question")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .onTapGesture {
                withAnimation(.spring(response: 0.4)) {
                    isFlipped.toggle()
                }
            }

            // Controls
            HStack(spacing: 20) {
                Button {
                    onAction?(LyoCommand(action: "flashcard.wrong", payload: nil))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red.opacity(0.7))
                }

                Button {
                    isFlipped = false
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

                Button {
                    onAction?(LyoCommand(action: "flashcard.correct", payload: nil))
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green.opacity(0.7))
                }
            }
        }
        .padding()
    }
}

// MARK: - Plan Primitive

/// Renders study plan variants: overview, weekly, daily, session, goal
struct LyoPlanPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "overview" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack {
                if let icon = component.content?.icon {
                    Image(systemName: icon)
                        .foregroundStyle(.blue)
                }
                Text(component.content?.title ?? planTitle)
                    .font(.headline)
                Spacer()
            }

            if let subtitle = component.content?.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Children
            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }

    private var planTitle: String {
        switch variant {
        case "weekly":  return "Weekly Plan"
        case "daily":   return "Today's Plan"
        case "session": return "Study Session"
        case "goal":    return "Goal"
        default:        return "Study Plan"
        }
    }
}

// MARK: - Tracker Primitive

/// Renders tracker variants: mistakes, streaks, progress, heatmap
struct LyoTrackerPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "progress" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: trackerIcon)
                    .foregroundStyle(trackerColor)
                Text(component.content?.title ?? variant.capitalized)
                    .font(.headline)
                Spacer()
            }

            if let body = component.content?.body {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Children for detail items
            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context)
                }
            }
        }
        .padding()
        .background(trackerColor.opacity(0.08))
        .cornerRadius(12)
    }

    private var trackerIcon: String {
        switch variant {
        case "mistakes": return "exclamationmark.triangle"
        case "streaks":  return "flame.fill"
        case "heatmap":  return "square.grid.3x3.fill"
        default:         return "chart.line.uptrend.xyaxis"
        }
    }

    private var trackerColor: Color {
        switch variant {
        case "mistakes": return .orange
        case "streaks":  return .red
        default:         return .blue
        }
    }
}

// MARK: - Assignment Primitive

/// Renders assignment variants: card, detail, submission
struct LyoAssignmentPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "card" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.content?.title ?? "Assignment")
                        .font(.headline)
                    if let subtitle = component.content?.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if variant == "card" {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let body = component.content?.body {
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

// MARK: - Document Primitive

/// Renders document variants: note, pdf, summary, definition, key-points
struct LyoDocumentPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "note" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: documentIcon)
                    .foregroundStyle(.indigo)
                Text(component.content?.title ?? variant.capitalized)
                    .font(.headline)
            }

            if let body = component.content?.body ?? component.content?.text {
                Text(body)
                    .font(.body)
            }

            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context)
                }
            }
        }
        .padding()
        .background(Color.indigo.opacity(0.06))
        .cornerRadius(12)
    }

    private var documentIcon: String {
        switch variant {
        case "pdf":        return "doc.richtext"
        case "summary":    return "text.justifyleft"
        case "definition": return "book.closed"
        case "key-points": return "list.star"
        default:           return "note.text"
        }
    }
}
