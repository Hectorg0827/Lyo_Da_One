//
//  A2UIRenderer.swift
//  Lyo
//
//  Main SwiftUI renderer for A2UI components
//  Routes component types to appropriate SwiftUI views
//

import SwiftUI
import Foundation
import UIKit

// MARK: - A2UI Render Context

/// Rendering context for A2UI components
struct A2UIRenderContext {
    let screenSize: CGSize
    let theme: A2UITheme
    let accessibility: A2UIAccessibilitySettings

    init(
        screenSize: CGSize = CGSize(width: 375, height: 812),
        theme: A2UITheme = A2UITheme.default,
        accessibility: A2UIAccessibilitySettings = A2UIAccessibilitySettings.default
    ) {
        self.screenSize = screenSize
        self.theme = theme
        self.accessibility = accessibility
    }
}

struct A2UITheme {
    let primaryColor: String
    let backgroundColor: String
    let isDarkMode: Bool

    static let `default` = A2UITheme(
        primaryColor: "#6366F1",
        backgroundColor: "#FFFFFF",
        isDarkMode: false
    )
}

struct A2UIAccessibilitySettings {
    let reduceMotion: Bool
    let increasedTextSize: Bool
    let highContrast: Bool

    static let `default` = A2UIAccessibilitySettings(
        reduceMotion: false,
        increasedTextSize: false,
        highContrast: false
    )
}

// MARK: - A2UI Renderer

