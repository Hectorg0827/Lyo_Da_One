import Foundation
import SwiftUI

// MARK: - Component Types
enum UIComponentType: String, Codable, CaseIterable {
    // Core Display
    case vstack, hstack, card, grid, text, button, image, divider, spacer, heading, markdown, codeBlock = "code_block", latex, highlight, quote, callout, badge, tag, label, caption, skeleton
    
    // Multimodal Input
    case textInput = "text_input", voiceInput = "voice_input", microphoneInput = "microphone_input", audioRecorder = "audio_recorder", cameraCapture = "camera_capture", documentUpload = "document_upload", fileDropZone = "file_drop_zone", screenCapture = "screen_capture", handwritingInput = "handwriting_input", drawingCanvas = "drawing_canvas", mathInput = "math_input", codeEditor = "code_editor", barcodeScanner = "barcode_scanner", ocrCorrection = "ocr_correction", locationInput = "location_input", dateTimeInput = "date_time_input", signaturePad = "signature_pad", emojiPicker = "emoji_picker"
    
    // Media & Visualization
    case animation, lottie, gif, diagram, chart, graph, model3D = "model_3d", handwritingPreview = "handwriting_preview", qrCode = "qr_code", pdfViewer = "pdf_viewer", imageCarousel = "image_carousel", videoTranscript = "video_transcript"
    
    // Quiz & Assessment
    case quiz, quizMcq = "quiz_mcq", quizMultiSelect = "quiz_multi_select", quizTrueFalse = "quiz_true_false", quizFillBlank = "quiz_fill_blank", quizMatching = "quiz_matching", quizDragDrop = "quiz_drag_drop", quizOrdering = "quiz_ordering", quizShortAnswer = "quiz_short_answer", quizEssay = "quiz_essay", quizMath = "quiz_math", quizCode = "quiz_code", quizDrawing = "quiz_drawing", quizAudio = "quiz_audio", quizSpeaking = "quiz_speaking", quizTiming = "quiz_timing", quizAdaptive = "quiz_adaptive", flashcard, flashcardDeck = "flashcard_deck", practiceSet = "practice_set", examMode = "exam_mode", rubric, confidenceMeter = "confidence_meter"
    
    // Study Planning
    case studyPlanOverview = "study_plan_overview", studyPlanWeek = "study_plan_week", studyPlanDay = "study_plan_day", studySession = "study_session", examCountdown = "exam_countdown", goalTracker = "goal_tracker", milestoneTimeline = "milestone_timeline", scheduleImport = "schedule_import", calendarEvent = "calendar_event", reminderSetup = "reminder_setup", timeBlocking = "time_blocking", habitTracker = "habit_tracker", pomodoroTimer = "pomodoro_timer", taskList = "task_list", priorityMatrix = "priority_matrix"
    
    // Mistake Tracking
    case mistakeCard = "mistake_card", mistakePattern = "mistake_pattern", weakAreaChart = "weak_area_chart", remediation, conceptMastery = "concept_mastery", errorHistory = "error_history", targetedPractice = "targeted_practice", masteryPath = "mastery_path", skillGap = "skill_gap", improvementPlan = "improvement_plan", confidenceHistory = "confidence_history", misconceptionAlert = "misconception_alert"
    
    // Homework
    case homeworkCard = "homework_card", homeworkHelper = "homework_helper", assignmentList = "assignment_list", dueDateBadge = "due_date_badge", submissionStatus = "submission_status", problemBreakdown = "problem_breakdown", solutionSteps = "solution_steps", hintReveal = "hint_reveal", workChecker = "work_checker", citationHelper = "citation_helper", plagiarismChecker = "plagiarism_checker", gradePredictor = "grade_predictor", rubricViewer = "rubric_viewer", peerReview = "peer_review", submissionPortal = "submission_portal"
    
    // Widgets
    case actionButton = "action_button", suggestions, selectionChips = "selection_chips", ratingInput = "rating_input", slider, toggle, picker, segmentedControl = "segmented_control", colorPicker = "color_picker", stepper, searchBar = "search_bar", filterChips = "filter_chips", sortSelector = "sort_selector", pagination, loadMoreButton = "load_more_button"
    
    // Document AI
    case notesSummary = "notes_summary", keyPointsList = "key_points_list", conceptMap = "concept_map", vocabularyList = "vocabulary_list", formulaSheet = "formula_sheet", documentPreview = "document_preview", annotatedDocument = "annotated_document", compareDocuments = "compare_documents", smartHighlights = "smart_highlights", documentOutline = "document_outline"
    
