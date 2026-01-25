//
//  A2UIProps.swift
//  Lyo
//
//  Universal props container for A2UI components
//  Contains all possible properties across element types
//

import Foundation

// MARK: - A2UI Props

/// Universal props container - only relevant properties are used per element type
struct A2UIProps: Codable, Equatable {
    
    // MARK: - Content Properties
    var text: String?
    var title: String?
    var subtitle: String?
    var body: String?
    var placeholder: String?
    var value: AnyCodableValue?
    var defaultValue: AnyCodableValue?
    var label: String?
    var hint: String?
    var helperText: String?
    var errorMessage: String?
    var successMessage: String?
    
    // MARK: - Media Properties
    var imageUrl: String?
    var imageAsset: String?
    var videoUrl: String?
    var audioUrl: String?
    var thumbnailUrl: String?
    var altText: String?
    var aspectRatio: Double?
    var autoplay: Bool?
    var loop: Bool?
    var muted: Bool?
    var controls: Bool?
    
    // MARK: - Layout Properties
    var width: A2UIDimension?
    var height: A2UIDimension?
    var minWidth: A2UIDimension?
    var maxWidth: A2UIDimension?
    var minHeight: A2UIDimension?
    var maxHeight: A2UIDimension?
    var padding: A2UIEdgeInsets?
    var margin: A2UIEdgeInsets?
    var alignment: A2UIAlignment?
    var spacing: Double?
    var columns: Int?                   // For grid layout
    var axis: String?                   // "horizontal" or "vertical" for stack
    var code: String?                   // Code content for code blocks
    var flex: Int?
    var zIndex: Int?
    
    // MARK: - Style Properties
    var backgroundColor: String?
    var foregroundColor: String?
    var borderColor: String?
    var borderWidth: Double?
    var borderRadius: Double?
    var shadowRadius: Double?
    var shadowColor: String?
    var shadowOffset: A2UIOffset?
    var opacity: Double?
    var blur: Double?
    var gradient: A2UIGradient?
    var styleRef: String?  // Reference to stylesheet
    
    // MARK: - Typography Properties
    var fontSize: Double?
    var fontWeight: String?
    var fontFamily: String?
    var lineHeight: Double?
    var letterSpacing: Double?
    var textAlignment: String?
    var textDecoration: String?
    var textTransform: String?
    var numberOfLines: Int?
    var truncationMode: String?
    
    // MARK: - Icon Properties
    var icon: String?
    var iconPosition: String?
    var iconSize: Double?
    var iconColor: String?
    var sfSymbol: String?
    
    // MARK: - Interactive Properties
    var isEnabled: Bool?
    var isSelected: Bool?
    var isLoading: Bool?
    var isRequired: Bool?
    var isSecure: Bool?
    var isEditable: Bool?
    var isFocused: Bool?
    var isHighlighted: Bool?
    var isHidden: Bool?
    var keyboardType: String?
    var autocapitalization: String?
    var autocorrection: Bool?
    
    // MARK: - Quiz Properties
    var question: String?
    var options: [A2UIQuizOption]?
    var correctAnswer: AnyCodableValue?
    var correctAnswers: [AnyCodableValue]?
    var explanation: String?
    var shuffleOptions: Bool?
    var showFeedback: Bool?
    var maxAttempts: Int?
    var timeLimit: Int?
    var points: Int?
    var difficulty: String?
    var matchingPairs: [A2UIMatchingPair]?
    var orderItems: [A2UIOrderItem]?
    var blanks: [A2UIBlankItem]?
    var codeLanguage: String?
    var codeTemplate: String?
    var testCases: [A2UITestCase]?
    
    // MARK: - Study Plan Properties
    var planId: String?
    var goalTitle: String?
    var goalDescription: String?
    var targetDate: Date?
    var startDate: Date?
    var endDate: Date?
    var recurrence: String?
    var duration: Int?  // minutes
    var priority: String?
    var status: String?
    var progress: Double?
    var completedCount: Int?
    var totalCount: Int?
    var sessions: [A2UIStudySession]?
    var milestones: [A2UIMilestone]?
    var reminders: [A2UIReminder]?
    
