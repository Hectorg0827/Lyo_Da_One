//
//  A2UIRenderer.swift
//  Lyo
//
//  Main SwiftUI renderer for A2UI components
//  Routes component types to appropriate SwiftUI views
//

import SwiftUI
import Foundation

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
        renderComponent(component)
            .onAppear {
                // Register this UI tree for voice control
                if let onAction = onAction {
                    A2UIVoiceController.shared.registerActiveUI(component: component, onAction: onAction)
                }
            }
    }


    // MARK: - Component Router

    @ViewBuilder
    private func renderComponent(_ comp: A2UIComponent) -> some View {
        // Check conditions first
        if shouldRender(comp) {
            switch comp.type {
            // MARK: - Core Display
            case .text, .heading, .paragraph, .label, .caption:
                A2UITextRenderer(component: comp, context: context, onAction: handleAction)
            case .markdown, .richText:
                A2UIMarkdownRenderer(component: comp, context: context, onAction: handleAction)
            case .code, .codeBlock:
                A2UICodeRenderer(component: comp, context: context, onAction: handleAction)
            case .latex, .equation:
                A2UILatexRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - Media
            case .image, .avatar, .icon:
                A2UIImageRenderer(component: comp, context: context, onAction: handleAction)
            case .video:
                A2UIVideoRenderer(component: comp, context: context, onAction: handleAction)
            case .audio:
                A2UIAudioRenderer(component: comp, context: context, onAction: handleAction)
            case .diagram, .chart, .graph:
                A2UIDiagramRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - Input
            case .textInput, .textArea:
                A2UITextInputRenderer(component: comp, context: context, onAction: handleAction)
            case .voiceInput:
                A2UIVoiceInputRenderer(component: comp, context: context, onAction: handleAction)
            case .cameraCapture, .documentScanner:
                A2UICameraRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - Quiz
            case .quizMcq:
                A2UIQuizMCQRenderer(component: comp, context: context, onAction: handleAction)
            case .quizMultiSelect:
                A2UIQuizMultiSelectRenderer(component: comp, context: context, onAction: handleAction)
            case .quizTrueFalse:
                A2UIQuizTrueFalseRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - Study Plan
            case .studyPlanOverview:
                A2UIStudyPlanOverviewRenderer(component: comp, context: context, onAction: handleAction)
            case .studySession:
                A2UIStudySessionRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - Layout
            case .stack:
                A2UIStackRenderer(component: comp, context: context, onAction: handleAction)
            case .grid:
                A2UIGridRenderer(component: comp, context: context, onAction: handleAction)
            case .card:
                A2UICardRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - Gamification
            case .xpBadge:
                A2UIXPBadgeRenderer(component: comp, context: context, onAction: handleAction)
            case .levelProgress:
                A2UILevelProgressRenderer(component: comp, context: context, onAction: handleAction)
            case .achievementCard:
                A2UIAchievementRenderer(component: comp, context: context, onAction: handleAction)
            case .progressBar:
                A2UIProgressRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - System
            case .loading, .skeleton, .loadingSkeleton:
                A2UILoadingRenderer(component: comp, context: context, onAction: handleAction)
            case .error:
                A2UIErrorRenderer(component: comp, context: context, onAction: handleAction)
            case .empty:
                A2UIEmptyRenderer(component: comp, context: context, onAction: handleAction)

            // MARK: - Fallback
            default:
                A2UIFallbackRenderer(component: comp, context: context, onAction: handleAction)
            }
        }
    }

    // MARK: - Helper Methods

    private func shouldRender(_ component: A2UIComponent) -> Bool {
        // TODO: Implement condition evaluation
        return true
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