    // Gamification
    case progressBar = "progress_bar", progressRing = "progress_ring", xpGain = "xp_gain", streakIndicator = "streak_indicator", achievement, confetti, levelUp = "level_up", leaderboardEntry = "leaderboard_entry", dailyChallenge = "daily_challenge", encouragement, motivationalQuote = "motivational_quote", rewardUnlock = "reward_unlock", socialShare = "social_share"
    
    // AI Assistant
    case aiThinking = "ai_thinking", aiSuggestion = "ai_suggestion", contextReminder = "context_reminder", checkIn = "check_in", dailyBrief = "daily_brief", weeklyReview = "weekly_review", smartNudge = "smart_nudge", focusMode = "focus_mode", breakReminder = "break_reminder", conversationStarter = "conversation_starter"
    
    // Legacy/Advanced
    case courseRoadmap = "course_roadmap", coursePreview = "course_preview", learningNode = "learning_node", progressTracker = "progress_tracker", interactiveLesson = "interactive_lesson"
    case lessonCard = "lesson_card", courseCard = "course_card"
    case aiPersonalitySelector = "ai_personality_selector", voiceConversation = "voice_conversation", augmentedRealityViewer = "ar_viewer", socialGroupCard = "social_group_card", resourceLibraryFolder = "resource_folder", knowledgeGraph = "knowledge_graph", cognitiveLoadIndicator = "cognitive_load"
    
    case placeholder = "placeholder"
}

// MARK: - Polymorphic Component Wrapper
struct DynamicComponent: Identifiable, Codable {
    let id: String
    let type: UIComponentType
    let payload: ComponentPayload

    enum CodingKeys: String, CodingKey {
        case id, type, props, children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(UIComponentType.self, forKey: .type)

        // Dynamic decoding based on type
        switch type {
        case .vstack: payload = .vstack(try VStackPayload(from: decoder))
        case .hstack: payload = .hstack(try HStackPayload(from: decoder))
        case .grid: payload = .grid(try GridPayload(from: decoder))
        case .card: payload = .card(try CardPayload(from: decoder))
        case .text: payload = .text(try TextPayload(from: decoder))
        case .button: payload = .button(try ButtonPayload(from: decoder))
        case .image: payload = .image(try RecursiveImagePayload(from: decoder))
        case .divider: payload = .divider(try DividerPayload(from: decoder))
        case .spacer: payload = .spacer(try SpacerPayload(from: decoder))
        case .quiz: payload = .quiz(try RecursiveQuizPayload(from: decoder))
        case .courseRoadmap: payload = .courseRoadmap(try CourseRoadmapPayload(from: decoder))
        case .coursePreview: payload = .coursePreview(try CoursePreviewPayload(from: decoder))
        case .learningNode: payload = .learningNode(try LearningNodePayload(from: decoder))
        case .progressTracker: payload = .progressTracker(try ProgressTrackerPayload(from: decoder))
        case .interactiveLesson: payload = .interactiveLesson(try InteractiveLessonPayload(from: decoder))
        case .lessonCard: payload = .lessonCard(try LessonCardPayload(from: decoder))
        case .courseCard: payload = .courseCard(try A2UICourseCardPayload(from: decoder))
        case .progressBar: payload = .progressBar(try ProgressBarPayload(from: decoder))
        default:
            // Graceful fallback for hundreds of new components
            payload = .placeholder(try PlaceholderPayload(from: decoder))
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
        case .grid(let data): try data.encode(to: encoder)
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
        case .lessonCard(let data): try data.encode(to: encoder)
        case .courseCard(let data): try data.encode(to: encoder)
        case .progressBar(let data): try data.encode(to: encoder)
        case .placeholder(let data): try data.encode(to: encoder)
        }

    }
}

// MARK: - Component Payloads
enum ComponentPayload {
    case vstack(VStackPayload)
    case hstack(HStackPayload)
    case grid(GridPayload)
    case card(CardPayload)
    case text(TextPayload)
    case button(ButtonPayload)
    case image(RecursiveImagePayload)
    case divider(DividerPayload)
    case spacer(SpacerPayload)
    case quiz(RecursiveQuizPayload)
    case courseRoadmap(CourseRoadmapPayload)
    // AI Classroom Integration Components
    case coursePreview(CoursePreviewPayload)
    case learningNode(LearningNodePayload)
    case progressTracker(ProgressTrackerPayload)
    case interactiveLesson(InteractiveLessonPayload)
    case lessonCard(LessonCardPayload)
    case courseCard(A2UICourseCardPayload)
    case progressBar(ProgressBarPayload)
    case placeholder(PlaceholderPayload)
}

