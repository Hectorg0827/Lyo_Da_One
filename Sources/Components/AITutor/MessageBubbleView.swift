import SwiftUI

struct LyoMessageBubbleView: View {
    let message: LyoMessage
    var onActionTap: ((MessageAction) -> Void)?
    var onQuickChipTap: ((String) -> Void)?
    var onCourseStart: ((CourseProposalData) -> Void)?
    var onAudioToggle: ((String, String) -> Void)?  // (messageId, text) -> Void
    var isPlayingAudio: Bool = false
    var audioProgress: Double = 0

    // Course interaction callbacks
    var onCourseStart_A2A: ((CourseCreationData) -> Void)?
    var onQuizAnswer_A2A: ((String, Int) -> Void)?
    
    // New Smart Block callbacks
    var onSmartBlockQuizAnswer: ((String, Int, Bool) -> Void)?
    var onSmartBlockTestPrepScheduled: ((Date, String, String, [String]) -> Void)?

    var mascotNamespace: Namespace.ID?

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var frameIndex = 0
    private let frames = [
        "Mascot_Reading_1", "Mascot_Reading_2", "Mascot_Reading_3", "Mascot_Reading_4",
    ]
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    /// True when contentTypes contains rich content (.courseProposal, .courseRoadmap, .quiz, .flashcards)
    /// — hides raw text so the rich component renders exclusively without duplication
    private var hasRichContent: Bool {
        // Also treat non-chat response modes (like course/explainer) as rich content
        if let mode = message.responseMode, mode != .chat {
            return true
        }
        
        // SmartBlocks v2 rich content (quiz, flashcard, dataViz, etc.) counts as rich
        if let blocks = message.smartBlocks, blocks.contains(where: { $0.type != .text }) {
            return true
        }

        guard let types = message.contentTypes else { return false }
        return types.contains { contentType in
            switch contentType {
            case .courseProposal: return true
            case .courseRoadmap: return true
            case .quiz: return true
            case .flashcards: return true
            case .studyPlan: return true
            case .testPrep: return true
            default: return false
            }
        }
    }

    private var shouldRenderPlainText: Bool {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        // If rich content is present, let that content handle the display exclusively
        // to prevent the "Double Bubble" overlay issue.
        if hasRichContent {
            return false
        }
        return !trimmed.isEmpty
    }

    @State private var showCursor: Bool = true

