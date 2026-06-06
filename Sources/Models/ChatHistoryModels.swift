import Foundation
import SwiftData

// MARK: - Chat Folder Model
@available(iOS 17.0, *)
@Model
class ChatFolder {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder"
    var createdAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade) var sessions: [ChatSession]? = []
    
    init(id: UUID = UUID(), name: String, icon: String = "folder") {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdAt = Date()
    }
}

// MARK: - Chat Session Model
@available(iOS 17.0, *)
@Model
class ChatSession {
    var id: UUID = UUID()
    var title: String = ""
    var lastMessage: String = ""
    var timestamp: Date = Date()
    var isPinned: Bool = false
    
    // Relationships
    var folder: ChatFolder?
    @Relationship(deleteRule: .cascade) var messages: [PersistedChatMessage] = []
    
    init(id: UUID = UUID(), title: String, lastMessage: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
}

// MARK: - Chat Message Model
@available(iOS 17.0, *)
@Model
class PersistedChatMessage {
    var id: UUID = UUID()
    var text: String = ""
    var isUser: Bool = false
    var timestamp: Date = Date()
    
    // Relationship
    var session: ChatSession?
    
    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
