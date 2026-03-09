//
//  LyoResponse.swift
//  Lyo
//
//  Unified response contract for A2UI v2.
//  One shape for both fast path (complete) and deep path (streamed).
//

import Foundation

// MARK: - Lyo Response (Unified Contract v2)

/// The single response envelope used by both fast and deep paths.
/// Fast path returns it complete; deep path streams fragments via SSE.
struct LyoResponse: Codable {
    /// Schema version (e.g. "2.0")
    let version: String
    
    /// Unique request identifier for tracing
    let requestId: String
    
    /// Plain-text AI response — always renderable even if `ui` is nil
    var message: String
    
    /// Optional structured UI component tree (v2 primitives)
    let ui: LyoUIComponent?
    
    /// Optional native command trigger (e.g. open_classroom, start_quiz)
    let command: LyoCommand?
    
    /// Context-aware suggestion chips
    let suggestions: [LyoSuggestion]?
    
    /// Conversation session identifier for continuity
    let conversationId: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case requestId = "request_id"
        case message
        case ui
        case command
        case suggestions
        case conversationId = "conversation_id"
    }
}

// MARK: - Lyo UI Component (v2)

/// A2UI v2 component node — uses 22 primitives + variant instead of 150+ types.
struct LyoUIComponent: Codable, Identifiable, Equatable {
    let id: String
    let type: A2UIPrimitive
    let variant: String?
    
    /// Universal content properties (text, title, image, etc.)
    let content: LyoContentProps?
    
    /// Client-hint styling (client may override)
    let style: LyoStyleProps?
    
    /// Domain-specific typed data (quiz options, course modules, etc.)
    let data: [String: AnyCodableValue]?
    
    /// Recursive children for layout primitives
    let children: [LyoUIComponent]?
    
    /// User interaction actions
    let actions: [A2UIAction]?
    
    /// Conditional rendering rules
    let conditions: A2UIConditions?
    
    /// Analytics / debug metadata
    let meta: LyoMetaProps?
    
    // MARK: - Init
    
    init(
        id: String = UUID().uuidString,
        type: A2UIPrimitive,
        variant: String? = nil,
        content: LyoContentProps? = nil,
        style: LyoStyleProps? = nil,
        data: [String: AnyCodableValue]? = nil,
        children: [LyoUIComponent]? = nil,
        actions: [A2UIAction]? = nil,
        conditions: A2UIConditions? = nil,
        meta: LyoMetaProps? = nil
    ) {
        self.id = id
        self.type = type
        self.variant = variant
        self.content = content
        self.style = style
        self.data = data
        self.children = children
        self.actions = actions
        self.conditions = conditions
        self.meta = meta
    }
    
    // MARK: - Custom Decoder
    
    private enum CodingKeys: String, CodingKey {
        case id, type, variant, content, style, data, children, actions, conditions, meta
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        type     = try c.decode(A2UIPrimitive.self, forKey: .type)
        variant  = try? c.decodeIfPresent(String.self, forKey: .variant)
        content  = try? c.decodeIfPresent(LyoContentProps.self, forKey: .content)
        style    = try? c.decodeIfPresent(LyoStyleProps.self, forKey: .style)
        data     = try? c.decodeIfPresent([String: AnyCodableValue].self, forKey: .data)
        
        if let childWrappers = try? c.decodeIfPresent([SafeDecodable<LyoUIComponent>].self, forKey: .children) {
            children = childWrappers.compactMap { $0.value }
        } else {
            children = nil
        }
        
        actions    = try? c.decodeIfPresent([A2UIAction].self, forKey: .actions)
        conditions = try? c.decodeIfPresent(A2UIConditions.self, forKey: .conditions)
        meta       = try? c.decodeIfPresent(LyoMetaProps.self, forKey: .meta)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: LyoUIComponent, rhs: LyoUIComponent) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.variant == rhs.variant
    }
    
    // MARK: - Resolved Variant
    
    /// Returns the variant, falling back to the primitive's default.
    var resolvedVariant: String {
        variant ?? type.defaultVariant ?? ""
    }
}

