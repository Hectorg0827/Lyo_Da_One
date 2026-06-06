//
//  UnifiedChatPersistence.swift
//  Lyo
//
//  Handles saving and loading chat conversations to local storage
//

import Foundation

@MainActor
final class UnifiedChatPersistence {
    static let shared = UnifiedChatPersistence()
    
    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "lyo_unified_conversations"
    private let maxConversations = 50 // Keep last 50 conversations
    
    private init() {}
    
    // MARK: - Save Conversation
    
    func saveConversation(_ conversation: SavedConversation) async {
        var conversations = await loadAllConversations()
        
        // Update or add
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        
        // Trim to max
        if conversations.count > maxConversations {
            conversations = Array(conversations.prefix(maxConversations))
        }
        
        // Sort by updated date
        conversations.sort(by: { (a: SavedConversation, b: SavedConversation) -> Bool in
            a.lastUpdated > b.lastUpdated
        })
        
        // Save
        if let data = try? JSONEncoder().encode(conversations) {
            userDefaults.set(data, forKey: conversationsKey)
        }
    }
    
    // MARK: - Load Conversations
    
    func loadConversation(id: String) async -> SavedConversation? {
        let conversations = await loadAllConversations()
        return conversations.first { $0.id == id }
    }
    
    func loadLastConversation() async -> SavedConversation? {
        let conversations = await loadAllConversations()
        return conversations.first
    }
    
    func loadAllConversations() async -> [SavedConversation] {
        guard let data = userDefaults.data(forKey: conversationsKey),
              let conversations = try? JSONDecoder().decode([SavedConversation].self, from: data) else {
            return []
        }
        return conversations
    }
    
    // MARK: - Delete Conversation
    
    func deleteConversation(id: String) async {
        var conversations = await loadAllConversations()
        conversations.removeAll { $0.id == id }
        
        if let data = try? JSONEncoder().encode(conversations) {
            userDefaults.set(data, forKey: conversationsKey)
        }
    }
    
    // MARK: - Clear All
    
    func clearAllConversations() {
        userDefaults.removeObject(forKey: conversationsKey)
    }
}
