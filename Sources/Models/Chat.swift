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
    var uiBlocks: [UIBlock]?

    enum MessageType: String, Codable {
        case text
        case image
        case file
        case voice
        case system
    }

    enum CodingKeys: String, CodingKey {
        case id, conversationId, sender, content, type, attachments, createdAt, readBy, reactions, replyTo, uiBlocks
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

// MARK: - Generative UI Blocks
enum UIBlock: Codable, Identifiable, Equatable {
    case map(lat: Double, lng: Double, title: String, subtitle: String?)
    case image(url: String, altText: String?, aspectRatio: Double?)
    case chart(type: String, data: [ChartDataPoint], title: String?)
    case code(code: String, language: String)
    case interactiveCard(title: String, content: String, actionLabel: String)
    case flashcard(frontText: String, backText: String)
    case media(url: String, mediaType: String)
    case richText(markdownContent: String)
    case fallback(errorMessage: String, rawData: String?)
    case skeletonLoader(expectedType: String)
    case actionGroup(actions: [ActionGroupItem])
    indirect case carousel(items: [UIBlock])
    
    var id: String {
        UUID().uuidString
    }
    
    // MARK: - Custom Decodable for Safety
    
    enum CodingKeys: String, CodingKey {
        case type
        
        // Payload keys
        case mapData = "map_data"
        case imageData = "image_data"
        case chartData = "chart_data"
        case codeData = "code_data"
        case interactiveCardData = "interactive_card_data"
        case flashcardData = "flashcard_data"
        case mediaData = "media_data"
        case richTextData = "rich_text_data"
        case fallbackData = "fallback_data"
        case skeletonLoaderData = "skeleton_loader_data"
        case actionGroupData = "action_group_data"
        case carouselData = "carousel_data"
    }
    
    // Nested decoding structs for payloads to keep it clean
    private struct MapPayload: Codable { let lat: Double; let lng: Double; let title: String; let subtitle: String? }
    private struct ImagePayload: Codable { let url: String; let alt_text: String?; let aspect_ratio: Double? }
    private struct ChartPayload: Codable { let type: String; let data: [ChartDataPoint]; let title: String? }
    private struct CodePayload: Codable { let code: String; let language: String }
    private struct InteractiveCardPayload: Codable { let title: String; let content: String; let action_label: String }
    private struct FlashcardPayload: Codable { let front_text: String; let back_text: String }
    private struct MediaPayload: Codable { let url: String; let media_type: String }
    private struct RichTextPayload: Codable { let markdown_content: String }
    private struct FallbackPayload: Codable { let error_message: String; let raw_data: String? }
    private struct SkeletonPayload: Codable { let expected_type: String }
    private struct ActionGroupPayload: Codable { let actions: [ActionGroupItem] }
    private struct CarouselPayload: Codable { let items: [UIBlock] } // Recursive decode happens here automatically!
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        do {
            switch type {
            case "MAP_BLOCK":
                let data = try container.decode(MapPayload.self, forKey: .mapData)
                self = .map(lat: data.lat, lng: data.lng, title: data.title, subtitle: data.subtitle)
                
            case "IMAGE_BLOCK":
                let data = try container.decode(ImagePayload.self, forKey: .imageData)
                self = .image(url: data.url, altText: data.alt_text, aspectRatio: data.aspect_ratio)
                
            case "CHART_BLOCK":
                let data = try container.decode(ChartPayload.self, forKey: .chartData)
                self = .chart(type: data.type, data: data.data, title: data.title)
                
            case "CODE_BLOCK":
                let data = try container.decode(CodePayload.self, forKey: .codeData)
                self = .code(code: data.code, language: data.language)
                
            case "INTERACTIVE_CARD_BLOCK":
                let data = try container.decode(InteractiveCardPayload.self, forKey: .interactiveCardData)
                self = .interactiveCard(title: data.title, content: data.content, actionLabel: data.action_label)
                
            case "FLASHCARD_BLOCK":
                let data = try container.decode(FlashcardPayload.self, forKey: .flashcardData)
                self = .flashcard(frontText: data.front_text, backText: data.back_text)
                
            case "MEDIA_BLOCK":
                let data = try container.decode(MediaPayload.self, forKey: .mediaData)
                self = .media(url: data.url, mediaType: data.media_type)
                
            case "RICH_TEXT_BLOCK":
                let data = try container.decode(RichTextPayload.self, forKey: .richTextData)
                self = .richText(markdownContent: data.markdown_content)
                
            case "SKELETON_LOADER_BLOCK":
                let data = try container.decode(SkeletonPayload.self, forKey: .skeletonLoaderData)
                self = .skeletonLoader(expectedType: data.expected_type)
                
            case "ACTION_GROUP_BLOCK":
                let data = try container.decode(ActionGroupPayload.self, forKey: .actionGroupData)
                self = .actionGroup(actions: data.actions)
                
            case "CAROUSEL_BLOCK":
                let data = try container.decode(CarouselPayload.self, forKey: .carouselData)
                self = .carousel(items: data.items)
                
            case "FALLBACK_BLOCK":
                let data = try container.decode(FallbackPayload.self, forKey: .fallbackData)
                self = .fallback(errorMessage: data.error_message, rawData: data.raw_data)
                
            default:
                // Unknown type fallback
                self = .fallback(errorMessage: "Unsupported block type: \(type)", rawData: nil)
            }
        } catch {
            // Safety Net: Catch JSON Hallucinations or missing keys and degrade gracefully
            let rawJSON = ["type": type].description // Optional: try to pull raw out
            self = .fallback(errorMessage: "Failed to parse \(type) data.", rawData: rawJSON)
        }
    }
    
    // Required to conform to Encodable explicitly since we wrote init(from:)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .map(let lat, let lng, let title, let subtitle):
            try container.encode("MAP_BLOCK", forKey: .type)
            try container.encode(MapPayload(lat: lat, lng: lng, title: title, subtitle: subtitle), forKey: .mapData)
        case .image(let url, let altText, let aspectRatio):
            try container.encode("IMAGE_BLOCK", forKey: .type)
            try container.encode(ImagePayload(url: url, alt_text: altText, aspect_ratio: aspectRatio), forKey: .imageData)
        case .chart(let type, let data, let title):
            try container.encode("CHART_BLOCK", forKey: .type)
            try container.encode(ChartPayload(type: type, data: data, title: title), forKey: .chartData)
        case .code(let code, let language):
            try container.encode("CODE_BLOCK", forKey: .type)
            try container.encode(CodePayload(code: code, language: language), forKey: .codeData)
        case .interactiveCard(let title, let content, let actionLabel):
            try container.encode("INTERACTIVE_CARD_BLOCK", forKey: .type)
            try container.encode(InteractiveCardPayload(title: title, content: content, action_label: actionLabel), forKey: .interactiveCardData)
        case .flashcard(let frontText, let backText):
            try container.encode("FLASHCARD_BLOCK", forKey: .type)
            try container.encode(FlashcardPayload(front_text: frontText, back_text: backText), forKey: .flashcardData)
        case .media(let url, let mediaType):
            try container.encode("MEDIA_BLOCK", forKey: .type)
            try container.encode(MediaPayload(url: url, media_type: mediaType), forKey: .mediaData)
        case .richText(let content):
            try container.encode("RICH_TEXT_BLOCK", forKey: .type)
            try container.encode(RichTextPayload(markdown_content: content), forKey: .richTextData)
        case .fallback(let error, let raw):
            try container.encode("FALLBACK_BLOCK", forKey: .type)
            try container.encode(FallbackPayload(error_message: error, raw_data: raw), forKey: .fallbackData)
        case .skeletonLoader(let type):
            try container.encode("SKELETON_LOADER_BLOCK", forKey: .type)
            try container.encode(SkeletonPayload(expected_type: type), forKey: .skeletonLoaderData)
        case .actionGroup(let actions):
            try container.encode("ACTION_GROUP_BLOCK", forKey: .type)
            try container.encode(ActionGroupPayload(actions: actions), forKey: .actionGroupData)
        case .carousel(let items):
            try container.encode("CAROUSEL_BLOCK", forKey: .type)
            try container.encode(CarouselPayload(items: items), forKey: .carouselData)
        }
    }
}

struct ActionGroupItem: Codable, Equatable {
    let id: String?
    let label: String
    let action: String
}

struct ChartDataPoint: Codable, Identifiable, Equatable {
    let id: UUID
    let label: String
    let value: Double
    
    init(id: UUID = UUID(), label: String, value: Double) {
        self.id = id
        self.label = label
        self.value = value
    }
    
    enum CodingKeys: String, CodingKey {
        case id, label, value
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
