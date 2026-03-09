//
//  LyoPrimitiveRenderer.swift
//  Lyo
//
//  v2 Renderer: dispatches LyoUIComponent trees to primitive-specific SwiftUI views.
//  Each A2UIPrimitive case has a dedicated renderer that handles all its variants internally.
//

import SwiftUI

// MARK: - Main Primitive Renderer

/// Entry point for rendering a v2 `LyoUIComponent` tree.
/// Mirrors `A2UIRenderer` but uses the 22-primitive type system.
struct LyoPrimitiveRenderer: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    var body: some View {
        renderPrimitive(component)
    }

    // MARK: - Dispatch

    @ViewBuilder
    private func renderPrimitive(_ comp: LyoUIComponent) -> some View {
        switch comp.type {
        // ── Content ──
        case .text:
            LyoTextPrimitiveView(component: comp, context: context)
        case .media:
            LyoMediaPrimitiveView(component: comp, context: context)
        case .divider:
            LyoDividerPrimitiveView(component: comp, context: context)

        // ── Input ──
        case .input:
            LyoInputPrimitiveView(component: comp, context: context, onAction: onAction)
        case .button:
            LyoButtonPrimitiveView(component: comp, context: context, onAction: onAction)

        // ── Layout ──
        case .container:
            LyoContainerPrimitiveView(component: comp, context: context, onAction: onAction)
        case .card:
            LyoCardPrimitiveView(component: comp, context: context, onAction: onAction)
        case .list:
            LyoListPrimitiveView(component: comp, context: context, onAction: onAction)
        case .nav:
            LyoNavPrimitiveView(component: comp, context: context, onAction: onAction)

        // ── Learning ──
        case .quiz:
            LyoQuizPrimitiveView(component: comp, context: context, onAction: onAction)
        case .quizResult:
            LyoQuizResultPrimitiveView(component: comp, context: context)
        case .course:
            LyoCoursePrimitiveView(component: comp, context: context, onAction: onAction)
        case .flashcard:
            LyoFlashcardPrimitiveView(component: comp, context: context, onAction: onAction)
        case .plan:
            LyoPlanPrimitiveView(component: comp, context: context, onAction: onAction)
        case .tracker:
            LyoTrackerPrimitiveView(component: comp, context: context)
        case .assignment:
            LyoAssignmentPrimitiveView(component: comp, context: context, onAction: onAction)
        case .document:
            LyoDocumentPrimitiveView(component: comp, context: context)

        // ── Engagement ──
        case .progress:
            LyoProgressPrimitiveView(component: comp, context: context)
        case .aiBubble:
            LyoAIBubblePrimitiveView(component: comp, context: context)
        case .social:
            LyoSocialPrimitiveView(component: comp, context: context, onAction: onAction)

        // ── System ──
        case .alert:
            LyoAlertPrimitiveView(component: comp, context: context, onAction: onAction)
        case .skeleton:
            LyoSkeletonPrimitiveView(component: comp, context: context)
        }
    }
}

// MARK: - Child Renderer Helper

/// Convenience to render child components recursively
struct LyoChildrenRenderer: View {
    let children: [LyoUIComponent]?
    let context: A2UIRenderContext
    var axis: Axis = .vertical
    var spacing: CGFloat = 8
    var onAction: ((LyoCommand) -> Void)?

    var body: some View {
        if let children = children, !children.isEmpty {
            switch axis {
            case .vertical:
                VStack(alignment: .leading, spacing: spacing) {
                    ForEach(children, id: \.id) { child in
                        LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                    }
                }
            case .horizontal:
                HStack(spacing: spacing) {
                    ForEach(children, id: \.id) { child in
                        LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                    }
                }
            }
        }
    }
}