// MARK: - Placeholder for unknown/unimplemented components
struct PlaceholderPayload: Codable {
    let props: [String: AnyCodable]?
    let children: [DynamicComponent]?
    
    enum CodingKeys: String, CodingKey {
        case props, children
    }
}

// MARK: - Missing Payload Types (stubs for compilation)

struct DividerPayload: Codable {
    let thickness: CGFloat?
    let color: String?
}

struct SpacerPayload: Codable {
    let minLength: CGFloat?
    let height: CGFloat?
}

struct CoursePreviewPayload: Codable {
    let courseId: String?
    let title: String
    let subject: String
    let description: String
    let thumbnailUrl: String?
    let gradeBand: String
    let estimatedMinutes: Int
    let totalNodes: Int
    let previewActionId: String
    let startActionId: String
    
    // Provide defaults for optional construction
    init(courseId: String? = nil, title: String = "", subject: String = "", description: String = "", thumbnailUrl: String? = nil, gradeBand: String = "", estimatedMinutes: Int = 0, totalNodes: Int = 0, previewActionId: String = "", startActionId: String = "") {
        self.courseId = courseId
        self.title = title
        self.subject = subject
        self.description = description
        self.thumbnailUrl = thumbnailUrl
        self.gradeBand = gradeBand
        self.estimatedMinutes = estimatedMinutes
        self.totalNodes = totalNodes
        self.previewActionId = previewActionId
        self.startActionId = startActionId
    }
}

struct LearningNodePayload: Codable {
    let nodeId: String?
    let title: String?
    let content: String?
    let isComplete: Bool?
    let isCompleted: Bool?
    let isCurrent: Bool?
    let estimatedMinutes: Int?
    let type: String?
    let actionId: String?
}

struct ProgressTrackerPayload: Codable {
    let current: Int?
    let total: Int?
    let label: String?
    let courseTitle: String?
    let completedPercentage: Double
    let currentNode: Int
    let totalNodes: Int
    let currentNodeTitle: String?
    let nextNodeTitle: String?
    let continueActionId: String
}

struct InteractiveLessonPayload: Codable {
    let lessonId: String?
    let title: String
    let lessonType: String
    let content: String
    let blocks: [DynamicComponent]?
    let durationSeconds: Int?
    let mediaUrl: String?
    let hasQuiz: Bool
    let quizActionId: String
    let continueActionId: String
    
    init(lessonId: String? = nil, title: String = "", lessonType: String = "", content: String = "", blocks: [DynamicComponent]? = nil, durationSeconds: Int? = nil, mediaUrl: String? = nil, hasQuiz: Bool = false, quizActionId: String = "", continueActionId: String = "") {
        self.lessonId = lessonId
        self.title = title
        self.lessonType = lessonType
        self.content = content
        self.blocks = blocks
        self.durationSeconds = durationSeconds
        self.mediaUrl = mediaUrl
        self.hasQuiz = hasQuiz
        self.quizActionId = quizActionId
        self.continueActionId = continueActionId
    }
}

// MARK: - Additional Payload Types (used by A2UIRecursiveRenderer)

struct LessonCardPayload: Codable {
    let action: String
    let type: String
    let completed: Bool
    let title: String
    let duration: String?
    let description: String?
}

struct A2UICourseCardPayload: Codable {
    let action: String
    let imageUrl: String?
    let title: String
    let description: String
    let progress: Double
    let modules: Int?
    let difficulty: String
    let duration: String
    let enrolled: Bool
    
    init(action: String = "", imageUrl: String? = nil, title: String = "", description: String = "", progress: Double = 0, modules: Int? = nil, difficulty: String = "Beginner", duration: String = "0 min", enrolled: Bool = false) {
        self.action = action
        self.imageUrl = imageUrl
        self.title = title
        self.description = description
        self.progress = progress
        self.modules = modules
        self.difficulty = difficulty
        self.duration = duration
        self.enrolled = enrolled
    }
}

struct ProgressBarPayload: Codable {
    let progress: Double
    let color: String?
}