/// Main entry point for rendering A2UI component trees
struct A2UIRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?

    init(
        component: A2UIComponent,
        context: A2UIRenderContext = A2UIRenderContext(),
        onAction: ((A2UIAction, A2UIComponent) -> Void)? = nil
    ) {
        self.component = component
        self.context = context
        self.onAction = onAction
    }

    var body: some View {
        // Wrap in AnyView to strict break type recursion for SwiftUI
        AnyView(renderRoot(component))
            .onAppear {
                // Register this UI tree for voice control
                if let onAction = onAction {
                    A2UIVoiceController.shared.registerActiveUI(component: component, onAction: onAction)
                }
            }
    }

    // MARK: - V2 Bridge

    /// When A2UI v2 is enabled and the component carries a `variant`,
    /// convert it to a `LyoUIComponent` and render via the primitive engine.
    @ViewBuilder
    private func renderRoot(_ comp: A2UIComponent) -> some View {
        if AppConfig.isA2UIv2Enabled, comp.variant != nil,
           let v2Comp = LyoUIComponent.from(legacy: comp) {
            LyoPrimitiveRenderer(
                component: v2Comp,
                context: context,
                onAction: { cmd in
                    // Bridge LyoCommand back to A2UIAction
                    let actionType = A2UIActionType(rawValue: cmd.action) ?? .submit
                    let action = A2UIAction(
                        trigger: .tap,
                        type: actionType,
                        payload: cmd.payload
                    )
                    self.onAction?(action, comp)
                }
            )
        } else {
            renderComponent(comp)
        }
    }


    // MARK: - Component Router

    @ViewBuilder
    private func renderComponent(_ comp: A2UIComponent) -> some View {
        if shouldRender(comp) {
            renderContent(comp)
        }
    }

    @ViewBuilder
    private func renderContent(_ comp: A2UIComponent) -> some View {
        switch comp.type {
        // MARK: - Core Display
        // Route plain text components that contain block-level markdown
        // (bullets, headers) to the full markdown renderer so they get
        // proper VStack layout. Pure inline text stays in A2UITextRenderer.
        case .text, .paragraph:
            let body = comp.props.text ?? comp.props.body ?? ""
            let hasBlockMarkdown = body.components(separatedBy: "\n")
                .contains { $0.hasPrefix("* ") || $0.hasPrefix("- ") || $0.hasPrefix("# ") }
            if hasBlockMarkdown {
                AnyView(A2UIMarkdownRenderer(component: comp, context: context, onAction: handleAction))
            } else {
                AnyView(A2UITextRenderer(component: comp, context: context, onAction: handleAction))
            }
        case .heading, .label, .caption:
            AnyView(A2UITextRenderer(component: comp, context: context, onAction: handleAction))
        case .markdown, .richText:
            AnyView(A2UIMarkdownRenderer(component: comp, context: context, onAction: handleAction))
        case .code, .codeBlock:
            AnyView(A2UICodeRenderer(component: comp, context: context, onAction: handleAction))
        case .latex, .equation:
            AnyView(A2UILatexRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Layout
        case .stack, .vStack, .hStack:
            AnyView(A2UIStackRenderer(component: comp, context: context, onAction: handleAction))
        case .grid:
            AnyView(A2UIGridRenderer(component: comp, context: context, onAction: handleAction))
        case .card:
            AnyView(A2UICardRenderer(component: comp, context: context, onAction: handleAction))
        
        // MARK: - Media
        case .image, .avatar, .icon:
            AnyView(A2UIImageRenderer(component: comp, context: context, onAction: handleAction))
        case .video:
            AnyView(A2UIVideoRenderer(component: comp, context: context, onAction: handleAction))
        case .audio:
            AnyView(A2UIAudioRenderer(component: comp, context: context, onAction: handleAction))
        case .diagram, .chart, .graph:
            AnyView(A2UIDiagramRenderer(component: comp, context: context, onAction: handleAction))
            
        // MARK: - Input
        case .textInput, .textArea:
            AnyView(A2UITextInputRenderer(component: comp, context: context, onAction: handleAction))
        case .voiceInput:
            AnyView(A2UIVoiceInputRenderer(component: comp, context: context, onAction: handleAction))
        case .cameraCapture, .documentScanner:
            AnyView(A2UICameraRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Quiz
        case .quizMcq:
            AnyView(A2UIQuizMCQRenderer(component: comp, context: context, onAction: handleAction))
        case .quizMultiSelect:
            AnyView(A2UIQuizMultiSelectRenderer(component: comp, context: context, onAction: handleAction))
        case .quizTrueFalse:
            AnyView(A2UIQuizTrueFalseRenderer(component: comp, context: context, onAction: handleAction))
        case .quizFillBlank:
            AnyView(A2UIQuizFillBlankRenderer(component: comp, context: context, onAction: handleAction))
        case .quizShortAnswer:
            AnyView(A2UIQuizShortAnswerRenderer(component: comp, context: context, onAction: handleAction))
            
        // MARK: - Course
        case .courseCard, .courseRoadmap:
            AnyView(A2UICourseCardRenderer(component: comp, context: context, onAction: handleAction))
        case .course:
            AnyView(A2UICourseGenericRenderer(component: comp, context: context, onAction: handleAction))
        case .lessonBlock:
            AnyView(A2UILessonCardRenderer(component: comp, context: context, onAction: handleAction))
        case .moduleHeader, .chapterNav, .lessonList, .courseOutline:
            AnyView(A2UIModuleListRenderer(component: comp, context: context, onAction: handleAction))
        case .courseHeader:
            AnyView(A2UICourseCardRenderer(component: comp, context: context, onAction: handleAction))
        case .completionBadge, .prerequisiteCheck, .learningPath, .skillTree:
            AnyView(A2UICourseGenericRenderer(component: comp, context: context, onAction: handleAction))
            
        default:
             renderRestOfContent(comp)
        }
    }
    
    @ViewBuilder
    private func renderRestOfContent(_ comp: A2UIComponent) -> some View {
        switch comp.type {
        // MARK: - Study Plan
        case .studyPlanOverview:
            AnyView(A2UIStudyPlanOverviewRenderer(component: comp, context: context, onAction: handleAction))
        case .studySession:
            AnyView(A2UIStudySessionRenderer(component: comp, context: context, onAction: handleAction))
        case .studyCalendar:
            AnyView(A2UIStudyCalendarRenderer(component: comp, context: context, onAction: handleAction))
        case .studyMilestone:
            AnyView(A2UIMilestoneTrackerRenderer(component: comp, context: context, onAction: handleAction))
        case .studyStreak:
            AnyView(A2UIStudyStreakRenderer(component: comp, context: context, onAction: handleAction))
        case .focusTimer, .pomodoroTimer:
            AnyView(A2UIFocusModeRenderer(component: comp, context: context, onAction: handleAction))
        case .studyPlanWeekly, .studyPlanDaily:
            AnyView(A2UIStudyPlanWeeklyRenderer(component: comp, context: context, onAction: handleAction))
        case .studyGoal, .studyProgress, .studyReminder, .examCountdown:
            AnyView(A2UIStudyGenericRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Homework
        case .homeworkCard:
            AnyView(A2UIHomeworkCardRenderer(component: comp, context: context, onAction: handleAction))
        case .homeworkList:
            AnyView(A2UIHomeworkListRenderer(component: comp, context: context, onAction: handleAction))
        case .gradeDisplay:
            AnyView(A2UIGradeDisplayRenderer(component: comp, context: context, onAction: handleAction))
        case .rubricView:
            AnyView(A2UIRubricRenderer(component: comp, context: context, onAction: handleAction))
        case .homeworkSubmission:
            AnyView(A2UISubmissionStatusRenderer(component: comp, context: context, onAction: handleAction))
        case .assignmentDetails, .feedbackCard, .homeworkProgress, .homeworkDeadline:
            AnyView(A2UIHomeworkGenericRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Mistake Tracker
        case .mistakeCard:
            AnyView(A2UIMistakeCardRenderer(component: comp, context: context, onAction: handleAction))
        case .mistakePattern:
            AnyView(A2UIMistakePatternRenderer(component: comp, context: context, onAction: handleAction))
        case .mistakeReview, .mistakeQuickFix:
            AnyView(A2UIMistakeQuizRenderer(component: comp, context: context, onAction: handleAction))
        case .mistakeHeatmap, .mistakeTimeline, .mistakeInsight, .weakAreaChart, .improvementGraph:
            AnyView(A2UIMistakeStatsRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Documents
        case .documentViewer, .pdfViewer:
            AnyView(A2UIDocumentViewerRenderer(component: comp, context: context, onAction: handleAction))
        case .flashcard, .flashcardDeck:
            AnyView(A2UIFlashcardRenderer(component: comp, context: context, onAction: handleAction))
        case .noteCard, .noteEditor, .highlightedText, .annotation, .summary, .outline, .keyPoints, .definition, .vocabulary, .citation:
            AnyView(A2UIDocumentGenericRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Navigation
        case .button, .backButton, .nextButton, .skipButton:
            AnyView(A2UIButtonRenderer(component: comp, context: context, onAction: handleAction))
        case .link, .navigationLink, .menuItem:
            AnyView(A2UILinkRenderer(component: comp, context: context, onAction: handleAction))
        case .breadcrumb, .stepIndicator, .pagination:
            AnyView(A2UIBreadcrumbRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Widget
        case .statCard, .metricDisplay:
            AnyView(A2UIStatCardRenderer(component: comp, context: context, onAction: handleAction))
        case .countdown, .timer:
            AnyView(A2UICountdownRenderer(component: comp, context: context, onAction: handleAction))
        case .quote, .weather:
            AnyView(A2UIQuoteRenderer(component: comp, context: context, onAction: handleAction))
        case .topicSelection, .suggestions, .filterChips:
            AnyView(A2UIChipsRenderer(component: comp, context: context, onAction: handleAction))
        case .quickActions, .recentItems, .recommended, .trending, .searchBar, .tagCloud, .calendar:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Gamification
        case .xpBadge:
            AnyView(A2UIXPBadgeRenderer(component: comp, context: context, onAction: handleAction))
        case .levelProgress:
            AnyView(A2UILevelProgressRenderer(component: comp, context: context, onAction: handleAction))
        case .achievementCard:
            AnyView(A2UIAchievementRenderer(component: comp, context: context, onAction: handleAction))
        case .progressBar:
            AnyView(A2UIProgressRenderer(component: comp, context: context, onAction: handleAction))
        case .leaderboardRow:
            AnyView(A2UILeaderboardRowRenderer(component: comp, context: context, onAction: handleAction))
        case .streakDisplay:
            AnyView(A2UIStreakDisplayRenderer(component: comp, context: context, onAction: handleAction))
        case .rewardAnimation:
            AnyView(A2UIRewardAnimationRenderer(component: comp, context: context, onAction: handleAction))
        case .challengeCard, .battleCard, .coinDisplay, .energyBar, .powerUp, .questCard, .dailyChallenge:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - AI Assistant
        case .chatBubble, .aiExplanation, .aiHint, .aiCorrection, .aiEncouragement, .aiMascot:
            AnyView(A2UIAIMessageRenderer(component: comp, context: context, onAction: handleAction))
        case .typingIndicator, .aiTyping:
            AnyView(A2UITypingIndicatorRenderer(component: comp, context: context, onAction: handleAction))
        case .aiSuggestion:
            AnyView(A2UISuggestionChipsRenderer(component: comp, context: context, onAction: handleAction))
        case .aiThinking, .processingSpinner:
            AnyView(A2UIThinkingRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Social
        case .userCard, .userAvatar:
            AnyView(A2UIUserCardRenderer(component: comp, context: context, onAction: handleAction))
        case .commentCard:
            AnyView(A2UICommentRenderer(component: comp, context: context, onAction: handleAction))
        case .studyGroup, .liveSession:
            AnyView(A2UIStudyGroupCardRenderer(component: comp, context: context, onAction: handleAction))
        case .reactionBar, .shareSheet, .collaboratorList, .notification:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - System
        case .loading, .skeleton, .loadingSkeleton:
            AnyView(A2UILoadingRenderer(component: comp, context: context, onAction: handleAction))
        case .error:
            AnyView(A2UIErrorRenderer(component: comp, context: context, onAction: handleAction))
        case .empty:
            AnyView(A2UIEmptyRenderer(component: comp, context: context, onAction: handleAction))
        case .warning, .info, .success, .placeholder, .offline, .maintenance, .upgrade, .premium, .unknown:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Remaining Media / Input
        case .animation, .lottie, .gif, .mindMap, .timeline, .ar3DModel:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))
        case .sketchPad, .handwriting, .screenCapture, .fileUpload, .audioRecorder:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))
        case .slider, .toggle, .checkbox, .radioGroup, .dropdown, .datePicker, .timePicker, .colorPicker, .ratingStars, .stepper:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))
        case .quizFillBlank, .quizMatching, .quizOrdering, .quizShortAnswer, .quizEssay, .quizCodeExercise, .quizDragDrop, .quizHotspot, .quizDrawing, .quizVoiceResponse, .quizMathInput:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))

        // MARK: - Layout (remaining)
        case .container, .zStack, .scrollView, .lazyVStack, .carousel, .tabs, .accordion, .collapsible, .modal, .sheet, .popover, .tooltip, .divider, .spacer, .section, .group:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))
        
        default:
            AnyView(A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction))
        }
    }

    // MARK: - Helper Methods

    // MARK: - Condition Evaluation

    private func shouldRender(_ component: A2UIComponent) -> Bool {
        guard let conditions = component.conditions else { return true }

        // 1. Platform version gate
        if let minVersion = conditions.minPlatformVersion {
            let current = ProcessInfo.processInfo.operatingSystemVersion
            let currentStr = "\(current.majorVersion).\(current.minorVersion)"
            if currentStr.compare(minVersion, options: .numeric) == .orderedAscending {
                return false
            }
        }

        // 2. Required device capabilities
        if let caps = conditions.requiredCapabilities, !caps.isEmpty {
            let deviceCaps = Self.currentDeviceCapabilities
            for cap in caps {
                if !deviceCaps.contains(cap) { return false }
            }
        }

        // 3. User tier gate (show only if user's tier is in the allowed list)
        if let tiers = conditions.userTier, !tiers.isEmpty {
            let userTier = Self.currentUserTier
            if !tiers.contains(userTier) { return false }
        }

        // 4. Simple boolean expression for hideIf
        if let hideExpr = conditions.hideIf {
            if Self.evaluateBoolExpression(hideExpr) { return false }
        }

        // 5. Simple boolean expression for showIf
        if let showExpr = conditions.showIf {
            if !Self.evaluateBoolExpression(showExpr) { return false }
        }

        return true
    }

    // MARK: - Condition Helpers

    /// Device capabilities detected at launch
    private static let currentDeviceCapabilities: Set<String> = {
        var caps: Set<String> = ["touch", "display"]
        #if targetEnvironment(simulator)
        caps.insert("simulator")
        #endif
        #if os(iOS)
        caps.insert("ios")
        if UIDevice.current.userInterfaceIdiom == .pad {
            caps.insert("ipad")
        } else {
            caps.insert("iphone")
        }
        #endif
        #if canImport(ARKit)
        caps.insert("arkit")
        #endif
        return caps
    }()

    /// Current user tier from MonetizationService
    @MainActor
    private static var currentUserTier: String {
        MonetizationService.shared.currentTier.rawValue.lowercased()
    }

    /// Evaluate simple boolean string expressions
    /// Supports: "true", "false", "!value", "value"
    private static func evaluateBoolExpression(_ expr: String) -> Bool {
        let trimmed = expr.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed == "true" || trimmed == "1" || trimmed == "yes" { return true }
        if trimmed == "false" || trimmed == "0" || trimmed == "no" || trimmed.isEmpty { return false }
        // Negation
        if trimmed.hasPrefix("!") {
            return !evaluateBoolExpression(String(trimmed.dropFirst()))
        }
        // Unknown expressions default to false (do not hide/show by default)
        return false
    }

    private func handleAction(_ action: A2UIAction) {
        onAction?(action, component)
    }
}

// MARK: - Preview

#if DEBUG
struct A2UIRenderer_Previews: PreviewProvider {
    static var previews: some View {
        let props: A2UIProps = {
            var p = A2UIProps()
            p.text = "Hello A2UI!"
            return p
        }()

        return A2UIRenderer(
            component: A2UIComponent(
                type: .text,
                props: props
            )
        )
        .padding()
        .previewDisplayName("Text Component")
    }
}
#endif