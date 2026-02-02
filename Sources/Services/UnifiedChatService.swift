//
//  UnifiedChatService.swift
//  Lyo
//
//  SINGLE SOURCE OF TRUTH for all AI chat functionality across the app.
//  This service handles:
//  - Message sending/receiving via BackendAIService
//  - A2UI protocol parsing and rendering
//  - Course creation flow
//  - Conversation persistence
//  - Stack integration
//
//  NOTE: This service uses existing LyoMessage type to maintain compatibility
//  with the existing UI components (LyoMessageBubbleView, etc.)
//

import Foundation
import Combine

// MARK: - Unified Chat Service

@MainActor
final class UnifiedChatService: ObservableObject {
    static let shared = UnifiedChatService()
    
    // Dependencies
    private let repository = LyoRepository.shared
    
    // MARK: - Published State
    
    /// All messages in the current conversation (uses existing LyoMessage type)
    @Published private(set) var messages: [LyoMessage] = []
    
    /// Current conversation ID
    @Published private(set) var currentConversationId: String = UUID().uuidString
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Error message
    @Published var error: String?
    
    /// Pending course to navigate to (set when AI creates a course)
    @Published var pendingCourse: CourseCreationData?
    
    /// Flag to trigger classroom navigation
    @Published var shouldNavigateToClassroom: Bool = false
    
    /// Last AI response source (for debug/analytics)
    @Published private(set) var lastAISource: String = ""
    
    /// Suggestions from last response
    @Published var suggestions: [SuggestionChip] = []
    
    // MARK: - Private Properties
    
    private let backendAI = BackendAIService.shared
    private let lioChatService = LioChatService.shared
    private let stackStore = UIStackStore.shared
    // Use ConversationManager for persistence (already exists in project)
    private var conversationHistory: [ConversationMessage] = []
    
    // MARK: - Initialization
    
    private init() {
        // Load last conversation if available
        Task {
            await loadLastConversation()
        }
    }
    
    // MARK: - Public API
    
    /// Start a completely new chat session
    /// Clears local state and generates a new session ID to ensure isolation
    func startNewChat(withId id: String? = nil) {
        // 1. Generate new session ID
        currentConversationId = id ?? UUID().uuidString
        
        // 2. Clear UI messages
        messages = []
        
        // 3. Clear LLM context
        conversationHistory = []
        
        // 4. Reset other state
        error = nil
        pendingCourse = nil
        shouldNavigateToClassroom = false
        suggestions = []
        
        print("🆕 Started new chat session: \(currentConversationId)")
    }

