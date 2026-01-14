//
//  ConversationManager.swift
//  Lyo
//
//  Service for managing and persisting chat conversations
//

import Foundation
import SwiftUI

/// Represents a saved conversation
struct SavedConversation: Identifiable, Codable {
    let id: String
    let title: String
    let lastMessagePreview: String
    let lastUpdated: Date
    let messageCount: Int
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
    }
    
    // MARK: - Conversation Management
    
    /// Create a new conversation
    func createNewConversation() -> SavedConversation {
        let conversation = SavedConversation(
            title: "New Conversation",
            lastMessagePreview: "Start chatting...",
            messageCount: 0,
            messages: []
        )
        
        // Add welcome message
        let welcomeMessage = MultimodalMessage(
            id: UUID(),
            role: .assistant,
            content: "Hello! I'm Lyo, your AI learning assistant. I can help you with courses, studying, quizzes, tutoring, and more. What would you like to learn today?",
            timestamp: Date(),
            attachments: []
        )
        
        var newConv = conversation
        newConv.messages = [welcomeMessage]
        
        currentConversation = newConv
        saveConversation(newConv)
        
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
        saveConversation(conversation)
    }
    
    /// Load a specific conversation
    func loadConversation(_ conversation: SavedConversation) {
        currentConversation = conversation
        userDefaults.set(conversation.id, forKey: currentConversationKey)
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: SavedConversation) {
        conversations.removeAll { $0.id == conversation.id }
        persistConversations()
        
        // If deleted conversation was current, create new one
        if currentConversation?.id == conversation.id {
            _ = createNewConversation()
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
    }
    
    // MARK: - Persistence
    
    private func persistConversations() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            userDefaults.set(data, forKey: conversationsKey)
        } catch {
            print("❌ Failed to persist conversations: \(error)")
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
            
            // Load current conversation
            if let currentId = userDefaults.string(forKey: currentConversationKey),
               let conversation = conversations.first(where: { $0.id == currentId }) {
                currentConversation = conversation
            } else if let first = conversations.first {
                currentConversation = first
            } else {
                _ = createNewConversation()
            }
        } catch {
            print("❌ Failed to load conversations: \(error)")
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
