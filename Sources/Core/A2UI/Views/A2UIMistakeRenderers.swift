//
//  A2UIMistakeRenderers.swift
//  Lyo
//
//  Routing renderers for Mistake Tracker A2UI element types.
//  Bridges A2UIComponent → A2UIMistakeViews.
//

import SwiftUI

// MARK: - Mistake Card Renderer

struct A2UIMistakeCardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIMistakeCardView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Mistake Pattern Renderer

struct A2UIMistakePatternRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIMistakePatternView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Mistake Stats Renderer

struct A2UIMistakeStatsRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIMistakeStatsView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Mistake Quiz Renderer

struct A2UIMistakeQuizRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIMistakeQuizView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Mistake Generic Renderer (fallback)

struct A2UIMistakeGenericRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIMistakeGenericView(props: component.props)
    }
}