// MARK: - Layout Payloads (with recursive children)
struct VStackPayload: Codable {
    let spacing: CGFloat?
    let alignment: String
    let padding: CGFloat?
    let children: [DynamicComponent]
    
    enum CodingKeys: String, CodingKey {
        case props, children
    }
    
    enum PropsKeys: String, CodingKey {
        case spacing, padding
        case alignment = "align"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        children = try container.decodeIfPresent([DynamicComponent].self, forKey: .children) ?? []
        
        // Decode props nested object
        if let propsContainer = try? container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props) {
            spacing = try propsContainer.decodeIfPresent(CGFloat.self, forKey: .spacing)
            alignment = try propsContainer.decodeIfPresent(String.self, forKey: .alignment) ?? "center"
            padding = try propsContainer.decodeIfPresent(CGFloat.self, forKey: .padding)
        } else {
            // Fallback for flat structure
            spacing = nil
            alignment = "center"
            padding = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        
        var propsContainer = container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props)
        try propsContainer.encodeIfPresent(spacing, forKey: .spacing)
        try propsContainer.encode(alignment, forKey: .alignment)
        try propsContainer.encodeIfPresent(padding, forKey: .padding)
    }
}

struct HStackPayload: Codable {
    let spacing: CGFloat?
    let alignment: String
    let padding: CGFloat?
    let children: [DynamicComponent]
    
    enum CodingKeys: String, CodingKey {
        case props, children
    }
    
    enum PropsKeys: String, CodingKey {
        case spacing, padding
        case alignment = "align"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        children = try container.decodeIfPresent([DynamicComponent].self, forKey: .children) ?? []
        
        // Decode props nested object
        if let propsContainer = try? container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props) {
            spacing = try propsContainer.decodeIfPresent(CGFloat.self, forKey: .spacing)
            alignment = try propsContainer.decodeIfPresent(String.self, forKey: .alignment) ?? "center"
            padding = try propsContainer.decodeIfPresent(CGFloat.self, forKey: .padding)
        } else {
            // Fallback for flat structure
            spacing = nil
            alignment = "center"
            padding = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        
        var propsContainer = container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props)
        try propsContainer.encodeIfPresent(spacing, forKey: .spacing)
        try propsContainer.encode(alignment, forKey: .alignment)
        try propsContainer.encodeIfPresent(padding, forKey: .padding)
    }
}

struct GridPayload: Codable {
    let columns: Int
    let spacing: CGFloat?
    let padding: CGFloat?
    let children: [DynamicComponent]
    
    enum CodingKeys: String, CodingKey {
        case props, children
    }
    
    enum PropsKeys: String, CodingKey {
        case columns, spacing, padding
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        children = try container.decodeIfPresent([DynamicComponent].self, forKey: .children) ?? []
        
        // Decode props nested object
        if let propsContainer = try? container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props) {
            columns = try propsContainer.decodeIfPresent(Int.self, forKey: .columns) ?? 2
            spacing = try propsContainer.decodeIfPresent(CGFloat.self, forKey: .spacing)
            padding = try propsContainer.decodeIfPresent(CGFloat.self, forKey: .padding)
        } else {
            // Fallback defaults
            columns = 2
            spacing = nil
            padding = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        
        var propsContainer = container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props)
        try propsContainer.encode(columns, forKey: .columns)
        try propsContainer.encodeIfPresent(spacing, forKey: .spacing)
        try propsContainer.encodeIfPresent(padding, forKey: .padding)
    }
}

struct CardPayload: Codable {
    let title: String?
    let subtitle: String?
    let backgroundColor: String?
    let padding: CGFloat?
    let children: [DynamicComponent]

    enum CodingKeys: String, CodingKey {
        case props, children
    }
    
    enum PropsKeys: String, CodingKey {
        case title, subtitle, padding
        case backgroundColor = "background_color"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        children = try container.decodeIfPresent([DynamicComponent].self, forKey: .children) ?? []
        
        // Decode props nested object
        if let propsContainer = try? container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props) {
            title = try propsContainer.decodeIfPresent(String.self, forKey: .title)
            subtitle = try propsContainer.decodeIfPresent(String.self, forKey: .subtitle)
            backgroundColor = try propsContainer.decodeIfPresent(String.self, forKey: .backgroundColor)
            padding = try propsContainer.decodeIfPresent(CGFloat.self, forKey: .padding)
        } else {
            title = nil
            subtitle = nil
            backgroundColor = nil
            padding = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        
        var propsContainer = container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props)
        try propsContainer.encodeIfPresent(title, forKey: .title)
        try propsContainer.encodeIfPresent(subtitle, forKey: .subtitle)
        try propsContainer.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try propsContainer.encodeIfPresent(padding, forKey: .padding)
    }
}