// MARK: - Content Props

/// Universal content properties shared across all primitives.
/// Only populate what's relevant — no 180-field god bag.
struct LyoContentProps: Codable, Equatable {
    var text: String?
    var title: String?
    var subtitle: String?
    var body: String?           // markdown content
    var label: String?
    var placeholder: String?
    var hint: String?
    var icon: String?           // SF Symbol name or asset name
    var imageUrl: String?
    var mediaUrl: String?       // video / audio URL
    var altText: String?
    
    enum CodingKeys: String, CodingKey {
        case text, title, subtitle, body, label, placeholder, hint, icon
        case imageUrl = "image_url"
        case mediaUrl = "media_url"
        case altText  = "alt_text"
    }
    
    init(
        text: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        body: String? = nil,
        label: String? = nil,
        placeholder: String? = nil,
        hint: String? = nil,
        icon: String? = nil,
        imageUrl: String? = nil,
        mediaUrl: String? = nil,
        altText: String? = nil
    ) {
        self.text = text
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        self.icon = icon
        self.imageUrl = imageUrl
        self.mediaUrl = mediaUrl
        self.altText = altText
    }
}

// MARK: - Style Props

/// Client-hint styling. The client CAN override all of these.
struct LyoStyleProps: Codable, Equatable {
    var foreground: String?
    var background: String?
    var spacing: Double?
    var padding: LyoEdgeInsets?
    var radius: Double?
    var axis: String?           // "h" or "v" for containers
    var columns: Int?           // for grid variant
    var fontSize: Double?
    var fontWeight: String?
    var alignment: String?
    var opacity: Double?
    var borderColor: String?
    var borderWidth: Double?
    
    enum CodingKeys: String, CodingKey {
        case foreground, background, spacing, padding, radius, axis, columns
        case fontSize = "font_size"
        case fontWeight = "font_weight"
        case alignment, opacity
        case borderColor = "border_color"
        case borderWidth = "border_width"
    }
    
    init(
        foreground: String? = nil,
        background: String? = nil,
        spacing: Double? = nil,
        padding: LyoEdgeInsets? = nil,
        radius: Double? = nil,
        axis: String? = nil,
        columns: Int? = nil,
        fontSize: Double? = nil,
        fontWeight: String? = nil,
        alignment: String? = nil,
        opacity: Double? = nil,
        borderColor: String? = nil,
        borderWidth: Double? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.spacing = spacing
        self.padding = padding
        self.radius = radius
        self.axis = axis
        self.columns = columns
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.alignment = alignment
        self.opacity = opacity
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}

/// Simple edge insets for v2 style props
struct LyoEdgeInsets: Codable, Equatable {
    let top: Double
    let leading: Double
    let bottom: Double
    let trailing: Double
    
    static func all(_ v: Double) -> LyoEdgeInsets {
        LyoEdgeInsets(top: v, leading: v, bottom: v, trailing: v)
    }
    
    static func symmetric(h: Double = 0, v: Double = 0) -> LyoEdgeInsets {
        LyoEdgeInsets(top: v, leading: h, bottom: v, trailing: h)
    }
    
    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

import SwiftUI

// MARK: - Meta Props

/// Analytics, debug, and accessibility metadata.
struct LyoMetaProps: Codable, Equatable {
    var analyticsId: String?
    var debugLabel: String?
    var version: String?
    var tags: [String]?
    var speakableText: String?      // TTS override
    var accessibilityLabel: String?
    var accessibilityHint: String?
    
    enum CodingKeys: String, CodingKey {
        case analyticsId = "analytics_id"
        case debugLabel = "debug_label"
        case version, tags
        case speakableText = "speakable_text"
        case accessibilityLabel = "accessibility_label"
        case accessibilityHint = "accessibility_hint"
    }
}

// MARK: - Lyo Command

/// Explicit native command trigger — replaces the embedded OPEN_CLASSROOM regex hack.
struct LyoCommand: Codable, Equatable {
    /// Action identifier: "open_classroom", "start_quiz", "show_flashcards", etc.
    let action: String
    
