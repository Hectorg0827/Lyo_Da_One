import SwiftUI

// MARK: - Lio Chat Sheet
/// The unified AI chat interface presented when tapping the Lio orb
struct LioChatSheet: View {
    @EnvironmentObject var uiState: AppUIState
    @EnvironmentObject var viewModel: LyoAIViewModel
    @Binding var isPresented: Bool
    
    @State private var errorMessage: String?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showMasteryProfile = false
    
    // Voice Animation State
    @State private var waveformPhase: CGFloat = 0
    
    // AI Command Handler for course creation navigation
    @StateObject private var commandHandler = AICommandHandler.shared
    @State private var showingClassroom = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Content-Aware Background
                AnimatedGradient(colors: contextColors)
                    .ignoresSafeArea()
                    .opacity(0.15)
                
                VStack(spacing: 0) {
                    // Custom Header
                    headerView
                    
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
                                            onCourseStart: { course in
                                                viewModel.inputText = "Start course: \(course.title)"
                                                Task { await viewModel.sendMessage() }
                                            },
                                            onAudioToggle: { messageId, text in
                                                viewModel.toggleMessageAudio(messageId: messageId, text: text)
                                            },
                                            isPlayingAudio: viewModel.currentlyPlayingMessageId == msg.id,
                                            audioProgress: viewModel.currentlyPlayingMessageId == msg.id ? viewModel.playbackProgress : 0
                                        )
                                        .id(msg.id)
                                    }
                                }
                                
                                // Typing indicator when sending
                                if viewModel.isLoading {
                                    LioChatTypingIndicator()
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
                    print("Loading chat history: \(sessionToLoad.title)")
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
                    showingClassroom = true
                    commandHandler.clearPendingNavigation()
                }
            }
            .fullScreenCover(isPresented: $showingClassroom) {
                if let course = commandHandler.pendingClassroomCourse {
                    // Generate course and open classroom
                    CourseGenerationIntermediateView(
                        topic: course.topic,
                        title: course.title,
                        level: course.level,
                        objectives: course.objectives,
                        onComplete: {
                            showingClassroom = false
                        }
                    )
                } else {
                    // Fallback if no course data
                    Text("Opening Classroom...")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                showingClassroom = false
                            }
                        }
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
            
            // Animated orb
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: contextColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 10)
                    .opacity(0.5)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: contextColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: contextColors.first!.opacity(0.3), radius: 10)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Hi! I'm Lio")
                    .font(.title2.bold())
                
                Text("Your AI learning companion. Ask me anything about \(uiState.currentTab.displayName.lowercased())!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Suggestion chips
            suggestionChips
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(activeSuggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.inputText = suggestion
                        send()
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Material.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
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
                            Text("NEXR SUGGESTION")
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
        .background(Material.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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
        HStack(alignment: .bottom, spacing: 12) {
            // Media Menu Button
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
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            
            // Text Input
            TextField("Ask Lio anything…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.black.opacity(0.05))
                .cornerRadius(20)
                .lineLimit(1...5)
            
            // Voice / Send Button
            if viewModel.inputText.isEmpty && viewModel.attachments.isEmpty {
                // Mic Button with Long Press
                Button(action: {
                    HapticManager.shared.playMediumImpact()
                    viewModel.toggleVoiceMode()
                }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .onEnded { _ in
                            HapticManager.shared.playRecordingStarted()
                            viewModel.startVoiceRecording()
                        }
                )
            } else {
                // Send Button
                Button(action: send) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: contextColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding(12)
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

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: LioChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.isUser ? "You" : "Lio")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(
                        message.isUser ?
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) :
                        AnyShapeStyle(Material.thinMaterial)
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16, corners: message.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                
                // Source indicator for AI messages
                if !message.isUser, let source = message.source, source != "system" {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(source == "ai" ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(source == "ai" ? "AI" : "Local")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isUser ? .trailing : .leading)
            
            if message.isUser {
                Spacer(minLength: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

// MARK: - Helper Extension for Rounded Corners
// RoundedCorner is now in Sources/Utils/ShapeExtensions.swift

// MARK: - Typing Indicator

struct LioChatTypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: animationOffset(for: index))
                }
            }
            .padding(12)
            .background(Material.thinMaterial)
            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationOffset = -6
            }
        }
    }
    
    private func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.15
        return animationOffset * (1.0 - delay)
    }
}

// MARK: - Preview

#Preview {
    LioChatSheet(isPresented: .constant(true))
        .environmentObject(AppUIState())
}
