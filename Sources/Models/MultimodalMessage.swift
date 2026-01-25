//
//  MultimodalMessage.swift
//  Lyo
//
//  Multimodal message types for rich AI chat experience
//

import Foundation

// MARK: - Message Content Types

/// Represents different types of content that can be sent or received in chat
enum MessageContentType: Codable, Equatable {
    case text
    case image(url: String, caption: String?)
    case audio(url: String, duration: TimeInterval, transcript: String?)
    case video(url: String, thumbnail: String?, duration: TimeInterval)
    case file(url: String, name: String, mimeType: String, size: Int64)
    case codeSnippet(language: String, code: String)
    case quiz(question: String, options: [String], correctIndex: Int, explanation: String?)
    case courseCard(courseId: String, title: String, subtitle: String?, thumbnail: String?)
    case poll(question: String, options: [String], votes: [Int]?)
    case richCard(title: String, body: String, imageURL: String?, actions: [CardAction]?)
    case processing(step: String, progress: Double?)
    case topicSelection(title: String, topics: [TopicOption])
    case courseRoadmap(title: String, modules: [CourseModule], totalModules: Int, completedModules: Int)
    case flashcards(title: String, cards: [Flashcard])
    case suggestions(title: String, options: [String])
    case recursiveUI(component: DynamicComponent)
    case a2ui(component: A2UIComponent)
    