    // MARK: - Mistake Tracker Properties
    var mistakeId: String?
    var mistakeType: String?
    var topic: String?
    var conceptTag: String?
    var originalAnswer: String?
    var correctSolution: String?
    var occurrenceCount: Int?
    var lastOccurrence: Date?
    var masteryLevel: Double?
    var patternDescription: String?
    var recommendedAction: String?
    var relatedMistakes: [String]?
    var heatmapData: [A2UIHeatmapCell]?
    
    // MARK: - Homework Properties
    var homeworkId: String?
    var assignmentTitle: String?
    var subject: String?
    var dueDate: Date?
    var submittedDate: Date?
    var grade: String?
    var maxGrade: String?
    var rubric: [A2UIRubricItem]?
    var feedback: String?
    var attachments: [A2UIAttachment]?
    var submissionType: String?
    var isLate: Bool?
    var canResubmit: Bool?
    
    // MARK: - Document Properties
    var documentUrl: String?
    var documentType: String?
    var pageCount: Int?
    var currentPage: Int?
    var highlights: [A2UIHighlight]?
    var annotations: [A2UIAnnotation]?
    var ocrText: String?
    var summaryPoints: [String]?
    var keyTerms: [A2UIKeyTerm]?
    
    // MARK: - Flashcard Properties
    var front: String?
    var back: String?
    var frontMedia: String?
    var backMedia: String?
    var deckId: String?
    var cardIndex: Int?
    var totalCards: Int?
    var confidence: Double?
    var nextReview: Date?
    var reviewCount: Int?
    var easeFactor: Double?
    var interval: Int?
    
    // MARK: - Course Properties
    var courseId: String?
    var lessonId: String?
    var moduleId: String?
    var chapterId: String?
    var courseName: String?
    var instructor: String?
    var level: String?
    var estimatedDuration: Int?
    var prerequisites: [String]?
    var objectives: [String]?
    var modules: [A2UIModuleInfo]?
    var completionPercentage: Double?
    var enrollmentDate: Date?
    var lastAccessDate: Date?
    
    // MARK: - Gamification Properties
    var xp: Int?
    var xpToNextLevel: Int?
    var levelNumber: Int?
    var levelName: String?
    var streak: Int?
    var coins: Int?
    var energy: Int?
    var maxEnergy: Int?
    var achievementId: String?
    var achievementName: String?
    var achievementIcon: String?
    var badgeUrl: String?
    var rank: Int?
    var leaderboardType: String?
    var challengeId: String?
    var challengeProgress: Double?
    var rewardType: String?
    var rewardAmount: Int?
    
    // MARK: - Voice Properties
    var speakableText: String?
    var ttsVoice: String?
    var ttsSpeed: Double?
    var autoSpeak: Bool?
    var acceptsVoiceInput: Bool?
    var voiceCommands: [String]?
    var audioTimings: [A2UIAudioTiming]?
    
    // MARK: - Animation Properties
    var animationName: String?
    var animationDuration: Double?
    var animationDelay: Double?
    var animationRepeat: Int?
    var animationAutoplay: Bool?
    var lottieAsset: String?
    var lottieUrl: String?
    
    // MARK: - AI Properties
    var aiPersonality: String?
    var aiMood: String?
    var thinkingMessage: String?
    var suggestionType: String?
    var confidenceScore: Double?
    var sourceReferences: [String]?

