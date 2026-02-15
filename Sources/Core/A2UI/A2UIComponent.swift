//
//  A2UIComponent.swift
//  Lyo
//
//  Component tree structure for A2UI rendering
//  Backend sends these structures to drive dynamic UI
//

import Foundation

// MARK: - A2UI Component

/// Main component structure sent from backend
/// Supports recursive children for complex layouts
struct A2UIComponent: Codable, Identifiable, Equatable {
    let id: String
    let type: A2UIElementType
    let props: A2UIProps
    let children: [A2UIComponent]?
    let actions: [A2UIAction]?
    let conditions: A2UIConditions?
    let metadata: A2UIMetadata?
    
    init(
        id: String = UUID().uuidString,
        type: A2UIElementType,
        props: A2UIProps = A2UIProps(),
        children: [A2UIComponent]? = nil,
        actions: [A2UIAction]? = nil,
        conditions: A2UIConditions? = nil,
        metadata: A2UIMetadata? = nil
    ) {
        self.id = id
        self.type = type
        self.props = props
        self.children = children
        self.actions = actions
        self.conditions = conditions
        self.metadata = metadata
    }
    
    static func == (lhs: A2UIComponent, rhs: A2UIComponent) -> Bool {
        lhs.id == rhs.id
        && lhs.type == rhs.type
        && lhs.props == rhs.props
        && lhs.children == rhs.children
        && lhs.actions == rhs.actions
        && lhs.conditions == rhs.conditions
        && lhs.metadata == rhs.metadata
    }
}

// MARK: - A2UI Action

/// Actions that can be triggered by user interaction
struct A2UIAction: Codable, Identifiable, Equatable {
    let id: String
    let trigger: A2UIActionTrigger
    let type: A2UIActionType
    let payload: [String: AnyCodableValue]?
    let debounceMs: Int?
    let hapticFeedback: String?
    
    enum CodingKeys: String, CodingKey {
        case id, trigger, type, payload
        case debounceMs = "debounce_ms"
        case hapticFeedback = "haptic_feedback"
    }

    init(
        id: String = UUID().uuidString,
        trigger: A2UIActionTrigger,
        type: A2UIActionType,
        payload: [String: AnyCodableValue]? = nil,
        debounceMs: Int? = nil,
        hapticFeedback: String? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.type = type
        self.payload = payload
        self.debounceMs = debounceMs
        self.hapticFeedback = hapticFeedback
    }
}

enum A2UIActionTrigger: String, Codable {
    case tap
    case doubleTap = "double_tap"
    case longPress = "long_press"
    case swipeLeft = "swipe_left"
    case swipeRight = "swipe_right"
    case swipeUp = "swipe_up"
    case swipeDown = "swipe_down"
    case onChange = "on_change"
    case onSubmit = "on_submit"
    case onAppear = "on_appear"
    case onDisappear = "on_disappear"
    case onFocus = "on_focus"
    case onBlur = "on_blur"
    case onComplete = "on_complete"
    case onError = "on_error"
    case onTimeout = "on_timeout"
    case voiceCommand = "voice_command"
}

enum A2UIActionType: String, Codable {
    // Navigation
    case navigate
    case navigateBack = "navigate_back"
    case openSheet = "open_sheet"
    case closeSheet = "close_sheet"
    case openModal = "open_modal"
    case closeModal = "close_modal"
    case openURL = "open_url"
    case deepLink = "deep_link"
    
    // Data
    case submit
    case save
    case delete
    case update
    case submitAnswer = "submit_answer"
    case refresh
    case load
    case validate
    
    // AI
    case sendMessage = "send_message"
    case askAI = "ask_ai"
    case requestHint = "request_hint"
    case requestExplanation = "request_explanation"
    case generateQuiz = "generate_quiz"
    case startSession = "start_session"
    case endSession = "end_session"
    
    // Study
    case startStudy = "start_study"
    case pauseStudy = "pause_study"
    case resumeStudy = "resume_study"
    case completeLesson = "complete_lesson"
    case markMistake = "mark_mistake"
    case addToStudyPlan = "add_to_study_plan"
    case scheduleReminder = "schedule_reminder"
    
    // Media
    case playAudio = "play_audio"
    case pauseAudio = "pause_audio"
    case playVideo = "play_video"
    case capturePhoto = "capture_photo"
    case startRecording = "start_recording"
    case stopRecording = "stop_recording"
    case scanDocument = "scan_document"
    
    // Gamification
    case claimReward = "claim_reward"
    case shareAchievement = "share_achievement"
    case joinChallenge = "join_challenge"
    case startBattle = "start_battle"
    