    enum CodingKeys: String, CodingKey {
        case type, url, caption, duration, transcript, thumbnail, name, mimeType, size
        case language, code, question, options, correctIndex, explanation
        case courseId, title, subtitle, body, imageURL, actions, votes
        case step, progress, topics
        case modules, totalModules, completedModules
        case cards, component
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            self = .text
        case "image":
            let url = try container.decode(String.self, forKey: .url)
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .image(url: url, caption: caption)
        case "audio":
            let url = try container.decode(String.self, forKey: .url)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            let transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
            self = .audio(url: url, duration: duration, transcript: transcript)
        case "video":
            let url = try container.decode(String.self, forKey: .url)
            let thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .video(url: url, thumbnail: thumbnail, duration: duration)
        case "file":
            let url = try container.decode(String.self, forKey: .url)
            let name = try container.decode(String.self, forKey: .name)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let size = try container.decode(Int64.self, forKey: .size)
            self = .file(url: url, name: name, mimeType: mimeType, size: size)
        case "code":
            let language = try container.decode(String.self, forKey: .language)
            let code = try container.decode(String.self, forKey: .code)
            self = .codeSnippet(language: language, code: code)
        case "quiz":
            let question = try container.decode(String.self, forKey: .question)
            let options = try container.decode([String].self, forKey: .options)
            let correctIndex = try container.decode(Int.self, forKey: .correctIndex)
            let explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
            self = .quiz(question: question, options: options, correctIndex: correctIndex, explanation: explanation)
        case "course_card":
            let courseId = try container.decode(String.self, forKey: .courseId)
            let title = try container.decode(String.self, forKey: .title)
            let subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            let thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
            self = .courseCard(courseId: courseId, title: title, subtitle: subtitle, thumbnail: thumbnail)
        case "poll":
            let question = try container.decode(String.self, forKey: .question)
            let options = try container.decode([String].self, forKey: .options)
            let votes = try container.decodeIfPresent([Int].self, forKey: .votes)
            self = .poll(question: question, options: options, votes: votes)
        case "rich_card":
            let title = try container.decode(String.self, forKey: .title)
            let body = try container.decode(String.self, forKey: .body)
            let imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
            let actions = try container.decodeIfPresent([CardAction].self, forKey: .actions)
            self = .richCard(title: title, body: body, imageURL: imageURL, actions: actions)
        case "processing":
            let step = try container.decode(String.self, forKey: .step)
            let progress = try container.decodeIfPresent(Double.self, forKey: .progress)
            self = .processing(step: step, progress: progress)
        case "topic_selection":
            let title = try container.decode(String.self, forKey: .title)
            let topics = try container.decode([TopicOption].self, forKey: .topics)
            self = .topicSelection(title: title, topics: topics)
        case "course_roadmap":
            let title = try container.decode(String.self, forKey: .title)
            let modules = try container.decode([CourseModule].self, forKey: .modules)
            let total = try container.decode(Int.self, forKey: .totalModules)
            let completed = try container.decode(Int.self, forKey: .completedModules)
            self = .courseRoadmap(title: title, modules: modules, totalModules: total, completedModules: completed)
        case "flashcards":
            let title = try container.decode(String.self, forKey: .title)
            let cards = try container.decode([Flashcard].self, forKey: .cards)
            self = .flashcards(title: title, cards: cards)
        case "suggestions":
            let title = try container.decode(String.self, forKey: .title)
            let options = try container.decode([String].self, forKey: .options)
            self = .suggestions(title: title, options: options)
        case "recursive_ui":
            let component = try container.decode(DynamicComponent.self, forKey: .component)
            self = .recursiveUI(component: component)
        case "a2ui":
            let component = try container.decode(A2UIComponent.self, forKey: .component)
            self = .a2ui(component: component)
        default:
            self = .text
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text:
            try container.encode("text", forKey: .type)
        case .image(let url, let caption):
            try container.encode("image", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encodeIfPresent(caption, forKey: .caption)
        case .audio(let url, let duration, let transcript):
            try container.encode("audio", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encode(duration, forKey: .duration)
            try container.encodeIfPresent(transcript, forKey: .transcript)
        case .video(let url, let thumbnail, let duration):
            try container.encode("video", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
            try container.encode(duration, forKey: .duration)
        case .file(let url, let name, let mimeType, let size):
            try container.encode("file", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encode(name, forKey: .name)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encode(size, forKey: .size)
        case .codeSnippet(let language, let code):
            try container.encode("code", forKey: .type)
            try container.encode(language, forKey: .language)
            try container.encode(code, forKey: .code)
        case .quiz(let question, let options, let correctIndex, let explanation):
            try container.encode("quiz", forKey: .type)
            try container.encode(question, forKey: .question)
            try container.encode(options, forKey: .options)
            try container.encode(correctIndex, forKey: .correctIndex)
            try container.encodeIfPresent(explanation, forKey: .explanation)
        case .courseCard(let courseId, let title, let subtitle, let thumbnail):
            try container.encode("course_card", forKey: .type)
            try container.encode(courseId, forKey: .courseId)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(subtitle, forKey: .subtitle)
            try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        case .poll(let question, let options, let votes):
            try container.encode("poll", forKey: .type)
            try container.encode(question, forKey: .question)
            try container.encode(options, forKey: .options)
            try container.encodeIfPresent(votes, forKey: .votes)
        case .richCard(let title, let body, let imageURL, let actions):
            try container.encode("rich_card", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(body, forKey: .body)
            try container.encodeIfPresent(imageURL, forKey: .imageURL)
            try container.encodeIfPresent(actions, forKey: .actions)
        case .processing(let step, let progress):
            try container.encode("processing", forKey: .type)
            try container.encode(step, forKey: .step)
            try container.encodeIfPresent(progress, forKey: .progress)
        case .topicSelection(let title, let topics):
            try container.encode("topic_selection", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(topics, forKey: .topics)
        case .courseRoadmap(let title, let modules, let total, let completed):
            try container.encode("course_roadmap", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(modules, forKey: .modules)
            try container.encode(total, forKey: .totalModules)
            try container.encode(completed, forKey: .completedModules)
        case .flashcards(let title, let cards):
            try container.encode("flashcards", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(cards, forKey: .cards)
        case .suggestions(let title, let options):
            try container.encode("suggestions", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(options, forKey: .options)
        case .recursiveUI(let component):
            try container.encode("recursive_ui", forKey: .type)
            try container.encode(component, forKey: .component)
        case .a2ui(let component):
            try container.encode("a2ui", forKey: .type)
            try container.encode(component, forKey: .component)
        }
    }
    
    static func == (lhs: MessageContentType, rhs: MessageContentType) -> Bool {
        switch (lhs, rhs) {
        case (.text, .text): return true
        case (.image(let u1, let c1), .image(let u2, let c2)): return u1 == u2 && c1 == c2
        case (.audio(let u1, let d1, let t1), .audio(let u2, let d2, let t2)): return u1 == u2 && d1 == d2 && t1 == t2
        case (.video(let u1, let t1, let d1), .video(let u2, let t2, let d2)): return u1 == u2 && t1 == t2 && d1 == d2
        case (.file(let u1, let n1, let m1, let s1), .file(let u2, let n2, let m2, let s2)): return u1 == u2 && n1 == n2 && m1 == m2 && s1 == s2
        case (.codeSnippet(let l1, let c1), .codeSnippet(let l2, let c2)): return l1 == l2 && c1 == c2
        case (.quiz(let q1, let o1, let c1, let e1), .quiz(let q2, let o2, let c2, let e2)): return q1 == q2 && o1 == o2 && c1 == c2 && e1 == e2
        case (.courseCard(let i1, let t1, let s1, let th1), .courseCard(let i2, let t2, let s2, let th2)): return i1 == i2 && t1 == t2 && s1 == s2 && th1 == th2
        case (.poll(let q1, let o1, let v1), .poll(let q2, let o2, let v2)): return q1 == q2 && o1 == o2 && v1 == v2
        case (.richCard(let t1, let b1, let i1, let a1), .richCard(let t2, let b2, let i2, let a2)): return t1 == t2 && b1 == b2 && i1 == i2 && a1 == a2
        case (.processing(let s1, let p1), .processing(let s2, let p2)): return s1 == s2 && p1 == p2
        case (.topicSelection(let t1, let to1), .topicSelection(let t2, let to2)): return t1 == t2 && to1 == to2
        case (.courseRoadmap(let t1, let m1, let tm1, let cm1), .courseRoadmap(let t2, let m2, let tm2, let cm2)): return t1 == t2 && m1 == m2 && tm1 == tm2 && cm1 == cm2
        case (.flashcards(let t1, let c1), .flashcards(let t2, let c2)): return t1 == t2 && c1 == c2
        case (.suggestions(let t1, let o1), .suggestions(let t2, let o2)): return t1 == t2 && o1 == o2
        case (.recursiveUI(let c1), .recursiveUI(let c2)): return c1.id == c2.id
        default: return false
        }
    }
}

// MARK: - Card Action

/// Action button for rich cards
struct CardAction: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let actionType: String // "open_url", "send_message", "open_course", etc.
    let payload: String?
    
    init(id: String = UUID().uuidString, label: String, actionType: String, payload: String? = nil) {
        self.id = id
        self.label = label
        self.actionType = actionType
        self.payload = payload
    }
}

// MARK: - Chat Attachment

/// Attachment for multimodal messages
struct ChatAttachment: Identifiable, Equatable, Codable {
    let id: String
    let type: AttachmentType
    var url: String?
    var localURL: URL?
    let name: String
    let mimeType: String
    let size: Int64
    var thumbnail: String?
    var uploadProgress: Double?
    var isUploading: Bool
    

    
    init(id: String = UUID().uuidString,
         type: AttachmentType,
         url: String? = nil,
         localURL: URL? = nil,
         name: String,
         mimeType: String,
         size: Int64,
         thumbnail: String? = nil,
         uploadProgress: Double? = nil,
         isUploading: Bool = false) {
        self.id = id
        self.type = type
        self.url = url
        self.localURL = localURL
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.thumbnail = thumbnail
        self.uploadProgress = uploadProgress
        self.isUploading = isUploading
    }
}

// MARK: - Multimodal Message

/// Enhanced message model with multimodal support
struct MultimodalMessage: Identifiable, Equatable, Codable {
    let id: String
    // Added session ID for isolating chat contexts
    var sessionId: String?
    let role: MessageRole
    var content: String
    var contentTypes: [MessageContentType]
    var attachments: [ChatAttachment]
    let timestamp: Date
    var isStreaming: Bool
    var metadata: MessageMetadata?
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    struct MessageMetadata: Equatable, Codable {
        var aiSource: String?
        var responseTimeMs: Double?
        var tokensUsed: Int?
        var isVoiceInput: Bool?
        var voiceTranscript: String?
    }
    
    init(id: String = UUID().uuidString,
         sessionId: String? = nil,
         role: MessageRole,
         content: String,
         contentTypes: [MessageContentType] = [.text],
         attachments: [ChatAttachment] = [],
         timestamp: Date = Date(),
         isStreaming: Bool = false,
         metadata: MessageMetadata? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.contentTypes = contentTypes
        self.attachments = attachments
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.metadata = metadata
    }
    
    var isFromUser: Bool { role == .user }
    
    // Convert from legacy LyoMessage
    init(from legacyMessage: LyoMessage) {
        self.id = legacyMessage.id
        self.role = legacyMessage.isFromUser ? .user : .assistant
        self.content = legacyMessage.content
        self.contentTypes = [.text]
        self.attachments = legacyMessage.attachments?.compactMap { attachment in
            ChatAttachment(
                id: attachment.id,
                type: attachment.type,
                url: attachment.url,
                localURL: nil,
                name: attachment.filename ?? "File",
                mimeType: attachment.mimeType ?? "application/octet-stream",
                size: Int64(attachment.size ?? 0),
                thumbnail: nil
            )
        } ?? []
        self.timestamp = legacyMessage.timestamp
        self.isStreaming = false
        self.metadata = nil
    }
}

// MARK: - Convenience Extensions

extension MultimodalMessage {
    /// Create a user text message
    static func userText(_ text: String, attachments: [ChatAttachment] = [], isVoiceInput: Bool = false) -> MultimodalMessage {
        MultimodalMessage(
            role: .user,
            content: text,
            contentTypes: [.text],
            attachments: attachments,
            metadata: isVoiceInput ? MessageMetadata(isVoiceInput: true) : nil
        )
    }
    
    /// Create an assistant text message
    static func assistantText(_ text: String, isStreaming: Bool = false) -> MultimodalMessage {
        MultimodalMessage(
            role: .assistant,
            content: text,
            contentTypes: [.text],
            isStreaming: isStreaming
        )
    }
    
    /// Create a message with a quiz
    static func quiz(question: String, options: [String], correctIndex: Int, explanation: String? = nil) -> MultimodalMessage {
        MultimodalMessage(
            role: .assistant,
            content: question,
            contentTypes: [.quiz(question: question, options: options, correctIndex: correctIndex, explanation: explanation)]
        )
    }
    
    /// Create a message with a course card
    static func courseCard(courseId: String, title: String, subtitle: String?, thumbnail: String?) -> MultimodalMessage {
        MultimodalMessage(
            role: .assistant,
            content: "Here's a course for you:",
            contentTypes: [.courseCard(courseId: courseId, title: title, subtitle: subtitle, thumbnail: thumbnail)]
        )
    }
}

// MARK: - Content Type Helper Structs

/// Helper struct for code snippet content used by bubble views
struct CodeSnippetContent {
    let language: String
    let code: String
    
    init(language: String, code: String) {
        self.language = language
        self.code = code
    }
}

/// Helper struct for quiz content used by bubble views
struct QuizContent {
    let question: String
    let options: [String]
    let correctAnswer: Int
    let explanation: String?
    var selectedAnswer: Int?
    
    init(question: String, options: [String], correctAnswer: Int, explanation: String?, selectedAnswer: Int? = nil) {
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.selectedAnswer = selectedAnswer
    }
}

/// Helper struct for course card content used by bubble views
struct CourseCardContent {
    let courseId: String
    let title: String
    let description: String?
    let thumbnail: URL?
    let duration: String?
    
    init(courseId: String, title: String, description: String?, thumbnail: URL?, duration: String?) {
        self.courseId = courseId
        self.title = title
        self.description = description
        self.thumbnail = thumbnail
        self.duration = duration
    }
}

/// Helper struct for poll content used by bubble views
struct PollContent {
    let question: String
    let options: [String]
    let votes: [Int]
    
    init(question: String, options: [String], votes: [Int]) {
        self.question = question
        self.options = options
        self.votes = votes
    }
}

/// Helper struct for rich card content used by bubble views
struct RichCardContent {
    let title: String
    let body: String
    let imageURL: URL?
    let actions: [CardAction]?
    
    init(title: String, body: String, imageURL: URL?, actions: [CardAction]?) {
        self.title = title
        self.body = body
        self.imageURL = imageURL
        self.actions = actions
    }
}

/// Option for topic selection widget
struct TopicOption: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let icon: String // System image name or emoji
    let gradientColors: [String]? // Hex codes for gradient
    
    init(id: String = UUID().uuidString, title: String, icon: String, gradientColors: [String]? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.gradientColors = gradientColors
    }
}

/// Payload for Quiz widget
struct QuizPayload: Codable, Equatable {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String?
}

/// Payload for Course Roadmap widget
struct CourseRoadmapPayload: Codable, Equatable {
    let title: String
    let modules: [CourseModule]
    let totalModules: Int
    let completedModules: Int
}

/// Module info for course roadmap widget
struct CourseModule: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let duration: String?
    let isCompleted: Bool
    let isLocked: Bool
    
    init(id: String = UUID().uuidString, title: String, duration: String?, isCompleted: Bool = false, isLocked: Bool = false) {
        self.id = id
        self.title = title
        self.duration = duration
        self.isCompleted = isCompleted
        self.isLocked = isLocked
    }
}

/// Flashcard for study mode widget
struct Flashcard: Codable, Identifiable, Equatable {
    let id: String
    let front: String
    let back: String
    var isMastered: Bool
    
    init(id: String = UUID().uuidString, front: String, back: String, isMastered: Bool = false) {
        self.id = id
        self.front = front
        self.back = back
        self.isMastered = isMastered
    }
}

// MARK: - A2UI Recursive Types (Moved for build fix)

// MARK: - Component Types
enum UIComponentType: String, Codable, CaseIterable {
    case vstack, hstack, card
    case text, button, image, divider, spacer
    case quiz, courseRoadmap = "course_roadmap"
    case coursePreview = "course_preview"
    case learningNode = "learning_node"
    case progressTracker = "progress_tracker"
    case interactiveLesson = "interactive_lesson"
    
    // Standard A2UI Components
    case lessonCard = "lessoncard"
    case courseCard = "coursecard"
    case progressBar = "progressbar"
}

// MARK: - Polymorphic Component Wrapper
struct DynamicComponent: Identifiable, Codable {
    let id: String
    let type: UIComponentType
    let payload: ComponentPayload

    enum CodingKeys: String, CodingKey { case id, type }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(UIComponentType.self, forKey: .type)

        switch type {
        case .vstack: payload = .vstack(try VStackPayload(from: decoder))
        case .hstack: payload = .hstack(try HStackPayload(from: decoder))
        case .card: payload = .card(try CardPayload(from: decoder))
        case .text: payload = .text(try TextPayload(from: decoder))
        case .button: payload = .button(try ButtonPayload(from: decoder))
        case .image: payload = .image(try ImagePayload(from: decoder))
        case .divider: payload = .divider(try DividerPayload(from: decoder))
        case .spacer: payload = .spacer(try SpacerPayload(from: decoder))
        case .quiz: payload = .quiz(try A2UIQuizPayload(from: decoder))
        case .courseRoadmap: payload = .courseRoadmap(try A2UICourseRoadmapPayload(from: decoder))
        case .coursePreview: payload = .coursePreview(try CoursePreviewPayload(from: decoder))
        case .learningNode: payload = .learningNode(try LearningNodePayload(from: decoder))
        case .progressTracker: payload = .progressTracker(try ProgressTrackerPayload(from: decoder))
        case .interactiveLesson: payload = .interactiveLesson(try InteractiveLessonPayload(from: decoder))
        case .lessonCard: payload = .lessonCard(try LessonCardPayload(from: decoder))
        case .courseCard: payload = .courseCard(try A2UICourseCardPayload(from: decoder))
        case .progressBar: payload = .progressBar(try ProgressBarPayload(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)

        switch payload {
        case .vstack(let data): try data.encode(to: encoder)
        case .hstack(let data): try data.encode(to: encoder)
        case .card(let data): try data.encode(to: encoder)
        case .text(let data): try data.encode(to: encoder)
        case .button(let data): try data.encode(to: encoder)
        case .image(let data): try data.encode(to: encoder)
        case .divider(let data): try data.encode(to: encoder)
        case .spacer(let data): try data.encode(to: encoder)
        case .quiz(let data): try data.encode(to: encoder)
        case .courseRoadmap(let data): try data.encode(to: encoder)
        case .coursePreview(let data): try data.encode(to: encoder)
        case .learningNode(let data): try data.encode(to: encoder)
        case .progressTracker(let data): try data.encode(to: encoder)
        case .interactiveLesson(let data): try data.encode(to: encoder)
        case .lessonCard(let data): try data.encode(to: encoder)
        case .courseCard(let data): try data.encode(to: encoder)
        case .progressBar(let data): try data.encode(to: encoder)
        }
    }
}

// MARK: - Component Payloads
enum ComponentPayload {
    case vstack(VStackPayload)
    case hstack(HStackPayload)
    case card(CardPayload)
    case text(TextPayload)
    case button(ButtonPayload)
    case image(ImagePayload)
    case divider(DividerPayload)
    case spacer(SpacerPayload)
    case quiz(A2UIQuizPayload)
    case courseRoadmap(A2UICourseRoadmapPayload)
    case coursePreview(CoursePreviewPayload)
    case learningNode(LearningNodePayload)
    case progressTracker(ProgressTrackerPayload)
    case interactiveLesson(InteractiveLessonPayload)
    case lessonCard(LessonCardPayload)
    case courseCard(A2UICourseCardPayload)
    case progressBar(ProgressBarPayload)
}

// MARK: - Layout Payloads
struct VStackPayload: Codable {
    let spacing: CGFloat?
    let alignment: String
    let children: [DynamicComponent]
}

struct HStackPayload: Codable {
    let spacing: CGFloat?
    let alignment: String
    let children: [DynamicComponent]
}

struct CardPayload: Codable {
    let title: String?
    let subtitle: String?
    let backgroundColor: String?
    let children: [DynamicComponent]

    enum CodingKeys: String, CodingKey {
        case title, subtitle
        case backgroundColor = "background_color"
        case children
    }
}

// MARK: - Content Payloads
struct TextPayload: Codable {
    let content: String
    let fontStyle: String
    let color: String?
    let alignment: String

    enum CodingKeys: String, CodingKey {
        case content, color, alignment
        case fontStyle = "font_style"
    }
}

struct ButtonPayload: Codable {
    let label: String
    let actionId: String
    let variant: String
    let isDisabled: Bool

    enum CodingKeys: String, CodingKey {
        case label, variant
        case actionId = "action_id"
        case isDisabled = "is_disabled"
    }
}

struct ImagePayload: Codable {
    let url: String
    let altText: String?
    let aspectRatio: String?

    enum CodingKeys: String, CodingKey {
        case url
        case altText = "alt_text"
        case aspectRatio = "aspect_ratio"
    }
}

struct DividerPayload: Codable {
    let color: String?
}

struct SpacerPayload: Codable {
    let height: CGFloat?
}

// MARK: - Legacy Payloads
struct A2UIQuizPayload: Codable {
    let question: String
    let options: [String]
    let correctIndex: Int?
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case question, options, explanation
        case correctIndex = "correct_index"
    }
}

struct A2UICourseRoadmapPayload: Codable {
    let title: String
    let modules: [A2UICourseModule]
    let totalModules: Int
    let completedModules: Int

    enum CodingKeys: String, CodingKey {
        case title, modules
        case totalModules = "total_modules"
        case completedModules = "completed_modules"
    }
}

// Supporting structures (Renamed to prevent conflict with MultimodalMessage structures)
struct A2UICourseModule: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let lessons: [A2UICourseLesson]?
    let duration: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, lessons, duration, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }

        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lessons = try container.decodeIfPresent([A2UICourseLesson].self, forKey: .lessons)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }
}

struct A2UICourseLesson: Codable, Identifiable {
    let id: String
    let title: String
    let duration: String?
    
