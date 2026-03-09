//
//  LyoContentPrimitives.swift
//  Lyo
//
//  v2 renderers for content primitives: text, media, divider
//

import SwiftUI

// MARK: - Text Primitive

/// Renders all text variants: heading, paragraph, caption, code, markdown, label, latex
struct LyoTextPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "paragraph" }

    var body: some View {
        Group {
            switch variant {
            case "heading":
                headingView
            case "caption":
                captionView
            case "code":
                codeView
            case "markdown":
                markdownView
            case "label":
                labelView
            case "latex":
                latexView
            default: // "paragraph"
                paragraphView
            }
        }
        .accessibilityLabel(component.meta?.accessibilityLabel ?? displayText)
    }

    private var displayText: String {
        component.content?.text
            ?? component.content?.body
            ?? component.content?.title
            ?? ""
    }

    // MARK: - Variant Views

    private var headingView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(component.content?.title ?? displayText)
                .font(headingFont)
                .fontWeight(.bold)
                .foregroundStyle(foregroundColor)

            if let subtitle = component.content?.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var paragraphView: some View {
        Text(displayText)
            .font(bodyFont)
            .foregroundStyle(foregroundColor)
            .lineSpacing(4)
    }

    private var captionView: some View {
        Text(displayText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var codeView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(displayText)
                .font(.system(.body, design: .monospaced))
                .padding(12)
        }
        .background(Color(.systemGray6))
        .cornerRadius(component.style?.radius ?? 8)
    }

    private var markdownView: some View {
        let content = displayText
        let attributed = (try? AttributedString(markdown: content)) ?? AttributedString(content)
        return Text(attributed)
            .font(bodyFont)
            .foregroundStyle(foregroundColor)
    }

    private var labelView: some View {
        HStack(spacing: 6) {
            if let icon = component.content?.icon {
                Image(systemName: icon)
                    .font(.body)
            }
            Text(component.content?.label ?? displayText)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(foregroundColor)
    }

    private var latexView: some View {
        // Fallback to plain text rendering; LaTeX library handled at integration layer
        Text(displayText)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(6)
    }

    // MARK: - Style Helpers

    private var headingFont: Font {
        if let size = component.style?.fontSize {
            if size >= 28 { return .largeTitle }
            if size >= 22 { return .title2 }
            if size >= 18 { return .title3 }
            return .headline
        }
        return .title
    }

    private var bodyFont: Font {
        if let size = component.style?.fontSize {
            if size >= 20 { return .title3 }
            if size < 14 { return .footnote }
            return .body
        }
        return .body
    }

    private var foregroundColor: Color {
        if let fg = component.style?.foreground {
            return Color(hex: fg)
        }
        return .primary
    }
}

// MARK: - Media Primitive

/// Renders all media variants: image, video, audio, chart, diagram
struct LyoMediaPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "image" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch variant {
            case "video":
                videoPlaceholder
            case "audio":
                audioPlaceholder
            case "chart":
                chartPlaceholder
            case "diagram":
                diagramPlaceholder
            default: // "image"
                imageView
            }

            if let altText = component.content?.altText {
                Text(altText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(component.content?.altText ?? "Media content")
    }

    private var imageView: some View {
        Group {
            if let url = mediaURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        imageFallback
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    @unknown default:
                        imageFallback
                    }
                }
            } else {
                imageFallback
            }
        }
        .cornerRadius(component.style?.radius ?? 12)
    }

    private var imageFallback: some View {
        RoundedRectangle(cornerRadius: component.style?.radius ?? 12)
            .fill(Color(.systemGray5))
            .frame(height: 200)
            .overlay(
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            )
    }

    private var videoPlaceholder: some View {
        RoundedRectangle(cornerRadius: component.style?.radius ?? 12)
            .fill(Color(.systemGray5))
            .frame(height: 220)
            .overlay(
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            )
    }

    private var audioPlaceholder: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(component.content?.title ?? "Audio")
                    .font(.subheadline.weight(.medium))
                Text("Tap to play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "play.fill")
                .foregroundStyle(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var chartPlaceholder: some View {
        RoundedRectangle(cornerRadius: component.style?.radius ?? 12)
            .fill(Color(.systemGray6))
            .frame(height: 200)
            .overlay(
                VStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title)
                    Text(component.content?.title ?? "Chart")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            )
    }

    private var diagramPlaceholder: some View {
        RoundedRectangle(cornerRadius: component.style?.radius ?? 12)
            .fill(Color(.systemGray6))
            .frame(height: 200)
            .overlay(
                VStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.title)
                    Text(component.content?.title ?? "Diagram")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            )
    }

    private var mediaURL: URL? {
        if let urlStr = component.content?.mediaUrl ?? component.content?.imageUrl {
            return URL(string: urlStr)
        }
        return nil
    }
}

// MARK: - Divider Primitive

/// Renders a visual separator
struct LyoDividerPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    var body: some View {
        Divider()
            .padding(.vertical, component.style?.spacing ?? 8)
    }
}
