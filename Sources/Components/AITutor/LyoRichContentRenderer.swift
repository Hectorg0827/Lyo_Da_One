//
//  LyoRichContentRenderer.swift
//  Lyo
//
//  Premium AI response renderer — LaTeX, code, tables, images, callouts.
//  Uses MathJax-style detection and native SwiftUI + WKWebView for math blocks.
//

import SwiftUI
import WebKit

#if canImport(LaTeXSwiftUI)
import LaTeXSwiftUI
#endif

// MARK: - Block Model

enum RichBlock: Identifiable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case bulletList([String])
    case numberedList([String])
    case codeBlock(language: String, code: String)
    case inlineMath(String)
    case displayMath(String)
    case table(headers: [String], rows: [[String]])
    case imageURL(String, caption: String?)
    case callout(icon: String, title: String?, body: String, color: Color)
    case divider
    case blank

    var id: String {
        switch self {
        case .paragraph(let t): return "p_\(t.prefix(20).hashValue)"
        case .heading(let l, let t): return "h\(l)_\(t.prefix(16).hashValue)"
        case .bulletList(let items): return "ul_\(items.count)_\(items.first?.prefix(10).hashValue ?? 0)"
        case .numberedList(let items): return "ol_\(items.count)_\(items.first?.prefix(10).hashValue ?? 0)"
        case .codeBlock(let lang, let c): return "code_\(lang)_\(c.prefix(20).hashValue)"
        case .inlineMath(let m): return "imath_\(m.prefix(20).hashValue)"
        case .displayMath(let m): return "dmath_\(m.prefix(20).hashValue)"
        case .table(let h, _): return "table_\(h.joined().hashValue)"
        case .imageURL(let u, _): return "img_\(u.hashValue)"
        case .callout(_, let title, let body, _): return "callout_\(title?.hashValue ?? 0)_\(body.prefix(10).hashValue)"
        case .divider: return "divider_\(UUID().uuidString)"
        case .blank: return "blank_\(UUID().uuidString)"
        }
    }
}

// MARK: - Parser

struct RichContentParser {

    static func parse(_ raw: String) -> [RichBlock] {
        var preprocessed = raw
        
        // Fix text dumps: inject newlines before " 1. ", " 2. ", " - ", " • " if missing
        do {
            // Match any non-newline character, followed by space, followed by digit+dot or bullet
            let numRegex = try NSRegularExpression(pattern: "([^\\n])\\s+(\\d+\\.)\\s", options: [])
            preprocessed = numRegex.stringByReplacingMatches(in: preprocessed, options: [], range: NSRange(location: 0, length: preprocessed.utf16.count), withTemplate: "$1\n\n$2 ")
            
            let bulletRegex = try NSRegularExpression(pattern: "([^\\n])\\s+([\\-\\•])\\s", options: [])
            preprocessed = bulletRegex.stringByReplacingMatches(in: preprocessed, options: [], range: NSRange(location: 0, length: preprocessed.utf16.count), withTemplate: "$1\n\n$2 ")
        } catch {}
        
        var blocks: [RichBlock] = []
        let lines = preprocessed.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // --- Display math $$…$$ (multi-line)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("$$") {
                var mathLines: [String] = []
                let starter = line.trimmingCharacters(in: .whitespaces)
                // single-line $$expr$$
                if starter.hasSuffix("$$") && starter.count > 4 {
                    let inner = starter.dropFirst(2).dropLast(2)
                    blocks.append(.displayMath(String(inner)))
                    i += 1; continue
                }
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("$$") {
                    mathLines.append(lines[i])
                    i += 1
                }
                blocks.append(.displayMath(mathLines.joined(separator: "\n")))
                i += 1; continue
            }

