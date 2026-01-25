import SwiftUI
import UIKit

struct LyoOverlayView: View {
    @Binding var isPresented: Bool
    var startFrame: CGRect // The frame of the tab bar button
    
    @EnvironmentObject var viewModel: LyoAIViewModel
    @EnvironmentObject var rootViewModel: RootViewModel
    @ObservedObject var conversationManager = ConversationManager.shared
    
    @State private var animationState: AnimationState = .initial
    @State private var isThinking = false
    @State private var showGreeting = false
    @State private var showHistory = false
    @State private var selectedMode: ChatMode = .chat
    @State private var greetingMessageIndex = Int.random(in: 0..<6)
    @State private var avatarFloatOffset: CGFloat = 0
    @State private var thinkingRotation: Double = 0
    
    // Rotating motivational messages
    private let motivationalMessages = [
        "What would you like to learn today?",
        "Ready to embark on a learning journey?",
        "What's on your mind?",
        "Let's explore something new together!",
        "What skill shall we master today?",
        "I'm here to help you grow!"
    ]
    
    // User's first name
    private var userFirstName: String {
        if let name = rootViewModel.currentUser?.name {
            return name.components(separatedBy: " ").first ?? name
        }
        return "there"
    }
    
    enum AnimationState {
        case initial // At tab bar position
        case active // Center screen
        case chatting // Small in chat
    }
    