    // MARK: - Convenience/Misc Properties
    var documentContent: String?
    var generatedNotes: String?
    var flashcardFront: String?
    var flashcardBack: String?
    var progressPercent: Double?
    var isCompleted: Bool?
    var isLocked: Bool?
    var lessonNumber: Int?
    var completedLessons: Int?
    var remainingLessons: Int?
    var iconName: String?
    var rightIconName: String?
    var isFullWidth: Bool?
    var buttonStyle: String?
    var showBackButton: Bool?
    var showExternalIcon: Bool?
    var breadcrumbItems: [String]?
    var quote: String?
    var quoteAuthor: String?
    var alertTitle: String?
    var alertType: String?
    var size: Double?
    var timeRemaining: String?
    var username: String?
    var streakCount: Int?
    var suggestions: [String]?
    var currentXP: Int?
    var nextLevelXP: Int?
    var isUnlocked: Bool?
    var likeCount: Int?
    var isLiked: Bool?
    var isBookmarked: Bool?
    var memberCount: Int?
    var loadingMessage: String?
    var showRetry: Bool?
    var debugInfo: String?
    var statValue: String?
    var isDismissible: Bool?
    var actionTitle: String?
    var score: Double?
    var earnedDate: Date?
    var xpAwarded: Int?
    var bio: String?
    var timestamp: Date?
    var commentCount: Int?
    
    // MARK: - Accessibility Properties
    var accessibilityLabel: String?
    var accessibilityHint: String?
    var accessibilityTraits: [String]?
    var accessibilityValue: String?
    var isAccessibilityElement: Bool?
    var accessibilityIdentifier: String?
    
    // MARK: - Data Binding
    var bindTo: String?
    var formatString: String?
    var transform: String?
    
    init() {}
    
