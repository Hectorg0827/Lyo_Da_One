import Foundation

// MARK: - UI Stack Item Type

/// Distinct card types for the Stack Panel UI
enum UIStackItemType: String, Codable, CaseIterable {
    case course
    case tutor
    case collab
    case chat
    
    var displayName: String {
        switch self {
        case .course: return "Course"
        case .tutor: return "Tutor"
        case .collab: return "Collab"
        case .chat: return "Chat"
        }
    }
}

// MARK: - UI Stack Item

/// A card in the user's "brain drawer" - represents courses, tutors, collabs, or chats
struct UIStackItem: Identifiable, Codable, Equatable {
    let id: String
    var type: UIStackItemType
    
    var title: String
    var subtitle: String?

    /// The course's own description, when the app has one.
    ///
    /// Optional, and it must stay optional: `UIStackStore` persists this list
    /// as JSON in UserDefaults and its loader drops the whole stack if decoding
    /// fails, so a required field added here would erase every saved course on
    /// first launch after the update.
    ///
    /// Only the backend stack item carries a real description today. Courses
    /// generated in chat carry `objectives`, not prose, so their cards fall
    /// back to the lesson the learner stopped on rather than being given a
    /// description nothing wrote.
    var courseDescription: String?
    
    /// Last updated timestamp for sorting by recency
    var updatedAt: Date
    
    /// Progress (0.0–1.0) - only used for course type
    var progress: Double?
    
    /// Optional context links
    var courseId: String?
    /// A generated review targets one existing mastery concept, even if its
    /// classroom planner creates several practice steps. Optional so saved
    /// cards from earlier app versions decode as ordinary free-topic classes.
    var focusedConcept: Bool?
    var lessonId: String?
    var collabRoomId: String?
    var chatKey: String?
    
    /// Optional metadata
    var lessonCount: Int?
    var completedLessons: Int?
    var participantCount: Int?
    var lastMessage: String?
    
    init(
        id: String = UUID().uuidString,
        type: UIStackItemType,
        title: String,
        subtitle: String? = nil,
        courseDescription: String? = nil,
        updatedAt: Date = Date(),
        progress: Double? = nil,
        courseId: String? = nil,
        focusedConcept: Bool? = nil,
        lessonId: String? = nil,
        collabRoomId: String? = nil,
        chatKey: String? = nil,
        lessonCount: Int? = nil,
        completedLessons: Int? = nil,
        participantCount: Int? = nil,
        lastMessage: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.courseDescription = courseDescription
        self.updatedAt = updatedAt
        self.progress = progress
        self.courseId = courseId
        self.focusedConcept = focusedConcept
        self.lessonId = lessonId
        self.collabRoomId = collabRoomId
        self.chatKey = chatKey
        self.lessonCount = lessonCount
        self.completedLessons = completedLessons
        self.participantCount = participantCount
        self.lastMessage = lastMessage
    }
    
    static func == (lhs: UIStackItem, rhs: UIStackItem) -> Bool {
        lhs.id == rhs.id
    }
}
