//
//  A2UIRendererViews.swift
//  Lyo
//
//  Basic renderer views for A2UI components
//  These render the core display elements
//

import SwiftUI

// MARK: - Text Renderers

/// Renders text, heading, paragraph, label, caption
struct A2UITextRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        Text(component.props.text ?? component.props.title ?? "")
            .font(fontForComponent())
            .foregroundColor(colorForComponent())
            .multilineTextAlignment(textAlignmentForComponent())
            .padding(paddingForComponent())
    }

    private func fontForComponent() -> Font {
        let size = component.props.fontSize ?? defaultFontSize()
        let weight = fontWeightForComponent()

        switch component.type {
        case .heading:
            return .system(size: size, weight: weight, design: .default)
        case .caption, .label:
            return .caption
        default:
            return .system(size: size, weight: weight)
        }
    }

    private func defaultFontSize() -> CGFloat {
        switch component.type {
        case .heading: return 28
        case .paragraph: return 16
        case .label: return 14
        case .caption: return 12
        default: return 16
        }
    }

    private func fontWeightForComponent() -> Font.Weight {
        switch component.props.fontWeight {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        default:
            return component.type == .heading ? .bold : .regular
        }
    }

    private func colorForComponent() -> Color {
        if let hex = component.props.foregroundColor {
            return Color(hex: hex)
        }
        return .primary
    }

    private func textAlignmentForComponent() -> TextAlignment {
        switch component.props.textAlignment {
        case "center": return .center
        case "trailing", "right": return .trailing
        default: return .leading
        }
    }

    private func paddingForComponent() -> EdgeInsets {
        guard let p = component.props.padding else { return EdgeInsets() }
        return EdgeInsets(
            top: p.top,
            leading: p.leading,
            bottom: p.bottom,
            trailing: p.trailing
        )
    }
}

// MARK: - Markdown Renderer

struct A2UIMarkdownRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        // For now, render as plain text - can be enhanced with markdown parsing later
        Text(component.props.text ?? component.props.body ?? "")
            .padding()
    }
}

// MARK: - Code Renderer

struct A2UICodeRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        ScrollView(.horizontal) {
            Text(component.props.code ?? component.props.text ?? "")
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}

// MARK: - Latex Renderer

struct A2UILatexRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        // For now, render as formatted text - can be enhanced with LaTeX rendering later
        Text(component.props.text ?? component.props.body ?? "")
            .font(.system(.body, design: .monospaced))
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

// MARK: - Image Renderer

struct A2UIImageRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        Group {
            if let imageUrl = component.props.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                        .frame(width: 100, height: 100)
                }
            } else if let assetName = component.props.imageAsset {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .font(.system(size: 40))
            }
        }
        .frame(maxWidth: dimensionToCGFloat(component.props.maxWidth),
               maxHeight: dimensionToCGFloat(component.props.maxHeight))
        .cornerRadius(component.props.borderRadius ?? 0)
    }

    private func dimensionToCGFloat(_ dimension: A2UIDimension?) -> CGFloat? {
        guard let dimension else { return nil }
        switch dimension.unit {
        case .points:
            return CGFloat(dimension.value)
        case .percent, .fill, .auto:
            return nil
        }
    }
}

// MARK: - Media Renderers (Stubs)

struct A2UIVideoRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack {
            Image(systemName: "play.rectangle")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            Text("Video Player")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 200, height: 120)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct A2UIAudioRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        HStack {
            Image(systemName: "play.circle")
                .font(.title2)
                .foregroundColor(.blue)
            Text("Audio Player")
                .font(.subheadline)
            Spacer()
            Text("0:00")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct A2UIDiagramRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundColor(.green)
            Text("Diagram/Chart")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 150, height: 100)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Input Renderers (Stubs)

struct A2UITextInputRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    @State private var text = ""

    var body: some View {
        TextField(component.props.placeholder ?? "Enter text...", text: $text)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
    }
}

struct A2UIVoiceInputRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        Button {
            // Handle voice input
        } label: {
            HStack {
                Image(systemName: "mic")
                Text("Voice Input")
            }
        }
        .buttonStyle(.bordered)
    }
}

struct A2UICameraRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        Button {
            // Handle camera capture
        } label: {
            HStack {
                Image(systemName: "camera")
                Text("Take Photo")
            }
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - System Renderers

struct A2UILoadingRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            if let text = component.props.text {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct A2UIErrorRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.red)
            Text(component.props.text ?? "An error occurred")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

struct A2UIEmptyRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(component.props.text ?? "No content available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct A2UIFallbackRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Unsupported: \(component.type.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
            if let text = component.props.text {
                Text(text)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}