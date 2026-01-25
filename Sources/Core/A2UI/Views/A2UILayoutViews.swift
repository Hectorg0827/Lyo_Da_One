//
//  A2UILayoutViews.swift
//  Lyo
//
//  Layout and Container renderer views for A2UI
//

import SwiftUI

// MARK: - Layout Views

struct A2UIContainerView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: spacing) {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
        .padding(padding)
        .background(backgroundColor)
        .cornerRadius(props.borderRadius ?? 0)
    }
    
    private var horizontalAlignment: HorizontalAlignment {
        props.alignment?.horizontalAlignment ?? .center
    }
    
    private var spacing: CGFloat {
        props.spacing ?? 8
    }
    
    private var padding: EdgeInsets {
        if let p = props.padding {
            return EdgeInsets(top: p.top, leading: p.leading, bottom: p.bottom, trailing: p.trailing)
        }
        return EdgeInsets()
    }
    
    private var backgroundColor: Color {
        if let hex = props.backgroundColor {
            return Color(hex: hex)
        }
        return .clear
    }
}

struct A2UIVStackView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: spacing) {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
    }
    
    private var horizontalAlignment: HorizontalAlignment {
        props.alignment?.horizontalAlignment ?? .center
    }
    
    private var spacing: CGFloat {
        props.spacing ?? 8
    }
}

struct A2UIHStackView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        HStack(alignment: verticalAlignment, spacing: spacing) {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
    }
    
    private var verticalAlignment: VerticalAlignment {
        props.alignment?.verticalAlignment ?? .center
    }
    
    private var spacing: CGFloat {
        props.spacing ?? 8
    }
}

struct A2UIZStackView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        ZStack(alignment: alignment) {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
    }
    
    private var alignment: Alignment {
        props.alignment?.swiftUIAlignment ?? .center
    }
}

struct A2UIScrollViewWrapper: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        ScrollView(axis, showsIndicators: showsIndicators) {
            if props.axis == "horizontal" {
                HStack(spacing: props.spacing ?? 8) {
                    ForEach(children, id: \.id) { child in
                        A2UIRenderer(component: child, onAction: onAction)
                    }
                }
            } else {
                VStack(spacing: props.spacing ?? 8) {
                    ForEach(children, id: \.id) { child in
                        A2UIRenderer(component: child, onAction: onAction)
                    }
                }
            }
        }
    }
    
    private var axis: Axis.Set {
        props.axis == "horizontal" ? .horizontal : .vertical
    }

    private var showsIndicators: Bool {
        props.isHidden == true ? false : true
    }
}

struct A2UIGridView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: props.spacing ?? 8) {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
    }
    
    private var columns: [GridItem] {
        let columnCount = props.columns ?? 2
        return Array(repeating: GridItem(.flexible(), spacing: props.spacing ?? 8), count: columnCount)
    }
}

struct A2UIListView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        List {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
                    .listRowSeparator(props.isHidden == true ? .hidden : .visible)
            }
        }
        .listStyle(.plain)
    }
}

struct A2UICardView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
        .padding(props.padding.map { EdgeInsets(top: $0.top, leading: $0.leading, bottom: $0.bottom, trailing: $0.trailing) } ?? EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .background(backgroundColor)
        .cornerRadius(props.borderRadius ?? 16)
        .shadow(color: shadowColor.opacity(0.1), radius: props.shadowRadius ?? 8, y: 4)
    }
    
    private var backgroundColor: Color {
        if let hex = props.backgroundColor {
            return Color(hex: hex)
        }
        return Color(.systemBackground)
    }

    private var shadowColor: Color {
        if let hex = props.shadowColor {
            return Color(hex: hex)
        }
        return .black
    }
}

struct A2UISectionView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = props.title {
                Text(title)
                    .font(.headline)
            }
            
            if let subtitle = props.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
        .padding(.vertical, 8)
    }
}

struct A2UIDividerView: View {
    let props: A2UIProps
    
    var body: some View {
        Divider()
            .background(dividerColor)
            .padding(.vertical, props.spacing ?? 8)
    }
    
    private var dividerColor: Color {
        if let hex = props.borderColor {
            return Color(hex: hex)
        }
        return Color(.separator)
    }
}

struct A2UISpacerView: View {
    let props: A2UIProps
    
    var body: some View {
        if let height = dimensionValue(props.height) {
            Spacer()
                .frame(height: height)
        } else if let width = dimensionValue(props.width) {
            Spacer()
                .frame(width: width)
        } else {
            Spacer()
        }
    }
}

struct A2UIExpandableView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    if let icon = props.sfSymbol ?? props.icon {
                        Image(systemName: icon)
                            .foregroundColor(.blue)
                    }
                    
                    Text(props.title ?? "Section")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(children, id: \.id) { child in
                        A2UIRenderer(component: child, onAction: onAction)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            isExpanded = props.isSelected ?? false
        }
    }
}

struct A2UIAccordionView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    @State private var expandedIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                let isExpanded = expandedIndex == index
                
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.spring()) {
                            expandedIndex = isExpanded ? nil : index
                        }
                    } label: {
                        HStack {
                            Text(child.props.title ?? "Item \(index + 1)")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: isExpanded ? "minus" : "plus")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                    }
                    .buttonStyle(.plain)
                    
                    if isExpanded {
                        A2UIRenderer(component: child, onAction: onAction)
                            .padding()
                    }
                }
            }
        }
        .cornerRadius(12)
        .clipped()
    }
}

struct A2UITabsView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                        Button {
                            withAnimation {
                                selectedTab = index
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(child.props.title ?? "Tab \(index + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(selectedTab == index ? .blue : .secondary)
                                
                                Rectangle()
                                    .fill(selectedTab == index ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Color(.systemGray6))
            
            // Content
            if children.indices.contains(selectedTab) {
                A2UIRenderer(component: children[selectedTab], onAction: onAction)
                    .padding()
            }
        }
    }
}

struct A2UICarouselView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $currentIndex) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    A2UIRenderer(component: child, onAction: onAction)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: dimensionValue(props.height) ?? 200)
            
            // Page indicators
            if props.isHidden != true {
                HStack(spacing: 8) {
                    ForEach(0..<children.count, id: \.self) { index in
                        Circle()
                            .fill(currentIndex == index ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}

struct A2UILayoutGenericView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
        .padding()
    }
}

private func dimensionValue(_ dimension: A2UIDimension?) -> CGFloat? {
    guard let dimension = dimension else { return nil }
    switch dimension.unit {
    case .points:
        return CGFloat(dimension.value)
    case .percent, .fill, .auto:
        return nil
    }
}

private extension A2UIAlignment {
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }

    var verticalAlignment: VerticalAlignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        default: return .center
        }
    }

    var swiftUIAlignment: Alignment {
        switch self {
        case .topLeading: return .topLeading
        case .top: return .top
        case .topTrailing: return .topTrailing
        case .leading: return .leading
        case .trailing: return .trailing
        case .bottomLeading: return .bottomLeading
        case .bottom: return .bottom
        case .bottomTrailing: return .bottomTrailing
        case .center: return .center
        }
    }
}
