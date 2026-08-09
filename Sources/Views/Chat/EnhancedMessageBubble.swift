//
//  EnhancedMessageBubble.swift
//  Lyo
//
//  Gemini-style full-width message bubble with top-positioned avatar
//

import SwiftUI
import AVKit
import os

#if canImport(LaTeXSwiftUI)
import LaTeXSwiftUI
#endif

private let assistantResponseWidthFraction: CGFloat = 0.99

struct EnhancedMessageBubble: View {
    let message: MultimodalMessage
    let onTTSToggle: (() -> Void)?
    let isSpeaking: Bool
    let canRegenerate: Bool
    let onRegenerate: (() -> Void)?
    let onQuizAnswer: ((Int) -> Void)?
    let onCourseOpen: ((String) -> Void)?
    let onTopicSelect: ((TopicOption) -> Void)?
    let onModuleSelect: ((CourseModule) -> Void)?
    let onSuggestionSelect: ((String) -> Void)?
    /// Stage A — primary tap on a SuggestedActionCard.
    let onSuggestedAction: ((SuggestedActionCard) -> Void)?
    let highlights: [ChatHighlight]
    let onTextSelectionAction: ((TextSelectionAction) -> Void)?

    @State private var showFullImage = false
    @State private var selectedImageURL: URL?
    @State private var didCopy = false

    init(
        message: MultimodalMessage,
        onTTSToggle: (() -> Void)? = nil,
        isSpeaking: Bool = false,
        canRegenerate: Bool = false,
        onRegenerate: (() -> Void)? = nil,
        onQuizAnswer: ((Int) -> Void)? = nil,
        onCourseOpen: ((String) -> Void)? = nil,
        onTopicSelect: ((TopicOption) -> Void)? = nil,
        onModuleSelect: ((CourseModule) -> Void)? = nil,
        onSuggestionSelect: ((String) -> Void)? = nil,
        onSuggestedAction: ((SuggestedActionCard) -> Void)? = nil,
        highlights: [ChatHighlight] = [],
        onTextSelectionAction: ((TextSelectionAction) -> Void)? = nil
    ) {
        self.message = message
        self.onTTSToggle = onTTSToggle
        self.isSpeaking = isSpeaking
        self.canRegenerate = canRegenerate
        self.onRegenerate = onRegenerate
        self.onQuizAnswer = onQuizAnswer
        self.onCourseOpen = onCourseOpen
        self.onTopicSelect = onTopicSelect
        self.onModuleSelect = onModuleSelect
        self.onSuggestionSelect = onSuggestionSelect
        self.onSuggestedAction = onSuggestedAction
        self.highlights = highlights
        self.onTextSelectionAction = onTextSelectionAction
    }
    
    /// True when contentTypes contains rich content that should suppress raw text rendering
    /// to prevent duplicate display (text + card both showing)
    private var hasRichContent: Bool {
        message.contentTypes.contains(where: { contentType in
            switch contentType {
            case .courseProposal: return true
            case .courseRoadmap: return true
            case .quiz: return true
            case .quizDeck: return true
            case .flashcards: return true
            case .studyPlan: return true
            default: return false
            }
        })
    }
    
    var body: some View {
        if message.role == .assistant {
            // AI Message - Full Width with Avatar on Top
            aiMessageView
        } else {
            // User Message - Keep as bubble on right
            userMessageView
        }
    }
    
    // MARK: - AI Message View (Full Width, Gemini Style)
    
    // MARK: - AI Message View (Enhanced Island Style)
    
    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header showing Mascot and "Lyo" (Standardized to original mascot)
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    // Assuming message streaming implies thinking
                    if message.contentTypes.contains(where: {
                        if case .processing = $0 { return true }
                        return false
                    }) || message.content.isEmpty {
                        AnimatedReadingMascotView(size: 28)
                    } else {
                        Image("Mascot_Standing")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .offset(y: 5)
                    }
                    
