//
//  EnhancedAIChatView.swift
//  Lyo
//
//  Main AI chat screen with Gemini-style interface
//

import SwiftUI

struct EnhancedAIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    @StateObject private var conversationManager = ConversationManager.shared
    @State private var userInput: String = ""
    @State private var selectedMode: AIChatMode = .chat
    @State private var showSettings = false
    @State private var showHistory = false
    
    init(conversation: SavedConversation? = nil) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(conversation: conversation))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    messageList
                    inputArea
                }
            }
            .navigationTitle("AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // New Chat Button
                        Button {
                            createNewChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title3)
                        }
                        
                        // Settings Button
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                ChatSettingsView()
            }
            .sheet(isPresented: $showHistory) {
                ChatHistoryView(
                    onSelectConversation: { conversation in
                        viewModel.loadConversation(conversation)
                    },
                    onNewChat: {
                        createNewChat()
                    }
                )
            }
            .onChange(of: viewModel.messages) { _, newMessages in
                // Auto-save conversation when messages change
                conversationManager.updateCurrentConversation(with: newMessages)
            }
        }
    }
    
    // MARK: - Actions
    
    private func createNewChat() {
        let newConversation = conversationManager.createNewConversation()
        viewModel.loadConversation(newConversation)
        HapticManager.shared.playSuccess()
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        HStack(spacing: 12) {
            // Avatar
            Image("LyoAvatar")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isLoading ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Subviews

extension EnhancedAIChatView {
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        EnhancedMessageBubble(
                            message: message,
                            onTTSToggle: {
                                viewModel.toggleTTS(for: message)
                            },
                            onQuizAnswer: { answerIndex in
                                viewModel.handleQuizAnswer(messageId: message.id, answerIndex: answerIndex)
                            },
                            onCourseOpen: { courseId in
                                viewModel.openCourse(courseId)
                            },
                            onTopicSelect: { topic in
                                viewModel.handleTopicSelection(topic)
                            },
                            onModuleSelect: { module in
                                viewModel.handleModuleSelection(module)
                            },
                            onSuggestionSelect: { suggestion in
                                viewModel.handleSuggestionSelect(suggestion)
                            }
                        )
                        .id(message.id)
                    }
                    
                    // Loading indicator
                    if viewModel.isLoading {
                        loadingIndicator
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // Auto-scroll to bottom on new message
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputArea: some View {
        EnhancedChatInputBar(
            text: $userInput,
            isLoading: $viewModel.isLoading,
            selectedMode: $selectedMode,
            onSend: { attachmentIds in
                await viewModel.sendMessage(
                    content: userInput,
                    mode: selectedMode,
                    attachmentIds: attachmentIds
                )
            }
        )
    }
}

// MARK: - AI Chat View Model

@MainActor
class AIChatViewModel: ObservableObject {
    @Published var messages: [MultimodalMessage] = []
    @Published var isLoading = false
    
    private let chatService = LioChatService.shared
    private let audioService = AudioPlaybackService.shared
    private let conversationManager = ConversationManager.shared
    
    init(conversation: SavedConversation? = nil) {
        if let conversation = conversation {
            // Load existing conversation
            self.messages = conversation.messages
        } else if let currentConversation = conversationManager.currentConversation {
            // Load current conversation from manager
            self.messages = currentConversation.messages
        } else {
            // No conversation - create new one
            loadWelcomeMessage()
        }
    }
    
    func loadConversation(_ conversation: SavedConversation) {
        messages = conversation.messages
        conversationManager.loadConversation(conversation)
    }
    
    func loadWelcomeMessage() {
        let welcome = MultimodalMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "Hello! I'm Lyo, your AI learning assistant. I can help you with courses, studying, quizzes, tutoring, and more. What would you like to learn today?",
            attachments: [],
            timestamp: Date()
        )
        messages.append(welcome)
    }
    
    func sendMessage(content: String, mode: AIChatMode, attachmentIds: [String]?) async {
        guard !content.isEmpty else { return }
        
        // ✅ TEST COMMAND: Manually trigger classroom
        if content.lowercased() == "/testclassroom" {
            print("🧪 TEST: Manually triggering classroom...")
            let testJSON = """
            {
                "type": "OPEN_CLASSROOM",
                "payload": {
                    "course": {
                        "title": "Test Course",
                        "topic": "Swift Programming",
                        "level": "beginner",
                        "duration": "2 hours",
                        "objectives": ["Learn Swift basics", "Build first app"]
                    }
                }
            }
            """
            let (displayText, wasCommand) = AICommandHandler.shared.processResponse(testJSON)
            print("🧪 Command processed: wasCommand=\(wasCommand)")
            print("🧪 Display text: \(displayText)")
            return
        }
        
        // Debug Demo Command
        if content.lowercased() == "/demo" {
            // Add user message
            let userMessage = MultimodalMessage(
                id: UUID().uuidString,
                role: .user,
                content: content,
                attachments: [],
                timestamp: Date()
            )
            messages.append(userMessage)
            
            // Show Topic Selection
            let topicMsg = MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "",
                contentTypes: [.topicSelection(title: "Choose a Subject", topics: [
                    TopicOption(title: "Physics", icon: "atom", gradientColors: ["#FF00CC", "#333399"]),
                    TopicOption(title: "Math", icon: "x.squareroot", gradientColors: ["#00C9FF", "#92FE9D"]),
                    TopicOption(title: "History", icon: "book.closed.fill", gradientColors: ["#F2994A", "#F2C94C"])
                ])],
                timestamp: Date()
            )
            messages.append(topicMsg)
            
            // Show Course Roadmap
            let roadMsg = MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "",
                contentTypes: [.courseRoadmap(
                    title: "SwiftUI Mastery",
                    modules: [
                        CourseModule(title: "Introduction", duration: "5 min", isCompleted: true),
                        CourseModule(title: "Views & Modifiers", duration: "12 min", isCompleted: false),
                        CourseModule(title: "State Management", duration: "15 min", isLocked: true)
                    ],
                    totalModules: 10,
                    completedModules: 1
                )],
                timestamp: Date()
            )
            messages.append(roadMsg)
            
            // Show Flashcards
            let flashMsg = MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "",
                contentTypes: [.flashcards(title: "Swift Keywords", cards: [
                    Flashcard(front: "let", back: "Constant property"),
                    Flashcard(front: "var", back: "Mutable variable"),
                    Flashcard(front: "func", back: "A function definition")
                ])],
                timestamp: Date()
            )
            messages.append(flashMsg)
            
            // Show Quiz
            let quizMsg = MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "",
                contentTypes: [.quiz(
                    question: "What wrapper property is used for local state in a View?",
                    options: ["@Binding", "@State", "@ObservedObject", "@Environment"],
                    correctIndex: 1,
                    explanation: "@State is designed for simple local state that is owned by the View."
                )],
                timestamp: Date()
            )
            messages.append(quizMsg)
            
            return
        }
        
        // Add user message
        let userMessage = MultimodalMessage(
            id: UUID().uuidString,
            role: .user,
            content: content,
            attachments: [],
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Start loading
        isLoading = true
        
        // Dynamic UI: Add "Thinking" bubble
        let processingId = UUID().uuidString
        let processingMessage = MultimodalMessage(
            id: processingId,
            role: .assistant,
            content: "Thinking...",
            contentTypes: [.processing(step: "Analyzing request...", progress: nil)],
            timestamp: Date()
        )
        messages.append(processingMessage)
        
        do {
            // Include mode context in the request
            let modeContext = getModeContext(for: mode)
            let fullContent = modeContext.isEmpty ? content : "\(modeContext)\n\n\(content)"
            
            // Send to backend - matches LioChatService.sendMessage(text:mode:context:contextHint:)
            let response = try await chatService.sendMessage(
                text: fullContent,
                mode: mode.rawValue
            )
            
            print("📥 AI Response received:")
            print("   - Text length: \(response.text.count) chars")
            print("   - Contains 'OPEN_CLASSROOM': \(response.text.contains("OPEN_CLASSROOM"))")
            print("   - Has action: \(response.action != nil)")
            print("   - Content types: \(response.contentTypes?.count ?? 0)")
            if response.text.count < 500 {
                print("   - Full text: \(response.text)")
            } else {
                print("   - Text preview: \(String(response.text.prefix(200)))...")
            }
            
            // NEW: Process response through AICommandHandler for structured redirections
            // This ensures that strings with embedded JSON are caught and acted upon.
            let (displayText, wasCommand) = AICommandHandler.shared.processResponse(response.text)
            
            print("🎯 Command Handler Result:")
            print("   - Was command: \(wasCommand)")
            print("   - Display text length: \(displayText.count)")
            
            // Remove processing message
            messages.removeAll { $0.id == processingId }
            
            // Use cleaned text if it was a command
            let finalOutput = wasCommand ? displayText : response.text
            
            // Add AI response with contentTypes from backend
            let aiMessage = MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: finalOutput,
                contentTypes: response.contentTypes ?? [.text],
                attachments: [],
                timestamp: Date()
            )
            messages.append(aiMessage)
            
            // Also handle explicit actions from LioChatResponse (legacy support)
            if let action = response.action {
                handleLioChatAction(action)
            }
            
            print("✅ AI response processed. Action detected: \(wasCommand || response.action != nil)")
            
        } catch {
            print("❌ Failed to send message: \(error)")
            
            // Remove processing message
            messages.removeAll { $0.id == processingId }
            
            // Add error message
            let errorMessage = MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "I apologize, but I encountered an error. Please try again.",
                attachments: [],
                timestamp: Date()
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    func toggleTTS(for message: MultimodalMessage) {
        if audioService.currentMessageId == message.id && audioService.isPlaying {
            audioService.pause()
        } else {
            Task {
                await audioService.playTTS(text: message.content, messageId: message.id)
            }
        }
    }
    
    func handleQuizAnswer(messageId: String, answerIndex: Int) {
        // Handle quiz answer selection
        print("Quiz answer selected: \(answerIndex) for message \(messageId)")
    }
    
    func openCourse(_ courseId: String) {
        // Navigate to course detail
        print("Opening course: \(courseId)")
    }
    
    func handleTopicSelection(_ topic: TopicOption) {
        print("Selected topic: \(topic.title)")
        Task {
            await sendMessage(content: "I choose \(topic.title)", mode: .chat, attachmentIds: nil)
        }
    }
    
    func handleModuleSelection(_ module: CourseModule) {
        print("Selected module: \(module.title)")
        Task {
            // Switch to Tutor mode implicitly
            await sendMessage(content: "Let's start module: \(module.title)", mode: .tutor, attachmentIds: nil)
        }
    }
    
    func handleSuggestionSelect(_ suggestion: String) {
        print("Selected suggestion: \(suggestion)")
        Task {
            await sendMessage(content: suggestion, mode: .chat, attachmentIds: nil)
        }
    }
    
    private func handleLioChatAction(_ action: LioChatAction) {
        print("⚡ Handling LioChatAction: \(action.type)")
        
        switch action.type {
        case "open_classroom", "generate_course":
            if let courseId = action.parameters?["courseId"] {
                NotificationCenter.default.post(
                    name: NSNotification.Name("openClassroom"),
                    object: nil,
                    userInfo: [
                        "courseId": courseId,
                        "courseTitle": action.parameters?["courseTitle"] ?? "New Course"
                    ]
                )
            }
        default:
            print("⚠️ Unhandled action type: \(action.type)")
        }
    }
    
    private func getModeContext(for mode: AIChatMode) -> String {
        switch mode {
        case .chat:
            return ""
        case .course:
            return "[Course Creation Mode] Please create a comprehensive course on this topic."
        case .study:
            return "[Study Mode] Help me study and understand this topic in depth."
        case .test:
            return "[Test Mode] Create a test or assessment on this topic."
        case .tutor:
            return "[Tutor Mode] Act as my personal tutor and help me understand this concept."
        case .quiz:
            return "[Quiz Mode] Create an engaging quiz on this topic."
        }
    }
}

// MARK: - Chat Settings View

struct ChatSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Voice Settings") {
                    Toggle("Auto-play AI responses", isOn: .constant(false))
                    Toggle("Voice feedback", isOn: .constant(true))
                }
                
                Section("Conversation") {
                    Button("Clear chat history") {
                        // Clear history
                    }
                    .foregroundColor(.red)
                    
                    Button("Export conversation") {
                        // Export
                    }
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedAIChatView()
}