    enum CodingKeys: String, CodingKey { case id, title, duration }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else {
            id = UUID().uuidString
        }

        title = try container.decode(String.self, forKey: .title)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
    }
}

// MARK: - AI Classroom Integration Payloads
struct CoursePreviewPayload: Codable {
    let courseId: String
    let title: String
    let description: String
    let subject: String
    let gradeBand: String
    let estimatedMinutes: Int
    let totalNodes: Int
    let thumbnailUrl: String?
    let startActionId: String
    let previewActionId: String

    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case title, description, subject
        case gradeBand = "grade_band"
        case estimatedMinutes = "estimated_minutes"
        case totalNodes = "total_nodes"
        case thumbnailUrl = "thumbnail_url"
        case startActionId = "start_action_id"
        case previewActionId = "preview_action_id"
    }
}

struct LearningNodePayload: Codable {
    let nodeId: String
    let title: String
    let content: String
    let nodeType: String
    let isCompleted: Bool
    let isCurrent: Bool
    let estimatedMinutes: Int?
    let continueActionId: String

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case title, content
        case nodeType = "node_type"
        case isCompleted = "is_completed"
        case isCurrent = "is_current"
        case estimatedMinutes = "estimated_minutes"
        case continueActionId = "continue_action_id"
    }
}

struct ProgressTrackerPayload: Codable {
    let courseTitle: String
    let currentNode: Int
    let totalNodes: Int
    let completedPercentage: Double
    let currentNodeTitle: String?
    let nextNodeTitle: String?
    let continueActionId: String

