import SwiftUI
import os

// MARK: - Lio Chat Sheet
/// The unified AI chat interface presented when tapping the Lio orb
struct LioChatSheet: View {
    @EnvironmentObject var uiState: AppUIState
    @EnvironmentObject var viewModel: LyoAIViewModel
    @Binding var isPresented: Bool
    
    @State private var errorMessage: String?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showMasteryProfile = false
    @State private var isArtifactExpanded: Bool = true
    /// Tracks the ID of the artifact the user explicitly dismissed, so Combine re-firing
    /// the same component doesn't immediately re-show the pane.
    @State private var dismissedArtifactId: String? = nil
    
    // Current mode for display
    private var currentModeName: String {
        // This could be enhanced to reflect actual mode state
        // For now, using the tab context
        switch uiState.currentTab {
        case .focus: return "Study"
        case .discover: return "Explore"
        case .campus: return "Chat"
        default: return "Study"
        }
    }
    
    // Voice Animation State
    @State private var waveformPhase: CGFloat = 0
    
    // AI Command Handler for course creation navigation
    @StateObject private var commandHandler = AICommandHandler.shared
    @State private var showingClassroom = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // FORCE BLACK BACKGROUND
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    headerView

                    // ── Artifact Pane (pinned, collapsible) ─────────────────────
                    if let artifact = viewModel.activeArtifact, artifact.id != dismissedArtifactId {
                        artifactPane(component: artifact)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isArtifactExpanded)
                            // Reset dismiss state whenever a brand-new artifact arrives
                            .onChange(of: artifact.id) { _, newId in
                                if newId != dismissedArtifactId {
                                    dismissedArtifactId = nil
                                    isArtifactExpanded = true
                                }
                            }
                    }

                    // Messages area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                if viewModel.messages.isEmpty {
                                    emptyStateView
                                } else {
                                    ForEach(viewModel.messages) { msg in
                                        LyoMessageBubbleView(
                                            message: msg,
                                            onActionTap: { action in
                                                viewModel.executeAction(action)
                                            },
                                            onQuickChipTap: { chip in
                                                viewModel.inputText = chip
                                                Task { await viewModel.sendMessage() }
                                            },
                                            onAudioToggle: { messageId, text in
                                                viewModel.toggleMessageAudio(messageId: messageId, text: text)
                                            },
                                            isPlayingAudio: viewModel.currentlyPlayingMessageId == msg.id,
                                            audioProgress: viewModel.currentlyPlayingMessageId == msg.id ? viewModel.playbackProgress : 0,
                                            onA2UICourseStart: { course in
                                                viewModel.onA2UICourseStart(course: course)
                                            },
                                            onA2UIQuizAnswer: { question, answerIndex in
                                                viewModel.onA2UIQuizAnswer(question: question, answerIndex: answerIndex)
                                            }
                                        )
                                        .id(msg.id)
                                    }
                                }
                                
                                // Typing indicator when sending
                                if viewModel.isLoading {
                                    LyoUnifiedThinkingIndicator()
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 100) // Space for input bar
                        }
                        .onAppear { scrollProxy = proxy }
                        .onChange(of: viewModel.messages.count) {
                            scrollToBottom(using: proxy)
                        }
                    }
                }
                
                // Floating Input Bar
                VStack {
                    Spacer()
                    
                    if !viewModel.isVoiceActive {
                        nextActionView
                    }
                    
                    if viewModel.isVoiceActive {
                        voiceListeningView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        inputBar
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showMasteryProfile) {
                MasteryProfileView()
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                scrollToBottom(using: scrollProxy)
                // Pass uiState reference to viewModel
                viewModel.uiState = uiState
                
                // Check if we need to load a specific history session
                if #available(iOS 17.0, *), let sessionToLoad = uiState.chatSessionToLoad as? ChatSession {
                    Log.ai.info("Loading chat history: \(sessionToLoad.title)")
                    viewModel.loadHistory(from: sessionToLoad)
                    // Clear state so it doesn't reload on next appear if not intended
                    uiState.chatSessionToLoad = nil
                } else {
                    // New session: Fetch proactive greeting and next action
                    Task {
                        await viewModel.fetchProactiveGreeting()
                        await viewModel.fetchNextAction()
                    }
                }
            }
            .sheet(isPresented: $uiState.showCourseDetail) {
                if let course = uiState.courseToDisplay {
                    CourseDetailSheet(course: course, isPresented: $uiState.showCourseDetail)
                }
            }
            // A2A Multi-Agent Generation Progress View
            .fullScreenCover(isPresented: $viewModel.showA2AProgressView) {
                A2AGenerationProgressView(
                    topic: viewModel.a2aGenerationTopic,
                    qualityTier: viewModel.a2aGenerationTier,
                    onComplete: { course in
                        viewModel.handleA2AGenerationComplete(course: course)
                    },
                    onCancel: {
                        viewModel.handleA2AGenerationCancelled()
                    }
                )
            }
            // AI Command Handler - Classroom Navigation
            .onChange(of: commandHandler.shouldOpenClassroom) { _, shouldOpen in
                if shouldOpen {
                    // Reset command handler state after notification is sent
                    // MainTabView will handle the actual navigation via .openClassroom notification
                    isPresented = false 
                    commandHandler.clearPendingNavigation()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            modeIndicator
            
            Spacer()
            
            // Mastery Profile Button
            Button {
                showMasteryProfile = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.trailing, 4)
            
            if !viewModel.messages.isEmpty {
                Button {
                    viewModel.messages.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
            } else {
                // Placeholder to balance layout
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Material.thinMaterial)
    }

    // MARK: - Artifact Pane

    /// Pinned "Claw"-style artifact pane — shows the active A2UI component above the chat stream.
    /// The user can collapse it to a compact handle or dismiss it entirely.
    @ViewBuilder
    private func artifactPane(component: A2UIComponent) -> some View {
        VStack(spacing: 0) {
            // Drag handle / collapse row
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.blue)
                Text("Artifact")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isArtifactExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isArtifactExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                // Dismiss / clear artifact for this session
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismissedArtifactId = component.id
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(white: 0.1))

            // Expanded content area
            if isArtifactExpanded {
                ScrollView {
                    A2UIRenderer(
                        component: component,
                        onAction: { action, _ in
                            Log.ai.info("🎨 Artifact action tapped: \(action.type.rawValue)")
                            // Route A2UI actions back into the chat input so the AI can respond
                            let messageText: String? = {
                                if let payload = action.payload {
                                    if let text = payload["message"]?.value as? String { return text }
                                    if let text = payload["label"]?.value as? String { return text }
                                    if let text = payload["query"]?.value as? String { return text }
                                }
                                return nil
                            }()
                            switch action.type {
                            case .sendMessage, .askAI, .requestHint, .requestExplanation:
                                if let text = messageText, !text.isEmpty {
                                    viewModel.inputText = text
                                    Task { await viewModel.sendMessage() }
                                }
                            case .startStudy, .navigate:
                                // If payload contains a text label, send as a follow-up message
                                if let text = messageText, !text.isEmpty {
                                    viewModel.inputText = text
                                    Task { await viewModel.sendMessage() }
                                } else if let courseId = action.payload?["course_id"]?.value as? String {
                                    // Navigate to an existing course by notifying the global state
                                    Log.ai.info("🎨 Artifact: navigate to course \(courseId)")
                                    NotificationCenter.default.post(
                                        name: .init("OpenClassroomById"),
                                        object: nil,
                                        userInfo: ["courseId": courseId]
                                    )
                                }
                            default:
                                if let text = messageText {
                                    viewModel.inputText = text
                                    Task { await viewModel.sendMessage() }
                                }
                            }
                        }
                    )
                    .padding(12)
                }
                .frame(maxHeight: 280)
                .background(Color(white: 0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider().background(Color.white.opacity(0.12))
        }
    }

    private var modeIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(contextColors.first ?? .blue)
                .frame(width: 8, height: 8)
            
            Text(uiState.currentTab.aiModeLabel)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.05))
        )
    }
    
    private var contextColors: [Color] {
        switch uiState.currentTab {
        case .focus:
            return [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary]
        case .discover:
            return [Color(hex: "F472B6"), Color(hex: "DB2777")] // Pink
        case .collab:
            return [Color(hex: "818CF8"), Color(hex: "4F46E5")] // Indigo
        case .campus:
            return [Color(hex: "34D399"), Color(hex: "059669")] // Green
        case .profile:
            return [Color(hex: "A78BFA"), Color(hex: "7C3AED")] // Purple
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 20)

            VStack(spacing: 8) {
                Text("How can I help?")
                    .font(.title3.weight(.semibold))
                Text("Ask a question or try a suggestion below.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !viewModel.suggestions.isEmpty {
                SuggestionChipsView(suggestions: viewModel.suggestions) { chip in
                    viewModel.executeSuggestion(chip)
                }
            }

            Spacer()
        }
        .padding(.top, 10)
    }
    
    private var nextActionView: some View {
        Group {
            if let action = viewModel.nextAction {
                Button {
                    viewModel.handleNextAction()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT SUGGESTION")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.yellow)
                            Text(action.contentString)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Material.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var activeSuggestions: [String] {
        if !viewModel.suggestions.isEmpty {
            return viewModel.suggestions.map { $0.text }
        }
        switch uiState.currentTab {
        case .focus:
            return [
                "Help me understand this topic",
                "Quiz me on what I learned",
                "Explain this in simpler terms"
            ]
        case .discover:
            return [
                "What should I learn next?",
                "Find courses about AI",
                "Recommend something new"
            ]
        case .collab:
            return [
                "Help us brainstorm ideas",
                "Summarize our discussion",
                "What should we work on next?"
            ]
        case .campus:
            return [
                "What events are happening?",
                "Find study groups near me",
                "Where can I find help?"
            ]
        case .profile:
            return [
                "How can I improve?",
                "What should I focus on?",
                "Show my progress"
            ]
        }
    }
    
    // MARK: - Multimodal Input Bar
    
    @State private var showMediaPicker = false
    @State private var mediaPickerSource: MediaPickerSource = .photoLibrary
    @State private var selectedImage: UIImage? = nil
    
    enum MediaPickerSource {
        case photoLibrary, camera, files
    }
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Attachment Preview
            if !viewModel.attachments.isEmpty {
                attachmentPreviewBar
            }
            
            // Voice Recording Overlay
            if viewModel.isRecordingVoice {
                voiceRecordingBar
            } else {
                standardInputBar
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 20)
        // Solid Black Background with Gradient Trim (Island Style)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.black)
                
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "8B5CF6").opacity(0.6), Color(hex: "3B82F6").opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .padding(.horizontal, 12) // Outer padding to make it look like an island
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        .sheet(isPresented: $showMediaPicker) {
            mediaPickerSheet
        }
    }
    
    private var attachmentPreviewBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.attachments) { attachment in
                    AttachmentPreviewChip(
                        attachment: attachment,
                        onRemove: { viewModel.removeAttachment(attachment) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    private var standardInputBar: some View {
        VStack(spacing: 12) {
            // Row 1: Text Input Area (Full Width)
            HStack {
                TextField("Ask anything...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .background(Color(white: 0.08))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                    .accentColor(DesignTokens.Colors.accent)
                    .lineLimit(1...6)
            }
            
            // Row 2: Bottom Toolbar Island
            HStack(spacing: 12) {
                // Left: Single "+" Menu button
                Menu {
                    Button(action: { openPhotoPicker() }) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                    Button(action: { openCamera() }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                    Button(action: { openFilePicker() }) {
                        Label("Choose File", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(white: 0.15))
                        .clipShape(Circle())
                }
                
                // Middle: Mode Selector
                Menu {
                    Button(action: { /* Switch to Study mode */ }) {
                        Label("Study", systemImage: "book.fill")
                    }
                    Button(action: { /* Switch to Quiz mode */ }) {
                        Label("Quiz", systemImage: "questionmark.circle")
                    }
                    Button(action: { /* Switch to Chat mode */ }) {
                        Label("Chat", systemImage: "message")
                    }
                    Button(action: { /* Switch to Course mode */ }) {
                        Label("Course", systemImage: "graduationcap")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentModeName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(white: 0.15))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Right: Mic / Live / Send
                HStack(spacing: 12) {
                    // Live Mode Button
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        // Handle Live Mode
                    }) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(Color(white: 0.15))
                            .clipShape(Circle())
                    }
                    
                    if viewModel.inputText.isEmpty && viewModel.attachments.isEmpty {
                        // Mic (TTS) Button
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            viewModel.toggleVoiceMode()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        // Send Button
                        Button(action: {
                            HapticManager.shared.playSuccess()
                            Task { await viewModel.sendMessage() }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(DesignTokens.Colors.accent)
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var voiceRecordingBar: some View {
        HStack(spacing: 16) {
            // Cancel Button
            Button(action: {
                viewModel.cancelVoiceRecording()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red.opacity(0.8))
            }
            
            // Waveform Visualization
            VoiceWaveformView(level: viewModel.voiceInputLevel)
                .frame(height: 40)
            
            // Recording Indicator
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(0.8)
                .modifier(PulseAnimation())
            
            // Stop/Send Button
            Button(action: {
                viewModel.stopVoiceRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
    }
    
    @ViewBuilder
    private var mediaPickerSheet: some View {
        switch mediaPickerSource {
        case .photoLibrary:
            ImagePickerView(selectedImage: $selectedImage, isPresented: $showMediaPicker)
                .onChange(of: selectedImage) { _, newImage in
                    if let image = newImage,
                       let data = image.jpegData(compressionQuality: 0.8) {
                        let media = PickedMedia(
                            type: .image,
                            data: data,
                            filename: "photo_library_image.jpg",
                            mimeType: "image/jpeg",
                            thumbnail: image,
                            originalURL: nil
                        )
                        viewModel.handlePickedMedia(media)
                        selectedImage = nil // Reset for next use
                    }
                }
        case .camera:
            CameraPickerView { media in
                if let media = media {
                    viewModel.handlePickedMedia(media)
                }
                showMediaPicker = false
            }
        case .files:
            DocumentPickerView { url in
                if let url = url {
                    // Convert URL to PickedMedia
                    let filename = url.lastPathComponent
                    let pathExtension = url.pathExtension.lowercased()
                    let mimeType: String
                    switch pathExtension {
                    case "pdf": mimeType = "application/pdf"
                    case "txt": mimeType = "text/plain"
                    case "doc", "docx": mimeType = "application/msword"
                    case "xls", "xlsx": mimeType = "application/vnd.ms-excel"
                    case "ppt", "pptx": mimeType = "application/vnd.ms-powerpoint"
                    case "jpg", "jpeg": mimeType = "image/jpeg"
                    case "png": mimeType = "image/png"
                    default: mimeType = "application/octet-stream"
                    }
                    
                    if let data = try? Data(contentsOf: url) {
                        let media = PickedMedia(
                            type: .document,
                            data: data,
                            filename: filename,
                            mimeType: mimeType,
                            thumbnail: nil,
                            originalURL: url
                        )
                        viewModel.handlePickedMedia(media)
                    }
                }
                showMediaPicker = false
            }
        }
    }
    
    private func openPhotoPicker() {
        mediaPickerSource = .photoLibrary
        showMediaPicker = true
    }
    
    private func openCamera() {
        mediaPickerSource = .camera
        showMediaPicker = true
    }
    
    private func openFilePicker() {
        mediaPickerSource = .files
        showMediaPicker = true
    }
    
    
    // MARK: - Actions
    
    private func send() {
        let trimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !viewModel.attachments.isEmpty else { return }
        HapticManager.shared.playLightImpact()
        
        if viewModel.attachments.isEmpty {
            viewModel.inputText = trimmed
            Task { await viewModel.sendMessage() }
        } else {
            Task { await viewModel.sendMessageWithAttachments(text: trimmed, attachments: viewModel.attachments) }
        }
    }

    // MARK: - Voice UI
    
    private var voiceListeningView: some View {
        VStack(spacing: 24) {
            Text("Listening...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Simulated Waveform
            HStack(spacing: 4) {
                ForEach(0..<10) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: contextColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 20 + CGFloat.random(in: 0...30))
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.1),
                            value: waveformPhase
                        )
                }
            }
            .frame(height: 60)
            .onAppear {
                waveformPhase = 1.0
            }
            
            Button(action: {
                viewModel.stopListening()
            }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.red)
                    .background(Color.white.clipShape(Circle()))
                    .shadow(radius: 4)
            }
        }
        .padding(32)
        .background(Material.regularMaterial)
        .cornerRadius(32)
        .padding(.bottom, 32)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    private func scrollToBottom(using proxy: ScrollViewProxy?) {
        guard let proxy else { return }
        guard let lastId = viewModel.messages.last?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(viewModel.isLoading ? "typing" : lastId, anchor: .bottom)
            }
        }
    }
}

// MARK: - Helper Extension for Rounded Corners
// RoundedCorner is now in Sources/Utils/ShapeExtensions.swift

// MARK: - Typing Indicator


// MARK: - Preview

#Preview {
    LioChatSheet(isPresented: .constant(true))
        .environmentObject(AppUIState())
}