    enum CodingKeys: String, CodingKey {
        case text, title, subtitle, body, placeholder, value, label, hint
        case defaultValue = "default_value"
        case helperText = "helper_text"
        case errorMessage = "error_message"
        case successMessage = "success_message"
        case imageUrl = "image_url"
        case imageAsset = "image_asset"
        case videoUrl = "video_url"
        case audioUrl = "audio_url"
        case thumbnailUrl = "thumbnail_url"
        case altText = "alt_text"
        case aspectRatio = "aspect_ratio"
        case autoplay, loop, muted, controls
        case width, height, padding, margin, alignment, spacing, flex
        case minWidth = "min_width"
        case maxWidth = "max_width"
        case minHeight = "min_height"
        case maxHeight = "max_height"
        case zIndex = "z_index"
        case backgroundColor = "background_color"
        case foregroundColor = "foreground_color"
        case borderColor = "border_color"
        case borderWidth = "border_width"
        case borderRadius = "border_radius"
        case shadowRadius = "shadow_radius"
        case shadowColor = "shadow_color"
        case shadowOffset = "shadow_offset"
        case opacity, blur, gradient
        case styleRef = "style_ref"
        case fontSize = "font_size"
        case fontWeight = "font_weight"
        case fontFamily = "font_family"
        case lineHeight = "line_height"
        case letterSpacing = "letter_spacing"
        case textAlignment = "text_alignment"
        case textDecoration = "text_decoration"
        case textTransform = "text_transform"
        case numberOfLines = "number_of_lines"
        case truncationMode = "truncation_mode"
        case icon
        case iconPosition = "icon_position"
        case iconSize = "icon_size"
        case iconColor = "icon_color"
        case sfSymbol = "sf_symbol"
        case isEnabled = "is_enabled"
        case isSelected = "is_selected"
        case isLoading = "is_loading"
        case isRequired = "is_required"
        case isSecure = "is_secure"
        case isEditable = "is_editable"
        case isFocused = "is_focused"
        case isHighlighted = "is_highlighted"
        case isHidden = "is_hidden"
        case keyboardType = "keyboard_type"
        case autocapitalization
        case autocorrection
        case question, options, explanation, points, difficulty
        case correctAnswer = "correct_answer"
        case correctAnswers = "correct_answers"
        case shuffleOptions = "shuffle_options"
        case showFeedback = "show_feedback"
        case maxAttempts = "max_attempts"
        case timeLimit = "time_limit"
        case matchingPairs = "matching_pairs"
        case orderItems = "order_items"
        case blanks
        case codeLanguage = "code_language"
        case codeTemplate = "code_template"
        case testCases = "test_cases"
        case planId = "plan_id"
        case goalTitle = "goal_title"
        case goalDescription = "goal_description"
        case targetDate = "target_date"
        case startDate = "start_date"
        case endDate = "end_date"
        case recurrence, duration, priority, status, progress
        case completedCount = "completed_count"
        case totalCount = "total_count"
        case sessions, milestones, reminders
        case mistakeId = "mistake_id"
        case mistakeType = "mistake_type"
        case topic
        case conceptTag = "concept_tag"
        case originalAnswer = "original_answer"
        case correctSolution = "correct_solution"
        case occurrenceCount = "occurrence_count"
        case lastOccurrence = "last_occurrence"
        case masteryLevel = "mastery_level"
        case patternDescription = "pattern_description"
        case recommendedAction = "recommended_action"
        case relatedMistakes = "related_mistakes"
        case heatmapData = "heatmap_data"
        case homeworkId = "homework_id"
        case assignmentTitle = "assignment_title"
        case subject
        case dueDate = "due_date"
        case submittedDate = "submitted_date"
        case grade
        case maxGrade = "max_grade"
        case rubric, feedback, attachments
        case submissionType = "submission_type"
        case isLate = "is_late"
        case canResubmit = "can_resubmit"
        case documentUrl = "document_url"
        case documentType = "document_type"
        case pageCount = "page_count"
        case currentPage = "current_page"
        case highlights, annotations
        case ocrText = "ocr_text"
        case summaryPoints = "summary_points"
        case keyTerms = "key_terms"
        case front, back
        case frontMedia = "front_media"
        case backMedia = "back_media"
        case deckId = "deck_id"
        case cardIndex = "card_index"
        case totalCards = "total_cards"
        case confidence
        case nextReview = "next_review"
        case reviewCount = "review_count"
        case easeFactor = "ease_factor"
        case interval
        case courseId = "course_id"
        case lessonId = "lesson_id"
        case moduleId = "module_id"
        case chapterId = "chapter_id"
        case courseName = "course_name"
        case instructor, level
        case estimatedDuration = "estimated_duration"
        case prerequisites, objectives, modules
        case completionPercentage = "completion_percentage"
        case enrollmentDate = "enrollment_date"
        case lastAccessDate = "last_access_date"
        case xp
        case xpToNextLevel = "xp_to_next_level"
        case levelNumber = "level_number"
        case levelName = "level_name"
        case streak, coins, energy
        case maxEnergy = "max_energy"
        case achievementId = "achievement_id"
        case achievementName = "achievement_name"
        case achievementIcon = "achievement_icon"
        case badgeUrl = "badge_url"
        case rank
        case leaderboardType = "leaderboard_type"
        case challengeId = "challenge_id"
        case challengeProgress = "challenge_progress"
        case rewardType = "reward_type"
        case rewardAmount = "reward_amount"
        case speakableText = "speakable_text"
        case ttsVoice = "tts_voice"
        case ttsSpeed = "tts_speed"
        case autoSpeak = "auto_speak"
        case acceptsVoiceInput = "accepts_voice_input"
        case voiceCommands = "voice_commands"
        case audioTimings = "audio_timings"
        case animationName = "animation_name"
        case animationDuration = "animation_duration"
        case animationDelay = "animation_delay"
        case animationRepeat = "animation_repeat"
        case animationAutoplay = "animation_autoplay"
        case lottieAsset = "lottie_asset"
        case lottieUrl = "lottie_url"
        case aiPersonality = "ai_personality"
        case aiMood = "ai_mood"
        case thinkingMessage = "thinking_message"
        case suggestionType = "suggestion_type"
        case confidenceScore = "confidence_score"
        case sourceReferences = "source_references"
        case documentContent = "document_content"
        case generatedNotes = "generated_notes"
        case flashcardFront = "flashcard_front"
        case flashcardBack = "flashcard_back"
        case progressPercent = "progress_percent"
        case isCompleted = "is_completed"
        case isLocked = "is_locked"
        case lessonNumber = "lesson_number"
        case completedLessons = "completed_lessons"
        case remainingLessons = "remaining_lessons"
        case iconName = "icon_name"
        case rightIconName = "right_icon_name"
        case isFullWidth = "is_full_width"
        case buttonStyle = "button_style"
        case showBackButton = "show_back_button"
        case showExternalIcon = "show_external_icon"
        case breadcrumbItems = "breadcrumb_items"
        case quote
        case quoteAuthor = "quote_author"
        case alertTitle = "alert_title"
        case alertType = "alert_type"
        case size
        case timeRemaining = "time_remaining"
        case username
        case streakCount = "streak_count"
        case suggestions
        case currentXP = "current_xp"
        case nextLevelXP = "next_level_xp"
        case isUnlocked = "is_unlocked"
        case likeCount = "like_count"
        case isLiked = "is_liked"
        case isBookmarked = "is_bookmarked"
        case memberCount = "member_count"
        case loadingMessage = "loading_message"
        case showRetry = "show_retry"
        case debugInfo = "debug_info"
        case statValue = "stat_value"
        case isDismissible = "is_dismissible"
        case actionTitle = "action_title"
        case score
        case earnedDate = "earned_date"
        case xpAwarded = "xp_awarded"
        case bio
        case timestamp
        case commentCount = "comment_count"
        case accessibilityLabel = "accessibility_label"
        case accessibilityHint = "accessibility_hint"
        case accessibilityTraits = "accessibility_traits"
        case accessibilityValue = "accessibility_value"
        case isAccessibilityElement = "is_accessibility_element"
        case accessibilityIdentifier = "accessibility_identifier"
        case bindTo = "bind_to"
        case formatString = "format_string"
        case transform
    }
}

