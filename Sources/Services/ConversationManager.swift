//
//  ConversationManager.swift
//  Lyo
//
//  Service for managing and persisting chat conversations
//

import Foundation
import SwiftUI
import os

// NetworkClient.request<T: Codable> needs both directions, so these are
// Codable even though the app only ever decodes them.
private struct ServerConversationList: Codable {
    let conversations: [ServerConversationSummary]
}

private struct ServerConversationSummary: Codable {
    let id: String
    let title: String
    let messageCount: Int
    let lastMessagePreview: String?
    let createdAt: Date
    let updatedAt: Date
}

private struct ServerConversationMessage: Codable {
    let id: String
    let role: String
    let content: String
    let createdAt: Date
}

private struct ServerConversationDetail: Codable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [ServerConversationMessage]
}

private struct ServerConversationUpdate: Encodable {
    let title: String?
    let isActive: Bool?
}

/// Represents a saved conversation
struct SavedConversation: Identifiable, Codable {
    let id: String
    var title: String
    var lastMessagePreview: String
    var lastUpdated: Date
    var messageCount: Int
    var messages: [MultimodalMessage]
    
    init(
        id: String = UUID().uuidString,
        title: String,
        lastMessagePreview: String,
        lastUpdated: Date = Date(),
        messageCount: Int,
        messages: [MultimodalMessage] = []
    ) {
        self.id = id
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.lastUpdated = lastUpdated
        self.messageCount = messageCount
        self.messages = messages
    }
    
    /// Generate a title from the first user message
    static func generateTitle(from messages: [MultimodalMessage]) -> String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let preview = firstUserMessage.content.prefix(50)
            return String(preview)
        }
        return "New Conversation"
    }
    
    /// Get last message preview
    static func getLastMessagePreview(from messages: [MultimodalMessage]) -> String {
        if let lastMessage = messages.last {
            let preview = lastMessage.content.prefix(60)
            return String(preview)
        }
        return "No messages yet"
    }
}