    var body: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {

            // AI Header: Mascot & Speaker ABOVE the bubble
            if !message.isFromUser {
                HStack(alignment: .center, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        // 1) Thinking: No text yet -> Show Animated Reading Mascot
                        // 2) Streaming: Text is arriving -> Show Mascot #1 (Standing)
                        // 3) Finished: Text complete -> Show Mascot #1 (Standing)
                        if message.status == .sending && message.content.isEmpty
                            && !message.isFromUser
                        {

                            // Show reading mascot animation when thinking/streaming
                            if let ns = mascotNamespace {
                                AnimatedReadingMascotView(size: 28)
                                    .matchedGeometryEffect(id: "mascot_\(message.id)", in: ns)
                            } else {
                                AnimatedReadingMascotView(size: 28)
                            }
                        } else {
                            // Show Mascot #1 (Standing) when finished, moved down by 10px
                            if let ns = mascotNamespace {
                                Image("Mascot_Standing")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .offset(y: 10)
                                    .matchedGeometryEffect(id: "mascot_\(message.id)", in: ns)
                            } else {
                                Image("Mascot_Standing")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .offset(y: 10)
                            }
                        }

                        Text("Lyo")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    // Speaker icon aligned with mascot above the bubble
                    if !message.content.isEmpty && onAudioToggle != nil {
                        MessageAudioButton(
                            messageId: message.id,
                            text: message.content,
                            isPlaying: isPlayingAudio,
                            progress: audioProgress,
                            onToggle: {
                                onAudioToggle?(message.id, message.content)
                            }
                        )
                        .scaleEffect(0.85)  // Slightly smaller helper icon
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            // Main Bubble Content
            ZStack(alignment: .topTrailing) {
                VStack(
                    alignment: message.isFromUser ? .trailing : .leading,
                    spacing: DesignTokens.Spacing.xs
                ) {
                    // Message content with premium styling
                    // Hide raw text when rich content is present (quiz/course/flashcards render their own UI)
                    if shouldRenderPlainText {
                        SmartBlockContainerView(
                            rawResponse: message.content,
                            isFromUser: message.isFromUser,
                            showCursor: message.isStreaming ? showCursor : false,
                            onQuizAnswerSubmitted: { selected, isCorrect in
                                onSmartBlockQuizAnswer?(message.content, selected, isCorrect)
                            },
                            onTestPrepScheduled: onSmartBlockTestPrepScheduled
                        )
                        .padding(.bottom, 4)
                    }

                    // Rich content rendering
                    if let contentTypes = message.contentTypes, !contentTypes.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(Array(contentTypes.enumerated()), id: \.offset) {
                                index, contentType in
                                renderContentType(contentType)
                            }
                        }
                        .padding(.top, shouldRenderPlainText ? 8 : 0)
                    }
                    
                    // SmartBlock v2 rendering — preferred format from backend
                    if let smartBlocks = message.smartBlocks, !smartBlocks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(smartBlocks) { block in
                                UnifiedBlockRenderer(
                                    block: block,
                                    context: .chat,
                                    onQuizAnswer: { index in
                                        onSmartBlockQuizAnswer?(message.content, index, false)
                                    }
                                )
                            }
                        }
                        .padding(.top, shouldRenderPlainText ? 8 : 0)
                    }

                    // Mentor Mode Content (Legacy support)
                    if let mode = message.responseMode {
                        switch mode {
                        case .explainer:
                            if let data = message.quickExplainer {
                                QuickExplainerView(data: data) { chip in
                                    onQuickChipTap?(chip)
                                }
                                .padding(.horizontal, 4)  // Indent slightly
                            }
                        case .course:
                            if let data = message.courseProposal {
                                ChatInteractiveCardView(
                                    type: .course(
                                        title: data.title,
                                        topic: data.subtext,
                                        level: data.summary,
                                        duration: nil,
                                        imageURL: nil
                                    ),
                                    onStart: { onCourseStart?(data) },
                                    onRefine: {
                                        onActionTap?(
                                            MessageAction(
                                                id: "refine_course", label: "Refine",
                                                actionType: .generateSyllabus))
                                    },
                                    onSave: {
                                        onActionTap?(
                                            MessageAction(
                                                id: "save_course", label: "Save",
                                                actionType: .addToLibrary))
                                    }
                                )
                            }
                        case .chat:
                            EmptyView()  // Handled by standard text view above
                        }
                    }

                    // Attachments
                    if let attachments = message.attachments, !attachments.isEmpty {
                        ForEach(attachments) { attachment in
                            PremiumAttachmentView(attachment: attachment)
                        }
                    }

                    // Action pills (Lyo messages only)
                    if !message.isFromUser, let actions = message.actions, !actions.isEmpty,
                        !hasRichContent
                    {
                        FlowLayout(spacing: DesignTokens.Spacing.xs) {
                            ForEach(actions) { action in
                                PremiumActionPillButton(action: action) {
                                    HapticManager.shared.playLightImpact()
                                    onActionTap?(action)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    // Timestamp and status
                    HStack(spacing: 4) {
                        Text(formatTime(message.timestamp))
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.gray)

                        if message.isFromUser, let status = message.status {
                            StatusIcon(status: status)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
                .padding(
                    .horizontal,
                    message.isFromUser ? DesignTokens.Spacing.md : DesignTokens.Spacing.xs
                )
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(messageBackground)
                .environment(\.colorScheme, .dark)
                .frame(
                    maxWidth: message.isFromUser
                        ? UIScreen.main.bounds.width * 0.8 : UIScreen.main.bounds.width * 0.998,
                    alignment: message.isFromUser ? .trailing : .leading)
            }
        }
        .padding(.horizontal, message.isFromUser ? 4 : 1)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if message.isStreaming {
                showCursor.toggle()
            }
        }
        .onChange(of: message.content) { oldValue, newValue in
            if message.isStreaming && newValue.count > oldValue.count {
                // Throttle haptics slightly so we don't overwhelm the Taptic Engine
                if newValue.count % 5 == 0 {
                    HapticManager.shared.playSoftImpact()
                }
            }
        }
    }

    // MARK: - Content Type Rendering

    @ViewBuilder
    private func renderContentType(_ contentType: MessageContentType) -> some View {
        switch contentType {
        case .courseProposal(let payload):
            CourseProposalCardView(
                payload: payload,
                onStart: {
                    let courseData = CourseCreationData(
                        id: payload.id ?? UUID().uuidString,
                        title: payload.title,
                        topic: payload.topic,
                        level: payload.level,
                        modules: payload.objectives.enumerated().map { index, objective in
                            CourseModuleData(
                                id: "course_preview_\(index + 1)",
                                title: "Module \(index + 1)",
                                description: objective
                            )
                        },
                        difficultyLevel: payload.level,
                        instructorId: "default"
                    )
                    UIStackStore.shared.upsertCourse(
                        courseId: courseData.id,
                        title: courseData.title,
                        subtitle: courseData.topic
                    )
                    onCourseStart_A2A?(courseData)
                },
                onAdjust: {
                    let refinePrompt = "Refine this course on \(payload.topic) for a \(payload.level.lowercased()) learner. Keep the title '\(payload.title)' but make the first module more hands-on, add a better project arc, and tighten the learning outcomes."
                    onQuickChipTap?(refinePrompt)
                }
            )

        case .courseRoadmap(let title, let modules, _, _):
            ChatInteractiveCardView(
                type: .course(
                    title: title, topic: title, level: "intermediate",
                    duration: "\(modules.count * 10) min", imageURL: nil),
                onStart: {
                    let courseData = CourseCreationData(
                        id: UUID().uuidString,
                        title: title,
                        topic: title,
                        level: "intermediate",
                        modules: modules.map {
                            CourseModuleData(
                                id: $0.id, title: $0.title, description: $0.duration ?? "")
                        },
                        difficultyLevel: "intermediate",
                        instructorId: "default"
                    )
                    onCourseStart_A2A?(courseData)
                },
                onRefine: { onQuickChipTap?("refine_course") },
                onSave: { onQuickChipTap?("save_course") }
            )

        case .quiz(let question, _, let correctIndex, _):
            ChatInteractiveCardView(
                type: .quiz(title: "Quick Quiz", questionCount: 1, imageURL: nil),
                onStart: {
                    // Start quiz UI action
                    onQuizAnswer_A2A?(question, correctIndex)
                },
                onRefine: { onQuickChipTap?("refine_quiz") },
                onSave: { onQuickChipTap?("save_quiz") }
            )

        case .flashcards(let title, let cards):
            ChatInteractiveCardView(
                type: .flashcards(title: title, cardCount: cards.count, imageURL: nil),
                onStart: { onQuickChipTap?("start_flashcards") },
                onRefine: { onQuickChipTap?("refine_flashcards") },
                onSave: { onQuickChipTap?("save_flashcards") }
            )

        case .notes(let title, let sections):
            NotesView(notes: NotesPayload(title: title, sections: sections))

        case .courseCard(let courseId, let title, let subtitle, let thumbnail):
            // Render as a mini course card
            InlineCourseCardView(
                courseId: courseId,
                title: title,
                subtitle: subtitle,
                thumbnail: thumbnail
            )

        case .codeSnippet(_, let code):
            // CodeSnippetView in ModuleCardView.swift only takes code parameter
            CodeSnippetView(code: code)

        case .richCard(let title, let body, let imageURLString, let actions):
            RichCardView(
                title: title,
                content: body,
                imageURL: imageURLString.flatMap { URL(string: $0) },
                actions: actions ?? [],
                onAction: { actionId in
                    onQuickChipTap?(actionId)
                }
            )

        case .processing(let step, let progress):
            ProcessingIndicatorView(step: step, progress: progress)

        case .topicSelection(let title, let topics):
            TopicSelectionView(title: title, topics: topics) { topic in
                onQuickChipTap?(topic.id)
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var messageBackground: some View {
        if message.isFromUser {
            // User message: Lighter black with depth + slim gradient trim
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(Color(white: 0.15))  // Lighter Black

                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
        } else {
            // AI message: Semi-transparent black glass effect
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)

                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(Color.black.opacity(0.55))

                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Strips emoji characters from text for cleaner UI
    private func stripEmojis(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            !(scalar.properties.isEmoji && scalar.properties.isEmojiPresentation)
                && scalar.value != 0xFE0F
        }.map { String($0) }.joined()
    }

    /// Renders content with inline Markdown styling:
    /// **bold** → white bold + larger font, rest → white
    private func markdownText(_ content: String) -> Text {
        guard
            let attributed = try? AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        else {
            return Text(content).foregroundColor(.white)
        }
        var styled = attributed
        for run in styled.runs {
            if let intent = run.inlinePresentationIntent,
                intent.contains(.stronglyEmphasized)
            {
                styled[run.range].foregroundColor = .white
                styled[run.range].font = .system(size: 17, weight: .bold)
            } else {
                styled[run.range].foregroundColor = .white.opacity(0.9)
            }
        }
        return Text(styled)
    }
}

// MARK: - Premium Lyo Avatar

struct PremiumLyoAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Gradient background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FCCC66"),
                            Color(hex: "ECA05B"),
                            Color(hex: "CC6F56"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Glossy overlay
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)

            // "L" letter
            Text("L")
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .applyShadow(DesignTokens.Shadow.sm)
    }
}

// MARK: - Premium Attachment View

struct PremiumAttachmentView: View {
    let attachment: MessageAttachment

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.accentGradient)
                    .frame(width: 36, height: 36)

                Image(systemName: iconForType(attachment.type))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename ?? "File")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                if let size = attachment.size {
                    Text(formatSize(size))
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
        .glassmorphic(cornerRadius: DesignTokens.Radius.md)
        .frame(maxWidth: 260)
    }

    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .file: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "play.rectangle.fill"
        case .audio: return "waveform"
        case .link: return "link"
        case .document: return "doc.text.fill"
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", kb / 1024.0)
    }
}

// MARK: - Premium Action Pill Button

struct PremiumActionPillButton: View {
    let action: MessageAction
    let onTap: () -> Void
    @State private var isPressed = false
    @State private var showShimmer = true
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button {
            HapticManager.shared.playLightImpact()
            withAnimation(DesignTokens.Animation.quick) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignTokens.Animation.springBouncy) {
                    isPressed = false
                }
                onTap()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconForAction(action.actionType))
                    .font(.system(size: 14, weight: .semibold))
                Text(action.label)
                    .font(DesignTokens.Typography.labelMedium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(pillBackground)
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .opacity(isPressed ? 0.8 : 1.0)
        .animation(DesignTokens.Animation.springBouncy, value: isPressed)
    }

