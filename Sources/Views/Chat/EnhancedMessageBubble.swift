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

struct EnhancedMessageBubble: View {
    let message: MultimodalMessage
    let onTTSToggle: (() -> Void)?
    let onQuizAnswer: ((Int) -> Void)?
    let onCourseOpen: ((String) -> Void)?
    let onTopicSelect: ((TopicOption) -> Void)?
    let onModuleSelect: ((CourseModule) -> Void)?
    let onSuggestionSelect: ((String) -> Void)?
    let onCinematicPlay: ((A2UICinematic) -> Void)?
    let highlights: [ChatHighlight]
    let onTextSelectionAction: ((TextSelectionAction) -> Void)?
    
    @StateObject private var audioService = AudioPlaybackService.shared
    @State private var showFullImage = false
    @State private var selectedImageURL: URL?
    
    init(
        message: MultimodalMessage,
        onTTSToggle: (() -> Void)? = nil,
        onQuizAnswer: ((Int) -> Void)? = nil,
        onCourseOpen: ((String) -> Void)? = nil,
        onTopicSelect: ((TopicOption) -> Void)? = nil,
        onModuleSelect: ((CourseModule) -> Void)? = nil,
        onSuggestionSelect: ((String) -> Void)? = nil,
        onCinematicPlay: ((A2UICinematic) -> Void)? = nil,
        highlights: [ChatHighlight] = [],
        onTextSelectionAction: ((TextSelectionAction) -> Void)? = nil
    ) {
        self.message = message
        self.onTTSToggle = onTTSToggle
        self.onQuizAnswer = onQuizAnswer
        self.onCourseOpen = onCourseOpen
        self.onTopicSelect = onTopicSelect
        self.onModuleSelect = onModuleSelect
        self.onSuggestionSelect = onSuggestionSelect
        self.onCinematicPlay = onCinematicPlay
        self.highlights = highlights
        self.onTextSelectionAction = onTextSelectionAction
    }
    
    /// True when contentTypes contains rich content that should suppress raw text rendering
    /// to prevent duplicate display (text + card both showing)
    private var hasRichContent: Bool {
        message.contentTypes.contains { contentType in
            switch contentType {
            case .courseProposal: return true
            case .courseRoadmap: return true
            case .quiz: return true
            case .flashcards: return true
            case .studyPlan: return true
            case .recursiveUI: return true
            case .cinematic: return true
            default: return false
            }
        }
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
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                            .offset(y: 10)
                    }
                    
                    Text("Lyo")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Read Aloud (TTS) in Header — only when there's text to speak
                if !message.content.isEmpty {
                Button(action: {
                    onTTSToggle?()
                }) {
                    Image(systemName: audioService.isPlaying ? "stop.circle.fill" : "speaker.wave.2")
                        .font(.system(size: 14))
                        .foregroundColor(audioService.isPlaying ? .red : .white.opacity(0.6))
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Content Area
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<message.contentTypes.count, id: \.self) { index in
                        let contentType = message.contentTypes[index]
                        
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

                        case .recursiveUI(let component):
                            A2UIRecursiveRenderer(component: component) { actionId in
                                handleA2UIAction(actionId)
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

                        case .cinematic(let data):
                            // Render a "Trailer" card that invites the user to tap
                            Button {
                                // Trigger callback
                                onCinematicPlay?(data)
                            } label: {
                                ZStack {
                                    Color.black
                                    
                                    // Placeholder Gradient
                                    LinearGradient(colors: [.purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .opacity(0.6)
                                    
                                    VStack(spacing: 16) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.white)
                                            .shadow(radius: 10)
                                        
                                        VStack(spacing: 4) {
                                            Text(data.title.uppercased())
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                            
                                            if let subtitle = data.subtitle {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.8))
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                    }
                                    .padding()
                                }
                                .frame(height: 180)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, -8)

                        case .studyPlan(let plan):
                            StudyPlanView(plan: plan)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, -8)

                        case .notes(let title, let sections):
                            NotesView(notes: NotesPayload(title: title, sections: sections))
                                .padding(.horizontal, -8)

                        default:
                            EmptyView()
                        }
                    }
                    
                    // Attachments
                    if !message.attachments.isEmpty {
                        attachmentsGrid(message.attachments)
                    }
                }
                
                // Action Footer (Share, Copy) — only when there's text to copy
                if !message.content.isEmpty {
                HStack(spacing: 16) {
                    Spacer()
                    
                    // Copy
                    Button(action: {
                        UIPasteboard.general.string = message.content
                        HapticManager.shared.light()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Share
                    Button(action: {
                        // Start simple share sheet
                        let activityVC = UIActivityViewController(activityItems: [message.content], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                } // end if !message.content.isEmpty
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, 14)
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 1) // Near edge-to-edge
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
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
            )
    }
    
    // MARK: - TTS Button
    
    private var ttsButton: some View {
        Button {
            onTTSToggle?()
            HapticManager.shared.playLightImpact()
        } label: {
            Group {
                if audioService.currentMessageId == message.id && audioService.isPlaying {
                    Image(systemName: "stop.circle.fill")
                } else if audioService.currentMessageId == message.id && audioService.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "speaker.wave.2.circle.fill")
                }
            }
            .font(.system(size: 20))
            .foregroundColor(.accentColor.opacity(0.8))
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

    private func handleA2UIAction(_ actionId: String) {
        Log.ai.info("Action triggered: \(actionId)")
        HapticManager.shared.light()

        // Parse action and route to appropriate handler
        if actionId == "create_course_from_topic" {
            let payload = CoursePayload(
                id: nil,
                title: "AI Generated Course",
                topic: "AI Generated Course",
                level: "Beginner",
                language: nil,
                duration: nil,
                objectives: []
            )
            
            AICommandHandler.shared.executeOpenClassroom(for: payload)
        } else if actionId.hasPrefix("quiz_answer_") {
            if let indexString = actionId.components(separatedBy: "_").last,
               let index = Int(indexString) {
                onQuizAnswer?(index)
            }
        } else if actionId.hasPrefix("start_module_") {
            if let moduleId = actionId.components(separatedBy: "_").last {
                // Create a CourseModule for the callback (simplified)
                let module = CourseModule(
                    id: moduleId,
                    title: "Module \(moduleId)",
                    duration: "30 min",
                    isCompleted: false,
                    isLocked: false
                )
                onModuleSelect?(module)
            }
        } else if actionId.hasPrefix("start_topic_") {
            if let topicId = actionId.components(separatedBy: "_").last {
                // Create a TopicOption for the callback
                let topic = TopicOption(
                    title: "Topic \(topicId)",
                    icon: "book.fill",
                    gradientColors: ["#3B82F6", "#8B5CF6"]
                )
                onTopicSelect?(topic)
            }
        } else {
            // Handle other actions as suggestions
            onSuggestionSelect?(actionId)
        }
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