    /// Action-specific payload
    let payload: [String: AnyCodableValue]?
}

// MARK: - Lyo Suggestion

/// Context-aware suggestion chip shown below the response.
struct LyoSuggestion: Codable, Equatable {
    let text: String
    let actionId: String?
    let icon: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case actionId = "action_id"
        case icon
    }
}

// MARK: - Lyo Stream Assembler

/// Accumulates SSE events into a complete LyoResponse.
/// Deep path streams fragments; this class assembles them.
@MainActor
final class LyoStreamAssembler {
    private(set) var version: String = "2.0"
    private(set) var requestId: String = UUID().uuidString
    private(set) var messageParts: [String] = []
    private(set) var ui: LyoUIComponent?
    private(set) var command: LyoCommand?
    private(set) var suggestions: [LyoSuggestion]?
    private(set) var conversationId: String?
    private(set) var isComplete = false
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    /// Handle a single SSE event. Returns true when done.
    @discardableResult
    func handleEvent(name: String, data: Data) -> Bool {
        switch name {
        case "start":
            if let meta = try? decoder.decode(StreamStartEvent.self, from: data) {
                version = meta.version ?? "2.0"
                requestId = meta.requestId ?? UUID().uuidString
            }
            
        case "message":
            if let delta = try? decoder.decode(StreamMessageDelta.self, from: data) {
                messageParts.append(delta.delta)
            }
            
        case "ui":
            ui = try? decoder.decode(LyoUIComponent.self, from: data)
            
        case "command":
            command = try? decoder.decode(LyoCommand.self, from: data)
            
        case "suggestions":
            suggestions = try? decoder.decode([LyoSuggestion].self, from: data)
            
        case "done":
            isComplete = true
            return true
            
        default:
            break
        }
        return false
    }
    
    /// Current accumulated message text.
    var currentMessage: String {
        messageParts.joined()
    }
    
    /// Build the final assembled response.
    func build() -> LyoResponse {
        LyoResponse(
            version: version,
            requestId: requestId,
            message: currentMessage,
            ui: ui,
            command: command,
            suggestions: suggestions,
            conversationId: conversationId
        )
    }
    
    /// Reset for reuse.
    func reset() {
        version = "2.0"
        requestId = UUID().uuidString
        messageParts = []
        ui = nil
        command = nil
        suggestions = nil
        conversationId = nil
        isComplete = false
    }
}

// MARK: - Stream Event DTOs

private struct StreamStartEvent: Decodable {
    let version: String?
    let requestId: String?
}

private struct StreamMessageDelta: Decodable {
    let delta: String
}

// MARK: - V1 → V2 Bridge

extension LyoUIComponent {
    /// Convert a legacy `A2UIComponent` into a v2 `LyoUIComponent`.
    /// Returns nil if the element type can't be mapped.
    static func from(legacy comp: A2UIComponent) -> LyoUIComponent? {
        guard let primitive = mapPrimitive(comp.type) else { return nil }
        
        let content = LyoContentProps(
            text: comp.props.text,
            title: comp.props.title,
            subtitle: comp.props.subtitle,
            body: comp.props.body,
            label: comp.props.label,
            placeholder: comp.props.placeholder,
            hint: comp.props.hint,
            icon: comp.props.icon,
            imageUrl: comp.props.imageUrl,
            mediaUrl: comp.props.videoUrl ?? comp.props.audioUrl,
            altText: comp.props.altText
        )
        
        let style = LyoStyleProps(
            foreground: comp.props.foregroundColor,
            background: comp.props.backgroundColor,
            spacing: comp.props.spacing,
            padding: comp.props.padding.map { edge in
                LyoEdgeInsets(
                    top: edge.top,
                    leading: edge.leading,
                    bottom: edge.bottom,
                    trailing: edge.trailing
                )
            },
            radius: comp.props.borderRadius,
            axis: comp.props.axis,
            columns: comp.props.columns,
            fontSize: comp.props.fontSize,
            fontWeight: comp.props.fontWeight,
            alignment: comp.props.alignment?.rawValue,
            opacity: comp.props.opacity,
            borderColor: comp.props.borderColor,
            borderWidth: comp.props.borderWidth
        )
        
        let variant = comp.variant ?? defaultVariant(for: comp.type)
        
        // Extract domain-specific data from the A2UIProps god-bag into the typed data dict
        let data = extractDomainData(from: comp.props, primitive: primitive)
        
        // Map metadata
        let meta: LyoMetaProps? = comp.metadata.map { m in
            LyoMetaProps(
                analyticsId: m.analyticsId,
                debugLabel: m.debugLabel,
                version: m.version,
                tags: m.tags
            )
        }
        
        // Convert children recursively
        let v2Children = comp.children?.compactMap { LyoUIComponent.from(legacy: $0) }
        
        return LyoUIComponent(
            id: comp.id,
            type: primitive,
            variant: variant,
            content: content,
            style: style,
            data: data,
            children: v2Children,
            actions: comp.actions,
            conditions: comp.conditions,
            meta: meta
        )
    }
    
