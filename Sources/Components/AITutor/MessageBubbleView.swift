import SwiftUI

struct LyoMessageBubbleView: View {
    let message: LyoMessage
    var onActionTap: ((MessageAction) -> Void)?
    var onQuickChipTap: ((String) -> Void)?
    var onCourseStart: ((CourseProposalData) -> Void)?
    var onAudioToggle: ((String, String) -> Void)?  // (messageId, text) -> Void
    var isPlayingAudio: Bool = false
    var audioProgress: Double = 0
    
    // A2UI callbacks for rich content interactions
    var onA2UICourseStart: ((CourseCreationData) -> Void)?
    var onA2UIQuizAnswer: ((String, Int) -> Void)?
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    @State private var frameIndex = 0
    private let frames = ["Mascot_Reading_1", "Mascot_Reading_2", "Mascot_Reading_3", "Mascot_Reading_4"]
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    /// True when contentTypes contains rich content (.a2ui, .courseProposal, .courseRoadmap, .quiz, .flashcards)
    /// — hides raw text so the rich component renders exclusively without duplication
    private var hasRichContent: Bool {
        // Also treat non-chat response modes (like course/explainer) as rich content
        if let mode = message.responseMode, mode != .chat {
            return true
        }
        
        guard let types = message.contentTypes else { return false }
        return types.contains { contentType in
            switch contentType {
            case .a2ui: return true
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

    private var shouldRenderPlainText: Bool {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        // If rich content is present, let that content handle the display exclusively
        // to prevent the "Double Bubble" overlay issue.
        if hasRichContent {
            return false
        }
        return !trimmed.isEmpty
    }
    
    var body: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 0) {
            // AI Header: Mascot & Speaker ABOVE the bubble
            if !message.isFromUser {
                HStack(alignment: .center, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        Image("Mascot_Standing")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Text("Lyo")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    if message.status == .sending || (message.content.isEmpty && !message.isFromUser) {
                        ThinkingDotsView()
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
                        .scaleEffect(0.85) // Slightly smaller helper icon
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            
            // Main Bubble Content
            ZStack(alignment: .topTrailing) {
                VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: DesignTokens.Spacing.xs) {
                    // Message content with premium styling
                    // Hide raw text when rich content is present (A2UI/quiz/course/flashcards render their own UI)
                    if shouldRenderPlainText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.content)
                                .font(DesignTokens.Typography.bodyMedium)
                                .foregroundColor(.white) // Force white text
                                .fixedSize(horizontal: false, vertical: true) // Wrap text
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, !message.isFromUser ? 32 : 0) // Leave room for speaker icon
                        }
                    }
                
                // ==== A2UI RICH CONTENT RENDERING ====
                // This renders Course Roadmaps, Quizzes, Flashcards inline
                if let contentTypes = message.contentTypes, !contentTypes.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(Array(contentTypes.enumerated()), id: \.offset) { index, contentType in
                            renderContentType(contentType)
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
                            .padding(.horizontal, 4) // Indent slightly
                        }
                    case .course:
                        if let data = message.courseProposal {
                            CourseProposalView(data: data) {
                                onCourseStart?(data)
                            }
                        }
                    case .chat:
                        EmptyView() // Handled by standard text view above
                    }
                }
                
                // Attachments
                if let attachments = message.attachments, !attachments.isEmpty {
                    ForEach(attachments) { attachment in
                        PremiumAttachmentView(attachment: attachment)
                    }
                }
                
                // Action pills (Lyo messages only)
                if !message.isFromUser, let actions = message.actions, !actions.isEmpty, !hasRichContent {
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
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(messageBackground)
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: message.isFromUser ? UIScreen.main.bounds.width * 0.8 : UIScreen.main.bounds.width * 0.995, alignment: message.isFromUser ? .trailing : .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }
    
    // MARK: - A2UI Content Type Rendering
    
    @ViewBuilder
    private func renderContentType(_ contentType: MessageContentType) -> some View {
        switch contentType {
        case .courseRoadmap(let title, let modules, _, _):
            // Convert CourseModule to CourseModuleData
            let convertedModules: [CourseModuleData] = modules.map { mod in
                CourseModuleData(
                    id: mod.id,
                    title: mod.title,
                    description: mod.duration ?? ""
                )
            }
            let courseData = CourseCreationData(
                id: UUID().uuidString,
                title: title,
                topic: title,
                level: "intermediate",
                modules: convertedModules
            )
            CourseRoadmapCardView(course: courseData) { course in
                onA2UICourseStart?(course)
            }
            
        case .quiz(let question, let options, let correctIndex, _):
            // Single question quiz - use local QuizData/QuizQuestionData
            let quizData = QuizData(
                title: "Quick Quiz",
                questions: [
                    QuizQuestionData(
                        id: UUID().uuidString,
                        question: question,
                        options: options,
                        correctAnswer: options.indices.contains(correctIndex) ? options[correctIndex] : options.first ?? ""
                    )
                ]
            )
            QuizCardView(quiz: quizData) { questionText, answerIndex in
                onA2UIQuizAnswer?(questionText, answerIndex)
            }
            
        case .flashcards(let title, let cards):
            // Convert Flashcard to FlashcardItem and wrap in FlashcardData
            let convertedCards: [FlashcardItem] = cards.map { card in
                FlashcardItem(id: card.id, front: card.front, back: card.back)
            }
            FlashcardsCardView(flashcards: FlashcardData(title: title, cards: convertedCards))
            
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
            
        case .recursiveUI(let component):
            // Use the centralized recursive renderer for rich A2UI components
            A2UIRecursiveRenderer(component: component) { actionId in
                onQuickChipTap?(actionId)
            }

        case .studyPlan(let plan):
            // Inline study plan rendering (compatible with StudyPlan type)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Study Plan")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.7))
                            .textCase(.uppercase)
                        Text(plan.title)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
                Divider().background(Color.white.opacity(0.2))
                ForEach(plan.schedule.prefix(3)) { day in
                    HStack(spacing: 12) {
                        Text("Day \(day.dayNumber)")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.7))
                        Text(day.topic)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
                if plan.schedule.count > 3 {
                    Text("+ \(plan.schedule.count - 3) more days")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
            .background(Color(white: 0.1))
            .cornerRadius(16)
            
        case .suggestions(let title, let options):
            // Render suggestions as quick chips
            VStack(alignment: .leading, spacing: 10) {
                if !title.isEmpty {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
                FlowLayout(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            onQuickChipTap?(option)
                        } label: {
                            Text(option)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            
        case .cinematic(let data):
            Button {
                NotificationCenter.default.post(name: Notification.Name("PlayCinematic"), object: data)
            } label: {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                    Text("Watch \(data.title)")
                        .bold()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple, lineWidth: 1))
            }
            
        case .a2ui(let component):
            A2UIRenderer(component: component, onAction: { (action: A2UIAction, _ component: A2UIComponent) in
                onQuickChipTap?("a2ui-\(action.id)")
            })
            
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
                    .fill(Color(white: 0.15)) // Lighter Black
                
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
            // AI message: Dark Transparent Black with Pulses (Integrated with PulsingTrim)
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(Color.black.opacity(0.85))
                
                PulsingTrimOverlay(cornerRadius: DesignTokens.Radius.lg)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                            Color(hex: "CC6F56")
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
                            Color.white.opacity(0)
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
    
    var body: some View {
        Button {
            withAnimation(DesignTokens.Animation.quick) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignTokens.Animation.quick) {
                    isPressed = false
                }
                onTap()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconForAction(action.actionType))
                    .font(.system(size: 13, weight: .semibold))
                Text(action.label)
                    .font(DesignTokens.Typography.labelMedium)
            }
            .foregroundColor(DesignTokens.Colors.accent)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                ZStack {
                    Capsule()
                        .fill(DesignTokens.Colors.surface)
                    
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Colors.accent.opacity(0.5),
                                    DesignTokens.Colors.accentSecondary.opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .applyShadow(DesignTokens.Shadow.sm)
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .opacity(isPressed ? 0.85 : 1.0)
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

// MARK: - Thinking Dots helper
struct ThinkingDotsView: View {
    @State private var animationPhase = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1.0 : 0.4)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}
