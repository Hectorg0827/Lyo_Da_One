//
//  A2UIElementType.swift
//  Lyo
//
//  Complete A2UI Element Catalog for AI-to-UI dynamic rendering
//  This enum defines all possible UI elements the backend can request
//

import Foundation

// MARK: - A2UI Element Type

/// Complete catalog of A2UI element types
/// Backend sends these types to drive dynamic UI rendering
/// Supports both camelCase (iOS native) and snake_case (backend) raw values
enum A2UIElementType: String, Codable, CaseIterable {
    
    // MARK: - Custom Decoder (snake_case → camelCase bridge)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // 1. Try exact match first (camelCase)
        if let exact = A2UIElementType(rawValue: rawValue) {
            self = exact
            return
        }
        
        // 2. Convert snake_case → camelCase and try again
        let camelCased = Self.snakeToCamelCase(rawValue)
        if let converted = A2UIElementType(rawValue: camelCased) {
            self = converted
            return
        }
        
        // 3. Check manual mapping for known mismatches
        if let mapped = Self.backendToIOSMapping[rawValue] {
            self = mapped
            return
        }
        
        // 4. Fallback to unknown
        self = .unknown
    }
    
    /// Converts "snake_case" → "snakeCase"
    private static func snakeToCamelCase(_ string: String) -> String {
        let parts = string.split(separator: "_")
        guard let first = parts.first else { return string }
        return String(first) + parts.dropFirst().map { $0.capitalized }.joined()
    }
    
    /// Manual mapping for types where snake_case→camelCase doesn't match iOS enum
    private static let backendToIOSMapping: [String: A2UIElementType] = [
        "action_button": .button,
        "scroll": .scrollView,
        "progress_ring": .progressBar,
        "code_block": .codeBlock,
    ]
    
    // MARK: - Core Display Elements
    case text
    case heading
    case paragraph
    case label
    case caption
    case richText
    case markdown
    case code
    case codeBlock
    case latex
    case equation
    
    // MARK: - Media Elements
    case image
    case video
    case audio
    case animation
    case lottie
    case gif
    case avatar
    case icon
    case diagram
    case chart
    case graph
    case mindMap
    case timeline
    case ar3DModel
    
    // MARK: - Multimodal Input Elements
    case voiceInput
    case cameraCapture
    case documentScanner
    case sketchPad
    case handwriting
    case screenCapture
    case fileUpload
    case audioRecorder
    
    // MARK: - Interactive Input Elements
    case textInput
    case textArea
    case slider
    case toggle
    case checkbox
    case radioGroup
    case dropdown
    case datePicker
    case timePicker
    case colorPicker
    case ratingStars
    case stepper
    
    // MARK: - Quiz & Assessment Elements
    case quizMcq
    case quizMultiSelect
    case quizTrueFalse
    case quizFillBlank
    case quizMatching
    case quizOrdering
    case quizShortAnswer
    case quizEssay
    case quizCodeExercise
    case quizDragDrop
    case quizHotspot
    case quizDrawing
    case quizVoiceResponse
    case quizMathInput
    
    // MARK: - Study Plan Elements
    case studyPlanOverview
    case studyPlanWeekly
    case studyPlanDaily
    case studySession
    case studyGoal
    case studyMilestone
    case studyProgress
    case studyStreak
    case studyCalendar
    case studyReminder
    case examCountdown
    case focusTimer
    case pomodoroTimer
    
    // MARK: - Mistake Tracker Elements
    case mistakeCard
    case mistakePattern
    case mistakeHeatmap
    case mistakeTimeline
    case mistakeInsight
    case mistakeQuickFix
    case mistakeReview
    case weakAreaChart
    case improvementGraph
    
    // MARK: - Homework & Assignment Elements
    case homeworkCard
    case homeworkList
    case homeworkProgress
    case homeworkDeadline
    case homeworkSubmission
    case assignmentDetails
    case gradeDisplay
    case rubricView
    case feedbackCard
    
    // MARK: - Document & Notes Elements
    case documentViewer
    case pdfViewer
    case noteCard
    case noteEditor
    case highlightedText
    case annotation
    case flashcard
    case flashcardDeck
    case summary
    case outline
    case keyPoints
    case definition
    case vocabulary
    case citation
    
    // MARK: - Course & Lesson Elements
    case courseCard
    case courseRoadmap
    case lessonBlock
    case moduleHeader
    case chapterNav
    case progressBar
    case completionBadge
    case prerequisiteCheck
    case learningPath
    case skillTree
    
    // MARK: - Layout & Container Elements
    case container
    case stack
    case hStack
    case vStack
    case zStack
    case grid
    case scrollView
    case lazyVStack
    case carousel
    case tabs
    case accordion
    case collapsible
    case modal
    case sheet
    case popover
    case tooltip
    case divider
    case spacer
    case card
    case section
    case group
    
    // MARK: - Navigation Elements
    case button
    case link
    case navigationLink
    case breadcrumb
    case stepIndicator
    case pagination
    case backButton
    case nextButton
    case skipButton
    case menuItem
    
    // MARK: - Widget Elements
    case topicSelection
    case suggestions
    case quickActions
    case recentItems
    case recommended
    case trending
    case searchBar
    case filterChips
    case tagCloud
    case statCard
    case metricDisplay
    case countdown
    case timer
    case calendar
    case weather
    case quote
    
    // MARK: - Gamification Elements
    case xpBadge
    case levelProgress
    case achievementCard
    case leaderboardRow
    case streakDisplay
    case rewardAnimation
    case challengeCard
    case battleCard
    case coinDisplay
    case energyBar
    case powerUp
    case questCard
    case dailyChallenge
    
    // MARK: - AI Assistant Elements
    case aiThinking
    case aiTyping
    case aiSuggestion
    case aiExplanation
    case aiHint
    case aiCorrection
    case aiEncouragement
    case aiMascot
    case chatBubble
    case typingIndicator
    case processingSpinner
    case loadingSkeleton
    
    // MARK: - Social Elements
    case userAvatar
    case userCard
    case commentCard
    case reactionBar
    case shareSheet
    case collaboratorList
    case studyGroup
    case liveSession
    case notification
    
    // MARK: - System Elements
    case error
    case warning
    case success
    case info
    case empty
    case loading
    case skeleton
    case placeholder
    case offline
    case maintenance
    case upgrade
    case premium
    case unknown
    
    // MARK: - Element Metadata
    
    /// Category for grouping related elements
    var category: A2UIElementCategory {
        switch self {
        case .text, .heading, .paragraph, .label, .caption, .richText, .markdown, .code, .codeBlock, .latex, .equation:
            return .coreDisplay
        case .image, .video, .audio, .animation, .lottie, .gif, .avatar, .icon, .diagram, .chart, .graph, .mindMap, .timeline, .ar3DModel:
            return .media
        case .voiceInput, .cameraCapture, .documentScanner, .sketchPad, .handwriting, .screenCapture, .fileUpload, .audioRecorder:
            return .multimodalInput
        case .textInput, .textArea, .slider, .toggle, .checkbox, .radioGroup, .dropdown, .datePicker, .timePicker, .colorPicker, .ratingStars, .stepper:
            return .interactiveInput
        case .quizMcq, .quizMultiSelect, .quizTrueFalse, .quizFillBlank, .quizMatching, .quizOrdering, .quizShortAnswer, .quizEssay, .quizCodeExercise, .quizDragDrop, .quizHotspot, .quizDrawing, .quizVoiceResponse, .quizMathInput:
            return .quiz
        case .studyPlanOverview, .studyPlanWeekly, .studyPlanDaily, .studySession, .studyGoal, .studyMilestone, .studyProgress, .studyStreak, .studyCalendar, .studyReminder, .examCountdown, .focusTimer, .pomodoroTimer:
            return .studyPlan
        case .mistakeCard, .mistakePattern, .mistakeHeatmap, .mistakeTimeline, .mistakeInsight, .mistakeQuickFix, .mistakeReview, .weakAreaChart, .improvementGraph:
            return .mistakeTracker
        case .homeworkCard, .homeworkList, .homeworkProgress, .homeworkDeadline, .homeworkSubmission, .assignmentDetails, .gradeDisplay, .rubricView, .feedbackCard:
            return .homework
        case .documentViewer, .pdfViewer, .noteCard, .noteEditor, .highlightedText, .annotation, .flashcard, .flashcardDeck, .summary, .outline, .keyPoints, .definition, .vocabulary, .citation:
            return .documents
        case .courseCard, .courseRoadmap, .lessonBlock, .moduleHeader, .chapterNav, .progressBar, .completionBadge, .prerequisiteCheck, .learningPath, .skillTree:
            return .course
        case .container, .stack, .hStack, .vStack, .zStack, .grid, .scrollView, .lazyVStack, .carousel, .tabs, .accordion, .collapsible, .modal, .sheet, .popover, .tooltip, .divider, .spacer, .card, .section, .group:
            return .layout
        case .button, .link, .navigationLink, .breadcrumb, .stepIndicator, .pagination, .backButton, .nextButton, .skipButton, .menuItem:
            return .navigation
        case .topicSelection, .suggestions, .quickActions, .recentItems, .recommended, .trending, .searchBar, .filterChips, .tagCloud, .statCard, .metricDisplay, .countdown, .timer, .calendar, .weather, .quote:
            return .widget
        case .xpBadge, .levelProgress, .achievementCard, .leaderboardRow, .streakDisplay, .rewardAnimation, .challengeCard, .battleCard, .coinDisplay, .energyBar, .powerUp, .questCard, .dailyChallenge:
            return .gamification
        case .aiThinking, .aiTyping, .aiSuggestion, .aiExplanation, .aiHint, .aiCorrection, .aiEncouragement, .aiMascot, .chatBubble, .typingIndicator, .processingSpinner, .loadingSkeleton:
            return .aiAssistant
        case .userAvatar, .userCard, .commentCard, .reactionBar, .shareSheet, .collaboratorList, .studyGroup, .liveSession, .notification:
            return .social
        case .error, .warning, .success, .info, .empty, .loading, .skeleton, .placeholder, .offline, .maintenance, .upgrade, .premium, .unknown:
            return .system
        }
    }
    
    /// Whether this element supports voice output (TTS)
    var supportsTTS: Bool {
        switch category {
        case .coreDisplay, .quiz, .aiAssistant, .documents:
            return true
        default:
            return false
        }
    }
    
    /// Whether this element accepts user input
    var isInteractive: Bool {
        switch category {
        case .interactiveInput, .quiz, .multimodalInput, .navigation:
            return true
        default:
            return false
        }
    }
    
    /// Whether this element can contain children
    var isContainer: Bool {
        switch self {
        case .container, .stack, .hStack, .vStack, .zStack, .grid, .scrollView, .lazyVStack, .carousel, .tabs, .accordion, .collapsible, .modal, .sheet, .card, .section, .group:
            return true
        default:
            return false
        }
    }
}

// MARK: - Element Category

enum A2UIElementCategory: String, Codable, CaseIterable {
    case coreDisplay = "core_display"
    case media = "media"
    case multimodalInput = "multimodal_input"
    case interactiveInput = "interactive_input"
    case quiz = "quiz"
    case studyPlan = "study_plan"
    case mistakeTracker = "mistake_tracker"
    case homework = "homework"
    case documents = "documents"
    case course = "course"
    case layout = "layout"
    case navigation = "navigation"
    case widget = "widget"
    case gamification = "gamification"
    case aiAssistant = "ai_assistant"
    case social = "social"
    case system = "system"
}
