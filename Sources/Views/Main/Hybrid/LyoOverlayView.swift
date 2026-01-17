import SwiftUI
import UIKit

struct LyoOverlayView: View {
    @Binding var isPresented: Bool
    var startFrame: CGRect // The frame of the tab bar button
    
    @EnvironmentObject var viewModel: LyoAIViewModel
    @ObservedObject var conversationManager = ConversationManager.shared
    
    @State private var animationState: AnimationState = .initial
    @State private var isThinking = false
    @State private var showGreeting = false
    @State private var showHistory = false
    @State private var selectedMode: ChatMode = .chat
    
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
                                        .id(message.id)
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
                        }
                    } else {
                        Spacer()
                        
                        // Greeting Text
                        if animationState == .active && showGreeting {
                            VStack(spacing: 12) {
                                Text(greetingText)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity.combined(with: .scale))
                                
                                Text("I'm here to help you learn")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.8))
                                    .transition(.opacity)
                            }
                            .padding(.bottom, 40)
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
                            onSubmit: {
                                submitText()
                            }
                        )
                        // Removed .padding() to allow full width
                        .padding(.bottom, 0) // Dock to bottom
                        .transition(.move(edge: .bottom))
                    }
                }
                
                // Avatar
                // We only show this "floating" avatar in .initial and .active states.
                // In .chatting state, it "disappears" (opacity 0) UNLESS it is thinking.
                if animationState != .chatting || isThinking {
                    LyoAvatarView(
                        size: animationState == .active ? 256 : (isThinking ? 100 : 60),
                        isListening: viewModel.isVoiceActive,
                        isThinking: isThinking
                    ) {
                        // On Tap Avatar
                    }
                    .position(
                        x: animationState == .active ? geometry.size.width / 2 : (isThinking ? geometry.size.width / 2 : startFrame.midX),
                        y: animationState == .active ? geometry.size.height / 2 - 50 : (isThinking ? geometry.size.height - 180 : startFrame.midY)
                    )
                    .opacity((animationState == .chatting && !isThinking) ? 0 : 1)
                }
                
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
        // Try to get user's first name from auth service or profile
        // For now, using a friendly generic greeting
        // TODO: Wire up to AuthService to get actual user name
        return "Hello!" // Will be "Hello, [Name]!" when auth is wired
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
        // Add welcome message
        viewModel.messages.append(LyoMessage(
            id: UUID().uuidString,
            content: "Hello! I'm Lyo, your AI learning assistant. What would you like to learn today?",
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
        
        // Trigger thinking animation
        withAnimation {
            isThinking = true
        }
        
        Task {
            await viewModel.sendMessage(mode: selectedMode.rawValue)
            
                await MainActor.run {
                    withAnimation {
                        isThinking = false
                        showGreeting = false // Hide greeting when transitioning to chat
                        // Transition to chatting state if not already
                        if animationState == .active {
                            animationState = .chatting
                        }
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
    var onSubmit: () -> Void
    
    @State private var showModeSelector = false
    @State private var showAttachments = false
    
    // Brand gradient colors
    private let gradientColors = [Color(hex: "6366F1"), Color(hex: "8B5CF6")]
    
    var body: some View {
        // Docked Console Container
        VStack(spacing: 0) {
            // 1. Glowing Horizon Border
            Rectangle()
                .fill(
                    LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 1)
                .shadow(color: gradientColors[0].opacity(0.8), radius: 8, x: 0, y: -2) // Upward glow
            
            // 2. Control Row
            HStack(spacing: 16) {
                // "Ghost" Plus Button
                Button(action: { showAttachments = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.gray)
                        .frame(width: 40, height: 40)
                        .background(Color.clear) // Ghost style
                        .contentShape(Rectangle())
                }
                
                // Input Field & Mode
                HStack(spacing: 8) {
                    // Mode Selector (Minimalist)
                    Button(action: { showModeSelector = true }) {
                        HStack(spacing: 4) {
                            Text(selectedMode.rawValue.prefix(1)) // Just first letter? Or icon?
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
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
                    
                    TextField("Command or ask...", text: $text)
                        .foregroundColor(.white)
                        .font(.system(size: 16, design: .monospaced)) // Terminal feel
                        .onSubmit(onSubmit)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "1A1A1A"))
                .cornerRadius(12)
                
                // Mic / Send Button
                if !text.isEmpty {
                    // Send Button
                    Button(action: onSubmit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Circle())
                    }
                } else {
                    // Mic Button (Gradient)
                    Button(action: { isListening.toggle() }) {
                        Image(systemName: isListening ? "waveform" : "mic.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Circle())
                            .shadow(color: gradientColors[0].opacity(0.3), radius: 5)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8) // Internal padding
        }
        .background(Color(hex: "0E0E0E").ignoresSafeArea(edges: .bottom)) // Matte Black, flush to bottom
        .clipShape(CustomRoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
        // .padding(.bottom, 20) -> Handled by parent or safe area
        .sheet(isPresented: $showAttachments) {
            AttachmentPickerSheet()
        }
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
