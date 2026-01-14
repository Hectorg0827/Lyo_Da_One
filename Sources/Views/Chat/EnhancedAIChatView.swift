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
                    // Messages List
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
                    
                    // Enhanced Input Bar
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
            .clipShape(Capsule())
            
            Spacer()
        }
        .padding(.horizontal, 16)
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
            id: UUID(),
            role: .assistant,
            content: "Hello! I'm Lyo, your AI learning assistant. I can help you with courses, studying, quizzes, tutoring, and more. What would you like to learn today?",
            timestamp: Date(),
            attachments: []
        )
        messages.append(welcome)
    }
    
    func sendMessage(content: String, mode: AIChatMode, attachmentIds: [String]?) async {
        guard !content.isEmpty else { return }
        
        // Add user message
        let userMessage = MultimodalMessage(
            id: UUID(),
            role: .user,
            content: content,
            timestamp: Date(),
            attachments: []
        )
        messages.append(userMessage)
        
        // Start loading
        isLoading = true
        
        do {
            // Include mode context in the request
            let modeContext = getModeContext(for: mode)
            let fullContent = modeContext.isEmpty ? content : "\(modeContext)\n\n\(content)"
            
            // Send to backend
            let response = try await chatService.sendMessage(
                content: fullContent,
                conversationId: nil
            )
            
            // Add AI response
            let aiMessage = MultimodalMessage(
                id: UUID(),
                role: .assistant,
                content: response.message,
                timestamp: Date(),
                attachments: []
            )
            messages.append(aiMessage)
            
        } catch {
            print("❌ Failed to send message: \(error)")
            
            // Add error message
            let errorMessage = MultimodalMessage(
                id: UUID(),
                role: .assistant,
                content: "I apologize, but I encountered an error. Please try again.",
                timestamp: Date(),
                attachments: []
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
                await audioService.playTTS(message.content, messageId: message.id)
            }
        }
    }
    
    func handleQuizAnswer(messageId: UUID, answerIndex: Int) {
        // Handle quiz answer selection
        print("Quiz answer selected: \(answerIndex) for message \(messageId)")
    }
    
    func openCourse(_ courseId: String) {
        // Navigate to course detail
        print("Opening course: \(courseId)")
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
