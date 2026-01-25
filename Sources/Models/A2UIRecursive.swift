import Foundation
import SwiftUI

// MARK: - Component Types
enum UIComponentType: String, Codable, CaseIterable {
    case vstack, hstack, card
    case text, button, image, divider, spacer
    case quiz, courseRoadmap = "course_roadmap" // Legacy types
    // AI Classroom Integration types
    case coursePreview = "course_preview"
    case learningNode = "learning_node"
    case progressTracker = "progress_tracker"
    case interactiveLesson = "interactive_lesson"
}

// MARK: - Polymorphic Component Wrapper
struct DynamicComponent: Identifiable, Codable {
    let id: String
    let type: UIComponentType
    let payload: ComponentPayload

    enum CodingKeys: String, CodingKey {
        case id, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(UIComponentType.self, forKey: .type)

        // Dynamic decoding based on type
        switch type {
        case .vstack: payload = .vstack(try VStackPayload(from: decoder))
        case .hstack: payload = .hstack(try HStackPayload(from: decoder))
        case .card: payload = .card(try CardPayload(from: decoder))
        case .text: payload = .text(try TextPayload(from: decoder))
        case .button: payload = .button(try ButtonPayload(from: decoder))
        case .image: payload = .image(try ImagePayload(from: decoder))
        case .divider: payload = .divider(try DividerPayload(from: decoder))
        case .spacer: payload = .spacer(try SpacerPayload(from: decoder))
        case .quiz: payload = .quiz(try QuizPayload(from: decoder))
        case .courseRoadmap: payload = .courseRoadmap(try CourseRoadmapPayload(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)

        // Encode the specific payload
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
        // AI Classroom Integration Components
        case .coursePreview(let data): try data.encode(to: encoder)
        case .learningNode(let data): try data.encode(to: encoder)
        case .progressTracker(let data): try data.encode(to: encoder)
        case .interactiveLesson(let data): try data.encode(to: encoder)
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
    case quiz(QuizPayload)
    case courseRoadmap(CourseRoadmapPayload)
    // AI Classroom Integration Components
    case coursePreview(CoursePreviewPayload)
    case learningNode(LearningNodePayload)
    case progressTracker(ProgressTrackerPayload)
    case interactiveLesson(InteractiveLessonPayload)
}

// MARK: - Layout Payloads (with recursive children)
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

// MARK: - Content Payloads (leaf nodes)
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

// MARK: - Legacy Payloads (for backward compatibility)
struct QuizPayload: Codable {
    let question: String
    let options: [String]
    let correctIndex: Int?
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case question, options, explanation
        case correctIndex = "correct_index"
    }
}

struct CourseRoadmapPayload: Codable {
    let title: String
    let modules: [CourseModule]
    let totalModules: Int
    let completedModules: Int

    enum CodingKeys: String, CodingKey {
        case title, modules
        case totalModules = "total_modules"
        case completedModules = "completed_modules"
    }
}

// Supporting structures for CourseRoadmap
struct CourseModule: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let lessons: [CourseLesson]?
    let duration: Int?
    let status: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle different ID formats from backend
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }

        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lessons = try container.decodeIfPresent([CourseLesson].self, forKey: .lessons)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }
}

struct CourseLesson: Codable, Identifiable {
    let id: String
    let title: String
    let duration: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle missing ID
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

// MARK: - Helper for dynamic JSON values


// MARK: - Convenience Extensions
extension DynamicComponent {
    /// Create a test component for debugging
    static func createTestCard() -> DynamicComponent {
        let testData = """
        {
            "id": "test-card-1",
            "type": "card",
            "title": "Test Card",
            "subtitle": "This is a test",
            "children": [
                {
                    "id": "test-text-1",
                    "type": "text",
                    "content": "Hello from recursive A2UI!",
                    "font_style": "body",
                    "alignment": "center"
                },
                {
                    "id": "test-button-1",
                    "type": "button",
                    "label": "Test Button",
                    "action_id": "test_action",
                    "variant": "primary",
                    "is_disabled": false
                }
            ]
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(DynamicComponent.self, from: testData)
    }
}