import Foundation
import SwiftUI
import Combine

// MARK: - Chat ViewModel
@MainActor
class ChatViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var conversations: [ChatConversation] = []
    @Published var selectedConversation: ChatConversation?
    @Published var messages: [ChatMessage] = []
    @Published var messageGroups: [MessageGroup] = []

    @Published var newMessageText = ""
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var error: LyoError?

    @Published var typingUsers: Set<String> = []
    @Published var searchQuery = ""

    // MARK: - Dependencies

    private let webSocketManager = WebSocketManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?

    // MARK: - Init

    init() {
        setupWebSocket()
    }

    // MARK: - WebSocket Setup

    private func setupWebSocket() {
        Task {
            do {
                // TODO: Replace with actual user ID
                try await webSocketManager.connectToChat(userId: "current_user_id")
                isConnected = true

                // TODO: Implement WebSocket message handlers
                // Listen for chat messages
                // webSocketManager.onMessage(type: "chat_message") { [weak self] message in
                //     Task { @MainActor in
                //         self?.handleChatMessage(message)
                //     }
                // }

                // Listen for typing indicators
                // webSocketManager.onMessage(type: "typing") { [weak self] message in
                //     Task { @MainActor in
                //         self?.handleTypingIndicator(message)
                //     }
                // }

                // Listen for message read receipts
                // webSocketManager.onMessage(type: "message_read") { [weak self] message in
                //     Task { @MainActor in
                //         self?.handleMessageRead(message)
                //     }
                // }

            } catch {
                handleError(error)
            }
        }
    }

    // MARK: - Message Handling

    // TODO: Implement WebSocketMessage type
    /*
    private func handleChatMessage(_ message: WebSocketMessage) {
        guard let data = message.data,
              let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let chatMessage = try? JSONDecoder.lyoDecoder.decode(ChatMessage.self, from: jsonData) else {
            return
        }

        // Add to messages if in current conversation
        if chatMessage.conversationId == selectedConversation?.id {
            messages.append(chatMessage)
            groupMessages()
            markMessageAsRead(chatMessage.id)
        }

        // Update conversation's last message
        if let index = conversations.firstIndex(where: { $0.id == chatMessage.conversationId }) {
            var conversation = conversations[index]
            conversation.lastMessage = chatMessage
            conversation.updatedAt = chatMessage.createdAt

            if chatMessage.conversationId != selectedConversation?.id {
                conversation.unreadCount += 1
            }

            conversations[index] = conversation
            sortConversations()
        }
    }

    */

    /*
    private func handleTypingIndicator(_ message: WebSocketMessage) {
        guard let data = message.data,
              let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let indicator = try? JSONDecoder.lyoDecoder.decode(TypingIndicator.self, from: jsonData) else {
            return
        }

        if indicator.conversationId == selectedConversation?.id {
            typingUsers.insert(indicator.userName)

            // Remove after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.typingUsers.remove(indicator.userName)
            }
        }
    }

    */

    /*
    private func handleMessageRead(_ message: WebSocketMessage) {
        guard let data = message.data,
              let messageId = data["message_id"] as? String,
              let userId = data["user_id"] as? String else {
            return
        }

        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updatedMessage = messages[index]
            updatedMessage.readBy.append(userId)
            messages[index] = updatedMessage
            groupMessages()
        }
    }
    */

    // MARK: - Conversations

    func loadConversations() async {
        isLoading = true
        error = nil

        // TODO: Implement API call to load conversations
        // For now, using mock data
        try? await Task.sleep(nanoseconds: 500_000_000)

        let mockUser1 = User(id: 1001, email: "alice@lyo.app", name: "Alice", avatarURL: nil, createdAt: Date(), level: 5, xp: 2500, streak: 3, totalLessonsCompleted: 10, achievements: [])
        let mockUser2 = User(id: 1002, email: "bob@lyo.app", name: "Bob", avatarURL: nil, createdAt: Date(), level: 8, xp: 4500, streak: 5, totalLessonsCompleted: 20, achievements: [])
        let currentUser = User(id: 1000, email: "you@lyo.app", name: "You", avatarURL: nil, createdAt: Date(), level: 6, xp: 3000, streak: 4, totalLessonsCompleted: 15, achievements: [])

        conversations = [
            ChatConversation(
                id: "conv1",
                participants: [currentUser, mockUser1],
                lastMessage: ChatMessage(
                    id: "msg1",
                    conversationId: "conv1",
                    sender: mockUser1,
                    content: "Hey! How's your Python study going?",
                    type: .text,
                    attachments: nil,
                    createdAt: Date().addingTimeInterval(-3600),
                    readBy: ["current_user_id"],
                    reactions: nil,
                    replyTo: nil
                ),
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-3600),
                unreadCount: 0,
                type: .direct
            ),
            ChatConversation(
                id: "conv2",
                participants: [currentUser, mockUser2],
                lastMessage: ChatMessage(
                    id: "msg2",
                    conversationId: "conv2",
                    sender: mockUser2,
                    content: "Don't forget about the study group tomorrow!",
                    type: .text,
                    attachments: nil,
                    createdAt: Date().addingTimeInterval(-7200),
                    readBy: [],
                    reactions: nil,
                    replyTo: nil
                ),
                createdAt: Date().addingTimeInterval(-172800),
                updatedAt: Date().addingTimeInterval(-7200),
                unreadCount: 2,
                type: .direct
            )
        ]

        sortConversations()
        isLoading = false
    }

    func selectConversation(_ conversation: ChatConversation) async {
        selectedConversation = conversation
        await loadMessages(for: conversation)
    }

    private func sortConversations() {
        conversations.sort { ($0.updatedAt) > ($1.updatedAt) }
    }

    // MARK: - Messages

    func loadMessages(for conversation: ChatConversation) async {
        isLoading = true
        error = nil

        // TODO: Implement API call to load messages
        // For now, using mock data
        try? await Task.sleep(nanoseconds: 300_000_000)

        let mockUser = conversation.participants.first { $0.id != 1000 }!
        let currentUser = conversation.participants.first { $0.id == 1000 }!

        messages = [
            ChatMessage(
                id: "msg1",
                conversationId: conversation.id,
                sender: mockUser,
                content: "Hey! How's your Python study going?",
                type: .text,
                attachments: nil,
                createdAt: Date().addingTimeInterval(-3600),
                readBy: ["1000"],
                reactions: nil,
                replyTo: nil
            ),
            ChatMessage(
                id: "msg2",
                conversationId: conversation.id,
                sender: currentUser,
                content: "Going great! Just finished the loops chapter.",
                type: .text,
                attachments: nil,
                createdAt: Date().addingTimeInterval(-3500),
                readBy: [String(mockUser.id)],
                reactions: nil,
                replyTo: nil
            ),
            ChatMessage(
                id: "msg3",
                conversationId: conversation.id,
                sender: mockUser,
                content: "Nice! Want to practice together?",
                type: .text,
                attachments: nil,
                createdAt: Date().addingTimeInterval(-3400),
                readBy: ["1000"],
                reactions: nil,
                replyTo: nil
            )
        ]

        groupMessages()
        isLoading = false

        // Mark all as read
        markConversationAsRead(conversation)
    }

    func sendMessage() async {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversation = selectedConversation else {
            return
        }

        let messageContent = newMessageText
        newMessageText = ""

        // Stop typing indicator
        sendTypingIndicator(isTyping: false)

        // Create optimistic message
        let currentUser = User(id: 1000, email: "you@lyo.app", name: "You", avatarURL: nil, createdAt: Date(), level: 6, xp: 3000, streak: 4, totalLessonsCompleted: 15, achievements: [])
        let optimisticMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversation.id,
            sender: currentUser,
            content: messageContent,
            type: .text,
            attachments: nil,
            createdAt: Date(),
            readBy: [String(currentUser.id)],
            reactions: nil,
            replyTo: nil
        )

        messages.append(optimisticMessage)
        groupMessages()

        // Send via WebSocket
        do {
            try await webSocketManager.sendChatMessage(content: messageContent)
        } catch {
            // Remove optimistic message on error
            messages.removeAll { $0.id == optimisticMessage.id }
            groupMessages()
            handleError(error)
        }
    }

    func sendTypingIndicator(isTyping: Bool) {
        guard selectedConversation != nil else { return }

        typingTimer?.invalidate()

        if isTyping {
            // TODO: Implement WebSocketMessage type
            // Task {
            //     try? await webSocketManager.send(message: WebSocketMessage(
            //         type: "typing",
            //         data: [
            //             "conversation_id": conversation.id,
            //             "user_id": "current_user_id",
            //             "user_name": "You"
            //         ]
            //     ))
            // }

            // Auto-stop typing after 3 seconds
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.sendTypingIndicator(isTyping: false)
                }
            }
        }
    }

    private func markMessageAsRead(_ messageId: String) {
        // TODO: Implement WebSocketMessage type
        // Task {
        //     try? await webSocketManager.send(message: WebSocketMessage(
        //         type: "message_read",
        //         data: [
        //             "message_id": messageId,
        //             "user_id": "current_user_id"
        //         ]
        //     ))
        // }
    }

    private func markConversationAsRead(_ conversation: ChatConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            var updated = conversations[index]
            updated.unreadCount = 0
            conversations[index] = updated
        }

        // Mark all messages as read
        for message in messages where !message.isFromCurrentUser {
            markMessageAsRead(message.id)
        }
    }

    // MARK: - Message Grouping

    private func groupMessages() {
        var groups: [MessageGroup] = []
        var currentGroup: [ChatMessage] = []
        var currentSender: User?

        for message in messages {
            if currentSender?.id == message.sender.id {
                // Same sender, add to current group
                currentGroup.append(message)
            } else {
                // Different sender, start new group
                if !currentGroup.isEmpty, let sender = currentSender {
                    groups.append(MessageGroup(
                        id: currentGroup.first!.id,
                        sender: sender,
                        messages: currentGroup,
                        timestamp: currentGroup.last!.createdAt
                    ))
                }
                currentGroup = [message]
                currentSender = message.sender
            }
        }

        // Add last group
        if !currentGroup.isEmpty, let sender = currentSender {
            groups.append(MessageGroup(
                id: currentGroup.first!.id,
                sender: sender,
                messages: currentGroup,
                timestamp: currentGroup.last!.createdAt
            ))
        }

        messageGroups = groups
    }

    // MARK: - Search

    var filteredConversations: [ChatConversation] {
        guard !searchQuery.isEmpty else { return conversations }

        return conversations.filter { conversation in
            conversation.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            (conversation.lastMessage?.content.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let lyoError = error as? LyoError {
            self.error = lyoError
        } else {
            self.error = .network(.serverError(500))
        }
    }

    // MARK: - Computed Properties

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var typingIndicatorText: String {
        let users = Array(typingUsers)
        if users.isEmpty {
            return ""
        } else if users.count == 1 {
            return "\(users[0]) is typing..."
        } else if users.count == 2 {
            return "\(users[0]) and \(users[1]) are typing..."
        } else {
            return "\(users[0]) and \(users.count - 1) others are typing..."
        }
    }

    // MARK: - Cleanup

    func disconnect() {
        webSocketManager.disconnect()
        isConnected = false
    }
}