    // Homework
    case submitHomework = "submit_homework"
    case requestExtension = "request_extension"
    case attachFile = "attach_file"
    
    // System
    case showToast = "show_toast"
    case vibrate
    case copyToClipboard = "copy_to_clipboard"
    case share
    case print
    case export
    case log
    case analytics
    case custom
}

// MARK: - A2UI Conditions

/// Conditional rendering rules
struct A2UIConditions: Codable, Equatable {
    let showIf: String?
    let hideIf: String?
    let enableIf: String?
    let disableIf: String?
    let animateIf: String?
    let repeatWhile: String?
    let minPlatformVersion: String?
    let requiredCapabilities: [String]?
    let userTier: [String]?
    
    enum CodingKeys: String, CodingKey {
        case showIf = "show_if"
        case hideIf = "hide_if"
        case enableIf = "enable_if"
        case disableIf = "disable_if"
        case animateIf = "animate_if"
        case repeatWhile = "repeat_while"
        case minPlatformVersion = "min_platform_version"
        case requiredCapabilities = "required_capabilities"
        case userTier = "user_tier"
    }
}

// MARK: - A2UI Metadata

/// Additional component metadata for analytics and debugging
struct A2UIMetadata: Codable, Equatable {
    let analyticsId: String?
    let testId: String?
    let debugLabel: String?
    let version: String?
    let createdAt: Date?
    let expiresAt: Date?
    let priority: Int?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case analyticsId = "analytics_id"
        case testId = "test_id"
        case debugLabel = "debug_label"
        case version
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case priority
        case tags
    }
}

// MARK: - A2UI Response

/// Complete response from backend containing A2UI components
struct A2UIResponse: Codable {
    let version: String
    let root: A2UIComponent
    let context: A2UIContext?
    let animations: [A2UIAnimation]?
    let styles: A2UIStyleSheet?
    
    enum CodingKeys: String, CodingKey {
        case version
        case root
        case context
        case animations
        case styles
    }
}

// MARK: - A2UI Context

/// Shared context for component tree
struct A2UIContext: Codable {
    let sessionId: String?
    let userId: String?
    let courseId: String?
    let lessonId: String?
    let locale: String?
    let theme: String?
    let voiceEnabled: Bool?
    let reducedMotion: Bool?
    let highContrast: Bool?
    let variables: [String: AnyCodableValue]?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case courseId = "course_id"
        case lessonId = "lesson_id"
        case locale, theme
        case voiceEnabled = "voice_enabled"
        case reducedMotion = "reduced_motion"
        case highContrast = "high_contrast"
        case variables
    }
}

// MARK: - A2UI Animation

/// Animation definitions for components
struct A2UIAnimation: Codable, Identifiable {
    let id: String
    let name: String
    let type: A2UIAnimationType
    let duration: Double
    let delay: Double?
    let easing: String?
    let repeatCount: Int?
    let autoReverse: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, duration, delay, easing
        case repeatCount = "repeat_count"
        case autoReverse = "auto_reverse"
    }
}

enum A2UIAnimationType: String, Codable {
    case fadeIn = "fade_in"
    case fadeOut = "fade_out"
    case slideIn = "slide_in"
    case slideOut = "slide_out"
    case scaleIn = "scale_in"
    case scaleOut = "scale_out"
    case bounce
    case shake
    case pulse
    case spin
    case flip
    case morph
    case confetti
    case celebration
    case custom
}

// MARK: - A2UI Style Sheet

/// Shared styles that can be referenced by components
struct A2UIStyleSheet: Codable {
    let colors: [String: String]?
    let fonts: [String: A2UIFontStyle]?
    let spacing: [String: Double]?
    let borderRadius: [String: Double]?
    let shadows: [String: A2UIShadowStyle]?
    
    enum CodingKeys: String, CodingKey {
        case colors, fonts, spacing
        case borderRadius = "border_radius"
        case shadows
    }
}

struct A2UIFontStyle: Codable {
    let family: String?
    let size: Double
    let weight: String?
    let lineHeight: Double?
    
    enum CodingKeys: String, CodingKey {
        case family, size, weight
        case lineHeight = "line_height"
    }
}

struct A2UIShadowStyle: Codable {
    let color: String
    let opacity: Double
    let radius: Double
    let x: Double
    let y: Double
}

// MARK: - AnyCodableValue

/// Type-erased wrapper for JSON values
enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dict)
        } else {
            self = .null
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
    
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    
    var value: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .array(let arr): return arr.map { $0.value }
        case .dictionary(let dict): return dict.mapValues { $0.value }
        case .null: return NSNull()
        }
    }
}