            // --- Code block ```lang
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                let lang = line.trimmingCharacters(in: .whitespaces).dropFirst(3).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                i += 1; continue
            }

            // --- Heading
            if line.hasPrefix("#") {
                var level = 0
                var rest = line
                while rest.hasPrefix("#") { level += 1; rest = String(rest.dropFirst()) }
                let text = rest.trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 4), text: text))
                i += 1; continue
            }

            // --- Horizontal divider
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "===" {
                blocks.append(.divider)
                i += 1; continue
            }

            // --- Callout blocks  > [!NOTE] / > [!TIP] / > [!WARNING]
            if trimmed.hasPrefix("> [!") {
                let tag = trimmed.components(separatedBy: "]").first?.dropFirst(4).uppercased() ?? ""
                var bodyLines: [String] = []
                i += 1
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    bodyLines.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                let (icon, color) = calloutMeta(tag)
                blocks.append(.callout(icon: icon, title: tag.capitalized, body: bodyLines.joined(separator: " "), color: color))
                continue
            }

            // --- Image  ![caption](url)
            if trimmed.hasPrefix("![") {
                let captionRange = trimmed.range(of: "![")
                let endCaption = trimmed.range(of: "](")
                let endURL = trimmed.range(of: ")", options: .backwards)
                if let ec = endCaption, let eu = endURL {
                    let caption = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<ec.lowerBound])
                    let url = String(trimmed[ec.upperBound..<eu.lowerBound])
                    let _ = captionRange
                    blocks.append(.imageURL(url, caption: caption.isEmpty ? nil : caption))
                    i += 1; continue
                }
            }

            // --- Table  | col | col |
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                var tableLines: [String] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    guard tl.hasPrefix("|") && tl.hasSuffix("|") else { break }
                    tableLines.append(tl)
                    i += 1
                }
                if tableLines.count >= 2 {
                    let headers = parseTableRow(tableLines[0])
                    let rows = tableLines.dropFirst(2).map { parseTableRow($0) }
                    blocks.append(.table(headers: headers, rows: Array(rows)))
                }
                continue
            }

            // --- Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                var items: [String] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    if tl.hasPrefix("- ") || tl.hasPrefix("* ") || tl.hasPrefix("• ") {
                        items.append(String(tl.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                        i += 1
                    } else { break }
                }
                blocks.append(.bulletList(items))
                continue
            }

            // --- Numbered list  1. ...
            if let firstChar = trimmed.first, firstChar.isNumber, trimmed.contains(". ") {
                var items: [String] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    if let dotRange = tl.range(of: ". "), tl.first?.isNumber == true {
                        items.append(String(tl[dotRange.upperBound...]))
                        i += 1
                    } else { break }
                }
                blocks.append(.numberedList(items))
                continue
            }

            // --- Blank line
            if trimmed.isEmpty {
                if let last = blocks.last, case .blank = last { /* skip double blanks */ } else {
                    blocks.append(.blank)
                }
                i += 1; continue
            }

            // --- Paragraph (may contain inline math $…$)
            if trimmed.contains("$") {
                blocks.append(.paragraph(trimmed))
            } else {
                // Merge consecutive paragraph lines
                var paraLines = [trimmed]
                i += 1
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    if tl.isEmpty || tl.hasPrefix("#") || tl.hasPrefix("-") || tl.hasPrefix("*")
                        || tl.hasPrefix("|") || tl.hasPrefix("```") || tl.hasPrefix("$$") { break }
                    paraLines.append(tl)
                    i += 1
                }
                blocks.append(.paragraph(paraLines.joined(separator: "\n")))
                continue
            }
            i += 1
        }
        return blocks.filter { block in
            if case .blank = block { return false }
            return true
        }
    }

    private static func parseTableRow(_ row: String) -> [String] {
        row.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.allSatisfy({ $0 == "-" || $0 == ":" }) }
    }

    private static func calloutMeta(_ tag: String) -> (String, Color) {
        switch tag {
        case "NOTE":    return ("info.circle.fill", Color.blue)
        case "TIP":     return ("lightbulb.fill", Color.green)
        case "WARNING": return ("exclamationmark.triangle.fill", Color.orange)
        case "CAUTION": return ("flame.fill", Color.red)
        case "IMPORTANT": return ("star.fill", Color.purple)
        default:        return ("quote.bubble.fill", Color.gray)
        }
    }
}

// MARK: - Main Rich Content View

struct LyoRichContentRenderer: View {
    let text: String
    let highlights: [ChatHighlight]
    var onAction: ((TextSelectionAction) -> Void)? = nil