// MARK: - Content Payloads (leaf nodes)
struct TextPayload: Codable {
    let content: String
    let fontStyle: String
    let color: String?
    let alignment: String

    enum CodingKeys: String, CodingKey {
        case props
    }
    
    enum PropsKeys: String, CodingKey {
        case content, color
        case fontStyle = "font_style"
        case alignment = "align"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode props nested object
        if let propsContainer = try? container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props) {
            content = try propsContainer.decodeIfPresent(String.self, forKey: .content) ?? ""
            fontStyle = try propsContainer.decodeIfPresent(String.self, forKey: .fontStyle) ?? "body"
            color = try propsContainer.decodeIfPresent(String.self, forKey: .color)
            alignment = try propsContainer.decodeIfPresent(String.self, forKey: .alignment) ?? "leading"
        } else {
            // Fallback defaults
            content = ""
            fontStyle = "body"
            color = nil
            alignment = "leading"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var propsContainer = container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props)
        try propsContainer.encode(content, forKey: .content)
        try propsContainer.encode(fontStyle, forKey: .fontStyle)
        try propsContainer.encodeIfPresent(color, forKey: .color)
        try propsContainer.encode(alignment, forKey: .alignment)
    }
}

struct ButtonPayload: Codable {
    let label: String
    let actionId: String
    let variant: String
    let isDisabled: Bool

    enum CodingKeys: String, CodingKey {
        case props
    }
    
    enum PropsKeys: String, CodingKey {
        case label, variant
        case actionId = "action_id"
        case isDisabled = "is_disabled"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode props nested object
        if let propsContainer = try? container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props) {
            label = try propsContainer.decodeIfPresent(String.self, forKey: .label) ?? "Button"
            actionId = try propsContainer.decodeIfPresent(String.self, forKey: .actionId) ?? ""
            variant = try propsContainer.decodeIfPresent(String.self, forKey: .variant) ?? "primary"
            isDisabled = try propsContainer.decodeIfPresent(Bool.self, forKey: .isDisabled) ?? false
        } else {
            // Fallback defaults
            label = "Button"
            actionId = ""
            variant = "primary"
            isDisabled = false
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var propsContainer = container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props)
        try propsContainer.encode(label, forKey: .label)
        try propsContainer.encode(actionId, forKey: .actionId)
        try propsContainer.encode(variant, forKey: .variant)
        try propsContainer.encode(isDisabled, forKey: .isDisabled)
    }
}

struct RecursiveImagePayload: Codable {
    let url: String
    let altText: String?
    let aspectRatio: String?

    enum CodingKeys: String, CodingKey {
        case props
    }
    
    enum PropsKeys: String, CodingKey {
        case url
        case altText = "alt_text"
        case aspectRatio = "aspect_ratio"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode props nested object
        if let propsContainer = try? container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props) {
            url = try propsContainer.decodeIfPresent(String.self, forKey: .url) ?? ""
            altText = try propsContainer.decodeIfPresent(String.self, forKey: .altText)
            aspectRatio = try propsContainer.decodeIfPresent(String.self, forKey: .aspectRatio)
        } else {
            url = ""
            altText = nil
            aspectRatio = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var propsContainer = container.nestedContainer(keyedBy: PropsKeys.self, forKey: .props)
        try propsContainer.encode(url, forKey: .url)
        try propsContainer.encodeIfPresent(altText, forKey: .altText)
        try propsContainer.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
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

// MARK: - Recursive Payloads
struct RecursiveQuizPayload: Codable {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String?
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
            "props": {
                "title": "Test Card",
                "subtitle": "This is a test"
            },
            "children": [
                {
                    "id": "test-text-1",
                    "type": "text",
                    "props": {
                        "content": "Hello from recursive A2UI!",
                        "font_style": "body",
                        "align": "center"
                    },
                    "children": []
                },
                {
                    "id": "test-button-1",
                    "type": "button",
                    "props": {
                        "label": "Test Button",
                        "action_id": "test_action",
                        "variant": "primary",
                        "is_disabled": false
                    },
                    "children": []
                }
            ]
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(DynamicComponent.self, from: testData)
    }
}