    enum CodingKeys: String, CodingKey {
        case courseTitle = "course_title"
        case currentNode = "current_node"
        case totalNodes = "total_nodes"
        case completedPercentage = "completed_percentage"
        case currentNodeTitle = "current_node_title"
        case nextNodeTitle = "next_node_title"
        case continueActionId = "continue_action_id"
    }
}

struct InteractiveLessonPayload: Codable {
    let lessonId: String
    let title: String
    let content: String
    let lessonType: String
    let mediaUrl: String?
    let durationSeconds: Int?
    let hasQuiz: Bool
    let quizActionId: String
    let continueActionId: String

    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case title, content
        case lessonType = "lesson_type"
        case mediaUrl = "media_url"
        case durationSeconds = "duration_seconds"
        case hasQuiz = "has_quiz"
        case quizActionId = "quiz_action_id"
        case continueActionId = "continue_action_id"
    }
}

// MARK: - Standard A2UI Payloads

struct LessonCardPayload: Codable {
    let title: String
    let description: String
    let type: String
    let duration: String
    let completed: Bool
    let action: String
}

struct A2UICourseCardPayload: Codable {
    let title: String
    let description: String
    let progress: Double
    let difficulty: String
    let duration: String
    let action: String
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description, progress, difficulty, duration, action
        case imageUrl = "image_url"
    }
}

struct ProgressBarPayload: Codable {
    let progress: Double
    let color: String?
}

// MARK: - Updated Chat Response
struct RecursiveChatResponse: Codable {
    let response: String
    let uiLayout: DynamicComponent?
    let sessionId: String?
    let conversationId: String?
    let responseMode: String?

    // Legacy compatibility fields
    let contentTypes: [String]?
    let quickExplainer: [String: AnyCodable]?
    let courseProposal: [String: AnyCodable]?
    let actions: [[String: AnyCodable]]?
    let suggestions: [String]?

    enum CodingKeys: String, CodingKey {
        case response
        case uiLayout = "ui_layout"
        case sessionId = "session_id"
        case conversationId = "conversation_id"
        case responseMode = "response_mode"
        case contentTypes = "content_types"
        case quickExplainer = "quick_explainer"
        case courseProposal = "course_proposal"
        case actions, suggestions
    }
}