    @ViewBuilder
    private var pillBackground: some View {
        ZStack {
            // Gradient background matching PremiumChipButton
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface,
                            DesignTokens.Colors.surfaceElevated,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border gradient
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.accent.opacity(0.6),
                            DesignTokens.Colors.accentSecondary.opacity(0.4),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            // Glossy overlay
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0),
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
        .applyShadow(DesignTokens.Shadow.sm)
        .modifier(ConditionalShimmer(enabled: showShimmer && !reduceMotion))
    }

    private func iconForAction(_ type: MessageAction.ActionType) -> String {
        switch type {
        case .createCourse: return "plus.circle.fill"
        case .createCourseA2A: return "cpu.fill"  // A2A multi-agent icon
        case .quizMe: return "questionmark.circle.fill"
        case .addToLibrary: return "bookmark.fill"
        case .openDrawer: return "square.grid.2x2.fill"
        case .generateSyllabus: return "list.bullet.clipboard.fill"
        case .quickExplainer: return "lightbulb.fill"
        case .makeFlashcards: return "rectangle.stack.fill"
        case .extractKeyPoints: return "list.star"
        case .openClassroom: return "book.circle.fill"
        }
    }
}

// MARK: - Status Icon

struct StatusIcon: View {
    let status: LyoMessage.MessageStatus

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
    }

    private var iconName: String {
        switch status {
        case .sending: return "clock.fill"
        case .sent: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .sending: return DesignTokens.Colors.textSecondary
        case .sent: return DesignTokens.Colors.accent
        case .failed: return DesignTokens.Colors.danger
        }
    }
}

// MARK: - Flow Layout for Action Pills

// FlowLayout moved to Sources/Components/Common/FlowLayout.swift

// MARK: - Inline Content Helper Views

/// Inline Course Card (compact version for chat)
struct InlineCourseCardView: View {
    let courseId: String
    let title: String
    let subtitle: String?
    let thumbnail: String?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "book.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(12)
        .background(Color(white: 0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "8B5CF6").opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Animated Reading Mascot
struct AnimatedReadingMascotView: View {
    let size: CGFloat
    @State private var frameIndex = 0
    private let frames = [
        "Mascot_Reading_1", "Mascot_Reading_2", "Mascot_Reading_3", "Mascot_Reading_4",
    ]
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        Image(frames[frameIndex])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .onReceive(timer) { _ in
                frameIndex = (frameIndex + 1) % frames.count
            }
    }
}