    // MARK: - Domain Data Extraction
    
    /// Extracts domain-specific fields from A2UIProps into a typed dictionary.
    /// Only includes keys that are actually populated.
    private static func extractDomainData(from props: A2UIProps, primitive: A2UIPrimitive) -> [String: AnyCodableValue]? {
        var data: [String: AnyCodableValue] = [:]
        
        switch primitive {
        case .quiz:
            if let q = props.question        { data["question"] = .string(q) }
            if let e = props.explanation      { data["explanation"] = .string(e) }
            if let s = props.shuffleOptions   { data["shuffle_options"] = .bool(s) }
            if let s = props.showFeedback     { data["show_feedback"] = .bool(s) }
            if let m = props.maxAttempts      { data["max_attempts"] = .int(m) }
            if let t = props.timeLimit        { data["time_limit"] = .int(t) }
            if let p = props.points           { data["points"] = .int(p) }
            if let d = props.difficulty       { data["difficulty"] = .string(d) }
            
        case .flashcard:
            if let f = props.front ?? props.flashcardFront  { data["front"] = .string(f) }
            if let b = props.back ?? props.flashcardBack    { data["back"] = .string(b) }
            if let fm = props.frontMedia      { data["front_media"] = .string(fm) }
            if let bm = props.backMedia       { data["back_media"] = .string(bm) }
            if let ci = props.cardIndex       { data["card_index"] = .int(ci) }
            if let tc = props.totalCards      { data["total_cards"] = .int(tc) }
            if let c = props.confidence       { data["confidence"] = .double(c) }
            
        case .course:
            if let cid = props.courseId       { data["course_id"] = .string(cid) }
            if let cn = props.courseName      { data["course_name"] = .string(cn) }
            if let lvl = props.level          { data["level"] = .string(lvl) }
            if let ed = props.estimatedDuration { data["estimated_duration"] = .int(ed) }
            if let cp = props.completionPercentage { data["completion_percentage"] = .double(cp) }
            if let inst = props.instructor    { data["instructor"] = .string(inst) }
            if let objs = props.objectives    { data["objectives"] = .array(objs.map { .string($0) }) }
            if let prereqs = props.prerequisites { data["prerequisites"] = .array(prereqs.map { .string($0) }) }
            
        case .plan:
            if let gt = props.goalTitle       { data["goal_title"] = .string(gt) }
            if let gd = props.goalDescription { data["goal_description"] = .string(gd) }
            if let p = props.progress         { data["progress"] = .double(p) }
            if let cc = props.completedCount  { data["completed_count"] = .int(cc) }
            if let tc = props.totalCount      { data["total_count"] = .int(tc) }
            if let dur = props.duration       { data["duration"] = .int(dur) }
            if let pri = props.priority       { data["priority"] = .string(pri) }
            if let st = props.status          { data["status"] = .string(st) }
            
        case .progress:
            if let p = props.progress         { data["value"] = .double(p) }
            if let tc = props.totalCount      { data["total"] = .int(tc) }
            if let cc = props.completedCount  { data["completed"] = .int(cc) }
            if let xp = props.xp              { data["xp"] = .int(xp) }
            if let streak = props.streak      { data["streak"] = .int(streak) }
            if let lvl = props.levelNumber    { data["level"] = .int(lvl) }
            
        case .assignment:
            if let hid = props.homeworkId     { data["homework_id"] = .string(hid) }
            if let at = props.assignmentTitle  { data["assignment_title"] = .string(at) }
            if let sub = props.subject        { data["subject"] = .string(sub) }
            if let g = props.grade            { data["grade"] = .string(g) }
            if let mg = props.maxGrade        { data["max_grade"] = .string(mg) }
            if let fb = props.feedback        { data["feedback"] = .string(fb) }
            if let il = props.isLate          { data["is_late"] = .bool(il) }
            
        case .tracker:
            if let mt = props.mistakeType     { data["mistake_type"] = .string(mt) }
            if let topic = props.topic        { data["topic"] = .string(topic) }
            if let ct = props.conceptTag      { data["concept_tag"] = .string(ct) }
            if let oc = props.occurrenceCount { data["occurrence_count"] = .int(oc) }
            if let ml = props.masteryLevel    { data["mastery_level"] = .double(ml) }
            if let ra = props.recommendedAction { data["recommended_action"] = .string(ra) }
            
        case .document:
            if let du = props.documentUrl     { data["document_url"] = .string(du) }
            if let dt = props.documentType    { data["document_type"] = .string(dt) }
            if let pc = props.pageCount       { data["page_count"] = .int(pc) }
            if let cp = props.currentPage     { data["current_page"] = .int(cp) }
            if let sp = props.summaryPoints   { data["summary_points"] = .array(sp.map { .string($0) }) }
            
        default:
            break
        }
        
        return data.isEmpty ? nil : data
    }
    
