import Foundation

// MARK: - Chat Models
/// Models for real-time chat functionality

// MARK: - Chat Conversation
struct ChatConversation: Identifiable, Codable {
    let id: String
    let participants: [User]
    var lastMessage: ChatMessage?
    let createdAt: Date
    var updatedAt: Date
    var unreadCount: Int
    let type: ConversationType

    enum ConversationType: String, Codable {
        case direct = "direct"
        case group = "group"
        case studyGroup = "study_group"
    }

    enum CodingKeys: String, CodingKey {
        case id, participants, lastMessage, createdAt, updatedAt, unreadCount, type
    }

    var otherParticipant: User? {
        // For direct messages, return the other user
        guard type == .direct, participants.count == 2 else { return nil }
        guard let currentUserID = UserSessionManager.shared.currentUserID,
              let userID = Int(currentUserID) else { return participants.first }
        return participants.first { $0.id != userID }
    }

    var displayName: String {
        if let other = otherParticipant {
            return other.name
        }
        return participants.map { $0.name }.joined(separator: ", ")
    }

    var displayAvatar: String? {
        if let other = otherParticipant {
            return other.avatarURL
        }
        return participants.first?.avatarURL
    }
}

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable {
    let id: String
    let conversationId: String
    let sender: User
    let content: String
    let type: MessageType
    let attachments: [SocialMessageAttachment]?
    let createdAt: Date
    var readBy: [String] // User IDs who have read this message
    var reactions: [MessageReaction]?
    let replyTo: String? // Message ID this is replying to

    enum MessageType: String, Codable {
        case text
        case image
        case file
        case voice
        case system
    }

    enum CodingKeys: String, CodingKey {
        case id, conversationId, sender, content, type, attachments, createdAt, readBy, reactions, replyTo
    }

    var isRead: Bool {
        guard let currentUserID = UserSessionManager.shared.currentUserID else { return false }
        return readBy.contains(currentUserID)
    }

    var isFromCurrentUser: Bool {
        guard let currentUserID = UserSessionManager.shared.currentUserID,
              let userID = Int(currentUserID) else { return false }
        return sender.id == userID
    }
}

// MARK: - Message Attachment
struct SocialMessageAttachment: Identifiable, Codable {
    let id: String
    let type: AttachmentType
    let url: String
    let thumbnailURL: String?
    let fileName: String?
    let fileSize: Int?
    let duration: TimeInterval? // For voice messages

    enum AttachmentType: String, Codable {
        case image
        case video
        case document
        case voice
    }

    var displaySize: String? {
        guard let fileSize = fileSize else { return nil }
        let kb = Double(fileSize) / 1024.0
        let mb = kb / 1024.0

        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
}

// MARK: - Message Reaction
struct MessageReaction: Codable {
    let emoji: String
    let userId: String
    let userName: String
}

// MARK: - Typing Indicator
struct TypingIndicator: Codable {
    let userId: String
    let userName: String
    let conversationId: String
    let timestamp: Date
}

// MARK: - Chat Event
enum ChatEvent {
    case messageReceived(ChatMessage)
    case messageRead(messageId: String, userId: String)
    case userTyping(TypingIndicator)
    case userStoppedTyping(userId: String)
    case conversationUpdated(ChatConversation)
    case error(String)
}

// MARK: - Message Group (for UI)
struct MessageGroup: Identifiable {
    let id: String
    let sender: User
    let messages: [ChatMessage]
    let timestamp: Date

    var isFromCurrentUser: Bool {
        guard let currentUserID = UserSessionManager.shared.currentUserID,
              let userID = Int(currentUserID) else { return false }
        return sender.id == userID
    }
}