// MARK: - Supporting Types

struct A2UIDimension: Codable, Equatable {
    let value: Double
    let unit: A2UIDimensionUnit
    
    static func points(_ value: Double) -> A2UIDimension {
        A2UIDimension(value: value, unit: .points)
    }
    
    static func percent(_ value: Double) -> A2UIDimension {
        A2UIDimension(value: value, unit: .percent)
    }
    
    static var fill: A2UIDimension {
        A2UIDimension(value: 1, unit: .fill)
    }
}

enum A2UIDimensionUnit: String, Codable {
    case points = "pt"
    case percent = "%"
    case fill
    case auto
}

struct A2UIEdgeInsets: Codable, Equatable {
    let top: Double
    let leading: Double
    let bottom: Double
    let trailing: Double
    
    static func all(_ value: Double) -> A2UIEdgeInsets {
        A2UIEdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
    
    static func horizontal(_ value: Double) -> A2UIEdgeInsets {
        A2UIEdgeInsets(top: 0, leading: value, bottom: 0, trailing: value)
    }
    
    static func vertical(_ value: Double) -> A2UIEdgeInsets {
        A2UIEdgeInsets(top: value, leading: 0, bottom: value, trailing: 0)
    }
}

enum A2UIAlignment: String, Codable {
    case leading
    case center
    case trailing
    case top
    case bottom
    case topLeading = "top_leading"
    case topTrailing = "top_trailing"
    case bottomLeading = "bottom_leading"
    case bottomTrailing = "bottom_trailing"
}

struct A2UIOffset: Codable, Equatable {
    let x: Double
    let y: Double
}

struct A2UIGradient: Codable, Equatable {
    let colors: [String]
    let startPoint: A2UIAlignment?
    let endPoint: A2UIAlignment?
    let type: String?  // linear, radial, angular
    