    // MARK: - Element Type → Primitive Mapping
    
    private static func mapPrimitive(_ type: A2UIElementType) -> A2UIPrimitive? {
        switch type {
        // Content
        case .text, .paragraph, .heading, .label, .caption, .markdown, .richText,
             .code, .codeBlock, .latex, .equation:
            return .text
        case .image, .avatar, .icon, .video, .audio, .animation, .lottie, .gif:
            return .media
        case .diagram, .chart, .graph, .mindMap, .timeline:
            return .media
        case .divider, .spacer:
            return .divider
            
        // Input
        case .textInput, .textArea, .voiceInput, .slider, .toggle, .checkbox, .radioGroup,
             .dropdown, .datePicker, .timePicker, .colorPicker, .ratingStars, .stepper,
             .handwriting, .sketchPad, .fileUpload, .audioRecorder, .screenCapture, .cameraCapture, .documentScanner:
            return .input
        case .button, .backButton, .nextButton, .skipButton:
            return .button
            
        // Layout
        case .container, .stack, .vStack, .hStack, .zStack, .scrollView, .lazyVStack,
             .carousel, .section, .group, .grid, .tabs, .accordion, .collapsible,
             .modal, .sheet, .popover, .tooltip:
            return .container
        case .card, .statCard, .metricDisplay:
            return .card
            
        // Navigation
        case .link, .navigationLink, .menuItem:
            return .nav
        case .breadcrumb, .stepIndicator, .pagination:
            return .nav
            
        // Learning
        case .quizMcq, .quizMultiSelect, .quizTrueFalse, .quizFillBlank, .quizShortAnswer,
             .quizEssay, .quizCodeExercise, .quizDragDrop, .quizHotspot, .quizDrawing,
             .quizVoiceResponse, .quizMathInput, .quizMatching, .quizOrdering:
            return .quiz
        case .courseCard, .courseRoadmap, .course, .courseHeader, .courseOutline,
             .lessonBlock, .moduleHeader, .chapterNav, .lessonList, .completionBadge,
             .prerequisiteCheck, .learningPath, .skillTree:
            return .course
        case .flashcard, .flashcardDeck:
            return .flashcard
        case .studyPlanOverview, .studyPlanWeekly, .studyPlanDaily, .studySession,
             .studyCalendar, .studyGoal, .studyProgress, .studyReminder, .examCountdown:
            return .plan
        case .studyMilestone, .studyStreak, .mistakeCard, .mistakePattern, .mistakeReview,
             .mistakeQuickFix, .mistakeHeatmap, .mistakeTimeline, .mistakeInsight,
             .weakAreaChart, .improvementGraph:
            return .tracker
        case .homeworkCard, .homeworkList, .homeworkSubmission, .assignmentDetails,
             .feedbackCard, .homeworkProgress, .homeworkDeadline, .gradeDisplay, .rubricView:
            return .assignment
        case .documentViewer, .pdfViewer, .noteCard, .noteEditor, .highlightedText,
             .annotation, .summary, .outline, .keyPoints, .definition, .vocabulary, .citation:
            return .document
            
        // Engagement
        case .progressBar, .xpBadge, .levelProgress, .achievementCard, .leaderboardRow,
             .streakDisplay, .rewardAnimation, .coinDisplay, .energyBar, .powerUp, .dailyChallenge:
            return .progress
        case .chatBubble, .aiExplanation, .aiHint, .aiCorrection, .aiEncouragement, .aiMascot,
             .typingIndicator, .aiTyping, .aiSuggestion, .aiThinking, .processingSpinner:
            return .aiBubble
        case .userCard, .userAvatar, .commentCard, .studyGroup, .liveSession,
             .reactionBar, .shareSheet, .collaboratorList, .notification:
            return .social
        case .error, .warning, .info, .success:
            return .alert
        case .loading, .skeleton, .loadingSkeleton:
            return .skeleton
            
        // System / fallback
        case .empty, .placeholder, .offline, .maintenance, .upgrade, .premium, .unknown,
             .focusTimer, .pomodoroTimer, .countdown, .timer, .quote, .weather,
             .topicSelection, .suggestions, .quickActions, .recentItems, .recommended,
             .trending, .searchBar, .filterChips, .tagCloud, .calendar,
             .challengeCard, .battleCard, .questCard, .ar3DModel:
            return .container  // Fallback to generic container
        }
    }
    
