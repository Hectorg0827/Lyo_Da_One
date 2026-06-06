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

    private let messagingService = MessagingService.shared
    private let webSocketManager = WebSocketManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private var webSocketTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        setupMessaging()
        setupWebSocket()
    }

    // MARK: - Messaging Setup

    private func setupMessaging() {
        // Subscribe to changes in MessagingService
        messagingService.$conversations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (apiConversations: [Conversation]) in
                self?.conversations = apiConversations.compactMap { self?.mapConversation($0) ?? self?.mockConversation($0.id) }
                self?.sortConversations()
            }
            .store(in: &cancellables)

        messagingService.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (apiMessages: [Message]) in
                self?.messages = apiMessages.compactMap { self?.mapMessage($0) ?? self?.mockMessage($0.id) }
                self?.groupMessages()
            }
            .store(in: &cancellables)
            
        messagingService.$unreadCount
             .sink { [weak self] (count: Int) in
                 self?.objectWillChange.send()
                 // Note: we can't directly assign to published property from sink easily without a helper
                 // but we can just use the property from service directly in the view if needed
             }
             .store(in: &cancellables)
    }
    
    // For assign to work with published properties we need a helper or just use sink
    private var totalUnreadCountDummy: Int = 0
    
    // MARK: - Mapping Helpers

    private func mapConversation(_ api: Conversation) -> ChatConversation {
        let participants = api.participants.map { mapParticipant($0) }
        
        return ChatConversation(
            id: api.id,
            participants: participants,
            lastMessage: api.lastMessage.map { mapMessagePreview($0, conversationId: api.id) },
            createdAt: Date(), // API doesn't provide createdAt for conversation
            updatedAt: api.updatedAt ?? Date(),
            unreadCount: api.unreadCount,
            type: api.type == "group" ? .group : .direct
        )
    }

    private func mapParticipant(_ participant: ConversationParticipant) -> User {
        return User(
            id: Int(participant.id) ?? 0,
            email: "", // Not available in participant DTO
            name: participant.displayName,
            avatarURL: participant.avatarUrl,
            createdAt: Date(),
            level: 0,
            xp: 0,
            streak: 0,
            totalLessonsCompleted: 0,
            achievements: []
        )
    }

    private func mapMessage(_ api: Message) -> ChatMessage {
        return ChatMessage(
            id: api.id,
            conversationId: api.conversationId,
            sender: mapParticipant(api.sender),
            content: api.content,
            type: mapMessageType(api.mediaType),
            attachments: mapAttachments(mediaUrl: api.mediaUrl, mediaType: api.mediaType),
            createdAt: api.createdAt,
            readBy: api.status == "read" ? ["someone"] : [], // API status is a string
            reactions: api.reactions.map { MessageReaction(emoji: $0.emoji, userId: $0.userId, userName: "") },
            replyTo: api.replyToId
        )
    }

    private func mapMessagePreview(_ preview: MessagePreview, conversationId: String) -> ChatMessage {
        // Create a minimal ChatMessage from a preview
        return ChatMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            sender: User(id: Int(preview.senderId ?? "0") ?? 0, email: "", name: "User", avatarURL: nil, createdAt: Date(), level: 0, xp: 0, streak: 0, totalLessonsCompleted: 0, achievements: []),
            content: preview.content,
            type: .text,
            attachments: nil,
            createdAt: preview.createdAt ?? Date(),
            readBy: [],
            reactions: nil,
            replyTo: nil
        )
    }

    private func mapAttachments(mediaUrl: String?, mediaType: String?) -> [SocialMessageAttachment]? {
        guard let url = mediaUrl, !url.isEmpty else { return nil }
        let type: SocialMessageAttachment.AttachmentType = {
            switch mediaType {
            case "image": return .image
            case "video": return .video
            case "voice", "audio": return .voice
            default: return .document
            }
        }()
        return [SocialMessageAttachment(
            id: UUID().uuidString,
            type: type,
            url: url,
            thumbnailURL: nil,
            fileName: nil,
            fileSize: nil,
            duration: nil
        )]
    }

    private func mapMessageType(_ type: String?) -> ChatMessage.MessageType {
        switch type {
        case "image": return .image
        case "file": return .file
        case "voice": return .voice
        default: return .text
        }
    }

    private func mockConversation(_ id: String) -> ChatConversation {
        // Fallback for types that might fail mapping
        ChatConversation(id: id, participants: [], lastMessage: nil, createdAt: Date(), updatedAt: Date(), unreadCount: 0, type: .direct)
    }

    private func mockMessage(_ id: String) -> ChatMessage {
        ChatMessage(id: id, conversationId: "", sender: User(id: 0, email: "", name: "", avatarURL: nil, createdAt: Date(), level: 0, xp: 0, streak: 0, totalLessonsCompleted: 0, achievements: []), content: "", type: .text, attachments: nil, createdAt: Date(), readBy: [], reactions: nil, replyTo: nil)
    }

    // MARK: - WebSocket Setup

    private func setupWebSocket() {
        webSocketTask = Task { [weak self] in
            do {
                // Get current user ID from token manager or auth service
                let userId = await TokenManager.shared.getUserId() ?? "guest"
                try await self?.webSocketManager.connectToChat(userId: userId)
                await MainActor.run {
                    self?.isConnected = true
                }
            } catch {
                await MainActor.run {
                    self?.handleError(error)
                }
            }
        }
    }

    // MARK: - Conversations

    func loadConversations() async {
        isLoading = true
        error = nil

        do {
            _ = try await messagingService.fetchConversations()
        } catch {
            handleError(error)
        }

        isLoading = false
    }
    
    func startDirectMessage(with user: User) async {
        isLoading = true
        error = nil
        
        do {
            // Check if conversation exists
            if let existing = conversations.first(where: { conv in
                conv.type == .direct && conv.participants.contains(where: { $0.id == user.id })
            }) {
                await selectConversation(existing)
            } else {
                let conversation = try await messagingService.createConversation(participantIds: [user.id], name: nil as String?, isGroup: false)
                let mapped = mapConversation(conversation)
                await selectConversation(mapped)
            }
        } catch {
            handleError(error)
        }
        
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

        do {
            _ = try await messagingService.fetchMessages(conversationId: conversation.id)
        } catch {
            handleError(error)
        }

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

        do {
            _ = try await messagingService.sendMessage(conversationId: conversation.id, content: messageContent)
        } catch {
            // Restore the message text so user doesn't lose what they typed
            newMessageText = messageContent
            handleError(error)
        }
    }

    func sendTypingIndicator(isTyping: Bool) {
        // Handled by MessagingService/WebSocket if implemented there
        // For now, minimal local implementation
    }

    private func markMessageAsRead(_ messageId: String) {
        guard let conversation = selectedConversation else { return }
        Task {
            try? await messagingService.markAsRead(conversationId: conversation.id, messageId: messageId)
        }
    }

    private func markConversationAsRead(_ conversation: ChatConversation) {
        // Mark last message as read
        if let lastId = conversation.lastMessage?.id {
            markMessageAsRead(lastId)
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
                if let first = currentGroup.first, let last = currentGroup.last, let sender = currentSender {
                    groups.append(MessageGroup(
                        id: first.id,
                        sender: sender,
                        messages: currentGroup,
                        timestamp: last.createdAt
                    ))
                }
                currentGroup = [message]
                currentSender = message.sender
            }
        }

        // Add last group
        if let first = currentGroup.first, let last = currentGroup.last, let sender = currentSender {
            groups.append(MessageGroup(
                id: first.id,
                sender: sender,
                messages: currentGroup,
                timestamp: last.createdAt
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
        messagingService.unreadCount
    }

    var typingIndicatorText: String {
        return "" // TODO: Implement if needed
    }

    // MARK: - Cleanup

    func disconnect() {
        webSocketTask?.cancel()
        webSocketTask = nil
        webSocketManager.disconnect()
        isConnected = false
    }
}
