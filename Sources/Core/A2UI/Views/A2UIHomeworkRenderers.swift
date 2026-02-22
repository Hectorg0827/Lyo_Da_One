//
//  A2UIHomeworkRenderers.swift
//  Lyo
//
//  Routing renderers for Homework A2UI element types.
//  Bridges A2UIComponent → A2UIHomeworkViews.
//

import SwiftUI

// MARK: - Homework Card Renderer

struct A2UIHomeworkCardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIHomeworkCardView(
            props: component.props,
            onAction: { action, _ in onAction?(action) }
        )
    }
}

// MARK: - Homework List Renderer

struct A2UIHomeworkListRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIHomeworkListView(
            props: component.props,
            children: component.children ?? [],
            onAction: { action, _ in onAction?(action) }
        )
    }
}

// MARK: - Grade Display Renderer

struct A2UIGradeDisplayRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIGradeDisplayView(
            props: component.props,
            onAction: { action, _ in onAction?(action) }
        )
    }
}

// MARK: - Rubric Renderer

struct A2UIRubricRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIRubricView(
            props: component.props,
            onAction: { action, _ in onAction?(action) }
        )
    }
}

// MARK: - Submission Status Renderer

struct A2UISubmissionStatusRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UISubmissionStatusView(
            props: component.props,
            onAction: { action, _ in onAction?(action) }
        )
    }
}

// MARK: - Homework Generic Renderer (fallback for unmatched homework types)

struct A2UIHomeworkGenericRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIHomeworkGenericView(props: component.props)
    }
}
