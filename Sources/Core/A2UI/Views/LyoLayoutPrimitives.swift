//
//  LyoLayoutPrimitives.swift
//  Lyo
//
//  v2 renderers for layout primitives: container, card, list, nav
//

import SwiftUI

// MARK: - Container Primitive

/// Renders layout containers: vstack, hstack, zstack, scroll, grid, tabs, accordion
struct LyoContainerPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "vstack" }
    private var spacing: CGFloat { component.style?.spacing ?? 8 }

    var body: some View {
        Group {
            switch variant {
            case "hstack":
                HStack(alignment: .center, spacing: spacing) {
                    childViews
                }

            case "zstack":
                ZStack {
                    childViews
                }

            case "scroll":
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: spacing) {
                        childViews
                    }
                }

            case "grid":
                let cols = component.style?.columns ?? 2
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols),
                    spacing: spacing
                ) {
                    childViews
                }

            case "tabs":
                tabsView

            default: // "vstack"
                VStack(alignment: .leading, spacing: spacing) {
                    childViews
                }
            }
        }
        .applyLyoPadding(component.style)
        .applyLyoBackground(component.style)
    }

    @ViewBuilder
    private var childViews: some View {
        if let children = component.children {
            ForEach(children, id: \.id) { child in
                LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
            }
        }
    }

    @ViewBuilder
    private var tabsView: some View {
        // Simple tab view from children; each child is a tab
        if let children = component.children, !children.isEmpty {
            TabView {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                        .tabItem {
                            Text(child.content?.title ?? child.content?.label ?? "Tab")
                        }
                }
            }
        }
    }
}

// MARK: - Card Primitive

/// Renders card variants: default, elevated, outlined, interactive, hero
struct LyoCardPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "default" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            if let title = component.content?.title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(variant == "hero" ? .title : .headline)
                        .fontWeight(.bold)

                    if let subtitle = component.content?.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Children
            if let children = component.children {
                ForEach(children, id: \.id) { child in
                    LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                }
            }

            // Body text
            if let body = component.content?.body {
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(component.style?.padding?.edgeInsets ?? EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .background(cardBackground)
        .cornerRadius(component.style?.radius ?? 16)
        .overlay(cardBorder)
        .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: 2)
    }

    private var cardBackground: some View {
        Group {
            if let bg = component.style?.background {
                Color(hex: bg)
            } else {
                Color(.systemBackground)
            }
        }
    }

    private var cardBorder: some View {
        Group {
            if variant == "outlined" {
                RoundedRectangle(cornerRadius: component.style?.radius ?? 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            } else {
                EmptyView()
            }
        }
    }

    private var cardShadowColor: Color {
        variant == "elevated" ? Color.black.opacity(0.12) : Color.clear
    }

    private var cardShadowRadius: CGFloat {
        variant == "elevated" ? 8 : 0
    }
}

// MARK: - List Primitive

/// Renders list variants: plain, numbered, bullet, checklist
struct LyoListPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "plain" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = component.content?.title {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 8)
            }

            if let children = component.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    HStack(alignment: .top, spacing: 8) {
                        // Prefix
                        listPrefix(index: index)

                        // Content
                        LyoPrimitiveRenderer(component: child, context: context, onAction: onAction)
                    }
                    .padding(.vertical, 4)

                    if index < children.count - 1 {
                        Divider().padding(.leading, 28)
                    }
                }
            }
        }
        .applyLyoPadding(component.style)
    }

    @ViewBuilder
    private func listPrefix(index: Int) -> some View {
        switch variant {
        case "numbered":
            Text("\(index + 1).")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        case "bullet":
            Text("•")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)
        case "checklist":
            Image(systemName: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)
        default:
            EmptyView()
                .frame(width: 0)
        }
    }
}

// MARK: - Nav Primitive

/// Renders navigation variants: breadcrumb, stepper, pagination, tab-bar
struct LyoNavPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "breadcrumb" }

    var body: some View {
        Group {
            switch variant {
            case "stepper":
                stepperView
            case "pagination":
                paginationView
            default: // "breadcrumb"
                breadcrumbView
            }
        }
    }

    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let children = component.children {
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                        Text(child.content?.label ?? child.content?.text ?? "")
                            .font(.caption)
                            .foregroundStyle(index == children.count - 1 ? .primary : .secondary)
                        if index < children.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var stepperView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let children = component.children {
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(index == 0 ? Color.blue : Color(.systemGray4))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(index == 0 ? .white : .secondary)
                                )
                            Text(child.content?.label ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var paginationView: some View {
        HStack(spacing: 16) {
            Button {
                onAction?(LyoCommand(action: "prev", payload: nil))
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(true) // Page management at integration layer

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<(component.children?.count ?? 3), id: \.self) { i in
                    Circle()
                        .fill(i == 0 ? Color.blue : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            Button {
                onAction?(LyoCommand(action: "next", payload: nil))
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Style Modifiers

extension View {
    @ViewBuilder
    func applyLyoPadding(_ style: LyoStyleProps?) -> some View {
        if let padding = style?.padding {
            self.padding(padding.edgeInsets)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyLyoBackground(_ style: LyoStyleProps?) -> some View {
        if let bg = style?.background {
            self.background(Color(hex: bg))
        } else {
            self
        }
    }
}
