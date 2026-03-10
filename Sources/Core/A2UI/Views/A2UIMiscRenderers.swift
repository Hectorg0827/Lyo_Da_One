//
//  A2UIMiscRenderers.swift
//  Lyo
//
//  Routing renderers for Document, Course, Navigation, Widget,
//  Gamification, AI Assistant, Social, and System A2UI element types.
//  Bridges A2UIComponent → A2UIMiscViews (previously orphaned views).
//

import SwiftUI

// MARK: - Document Renderers

struct A2UIDocumentViewerRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIDocumentViewerView(props: component.props, onAction: onAction)
    }
}

struct A2UIFlashcardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIFlashcardView(props: component.props, onAction: onAction)
    }
}

struct A2UIDocumentGenericRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIDocumentGenericView(props: component.props)
    }
}

// MARK: - Course Renderers

struct A2UICourseCardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UICourseCardView(props: component.props, onAction: onAction)
    }
}

struct A2UILessonCardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UILessonCardView(props: component.props, onAction: onAction)
    }
}

struct A2UICourseProgressRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UICourseProgressView(props: component.props, onAction: onAction)
    }
}

struct A2UIModuleListRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIModuleListView(
            props: component.props,
            children: component.children ?? [],
            onAction: { action, _ in onAction?(action) }
        )
    }
}

struct A2UICourseGenericRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UICourseGenericView(props: component.props)
    }
}

// MARK: - Navigation Renderers

struct A2UIButtonRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIButtonView(props: component.props, onAction: onAction)
    }
}

struct A2UILinkRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UILinkView(props: component.props, onAction: onAction)
    }
}

struct A2UIBreadcrumbRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIBreadcrumbView(props: component.props, onAction: onAction)
    }
}

// MARK: - Widget Renderers

struct A2UIStatCardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIStatCardView(props: component.props, onAction: onAction)
    }
}

struct A2UICountdownRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UICountdownView(props: component.props, onAction: onAction)
    }
}

struct A2UIQuoteRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIQuoteView(props: component.props, onAction: onAction)
    }
}

// MARK: - Gamification Renderers

struct A2UILeaderboardRowRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UILeaderboardRowView(props: component.props, onAction: onAction)
    }
}

struct A2UIStreakDisplayRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIStreakDisplayView(props: component.props, onAction: onAction)
    }
}

struct A2UIRewardAnimationRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIRewardAnimationView(props: component.props, onAction: onAction)
    }
}

// MARK: - AI Assistant Renderers

struct A2UIAIMessageRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIAIMessageView(props: component.props, onAction: onAction)
    }
}

struct A2UITypingIndicatorRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UITypingIndicatorView(props: component.props)
    }
}

struct A2UISuggestionChipsRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UISuggestionChipsView(props: component.props, onAction: onAction)
    }
}

struct A2UIThinkingRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIThinkingView(props: component.props)
    }
}

// MARK: - Social Renderers

struct A2UIUserCardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIUserCardView(props: component.props, onAction: onAction)
    }
}

struct A2UICommentRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UICommentView(props: component.props, onAction: onAction)
    }
}

struct A2UIStudyGroupCardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UIStudyGroupCardView(props: component.props, onAction: onAction)
    }
}

// MARK: - Chips Renderer (Topic Selection, Suggestions, Filter Chips)

struct A2UIChipsRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        A2UISuggestionChipsView(props: component.props, onAction: onAction)
    }
}