/// Service for managing conversations
@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    // MARK: - Published State
    @Published var conversations: [SavedConversation] = []
    @Published var currentConversation: SavedConversation?
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "saved_conversations"
    private let currentConversationKey = "current_conversation_id"
    
    private init() {
        loadConversations()
        Task { await refreshFromServer() }
    }
    
    // MARK: - Conversation Management
    
    /// Create a new conversation (Ephemeral until Used)
    func createNewConversation() -> SavedConversation {
        let conversation = SavedConversation(
            title: "New Conversation",
            lastMessagePreview: "Start chatting...",
            messageCount: 0,
            messages: []
        )
        
        // Add welcome message
        let welcomeMessage = MultimodalMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "Hello! I'm Lyo, your AI learning assistant. I can help you with courses, studying, quizzes, tutoring, and more. What would you like to learn today?",
            attachments: [],
            timestamp: Date()
        )
        
        var newConv = conversation
        newConv.messages = [welcomeMessage]
        
        // Set as current but DO NOT add to saved list yet
        currentConversation = newConv
        
        // Sync with UnifiedChatService for session isolation
        Task { @MainActor in
            UnifiedChatService.shared.startNewChat(withId: newConv.id)
        }
        
        return newConv
    }
    
    /// Save a conversation
    func saveConversation(_ conversation: SavedConversation) {
        // Update or add to conversations list
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
        
        // Sort by last updated (most recent first)
        conversations.sort { $0.lastUpdated > $1.lastUpdated }
        
        // Persist to storage
        persistConversations()
    }

    /// Replace a provisional device UUID with the canonical server UUID.
    /// This prevents one first message from appearing as two conversations.
    func adoptCanonicalId(_ canonicalId: String, replacing localId: String) {
        guard canonicalId != localId else { return }
        conversations.removeAll { $0.id == localId }
        if let current = currentConversation, current.id == localId {
            currentConversation = SavedConversation(
                id: canonicalId,
                title: current.title,
                lastMessagePreview: current.lastMessagePreview,
                lastUpdated: current.lastUpdated,
                messageCount: current.messageCount,
                messages: current.messages
            )
        }
        userDefaults.set(canonicalId, forKey: currentConversationKey)
        persistConversations()
    }
    
    /// Update current conversation with new messages
    func updateCurrentConversation(with messages: [MultimodalMessage]) {
        guard var conversation = currentConversation else { return }
        
        conversation.messages = messages
        conversation.messageCount = messages.count
        conversation.lastUpdated = Date()
        
        // Update title if it's still default
        if conversation.title == "New Conversation" && messages.count > 1 {
            conversation.title = SavedConversation.generateTitle(from: messages)
        }
        
        // Update preview
        conversation.lastMessagePreview = SavedConversation.getLastMessagePreview(from: messages)
        
        currentConversation = conversation
        
        // Only save to persistence if we have user messages (not just welcome)
        let hasUserMessage = messages.contains(where: { $0.role == .user })
        if hasUserMessage {
            saveConversation(conversation)
        }
    }
    
    /// Load a specific conversation
    func loadConversation(_ conversation: SavedConversation) {
        currentConversation = conversation
        userDefaults.set(conversation.id, forKey: currentConversationKey)
        
        // Sync with UnifiedChatService for session context
        Task { @MainActor in
            UnifiedChatService.shared.loadConversation(conversation)
        }

        if conversation.messages.isEmpty {
            Task { await hydrateConversation(id: conversation.id) }
        }
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: SavedConversation) {
        conversations.removeAll { $0.id == conversation.id }
        persistConversations()
        
        // If deleted conversation was current, create new one
        if currentConversation?.id == conversation.id {
            _ = createNewConversation()
        }

        Task {
            let endpoint = DynamicEndpoint(
                urlString: "/api/v1/chat/conversations/\(conversation.id)",
                method: .delete,
                requiresAuth: true
            )
            let _: EmptyResponse? = try? await NetworkClient.shared.request(endpoint)
        }
    }
    
    /// Rename a conversation
    func renameConversation(_ conversation: SavedConversation, newTitle: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index].title = newTitle
        
        if currentConversation?.id == conversation.id {
            currentConversation?.title = newTitle
        }
        
        persistConversations()
        Task {
            let endpoint = DynamicEndpoint(
                urlString: "/api/v1/chat/conversations/\(conversation.id)",
                method: .patch,
                body: ServerConversationUpdate(title: newTitle, isActive: nil),
                requiresAuth: true
            )
            let _: ServerConversationSummary? = try? await NetworkClient.shared.request(endpoint)
        }
    }

    /// Replace stale device-local cache with the authenticated server history.
    /// Local storage remains an offline cache, never the cross-device source of truth.
    func refreshFromServer() async {
        do {
            let endpoint = DynamicEndpoint(
                urlString: "/api/v1/chat/conversations?limit=30",
                method: .get,
                requiresAuth: true
            )
            let response: ServerConversationList = try await NetworkClient.shared.request(endpoint)
            let serverRows = response.conversations.map { summary in
                SavedConversation(
                    id: summary.id,
                    title: summary.title,
                    lastMessagePreview: summary.lastMessagePreview ?? "No messages yet",
                    lastUpdated: summary.updatedAt,
                    messageCount: summary.messageCount,
                    messages: []
                )
            }
            guard !serverRows.isEmpty else { return }

            let localById = Dictionary(uniqueKeysWithValues: conversations.map { ($0.id, $0) })
            conversations = serverRows.map { row in
                guard let cached = localById[row.id], !cached.messages.isEmpty else { return row }
                return SavedConversation(
                    id: row.id,
                    title: row.title,
                    lastMessagePreview: row.lastMessagePreview,
                    lastUpdated: row.lastUpdated,
                    messageCount: row.messageCount,
                    messages: cached.messages
                )
            }
            persistConversations()

            if let latest = conversations.first {
                await hydrateConversation(id: latest.id)
            }
        } catch {
            Log.net.warning("Server chat history unavailable; using offline cache: \(error)")
        }
    }

    private func hydrateConversation(id: String) async {
        do {
            let endpoint = DynamicEndpoint(
                urlString: "/api/v1/chat/conversations/\(id)?limit=200",
                method: .get,
                requiresAuth: true
            )
            let detail: ServerConversationDetail = try await NetworkClient.shared.request(endpoint)
            let messages = detail.messages.map { message in
                MultimodalMessage(
                    id: message.id,
                    sessionId: detail.id,
                    role: MultimodalMessage.MessageRole(rawValue: message.role) ?? .assistant,
                    content: message.content,
                    timestamp: message.createdAt
                )
            }
            let hydrated = SavedConversation(
                id: detail.id,
                title: detail.title,
                lastMessagePreview: SavedConversation.getLastMessagePreview(from: messages),
                lastUpdated: detail.updatedAt,
                messageCount: messages.count,
                messages: messages
            )
            if let index = conversations.firstIndex(where: { $0.id == id }) {
                conversations[index] = hydrated
            } else {
                conversations.insert(hydrated, at: 0)
            }
            currentConversation = hydrated
            persistConversations()
            UnifiedChatService.shared.loadConversation(hydrated)
        } catch {
            Log.net.warning("Could not hydrate server conversation \(id): \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func persistConversations() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            userDefaults.set(data, forKey: conversationsKey)
        } catch {
            Log.net.error("Failed to persist conversations: \(error)")
        }
    }
    
    private func loadConversations() {
        guard let data = userDefaults.data(forKey: conversationsKey) else {
            // No saved conversations - create a new one
            _ = createNewConversation()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            conversations = try decoder.decode([SavedConversation].self, from: data)
            
            // ALWAYS finish loading by starting a NEW chat on launch
            // We ignore the stored `current_conversation_id` so the user starts fresh
            _ = createNewConversation()
            
        } catch {
            Log.net.error("Failed to load conversations: \(error)")
            // Create new conversation on error
            _ = createNewConversation()
        }
    }
    
    /// Clear all conversations (for testing/reset)
    func clearAllConversations() {
        conversations.removeAll()
        persistConversations()
        _ = createNewConversation()
    }
}
