import SwiftUI

/// Renders AI-generated lesson text as proper Markdown: bold/italic runs,
/// headings, lists, and inline links via SwiftUI's native `AttributedString`.
///
/// Fenced blocks are split out and routed to dedicated renderers:
/// - ```` ```mermaid ```` → `PremiumMermaidWebView`
/// - ```` ```<language> ```` → `CodeBlockView` (with light syntax coloring)
///
/// Lives in the classroom layer because it consumes `ClassroomTokens`
/// typography. Pure SwiftUI — no external markdown library required.
struct LessonMarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(Self.segments(from: markdown).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let body):
                    InlineMarkdownView(source: body)
                case .code(let language, let code):
                    CodeBlockView(code: code, language: language)
                case .mermaid(let diagram):
                    MermaidDiagramCard(diagram: diagram)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Segmentation

    enum Segment: Equatable {
        case text(String)              // markdown text (may contain headings, lists, bold, etc.)
        case code(String?, String)     // (language, code)
        case mermaid(String)
    }

    /// Walk the source markdown once and split it into text/code/mermaid
    /// segments. A naive but predictable parser — handles the fence shapes the
    /// backend actually emits (``` followed by an optional language tag, then
    /// content, then ``` on its own line).
    static func segments(from source: String) -> [Segment] {
        var out: [Segment] = []
        var textBuffer: [Substring] = []

        func flushText() {
            let joined = textBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { out.append(.text(joined)) }
            textBuffer.removeAll(keepingCapacity: true)
        }

        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [Substring] = []
                i += 1
                while i < lines.count {
                    let inner = lines[i].trimmingCharacters(in: .whitespaces)
                    if inner == "```" { break }
                    body.append(lines[i])
                    i += 1
                }
                flushText()
                let code = body.joined(separator: "\n")
                if lang.lowercased() == "mermaid" {
                    out.append(.mermaid(code))
                } else {
                    out.append(.code(lang.isEmpty ? nil : lang, code))
                }
            } else {
                textBuffer.append(line)
            }
            i += 1
        }
        flushText()
        return out
    }
}

// MARK: - Inline markdown text (headings, lists, bold, links)

private struct InlineMarkdownView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let text):
                    Text(attributed(text))
                        .font(font(forHeading: level))
                        .foregroundStyle(ClassroomTokens.textPrimary)
                        .padding(.top, level == 1 ? 8 : 4)
                case .listItem(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle()
                            .fill(ClassroomTokens.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(attributed(text))
                            .font(ClassroomTokens.bodyLesson)
                            .foregroundStyle(ClassroomTokens.textSecondary)
                            .lineSpacing(ClassroomTokens.bodyLineSpacing)
                    }
                case .paragraph(let text):
                    Text(attributed(text))
                        .font(ClassroomTokens.bodyLesson)
                        .foregroundStyle(ClassroomTokens.textSecondary)
                        .lineSpacing(ClassroomTokens.bodyLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: helpers

    private enum InlineBlock {
        case heading(Int, String)
        case listItem(String)
        case paragraph(String)
    }

    /// Parse the body into headings / list-items / paragraphs. Inline
    /// formatting (bold, italic, links) is handled later by AttributedString.
    private func blocks() -> [InlineBlock] {
        var out: [InlineBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            let text = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { out.append(.paragraph(text)) }
            paragraph.removeAll(keepingCapacity: true)
        }

        for raw in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                continue
            }
            if line.hasPrefix("###### ") { flushParagraph(); out.append(.heading(6, String(line.dropFirst(7)))); continue }
            if line.hasPrefix("##### ")  { flushParagraph(); out.append(.heading(5, String(line.dropFirst(6)))); continue }
            if line.hasPrefix("#### ")   { flushParagraph(); out.append(.heading(4, String(line.dropFirst(5)))); continue }
            if line.hasPrefix("### ")    { flushParagraph(); out.append(.heading(3, String(line.dropFirst(4)))); continue }
            if line.hasPrefix("## ")     { flushParagraph(); out.append(.heading(2, String(line.dropFirst(3)))); continue }
            if line.hasPrefix("# ")      { flushParagraph(); out.append(.heading(1, String(line.dropFirst(2)))); continue }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                out.append(.listItem(String(line.dropFirst(2))))
                continue
            }
            if let dot = line.firstIndex(of: "."),
               line.distance(from: line.startIndex, to: dot) <= 2,
               Int(line[line.startIndex..<dot]) != nil {
                flushParagraph()
                let after = line.index(after: dot)
                out.append(.listItem(String(line[after...]).trimmingCharacters(in: .whitespaces)))
                continue
            }
            paragraph.append(line)
        }
        flushParagraph()
        return out
    }

    private func font(forHeading level: Int) -> Font {
        switch level {
        case 1: return ClassroomTokens.titleSection
        case 2: return ClassroomTokens.titleSub
        default: return ClassroomTokens.titleMinor
        }
    }

    /// Convert a single line of inline markdown to AttributedString. Falls back
    /// to a plain string if the system can't parse it (rare, but possible on
    /// malformed input).
    private func attributed(_ text: String) -> AttributedString {
        if let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(text)
    }
}

// MARK: - Mermaid card wrapper

private struct MermaidDiagramCard: View {
    let diagram: String

    var body: some View {
        VStack(spacing: 6) {
            PremiumMermaidWebView(mermaidCode: diagram)
                .frame(minHeight: 240)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: ClassroomTokens.stripRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ClassroomTokens.stripRadius, style: .continuous)
                        .stroke(ClassroomTokens.glassBorder, lineWidth: 1)
                )
            Text("Diagram")
                .font(ClassroomTokens.captionMeta)
                .foregroundStyle(ClassroomTokens.textTertiary)
        }
        .padding(.vertical, 4)
    }
}