    // ChatMessage struct removed, using LyoMessage from ViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred Background & Ambient Effects
                if animationState != .initial {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                        
                        // Ambient "Alive" Particles
                        ForEach(0..<5) { i in
                            Circle()
                                .fill(Color(hex: "FF8C00").opacity(0.1))
                                .frame(width: CGFloat.random(in: 50...150), height: CGFloat.random(in: 50...150))
                                .position(
                                    x: CGFloat.random(in: 0...geometry.size.width),
                                    y: CGFloat.random(in: 0...geometry.size.height)
                                )
                                .blur(radius: 30)
                                .animation(
                                    Animation.easeInOut(duration: Double.random(in: 5...10))
                                        .repeatForever(autoreverses: true),
                                    value: animationState
                                )
                        }
                    }
                    .transition(.opacity)
                    .onTapGesture {
                        if animationState == .active {
                            close()
                        }
                    }
                }
                
                // Main Content Stack (Chat/Suggestions + Input)
                VStack(spacing: 0) {
                    if animationState == .chatting {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 16) {
                                    ForEach(viewModel.messages) { message in
                                        HStack(alignment: .top, spacing: 0) {
                                            // Add left padding for AI messages to make room for the small avatar
                                            if !message.isFromUser {
                                                Spacer().frame(width: 50)
                                            }
                                            
                                            // Convert LyoMessage to MultimodalMessage for A2UI widgets
                                            EnhancedMessageBubble(
                                                message: MultimodalMessage(from: message),
                                                onTTSToggle: nil,
                                                onQuizAnswer: nil,
                                                onCourseOpen: { id in
                                                    viewModel.openCourse(id: id)
                                                },
                                                onTopicSelect: nil,
                                                onModuleSelect: nil,
                                                onSuggestionSelect: { suggestion in
                                                    viewModel.inputText = suggestion
                                                    submitText()
                                                }
                                            )
                                        }
                                        .id(message.id)
                                    }
                                    
                                    // Thinking indicator bubble
                                    if isThinking {
                                        HStack(alignment: .top, spacing: 0) {
                                            Spacer().frame(width: 50)
                                            ThinkingBubble()
                                        }
                                        .id("thinking")
                                    }
                                }
                                .padding(.top, 60) // Space for header/back button
                                .padding(.bottom, 20) // Minimal space before input
                            }
                            .onChange(of: viewModel.messages.count) { _, _ in
                                if let lastId = viewModel.messages.last?.id {
                                    withAnimation {
                                        proxy.scrollTo(lastId, anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: isThinking) { _, thinking in
                                if thinking {
                                    withAnimation {
                                        proxy.scrollTo("thinking", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    } else {
                        Spacer()
                        
                        // Greeting Text
                        if animationState == .active && showGreeting {
                            VStack(spacing: 16) {
                                Text("Hello, \(userFirstName)!")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, Color(hex: "FF8C00")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                
                                Text(motivationalMessages[greetingMessageIndex])
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 250)
                        }
                        
                        Spacer()
                    }
                    
                    if animationState == .active {
                        // Suggestions
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.suggestions) { chip in
                                    LyoSuggestionChip(text: chip.text) { 
                                        viewModel.inputText = chip.text
                                        submitText() 
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    if animationState != .initial {
                        // Input Bar
                        // Input Bar
                        // Input Bar (Docked Console)
                        HybridInputBar(
                            text: $viewModel.inputText,
                            isListening: Binding(
                                get: { viewModel.isVoiceActive },
                                set: { active in
                                    if active { viewModel.startListening() } else { viewModel.stopListening() }
                                }
                            ),
                            selectedMode: $selectedMode,
                            isThinking: isThinking,
                            onSubmit: {
                                submitText()
                            }
                        )
                        // Removed .padding() to allow full width
                        .padding(.bottom, 0) // Dock to bottom
                        .transition(.move(edge: .bottom))
                    }
                }
                
                // Avatar - Always visible, different sizes and positions based on state
                ZStack {
                    // Large avatar glow in active state
                    if animationState == .active {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "FF8C00").opacity(0.5),
                                        Color(hex: "FF8C00").opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 140
                                )
                            )
                            .frame(width: 280, height: 280)
                            .blur(radius: 25)
                    }
                    
                    // Avatar with thinking indicator
                    ZStack {
                        LyoAvatarView(
                            size: animationState == .active ? 200 : (animationState == .chatting ? 44 : 60),
                            isListening: viewModel.isVoiceActive,
                            isThinking: isThinking && animationState == .chatting
                        ) {
                            // On Tap Avatar
                        }
                        
                        // Thinking ring around small avatar
                        if animationState == .chatting && isThinking {
                            Circle()
                                .trim(from: 0, to: 0.7)
                                .stroke(
                                    AngularGradient(
                                        colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6"), Color(hex: "EC4899"), Color(hex: "6366F1")],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 52, height: 52)
                                .rotationEffect(.degrees(thinkingRotation))
                        }
                    }
                }
                .position(
                    x: animationState == .active ? geometry.size.width / 2 : (animationState == .chatting ? 36 : startFrame.midX),
                    y: animationState == .active ? geometry.size.height / 2 - 50 + avatarFloatOffset : (animationState == .chatting ? 85 : startFrame.midY)
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animationState)
                .zIndex(animationState == .chatting ? 100 : 10)
                
                // Header Bar (Top)
                if animationState != .initial {
                    VStack {
                        HStack(spacing: 16) {
                            // History Button (Left)
                            Button(action: { showHistory = true }) {
                                Image(systemName: "list.bullet")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            // New Chat Button
                            Button(action: createNewChat) {
                                Image(systemName: "square.and.pencil")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            // Close Button (Right)
                            Button(action: close) {
                                Image(systemName: "xmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            // Randomize greeting message on each visit
            greetingMessageIndex = Int.random(in: 0..<motivationalMessages.count)
            
            // Trigger the "Jump"
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationState = .active
            }
            
            // Show greeting after avatar animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showGreeting = true
                }
            }
            
            // Start floating animation for avatar
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                avatarFloatOffset = 10
            }
            
            // Start thinking ring rotation
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                thinkingRotation = 360
            }
        }
        .sheet(isPresented: $showHistory) {
            ChatHistoryView(
                onSelectConversation: { conversation in
                    // Load the selected conversation
                    loadConversation(conversation)
                },
                onNewChat: {
                    createNewChat()
                }
            )
        }
    }
    
    private var greetingText: String {
        return "Hello, \(userFirstName)!"
    }
    
    private func close() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .initial
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
        }
    }
    
    private func createNewChat() {
        _ = conversationManager.createNewConversation()
        viewModel.messages.removeAll()
        // Add personalized welcome message
        let welcomeMessage = "Hello, \(userFirstName)! I'm Lyo, your AI learning assistant. \(motivationalMessages.randomElement() ?? "What would you like to learn today?")"
        viewModel.messages.append(LyoMessage(
            id: UUID().uuidString,
            content: welcomeMessage,
            isFromUser: false,
            timestamp: Date()
        ))
        HapticManager.shared.playSuccess()
    }
    
    private func loadConversation(_ conversation: SavedConversation) {
        // Clear current messages and load from saved conversation
        viewModel.messages.removeAll()
        for message in conversation.messages {
            viewModel.messages.append(LyoMessage(
                id: UUID().uuidString,
                content: message.content,
                isFromUser: message.role == .user,
                timestamp: message.timestamp
            ))
        }
        conversationManager.loadConversation(conversation)
    }
    
    private func submitText() {
        guard !viewModel.inputText.isEmpty else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Trigger thinking animation and transition to chatting state
        withAnimation {
            isThinking = true
            showGreeting = false
            // Transition to chatting state immediately when sending
            if animationState == .active {
                animationState = .chatting
            }
        }
        
        Task {
            await viewModel.sendMessage(mode: selectedMode.rawValue)
            
            await MainActor.run {
                withAnimation {
                    isThinking = false
                }
                
                // Haptic: Response Received
                let responseGenerator = UINotificationFeedbackGenerator()
                responseGenerator.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Chat Mode Enum
enum ChatMode: String, CaseIterable {
    case chat = "Chat"
    case study = "Study"
    case course = "Course"
    case quiz = "Quiz"
    case tutor = "Tutor"
    
    var icon: String {
        switch self {
        case .chat: return "bubble.left.fill"
        case .study: return "book.fill"
        case .course: return "graduationcap.fill"
        case .quiz: return "checkmark.circle.fill"
        case .tutor: return "person.fill.questionmark"
        }
    }
}

// MARK: - Thinking Bubble
struct ThinkingBubble: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale[index])
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(hex: "1e293b"))
        .cornerRadius(20)
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                Animation.easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
            ) {
                dotScale[i] = 1.4
            }
        }
    }
}

struct LyoSuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}