    private var blocks: [RichBlock] { RichContentParser.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks) { block in
                blockView(block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: RichBlock) -> some View {
        switch block {

        case .paragraph(let text):
            InlineMathText(text: text)

        case .heading(let level, let text):
            HeadingView(level: level, text: text)

        case .bulletList(let items):
            BulletListView(items: items)

        case .numberedList(let items):
            NumberedListView(items: items)

        case .codeBlock(let lang, let code):
            RichCodeBlockView(language: lang, code: code)

        case .displayMath(let expr):
            MathDisplayView(expression: expr, isInline: false)

        case .inlineMath(let expr):
            MathDisplayView(expression: expr, isInline: true)

        case .table(let headers, let rows):
            RichTableView(headers: headers, rows: rows)

        case .imageURL(let url, let caption):
            RichImageView(urlString: url, caption: caption)

        case .callout(let icon, let title, let body, let color):
            CalloutView(icon: icon, title: title, bodyText: body, color: color)

        case .divider:
            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 4)

        case .blank:
            Spacer().frame(height: 4)
        }
    }
}

// MARK: - Heading

private struct HeadingView: View {
    let level: Int
    let text: String

    var body: some View {
        Text(text)
            .font(headingFont)
            .foregroundColor(.white)
            .padding(.top, level <= 2 ? 16 : 10)
            .padding(.bottom, 6)
    }

    private var headingFont: Font {
        switch level {
        case 1: return .system(size: 24, weight: .bold, design: .default)
        case 2: return .system(size: 21, weight: .semibold, design: .default)
        case 3: return .system(size: 19, weight: .semibold, design: .default)
        default: return .system(size: 18, weight: .medium, design: .default)
        }
    }
}

// MARK: - Inline Math Text (renders paragraphs with $…$ math inline)

struct InlineMathText: View {
    let text: String
    var isSelectable: Bool = true

