//
//  A2UIStudyPlanRenderers.swift
//  Lyo
//
//  Routing renderers for Study Plan A2UI element types.
//  Bridges A2UIComponent → A2UIStudyPlanViews (orphaned views).
//  Note: studyPlanOverview and studySession already have renderers
//  in A2UIRendererViews.swift — these cover the remaining types.
//

import SwiftUI

// MARK: - Study Calendar Renderer

struct A2UIStudyCalendarRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIStudyCalendarView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Milestone Tracker Renderer

struct A2UIMilestoneTrackerRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIMilestoneTrackerView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Study Streak Renderer

struct A2UIStudyStreakRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIStudyStreakView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Focus Mode Renderer

struct A2UIFocusModeRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIFocusModeView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Study Plan Overview (View-based, for weekly/daily variants)

struct A2UIStudyPlanWeeklyRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIStudyPlanOverviewView(
            props: component.props,
            onAction: onAction
        )
    }
}

// MARK: - Study Generic Renderer (fallback)

struct A2UIStudyGenericRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIStudyGenericView(props: component.props)
    }
}
