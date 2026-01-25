//
//  EnhancedMessageBubble.swift
//  Lyo
//
//  Gemini-style full-width message bubble with top-positioned avatar
//

import SwiftUI
import AVKit

struct EnhancedMessageBubble: View {
    let message: MultimodalMessage
    let onTTSToggle: (() -> Void)?
    let onQuizAnswer: ((Int) -> Void)?
    let onCourseOpen: ((String) -> Void)?
    let onTopicSelect: ((TopicOption) -> Void)?
    let onModuleSelect: ((CourseModule) -> Void)?
    let onSuggestionSelect: ((String) -> Void)?
    
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
        onSuggestionSelect: ((String) -> Void)? = nil
    ) {
        self.message = message
        self.onTTSToggle = onTTSToggle
        self.onQuizAnswer = onQuizAnswer
        self.onCourseOpen = onCourseOpen
        self.onTopicSelect = onTopicSelect
        self.onModuleSelect = onModuleSelect
        self.onSuggestionSelect = onSuggestionSelect
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
        VStack(alignment: .leading, spacing: 12) {
            // Content Area
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<message.contentTypes.count, id: \.self) { index in
                    let contentType = message.contentTypes[index]
                    
                    switch contentType {
                    case .text:
                        if !message.content.isEmpty {
                            Text(LocalizedStringKey(message.content))
                                .font(.body)
                                .foregroundColor(.white)
                                .textSelection(.enabled)
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
                        InteractiveQuizBubbleView(
                            question: question,
                            options: options,
                            correctIndex: correctIndex,
                            explanation: explanation,
                            onAnswerSelected: { index in
                                onQuizAnswer?(index)
                            }
                        )
                        
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

                    case .a2ui(let component):
                        A2UIRenderer(component: component) { action, _ in
                            handleA2UIAction("a2ui-\(action.id)")
                        }
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
            
            // Action Footer (Share, Copy, Read Aloud)
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
                
                // Read Aloud (TTS)
                Button(action: {
                    onTTSToggle?()
                }) {
                    Image(systemName: audioService.isPlaying ? "stop.circle.fill" : "speaker.wave.2")
                        .font(.system(size: 14))
                        .foregroundColor(audioService.isPlaying ? .red : .white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity) // Take up available width
        // 99% logic handled by parent padding or frame, but here we enforce taking space
        .background(
            ZStack {
                Color.black.opacity(0.4) // Darker, transparent, enough for white text
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 4) // Slight padding from screen edge for the "99%" feel
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
                // Main content
                Text(LocalizedStringKey(message.content))
                    .font(.body)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
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

    // MARK: - A2UI Action Handling

    private func handleA2UIAction(_ actionId: String) {
        print("🎯 A2UI Action triggered: \(actionId)")
        HapticManager.shared.light()

        // Parse action and route to appropriate handler
        if actionId.hasPrefix("quiz_answer_") {
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

import SwiftUI

struct A2UIRecursiveRenderer: View {
    let component: DynamicComponent
    let onAction: ((String) -> Void)?

    var body: some View {
        switch component.payload {
        case .vstack(let data):
            VStack(alignment: mapVStackAlignment(data.alignment), spacing: data.spacing ?? 12) {
                ForEach(data.children) { child in
                    A2UIRecursiveRenderer(component: child, onAction: onAction)
                }
            }

        case .hstack(let data):
            HStack(alignment: mapHStackAlignment(data.alignment), spacing: data.spacing ?? 12) {
                ForEach(data.children) { child in
                    A2UIRecursiveRenderer(component: child, onAction: onAction)
                }
            }

        case .card(let data):
            VStack(alignment: .leading, spacing: 12) {
                if let title = data.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let subtitle = data.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(data.children) { child in
                    A2UIRecursiveRenderer(component: child, onAction: onAction)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(parseColor(data.backgroundColor) ?? Color(.secondarySystemBackground))
            )

        case .text(let data):
            Text(data.content)
                .font(mapFont(data.fontStyle))
                .foregroundColor(parseColor(data.color) ?? .primary)
                .multilineTextAlignment(mapTextAlignment(data.alignment))
                .frame(maxWidth: .infinity, alignment: mapFrameAlignment(data.alignment))

        case .button(let data):
            Button(action: { onAction?(data.actionId) }) {
                Text(data.label)
                    .font(.body)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(buttonBackground(for: data.variant, disabled: data.isDisabled))
                    .foregroundColor(buttonForeground(for: data.variant, disabled: data.isDisabled))
                    .cornerRadius(8)
            }
            .disabled(data.isDisabled)
            .opacity(data.isDisabled ? 0.6 : 1.0)

        case .image(let data):
            AsyncImage(url: URL(string: data.url)) { image in
                image
                    .resizable()
                    .aspectRatio(parseAspectRatio(data.aspectRatio) ?? 1.0, contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            if let altText = data.altText {
                                Text(altText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    )
            }
            .frame(maxHeight: 200)
            .cornerRadius(8)

        case .divider(let data):
            Divider()
                .overlay(parseColor(data.color) ?? Color(.separator))

        case .spacer(let data):
            Spacer()
                .frame(height: data.height ?? 16)

        case .quiz(let data):
            LegacyQuizRenderer(data: data, onAction: onAction)

        case .courseRoadmap(let data):
            LegacyCourseRoadmapRenderer(data: data, onAction: onAction)

        // AI Classroom Integration Components
        case .coursePreview(let data):
            CoursePreviewRenderer(data: data, onAction: onAction)

        case .learningNode(let data):
            LearningNodeRenderer(data: data, onAction: onAction)

        case .progressTracker(let data):
            ProgressTrackerRenderer(data: data, onAction: onAction)

        case .interactiveLesson(let data):
            InteractiveLessonRenderer(data: data, onAction: onAction)

        // Standard A2UI Components
        case .lessonCard(let data):
            LessonCardRenderer(data: data, onAction: onAction)
            
        case .courseCard(let data):
            A2UICourseCardRenderer(data: data, onAction: onAction)
            
        case .progressBar(let data):
            ProgressBarRenderer(data: data)
        }
    }

    // MARK: - Helper Functions
    private func mapVStackAlignment(_ alignment: String) -> HorizontalAlignment {
        switch alignment.lowercased() {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func mapHStackAlignment(_ alignment: String) -> VerticalAlignment {
        switch alignment.lowercased() {
        case "top": return .top
        case "bottom": return .bottom
        default: return .center
        }
    }

    private func mapFont(_ style: String) -> Font {
        switch style.lowercased() {
        case "title": return .title
        case "headline": return .headline
        case "caption": return .caption
        case "code": return .system(.body, design: .monospaced)
        default: return .body
        }
    }

    private func mapTextAlignment(_ alignment: String) -> TextAlignment {
        switch alignment.lowercased() {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func mapFrameAlignment(_ alignment: String) -> Alignment {
        switch alignment.lowercased() {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func parseColor(_ colorString: String?) -> Color? {
        guard let colorString = colorString else { return nil }

        // Handle hex colors
        if colorString.hasPrefix("#") {
            return Color(hex: colorString)
        }

        // Handle named colors
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "primary": return .primary
        case "secondary": return .secondary
        default: return Color(hex: colorString)
        }
    }

    private func parseAspectRatio(_ ratioString: String?) -> CGFloat? {
        guard let ratioString = ratioString else { return nil }
        let components = ratioString.split(separator: ":")
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]),
              height > 0 else { return nil }
        return CGFloat(width / height)
    }

    private func buttonBackground(for variant: String, disabled: Bool) -> Color {
        if disabled {
            return Color.gray.opacity(0.3)
        }

        switch variant.lowercased() {
        case "primary": return .blue
        case "secondary": return .gray
        case "destructive": return .red
        case "ghost": return .clear
        default: return .gray
        }
    }

    private func buttonForeground(for variant: String, disabled: Bool) -> Color {
        if disabled {
            return .gray
        }

        switch variant.lowercased() {
        case "primary": return .white
        case "secondary": return .white
        case "destructive": return .white
        case "ghost": return .blue
        default: return .white
        }
    }
}

// MARK: - Legacy Component Renderers
struct LegacyQuizRenderer: View {
    let data: A2UIQuizPayload
    let onAction: ((String) -> Void)?

    @State private var selectedAnswer: Int? = nil
    @State private var showExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question
            Text(data.question)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            // Options
            VStack(spacing: 12) {
                ForEach(Array(data.options.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        selectedAnswer = index
                        showExplanation = true
                        onAction?("quiz_answer_\(index)")
                    }) {
                        HStack {
                            Text(option)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()

                            if selectedAnswer == index {
                                Image(systemName: isCorrectAnswer(index) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isCorrectAnswer(index) ? .green : .red)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(backgroundColorForOption(index))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColorForOption(index), lineWidth: 1)
                        )
                    }
                    .disabled(selectedAnswer != nil)
                }
            }

            // Explanation
            if showExplanation, let explanation = data.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explanation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(explanation)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func isCorrectAnswer(_ index: Int) -> Bool {
        return (data.correctIndex ?? 0) == index
    }

    private func backgroundColorForOption(_ index: Int) -> Color {
        guard let selected = selectedAnswer else {
            return Color(.tertiarySystemBackground)
        }

        if selected == index {
            return isCorrectAnswer(index) ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        }

        return Color(.tertiarySystemBackground)
    }

    private func borderColorForOption(_ index: Int) -> Color {
        guard let selected = selectedAnswer else {
            return Color(.separator)
        }

        if selected == index {
            return isCorrectAnswer(index) ? .green : .red
        }

        return Color(.separator)
    }
}

struct LegacyCourseRoadmapRenderer: View {
    let data: A2UICourseRoadmapPayload
    let onAction: ((String) -> Void)?

    @State private var expandedModules: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(data.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                HStack {
                    Text("\(data.completedModules) of \(data.totalModules) modules completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Progress indicator
                    let progress = data.totalModules > 0 ? Double(data.completedModules) / Double(data.totalModules) : 0
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(progress >= 0.7 ? .green : .orange)
                }
            }

            // Progress bar
            ProgressView(value: data.totalModules > 0 ? Double(data.completedModules) / Double(data.totalModules) : 0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            Divider()

            // Modules
            VStack(spacing: 12) {
                ForEach(Array(data.modules.enumerated()), id: \.element.id) { index, module in
                    ModuleRowView(
                        module: module,
                        index: index,
                        isCompleted: index < data.completedModules,
                        isExpanded: expandedModules.contains(module.id),
                        onToggleExpansion: {
                            if expandedModules.contains(module.id) {
                                expandedModules.remove(module.id)
                            } else {
                                expandedModules.insert(module.id)
                            }
                        },
                        onAction: onAction
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ModuleRowView: View {
    let module: A2UICourseModule
    let index: Int
    let isCompleted: Bool
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Module header
            HStack {
                // Status indicator
                Circle()
                    .fill(isCompleted ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(module.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let description = module.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }

                    HStack {
                        if let lessons = module.lessons {
                            Text("\(lessons.count) lessons")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let duration = module.duration {
                            Text("• \(duration) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Expand/collapse button
                Button(action: onToggleExpansion) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let lessons = module.lessons, !lessons.isEmpty {
                        Text("Lessons")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        ForEach(lessons) { lesson in
                            HStack {
                                Text("•")
                                    .foregroundColor(.secondary)

                                Text(lesson.title)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Spacer()

                                if let duration = lesson.duration {
                                    Text(duration)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            onAction?("start_module_\(module.id)")
                        }) {
                            Text(isCompleted ? "Review" : "Start")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isCompleted ? Color.blue : Color.green)
                                .cornerRadius(6)
                        }

                        if isCompleted {
                            Button(action: {
                                onAction?("certificate_\(module.id)")
                            }) {
                                Text("Certificate")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}
// MARK: - AI Classroom Integration Renderers
struct CoursePreviewRenderer: View {
    let data: CoursePreviewPayload
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Course Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(data.subject)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(data.gradeBand)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)

                    Text("\(data.estimatedMinutes) min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Course Description
            Text(data.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)

            // Course Stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.caption)
                    Text("\(data.totalNodes) lessons")
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(data.estimatedMinutes) minutes")
                        .font(.caption)
                }

                Spacer()
            }
            .foregroundColor(.secondary)

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { onAction?(data.previewActionId) }) {
                    Text("Preview")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: { onAction?(data.startActionId) }) {
                    Text("Start Course")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct LearningNodeRenderer: View {
    let data: LearningNodePayload
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Node Status Indicator
                Circle()
                    .fill(data.isCompleted ? Color.green : (data.isCurrent ? Color.blue : Color.gray.opacity(0.3)))
                    .frame(width: 12, height: 12)

                Text(data.title)
                    .font(.headline)
                    .fontWeight(data.isCurrent ? .semibold : .medium)
                    .foregroundColor(data.isCurrent ? .primary : .secondary)

                Spacer()

                if let estimatedMinutes = data.estimatedMinutes {
                    Text("\(estimatedMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(data.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(data.isCurrent ? nil : 2)

            HStack {
                Text(data.nodeType.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(nodeTypeColor(data.nodeType).opacity(0.1))
                    .foregroundColor(nodeTypeColor(data.nodeType))
                    .cornerRadius(6)

                Spacer()

                if data.isCurrent {
                    Button(action: { onAction?(data.continueActionId) }) {
                        Text("Continue")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(data.isCurrent ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(data.isCurrent ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func nodeTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "narrative": return .purple
        case "interaction": return .blue
        case "quiz": return .orange
        case "summary": return .green
        default: return .gray
        }
    }
}

struct ProgressTrackerRenderer: View {
    let data: ProgressTrackerPayload
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.courseTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(Int(data.completedPercentage))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * (data.completedPercentage / 100.0), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }

            // Current Status
            VStack(alignment: .leading, spacing: 8) {
                if let currentNodeTitle = data.currentNodeTitle {
                    HStack {
                        Text("Current:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(currentNodeTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                if let nextNodeTitle = data.nextNodeTitle {
                    HStack {
                        Text("Next:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(nextNodeTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                Text("\(data.currentNode) of \(data.totalNodes) lessons completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Continue Button
            Button(action: { onAction?(data.continueActionId) }) {
                Text("Continue Learning")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct InteractiveLessonRenderer: View {
    let data: InteractiveLessonPayload
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Lesson Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(data.lessonType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(lessonTypeColor(data.lessonType).opacity(0.1))
                        .foregroundColor(lessonTypeColor(data.lessonType))
                        .cornerRadius(6)
                }

                Spacer()

                if let durationSeconds = data.durationSeconds {
                    VStack {
                        Image(systemName: "play.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("\(durationSeconds / 60):\(String(format: "%02d", durationSeconds % 60))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Lesson Content
            Text(data.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)

            // Media Preview (if available)
            if let mediaUrl = data.mediaUrl {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        VStack {
                            Image(systemName: mediaIconName(data.lessonType))
                                .font(.title)
                                .foregroundColor(.gray)
                            Text("Media Content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }

            // Action Buttons
            HStack(spacing: 12) {
                if data.hasQuiz {
                    Button(action: { onAction?(data.quizActionId) }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Take Quiz")
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                Button(action: { onAction?(data.continueActionId) }) {
                    Text(data.hasQuiz ? "Continue" : "Complete Lesson")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func lessonTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "video": return .red
        case "audio": return .purple
        case "interactive": return .blue
        case "text": return .green
        default: return .gray
        }
    }

    private func mediaIconName(_ type: String) -> String {
        switch type.lowercased() {
        case "video": return "play.rectangle"
        case "audio": return "waveform"
        case "interactive": return "hand.tap"
        default: return "doc.text"
        }
    }
}

// MARK: - Standard A2UI Renderers

struct LessonCardRenderer: View {
    let data: LessonCardPayload
    let onAction: ((String) -> Void)?
    
    var body: some View {
        Button(action: { onAction?(data.action) }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: iconForType(data.type))
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(data.completed ? Color.green : Color.blue)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(data.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(data.duration)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if data.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "video": return "play.rectangle.fill"
        case "reading": return "book.fill"
        case "quiz": return "questionmark.circle.fill"
        default: return "doc.text.fill"
        }
    }
}

struct A2UICourseCardRenderer: View {
    let data: A2UICourseCardPayload
    let onAction: ((String) -> Void)?
    
    var body: some View {
        Button(action: { onAction?(data.action) }) {
            VStack(alignment: .leading, spacing: 12) {
                // Image or Placeholder
                if let imageUrl = data.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(height: 140)
                             .clipped()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 140)
                    }
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(data.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Stats row
                    HStack {
                        Label(data.difficulty, systemImage: "chart.bar")
                        Spacer()
                        Label(data.duration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Progress
                    if data.progress > 0 {
                        VStack(spacing: 4) {
                            ProgressView(value: data.progress, total: 100)
                            Text("\(Int(data.progress))% Complete")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ProgressBarRenderer: View {
    let data: ProgressBarPayload
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(parseColor(data.color) ?? Color.blue)
                        .frame(width: geometry.size.width * (CGFloat(data.progress) / 100.0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private func parseColor(_ colorString: String?) -> Color? {
        guard let colorString = colorString else { return nil }
        // Simple hex parser reuse or just return basic color
        if colorString.hasPrefix("#") { return Color(hex: colorString) }
        return .blue
    }
}//