    var body: some View {
        Group {
            if text.contains("$") || text.contains("\\(") {
                // Split by delimiters for mixed text+math
                inlineMixedView
            } else {
                if isSelectable {
                    styledMarkdown(text)
                } else {
                    plainText(text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var inlineMixedView: some View {
#if canImport(LaTeXSwiftUI)
        LaTeX(text)
            .parsingMode(.all)
            .errorMode(.original)
            .font(.system(size: 18))
            .lineSpacing(8)
#else
        // Collect segments: alternating plain / math
        let segments = splitInlineMath(text)
        return VStack(alignment: .leading, spacing: 6) {
            // Wrap in flowing HStack-like text using concatenated Text views
            segments.reduce(Text("")) { acc, seg in
                if seg.isMath {
                    return acc + Text("[\(seg.content)]")
                        .font(.system(size: 17, design: .monospaced))
                        .foregroundColor(Color(red: 0.5, green: 0.9, blue: 1.0))
                } else {
                    return acc + plainText(seg.content)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(8)

            // Separate display for each math segment using WKWebView
            ForEach(segments.filter(\.isMath).indices, id: \.self) { idx in
                let mathSeg = segments.filter(\.isMath)[idx]
                MathDisplayView(expression: mathSeg.content, isInline: true)
                    .padding(.vertical, 4)
            }
        }
#endif
    }

    private func plainText(_ s: String) -> Text {
        guard let attr = try? AttributedString(markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return Text(s).foregroundColor(.white.opacity(0.9))
        }
        return Text(attr)
    }

    private func styledMarkdown(_ content: String) -> some View {
        SelectableTextView(content: content, messageId: content.prefix(20).description, highlights: [], onAction: nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    struct Segment { let content: String; let isMath: Bool }

    private func splitInlineMath(_ s: String) -> [Segment] {
        var result: [Segment] = []
        var current = ""
        var inMath = false
        var i = s.startIndex
        
        while i < s.endIndex {
            let c = s[i]
            
            // Check for \$
            if c == "$" {
                if !current.isEmpty {
                    result.append(Segment(content: current, isMath: inMath))
                    current = ""
                }
                inMath.toggle()
                i = s.index(after: i)
                continue
            }
            
            // Check for \\( and \\)
            if c == "\\" {
                let nextIdx = s.index(after: i)
                if nextIdx < s.endIndex {
                    let nextC = s[nextIdx]
                    if nextC == "(" && !inMath {
                        if !current.isEmpty {
                            result.append(Segment(content: current, isMath: false))
                            current = ""
                        }
                        inMath = true
                        i = s.index(after: nextIdx)
                        continue
                    } else if nextC == ")" && inMath {
                        if !current.isEmpty {
                            result.append(Segment(content: current, isMath: true))
                            current = ""
                        }
                        inMath = false
                        i = s.index(after: nextIdx)
                        continue
                    }
                }
            }
            
            current.append(c)
            i = s.index(after: i)
        }
        
        if !current.isEmpty { result.append(Segment(content: current, isMath: inMath)) }
        return result
    }
}

// MARK: - Math Display (WKWebView with MathJax)

struct MathDisplayView: View {
    let expression: String
    let isInline: Bool

    @State private var height: CGFloat = 44

    var body: some View {
        MathWebView(expression: expression, isInline: isInline, height: $height)
            .frame(height: max(height, isInline ? 30 : 50))
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: isInline ? 6 : 10))
    }
}

struct MathWebView: UIViewRepresentable {
    let expression: String
    let isInline: Bool
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "heightHandler")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.navigationDelegate = context.coordinator
        wv.loadHTMLString(buildHTML(), baseURL: nil)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(buildHTML(), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    private func buildHTML() -> String {
        let delim = isInline ? "\\(" + expression + "\\)" : "\\[" + expression + "\\]"
        return """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { margin:0; padding:6px 10px; background:transparent;
                 color: rgba(255,255,255,0.93);
                 font-family: -apple-system; font-size: 16px; }
          .math-container { display: inline-block; width: 100%; }
        </style>
        <script>MathJax = {
          tex: { inlineMath: [['\\\\(','\\\\)']], displayMath: [['\\\\[','\\\\]']] },
          startup: { ready() { MathJax.startup.defaultReady();
            MathJax.startup.promise.then(() => {
              const h = document.body.scrollHeight;
              window.webkit.messageHandlers.heightHandler.postMessage(h);
            });
          }}
        };</script>
        <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js" async></script>
        </head><body><div class="math-container">\(delim)</div></body></html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if let h = message.body as? CGFloat, h > 10 {
                DispatchQueue.main.async { self.height = h + 12 }
            } else if let h = message.body as? Int, h > 10 {
                DispatchQueue.main.async { self.height = CGFloat(h) + 12 }
            }
        }
    }
}

// MARK: - Code Block

private struct RichCodeBlockView: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Circle().fill(Color(red: 1, green: 0.35, blue: 0.35)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 1, green: 0.73, blue: 0.22)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 0.27, green: 0.82, blue: 0.5)).frame(width: 9, height: 9)
                Spacer()
                if !language.isEmpty {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? "Copied!" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(copied ? .green : .white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.07))

            Divider().background(Color.white.opacity(0.1))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0.9, green: 0.95, blue: 1.0))
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .background(Color(red: 0.1, green: 0.11, blue: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Bullet / Numbered Lists

private struct BulletListView: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .offset(y: 8)
                    InlineMathText(text: item)
                }
            }
        }
        .padding(.leading, 4)
    }
}

private struct NumberedListView: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1).")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor.opacity(0.9))
                        .frame(minWidth: 24, alignment: .trailing)
                    InlineMathText(text: item)
                }
            }
        }
        .padding(.leading, 4)
    }
}

// MARK: - Table

private struct RichTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(headers.indices, id: \.self) { i in
                        Text(headers[i])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 80, alignment: .leading)
                            .background(Color.white.opacity(0.12))
                    }
                }
                Divider().background(Color.white.opacity(0.2))
                // Rows
                ForEach(rows.indices, id: \.self) { rowIdx in
                    HStack(spacing: 0) {
                        ForEach(rows[rowIdx].indices, id: \.self) { colIdx in
                            Text(rows[rowIdx][colIdx])
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(minWidth: 80, alignment: .leading)
                                .background(rowIdx.isMultiple(of: 2) ? Color.white.opacity(0.04) : Color.clear)
                        }
                    }
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Image

private struct RichImageView: View {
    let urlString: String
    let caption: String?
    @State private var showFull = false

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .onTapGesture { showFull = true }
                    case .failure:
                        HStack {
                            Image(systemName: "photo.badge.exclamationmark")
                            Text("Image unavailable").font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    default:
                        ProgressView()
                            .frame(height: 120)
                    }
                }
                .fullScreenCover(isPresented: $showFull) {
                    FullImageView(url: url) { showFull = false }
                }
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Callout / Admonition

private struct CalloutView: View {
    let icon: String
    let title: String?
    let bodyText: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                }
                Text(bodyText)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