    /// Best-effort default variant from the v1 type name.
    private static func defaultVariant(for type: A2UIElementType) -> String {
        switch type {
        case .heading: return "heading"
        case .paragraph, .text: return "paragraph"
        case .caption: return "caption"
        case .code, .codeBlock: return "code"
        case .markdown, .richText: return "markdown"
        case .latex, .equation: return "latex"
        case .label: return "label"
        case .image, .avatar, .icon: return "image"
        case .video: return "video"
        case .audio: return "audio"
        case .diagram, .chart, .graph: return "chart"
        case .quizMcq: return "mcq"
        case .quizMultiSelect: return "multi-select"
        case .quizTrueFalse: return "true-false"
        case .quizFillBlank: return "fill-blank"
        case .quizShortAnswer: return "short-answer"
        case .courseCard, .courseHeader: return "overview"
        case .moduleHeader: return "module"
        case .lessonBlock: return "lesson"
        case .courseOutline: return "outline"
        case .courseRoadmap: return "roadmap"
        case .flashcard, .flashcardDeck: return "default"
        case .studyPlanOverview: return "overview"
        case .studyPlanWeekly: return "weekly"
        case .studyPlanDaily: return "daily"
        case .studySession: return "session"
        case .homeworkCard: return "card"
        case .assignmentDetails: return "detail"
        case .error: return "error"
        case .warning: return "warning"
        case .info: return "info"
        case .success: return "success"
        case .loading, .skeleton, .loadingSkeleton: return "card"
        default: return "default"
        }
    }
}