struct HybridInputBar: View {
    @Binding var text: String
    @Binding var isListening: Bool
    @Binding var selectedMode: ChatMode
    var isThinking: Bool // Passed from parent
    var onSubmit: () -> Void
    
    @EnvironmentObject var viewModel: LyoAIViewModel
    @StateObject var audioService = AudioPlaybackService.shared
    
    @State private var showModeSelector = false
    @State private var gradientRotation = 0.0
    
    var isSpeaking: Bool { audioService.isPlaying }
    
    // Gradient colors for animations
    private let thinkingColors = [Color(hex: "6366F1"), Color(hex: "8B5CF6"), Color(hex: "EC4899")]
    private let respondingColors = [Color(hex: "10B981"), Color(hex: "34D399"), Color(hex: "6EE7B7")]
    private let idleColors = [Color.white.opacity(0.2), Color.white.opacity(0.1)]
    
    var body: some View {
        ZStack {
            // Island Container
            VStack(spacing: 0) {
                // Top Line: Text Input
                TextField("Message Lyo...", text: $text, axis: .vertical)
                    .lineLimit(1...3) // Dynamic height, max 3 lines
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .submitLabel(.send)
                    .onSubmit {
                        submitAction()
                    }
                
                // Bottom Line: Selectors & Actions
                HStack(spacing: 12) {
                    // LEFT: Add & Mode
                    HStack(spacing: 8) {
                        // Add Button
                        Button(action: { /* Show attachments */ }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        // Mode Button
                        Button(action: { showModeSelector = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: selectedMode.icon)
                                    .font(.system(size: 12))
                                Text(selectedMode.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    // RIGHT: Mic, Live, Send
                    HStack(spacing: 8) {
                        if !text.isEmpty {
                            // Send Button
                            Button(action: submitAction) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Mic (TTS)
                            Button(action: { isListening.toggle() }) {
                                Image(systemName: isListening ? "waveform" : "mic")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(width: 32, height: 32)
                            }
                            
                            // Live Mode
                            Button(action: { /* Trigger Live Mode */ }) {
                                Image(systemName: "video")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color.black) // Island Background
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        AngularGradient(
                            colors: isThinking ? thinkingColors : (isSpeaking ? respondingColors : idleColors),
                            center: .center,
                            angle: .degrees(gradientRotation)
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: isThinking ? thinkingColors[0].opacity(0.4) : Color.black.opacity(0.3), radius: isThinking ? 15 : 10)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10) // Lift slightly
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
        .confirmationDialog("Select Mode", isPresented: $showModeSelector) {
            ForEach(ChatMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        }
    }
    
    private func submitAction() {
        // Close keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        onSubmit()
    }
}



// Helper Shape (since iOS 16 doesn't fully expose UnevenRoundedRectangle in all contexts without check)
struct CustomRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Attachment Picker Sheet

struct AttachmentPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    // Camera action
                    dismiss()
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                }
                
                Button {
                    // Photo library action
                    dismiss()
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                
                Button {
                    // Document action
                    dismiss()
                } label: {
                    Label("Document", systemImage: "doc.fill")
                }
                
                Button {
                    // Link action
                    dismiss()
                } label: {
                    Label("Paste Link", systemImage: "link")
                }
            }
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