    /// Send a message and get AI response with full A2UI support
    /// - Parameters:
    ///   - text: The message text
    ///   - attachments: Optional file attachments
    ///   - context: Optional context (course ID, lesson ID, etc.)
    ///   - mode: Chat mode (study, quiz, etc.)
    /// Send a message and get AI response using the unified LioChatService flow
    func sendMessage(
        _ text: String,
        attachments: [MessageAttachment] = [],
        context: ChatContext? = nil,
        mode: String = "chat"
    ) async -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }
        
        // 1. Add user message to UI state
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: trimmedText,
            isFromUser: true,
            timestamp: Date(),
            attachments: attachments.isEmpty ? nil : attachments
        )
        messages.append(userMessage)
        
        // 2. Update conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: trimmedText))
        
        // 3. Save to persistence
        await saveConversation()
        
        // 4. Update stack
        stackStore.upsertChat(
            key: currentConversationId,
            title: extractTitle(from: trimmedText),
            subtitle: "Just now",
            lastMessage: trimmedText
        )
        
        // 5. Get AI response via the Bulletproof Flow in LioChatService
        isLoading = true
        error = nil
        
        do {
            let response = try await lioChatService.sendMessage(
                text: trimmedText,
                sessionId: currentConversationId,
                mode: mode,
                contextHint: context?.courseId,
                attachments: attachments
            )
            
            // 6. Process response through AICommandHandler (for navigation triggers)
            // Note: Even if LioChatService returns an action, we still process the text here
            // to catch any embedded JSON triggers that might have slipped through.
            let (displayText, _) = AICommandHandler.shared.processResponse(response.text)
            
            // 7. Create and add AI message
            let aiMessage = LyoMessage(
                id: UUID().uuidString,
                sessionId: currentConversationId,
                content: displayText,
                isFromUser: false,
                timestamp: Date(),
                contentTypes: response.contentTypes
            )
            
            messages.append(aiMessage)
            suggestions = response.suggestions?.map { SuggestionChip(id: UUID().uuidString, text: $0) } ?? []
            
            // 8. Handle any structured actions from LioChatService
            if let action = response.action {
                handleLioChatAction(action)
            }
            
            // 9. Update history and persistence
            conversationHistory.append(ConversationMessage(role: "assistant", content: response.text))
            await saveConversation()
            
            isLoading = false
            return displayText
            
        } catch {
            print("❌ UnifiedChatService: Error sending message: \(error)")
            self.error = error.localizedDescription
            
            let errorMessage = LyoMessage(
                id: UUID().uuidString,
                sessionId: currentConversationId,
                content: "I encountered an error. Please try again.",
                isFromUser: false,
                timestamp: Date(),
                status: .failed
            )
            messages.append(errorMessage)
            
            isLoading = false
            return nil
        }
    }

    private func handleLioChatAction(_ action: LioChatAction) {
        print("⚡ UnifiedChatService: Handling action \(action.type)")
        
        switch action.type {
        case "open_classroom":
            // Construct a payload from parameters to trigger the AICommandHandler
            if let params = action.parameters {
                let course = CoursePayload(
                    id: params["courseId"],
                    title: params["courseTitle"] ?? "New Course",
                    topic: params["topic"] ?? "Learning",
                    level: params["level"] ?? "Beginner",
                    language: "English",
                    duration: nil,
                    objectives: []
                )
                let commandPayload = AICommandPayload(stackItem: nil, course: course)
                _ = AICommandHandler.shared.handleOpenClassroom(commandPayload)
            }
            
        default:
            print("⚠️ UnifiedChatService: Received unhandled action type: \(action.type)")
        }
    }

    // MARK: - Streaming Support (Live AI)
    
    func sendMessageStreaming(
        _ text: String,
        attachments: [MessageAttachment] = [],
        context: ChatContext? = nil,
        mode: String = "chat",
        speakResponse: Bool = false
    ) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // 1. Add user message
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: trimmedText,
            isFromUser: true,
            timestamp: Date(),
            attachments: attachments.isEmpty ? nil : attachments
        )
        messages.append(userMessage)
        conversationHistory.append(ConversationMessage(role: "user", content: trimmedText))
        await saveConversation()
        
        // 2. Create Placeholder AI Message
        let aiMessageId = UUID().uuidString
        let aiMessage = LyoMessage(
            id: aiMessageId,
            sessionId: currentConversationId,
            content: "",
            isFromUser: false,
            timestamp: Date(),
            contentTypes: [.processing(step: "Thinking...", progress: nil)]
        )
        messages.append(aiMessage)
        
        isLoading = true
        
        // 3. Start Stream via LioChatService
        lioChatService.sendMessageStreaming(
            text: trimmedText,
            sessionId: currentConversationId,
            contextHint: context?.courseId,
            speakResponse: speakResponse,
            onToken: { [weak self] token in
                Task { @MainActor [weak self] in
                    self?.appendToken(to: aiMessageId, token: token)
                }
            },
            onComplete: { [weak self] response in
                Task { @MainActor [weak self] in
                    self?.finalizeStreaming(id: aiMessageId, response: response)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.handleStreamingError(error)
                }
            }
        )
    }
    
    private func appendToken(to messageId: String, token: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        var message = messages[index]
        
        // Remove processing state if it exists
        if message.contentTypes?.contains(where: { 
            if case .processing = $0 { return true } else { return false }
        }) == true {
            message.contentTypes = nil
        }
        
        // Append text by creating a NEW message (since content is immutable)
        let updatedContent = message.content + token
        let newMessage = LyoMessage(
            id: message.id,
            sessionId: message.sessionId,
            content: updatedContent,
            isFromUser: message.isFromUser,
            timestamp: message.timestamp,
            attachments: message.attachments,
            actions: message.actions,
            status: message.status,
            contentTypes: message.contentTypes,
            responseMode: message.responseMode,
            quickExplainer: message.quickExplainer,
            courseProposal: message.courseProposal
        )
        
        messages[index] = newMessage
    }
    
    private func finalizeStreaming(id: String, response: LioChatResponse) {
        isLoading = false
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        
        let oldMessage = messages[index] // get current state
        let fullText = oldMessage.content // current accumulated text
        
        // Process for triggers (Course creation, etc.)
        let (displayText, _) = AICommandHandler.shared.processResponse(fullText)
        
        // Create FINAL message
        let finalMessage = LyoMessage(
            id: oldMessage.id,
            sessionId: oldMessage.sessionId,
            content: displayText,
            isFromUser: oldMessage.isFromUser,
            timestamp: oldMessage.timestamp,
            attachments: oldMessage.attachments,
            actions: oldMessage.actions,
            status: oldMessage.status,
            contentTypes: oldMessage.contentTypes,
            responseMode: oldMessage.responseMode, // Maintain mentor mode data
            quickExplainer: oldMessage.quickExplainer,
            courseProposal: oldMessage.courseProposal
        )
        
        messages[index] = finalMessage
        
        // Add suggestions
        suggestions = response.suggestions?.map { SuggestionChip(id: UUID().uuidString, text: $0) } ?? []
        
        // Handle actions
        if let action = response.action {
            handleLioChatAction(action)
        }
        
        // Save to history
        conversationHistory.append(ConversationMessage(role: "assistant", content: fullText))
        Task { await saveConversation() }
    }
    
    private func handleStreamingError(_ error: Error) {
        isLoading = false
        self.error = error.localizedDescription
        
        let errorMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: "I encountered an error. Please try again.",
            isFromUser: false,
            timestamp: Date(),
            status: .failed
        )
        messages.append(errorMessage)
    }

    
    /// Start a new conversation
    func startNewConversation() {
        currentConversationId = UUID().uuidString
        messages.removeAll()
        conversationHistory.removeAll()
        error = nil
    }
    
    /// Fetch and display a proactive greeting from the AI
    func fetchProactiveGreeting() async {
        guard messages.isEmpty else { return }
        
        isLoading = true
        do {
            // Re-use LioGreetingResponse which is visible in the module
            let response: LioGreetingResponse = try await NetworkClient.shared.request(Endpoints.ChatModule.getGreeting)
            
            let greetingMessage = LyoMessage(
                id: UUID().uuidString,
                content: response.greeting,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .sent
            )
            
            messages.append(greetingMessage)
            conversationHistory.append(ConversationMessage(role: "assistant", content: response.greeting))
            
        } catch {
            print("⚠️ Failed to fetch proactive greeting: \(error)")
            // Fallback greeting
            let fallback = LyoMessage(
                id: UUID().uuidString,
                content: "Hello! I'm Lyo, your AI learning companion. How can I help you today?",
                isFromUser: false,
                timestamp: Date(),
                status: .sent
            )
            messages.append(fallback)
        }
        isLoading = false
    }
    
    /// Load a specific saved conversation
    func loadConversation(_ conversation: SavedConversation) {
        // 1. Set ID
        currentConversationId = conversation.id
        
        // 2. Set messages
        messages = conversation.messages.map { convertToLyo($0) }
        
        // 3. Rebuild context history for LLM
        // We map LyoMessage back to ConversationMessage format for the AI context
        conversationHistory = conversation.messages.suffix(10).map { msg in
            ConversationMessage(
                role: msg.isFromUser ? "user" : "assistant",
                content: msg.content
            )
        }
        
        // 4. Reset state
        error = nil
        pendingCourse = nil
        shouldNavigateToClassroom = false
        suggestions = []
        
        print("📂 Loaded saved conversation: \(conversation.id) with \(messages.count) messages")
    }
    
    /// Navigate to course that was just created
    func navigateToCourse(_ course: CourseCreationData) {
        pendingCourse = course
        shouldNavigateToClassroom = true
        
        // Post global notification for cinematic flow
        NotificationCenter.default.post(
            name: .openClassroom, 
            object: nil, 
            userInfo: [
                "courseId": "GENERATE:\(course.topic)",
                "courseTitle": course.title,
                "lessonId": "intro_1",
                "lessonTitle": "Introduction"
            ]
        )
    }
    
    /// Explicitly trigger navigation to the current pending course
    func triggerCourseNavigation() {
        guard let course = pendingCourse else { return }
        shouldNavigateToClassroom = true
        
        // Post global notification for cinematic flow
        NotificationCenter.default.post(
            name: .openClassroom, 
            object: nil, 
            userInfo: [
                "courseId": "GENERATE:\(course.topic)",
                "courseTitle": course.title,
                "lessonId": "intro_1",
                "lessonTitle": "Introduction"
            ]
        )
    }
    
    /// Clear navigation flags
    func clearNavigation() {
        shouldNavigateToClassroom = false
    }
    
    // MARK: - Response Parsing

    
    // MARK: - Persistence (Simplified - uses UserDefaults for now)
    
    private let conversationStorageKey = "com.lyo.unifiedChat.lastConversation"
    
    private func saveConversation() async {
        // Use ConversationManager as source of truth
        let multimodalMessages = messages.map { convertToMultimodal($0) }
        
        // Generate title if new
        let title = messages.isEmpty ? "New Chat" : SavedConversation.generateTitle(from: multimodalMessages)
        let preview = SavedConversation.getLastMessagePreview(from: multimodalMessages)
        
        let savedConversation = SavedConversation(
            id: currentConversationId,
            title: title,
            lastMessagePreview: preview,
            lastUpdated: Date(),
            messageCount: messages.count,
            messages: multimodalMessages
        )
        
        // Save to Manager
        ConversationManager.shared.saveConversation(savedConversation)
        
        // Also update current pointer
        ConversationManager.shared.loadConversation(savedConversation)
    }
    
    private func loadLastConversation() async {
        // Load from ConversationManager
        if let current = ConversationManager.shared.currentConversation {
            loadConversation(current)
        } else if let recent = ConversationManager.shared.conversations.first {
            loadConversation(recent)
        }
    }
    
    // MARK: - Message Compatibility
    
    private func convertToMultimodal(_ msg: LyoMessage) -> MultimodalMessage {
        return MultimodalMessage(
            id: msg.id,
            sessionId: msg.sessionId,
            role: msg.isFromUser ? .user : .assistant,
            content: msg.content,
            contentTypes: msg.contentTypes ?? [.text], // Preserve A2UI widgets
            timestamp: msg.timestamp,
            isStreaming: false
        )
    }
    
    private func convertToLyo(_ msg: MultimodalMessage) -> LyoMessage {
        var lyoMsg = LyoMessage(
            id: msg.id,
            content: msg.content,
            isFromUser: msg.role == .user,
            timestamp: msg.timestamp,
            status: .sent
        )
        lyoMsg.sessionId = msg.sessionId
        lyoMsg.contentTypes = msg.contentTypes
        return lyoMsg
    }
    
    private func extractTitle(from text: String) -> String {
        let words = text.split(separator: " ").prefix(5)
        return words.joined(separator: " ") + (text.split(separator: " ").count > 5 ? "..." : "")
    }
}

// NOTE: SavedConversation is defined in ConversationManager.swift
// Course models are in Sources/Models/CourseModels.swift