                    Text("Lyo")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Content Area
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<message.contentTypes.count, id: \.self) { index in
                        contentView(for: message.contentTypes[index])
                    }
                    
                    // Attachments
                    if !message.attachments.isEmpty {
                        attachmentsGrid(message.attachments)
                    }
                }
                
                // Persistent actions remain discoverable on touch devices.
                if !message.content.isEmpty {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.top, 4)

                    HStack(spacing: 6) {
                        responseActionButton(
                            title: didCopy ? "Copied" : "Copy",
                            systemImage: didCopy ? "checkmark" : "doc.on.doc"
                        ) {
                            UIPasteboard.general.string = message.content
                            didCopy = true
                            HapticManager.shared.light()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                didCopy = false
                            }
                        }

                        responseActionButton(
                            title: isSpeaking ? "Stop" : "Listen",
                            systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2",
                            isActive: isSpeaking,
                            isEnabled: onTTSToggle != nil
                        ) { onTTSToggle?() }

                        responseActionButton(
                            title: "Try again",
                            systemImage: "arrow.clockwise",
                            isEnabled: canRegenerate && onRegenerate != nil
                        ) { onRegenerate?() }

                        responseActionButton(
                            title: "Save",
                            systemImage: "arrow.down.doc"
                        ) {
                            saveResponseToFiles()
                        }
                    }
                } // end if !message.content.isEmpty
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.075),
                                Color.white.opacity(0.04),
                                Color.accentColor.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        }
        .containerRelativeFrame(.horizontal) { width, _ in
            width * assistantResponseWidthFraction
        }
        .fullScreenCover(isPresented: $showFullImage) {
            FullImageView(url: selectedImageURL) {
                showFullImage = false
            }
        }
    }
    
    // MARK: - User Message View (Traditional Bubble)
    
    private var userMessageView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 60)
            
            VStack(alignment: .trailing, spacing: 8) {
                // Main content — user bubbles still use native text selection
                SelectableTextView(
                    content: message.content,
                    messageId: message.id,
                    highlights: [],
                    onAction: { action in
                        onTextSelectionAction?(action)
                    }
                )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(ChatBubbleShape(isFromUser: true))
                
                // Attachments
                if !message.attachments.isEmpty {
                    attachmentsGrid(message.attachments)
                }
                
                // Metadata footer
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.isStreaming {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        Image("LyoAvatar")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
    }
    
    // MARK: - Response Actions

    private func responseActionButton(
        title: String,
        systemImage: String,
        isActive: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundColor(isActive ? Color.accentColor : Color.white.opacity(0.62))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isActive ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(title)
    }

    private func saveResponseToFiles() {
        let markdown = "# Lyo response\n\n\(message.content.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyo-response-\(String(message.id.prefix(8))).md")

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                return
            }

            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            if let popover = activity.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.maxY - 1,
                    width: 1,
                    height: 1
                )
            }
            activity.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: fileURL)
            }
            presenter.present(activity, animated: true)
            HapticManager.shared.playSuccess()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    /// One rendered chunk of a multimodal message. Extracted from the
    /// body's ForEach so the large switch type-checks as its own function
    /// (inlined, it failed generic inference on CI's Xcode).
    @ViewBuilder
    private func contentView(for contentType: MessageContentType) -> some View {
        switch contentType {
                        case .text:
                            // Suppress raw text when rich content (courseProposal, quiz, etc.) is present
                            if !hasRichContent && !message.content.isEmpty {
                                SelectableTextView(
                                    content: stripEmojis(message.content),
                                    messageId: message.id,
                                    highlights: highlights,
                                    onAction: { action in
                                        onTextSelectionAction?(action)
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            
                        case .processing(let step, let progress):
                            ProcessingBubbleView(step: step, progress: progress)
                            
                        case .topicSelection(let title, let topics):
                            TopicSelectionBubbleView(
                                title: title,
                                topics: topics,
                                onSelect: { topic in
                                    onTopicSelect?(topic)
                                }
                            )
                            .padding(.horizontal, -8)
                            
                        case .courseRoadmap(let title, let modules, let total, let completed):
                            CourseRoadmapBubbleView(
                                title: title,
                                modules: modules,
                                totalModules: total,
                                completedModules: completed,
                                onModuleSelect: { module in
                                    onModuleSelect?(module)
                                }
                            )
                            
                        case .flashcards(let title, let cards):
                            FlashcardCarouselBubbleView(
                                title: title,
                                cards: cards
                            )
                            .padding(.horizontal, -8)
                            
                        case .quiz(let question, let options, let correctIndex, let explanation):
                            PremiumQuizView(
                                question: question,
                                options: options,
                                correctIndex: correctIndex,
                                explanation: explanation,
                                onAnswerSubmitted: { index, _ in
                                    onQuizAnswer?(index)
                                }
                            )
                            .padding(.horizontal, -8)
                            
                        case .courseCard(let courseId, let title, let subtitle, _):
                             Button {
                                 onCourseOpen?(courseId)
                             } label: {
                                 VStack(alignment: .leading) {
                                     Text(title).font(.headline)
                                     if let subtitle { Text(subtitle).font(.caption) }
                                 }
                                 .padding()
                                 .frame(maxWidth: .infinity, alignment: .leading)
                                 .background(Color(.secondarySystemBackground))
                                 .cornerRadius(12)
                             }
                        
                        case .suggestions(let title, let options):
                            InlineSuggestionsView(title: title, options: options) { selected in
                                onSuggestionSelect?(selected)
                            }

                        case .courseProposal(let payload):
                            ChatInteractiveCardView(
                                type: .course(
                                    title: payload.title,
                                    topic: payload.topic,
                                    level: payload.level,
                                    duration: payload.duration,
                                    imageURL: nil
                                ),
                                onStart: {
                                    // Save to Focus stack then open classroom
                                    _ = AICommandHandler.shared.handleOpenClassroom(
                                        AICommandPayload(stackItem: nil, course: payload)
                                    )
                                    UIStackStore.shared.upsertCourse(
                                        courseId: payload.id ?? UUID().uuidString,
                                        title: payload.title,
                                        subtitle: payload.topic
                                    )
                                    AICommandHandler.shared.executeOpenClassroom(for: payload)
                                },
                                onRefine: {
                                    onSuggestionSelect?("I want to refine the course '\(payload.title)' on \(payload.topic). Please offer options to adjust the difficulty, duration, or focus areas.")
                                },
                                onSave: {
                                    UIStackStore.shared.upsertCourse(
                                        courseId: payload.id ?? UUID().uuidString,
                                        title: payload.title,
                                        subtitle: payload.topic
                                    )
                                    HapticManager.shared.playSuccess()
                                }
                            )
                            .padding(.horizontal, -8)

                        case .studyPlan(let plan):
                            StudyPlanView(plan: plan)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, -8)

                        case .notes(let title, let sections):
                            NotesView(notes: NotesPayload(title: title, sections: sections))
                                .padding(.horizontal, -8)

                        case .quizDeck(let deck):
                            ChatQuizDeckView(deck: deck) { action in
                                onSuggestionSelect?(action)
                            }
                            .padding(.horizontal, -8)

                        case .suggestedActionCard(let card):
                            SuggestedActionCardView(
                                card: card,
                                onPrimary: { c in onSuggestedAction?(c) },
                                onChip: { label, _ in onSuggestionSelect?(label) }
                            )
                            .padding(.horizontal, -8)

                        default:
                            EmptyView()
        }
    }

    // MARK: - Attachments Grid
    
    private func attachmentsGrid(_ attachments: [ChatAttachment]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(attachments) { attachment in
                attachmentThumbnail(attachment)
            }
        }
    }
    
    @ViewBuilder
    private func attachmentThumbnail(_ attachment: ChatAttachment) -> some View {
        if attachment.type == .image,
           let urlString = attachment.url,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray5)
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                selectedImageURL = url
                showFullImage = true
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.title2)
                Text(attachment.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Action Handling
    
    /// Strips emoji characters from text for cleaner UI presentation
    private func stripEmojis(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            // Keep everything except emoji-range scalars
            !(scalar.properties.isEmoji && scalar.properties.isEmojiPresentation)
            && scalar.value != 0xFE0F // variation selector
        }.map { String($0) }.joined()
    }

    /// Renders content with inline Markdown styling for a modern, polished look:
    /// Handles bold, italics, inline code, and links with distinct visual hierarchy.
    private func styledMarkdownText(_ content: String) -> Text {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        
        guard let attributed = try? AttributedString(markdown: content, options: options) else {
            return Text(content)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
        }
        
        var styled = attributed
        // Base styling for modern look
        styled.font = .system(size: 16, weight: .regular, design: .default)
        styled.foregroundColor = .white.opacity(0.9)
        
        for run in styled.runs {
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.stronglyEmphasized) {
                    // Bold: Slightly larger, crisp white for emphasis
                    styled[run.range].font = .system(size: 17, weight: .bold, design: .default)
                    styled[run.range].foregroundColor = .white
                } 
                if intent.contains(.emphasized) {
                    // Italic: Softer
                    styled[run.range].font = .system(size: 16, weight: .regular, design: .default).italic()
                    styled[run.range].foregroundColor = .white.opacity(0.85)
                }
                if intent.contains(.code) {
                    // Inline Code: Monospaced, soft blue tint, subtle background
                    styled[run.range].font = .system(size: 15, weight: .semibold, design: .monospaced)
                    styled[run.range].foregroundColor = Color(red: 0.6, green: 0.85, blue: 1.0)
                    styled[run.range].backgroundColor = Color.white.opacity(0.12)
                }
            }
            if run.link != nil {
                // Links: Bright blue with underline
                styled[run.range].foregroundColor = Color(red: 0.4, green: 0.7, blue: 1.0)
                styled[run.range].underlineStyle = .single
            }
        }
        
        return Text(styled)
    }

}


// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        EnhancedMessageBubble(
            message: MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "Here's a comprehensive explanation of SwiftUI. SwiftUI is Apple's modern framework for building user interfaces across all Apple platforms. It uses a declarative syntax that makes it easy to create complex UIs with less code.",
                attachments: [],
                timestamp: Date()
            )
        )
        
        EnhancedMessageBubble(
            message: MultimodalMessage(
                id: UUID().uuidString,
                role: .user,
                content: "Tell me about SwiftUI",
                attachments: [],
                timestamp: Date()
            )
        )
    }
    .padding()
}