    enum CodingKeys: String, CodingKey {
        case colors
        case startPoint = "start_point"
        case endPoint = "end_point"
        case type
    }
}

// MARK: - Quiz Supporting Types

struct A2UIQuizOption: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let imageUrl: String?
    let isCorrect: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, text
        case imageUrl = "image_url"
        case isCorrect = "is_correct"
    }
}

struct A2UIMatchingPair: Codable, Identifiable, Equatable {
    let id: String
    let left: String
    let right: String
}

struct A2UIOrderItem: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let correctPosition: Int
    
    enum CodingKeys: String, CodingKey {
        case id, text
        case correctPosition = "correct_position"
    }
}

struct A2UIBlankItem: Codable, Identifiable, Equatable {
    let id: String
    let position: Int
    let answer: String
    let acceptedAnswers: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, position, answer
        case acceptedAnswers = "accepted_answers"
    }
}

struct A2UITestCase: Codable, Identifiable, Equatable {
    let id: String
    let input: String
    let expectedOutput: String
    let isHidden: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, input
        case expectedOutput = "expected_output"
        case isHidden = "is_hidden"
    }
}

// MARK: - Study Plan Supporting Types

struct A2UIStudySession: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let topic: String?
    let scheduledDate: Date
    let duration: Int  // minutes
    let isCompleted: Bool
    let focusType: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, topic, duration
        case scheduledDate = "scheduled_date"
        case isCompleted = "is_completed"
        case focusType = "focus_type"
    }
}

struct A2UIMilestone: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let targetDate: Date?
    let isCompleted: Bool
    let xpReward: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case targetDate = "target_date"
        case isCompleted = "is_completed"
        case xpReward = "xp_reward"
    }
}

struct A2UIReminder: Codable, Identifiable, Equatable {
    let id: String
    let message: String
    let time: Date
    let repeatPattern: String?
    let isEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, message, time
        case repeatPattern = "repeat_pattern"
        case isEnabled = "is_enabled"
    }
}

// MARK: - Mistake Tracker Supporting Types

struct A2UIHeatmapCell: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let value: Double
    let color: String?
}

// MARK: - Homework Supporting Types

struct A2UIRubricItem: Codable, Identifiable, Equatable {
    let id: String
    let criterion: String
    let maxPoints: Int
    let earnedPoints: Int?
    let feedback: String?
    
    enum CodingKeys: String, CodingKey {
        case id, criterion, feedback
        case maxPoints = "max_points"
        case earnedPoints = "earned_points"
    }
}

struct A2UIAttachment: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let url: String
    let size: Int?
    let thumbnailUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, url, size
        case thumbnailUrl = "thumbnail_url"
    }
}

// MARK: - Document Supporting Types

struct A2UIHighlight: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let color: String
    let pageNumber: Int?
    let startOffset: Int
    let endOffset: Int
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case id, text, color, note
        case pageNumber = "page_number"
        case startOffset = "start_offset"
        case endOffset = "end_offset"
    }
}

struct A2UIAnnotation: Codable, Identifiable, Equatable {
    let id: String
    let type: String  // text, drawing, sticky
    let content: String?
    let pageNumber: Int
    let position: A2UIOffset
    let color: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, content, position, color
        case pageNumber = "page_number"
    }
}

struct A2UIKeyTerm: Codable, Identifiable, Equatable {
    let id: String
    let term: String
    let definition: String
    let importance: Int?
}

// MARK: - Course Supporting Types

struct A2UIModuleInfo: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let lessonCount: Int
    let completedLessons: Int
    let duration: Int?
    let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, duration
        case lessonCount = "lesson_count"
        case completedLessons = "completed_lessons"
        case isLocked = "is_locked"
    }
}

// MARK: - Voice Supporting Types

struct A2UIAudioTiming: Codable, Identifiable, Equatable {
    let id: String
    let word: String
    let startTime: Double
    let endTime: Double
    
    enum CodingKeys: String, CodingKey {
        case id, word
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
