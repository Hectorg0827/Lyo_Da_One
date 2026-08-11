import SwiftUI
import UIKit
import WebKit

// MARK: - Unified Block Renderer

/// Routes `SmartBlock` instances to the appropriate SwiftUI view.
/// Replaces the 30-case `BlockRendererView` switch and the 13-case `SmartBlockContainerView`.
/// Works in both chat and classroom contexts.
struct UnifiedBlockRenderer: View {
    let block: SmartBlock
    var context: RenderContext = .chat
    /// Server verdict for this block, when it's a quiz that has been
    /// answered — nil while unanswered or pending. Never derived from
    /// `QuizBlockPayload.correctIndex` locally; see `SmartQuizBlockView`.
    var checkResult: CheckAnswerResult?

    // Callbacks
    var onQuizAnswer: ((Int) -> Void)?
    var onAction: ((String) -> Void)?

    enum RenderContext {
        case chat
        case classroom
    }

    var body: some View {
        Group {
            switch block.content {
            case .text(let payload):
                SmartTextBlockView(payload: payload, subtype: block.subtype)

            case .code(let payload):
                SmartCodeBlockView(payload: payload, subtype: block.subtype)

            case .quiz(let payload):
                SmartQuizBlockView(payload: payload, subtype: block.subtype, checkResult: checkResult, onAnswer: onQuizAnswer)
                
            case .flashcard(let payload):
                SmartFlashcardBlockView(payload: payload, subtype: block.subtype)
                
            case .dataViz(let payload):
                SmartDataVizBlockView(payload: payload, subtype: block.subtype)
                
            case .media(let payload):
                SmartMediaBlockView(payload: payload, subtype: block.subtype)
                
            case .progress(let payload):
                SmartProgressBlockView(payload: payload, subtype: block.subtype)
                
            case .interactive(let payload):
                SmartInteractiveBlockView(payload: payload, subtype: block.subtype)
                
            case .masteryMap(let payload):
                SmartMasteryMapBlockView(payload: payload)
                
            case .unknown:
                ContentUnavailableCard()
            }
        }
    }
}

// MARK: - Content Unavailable Card (unknown block fallback)

struct ContentUnavailableCard: View {
    var message: String = "Update Lyo to see this content"
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("New Content Available")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Text Block

struct SmartTextBlockView: View {
    let payload: TextBlockPayload
    let subtype: String?
    
    var body: some View {
        content
    }
    
    @ViewBuilder
    private var content: some View {
        switch subtype {
        case "heading":
            headingView
        case "summary":
            summaryView
        case "callout":
            calloutView
        case "hook":
            hookView
        default:
            SmartTextParagraphView(text: payload.text)
        }
    }
    
    private var headingView: some View {
        Text(payload.text)
            .font(.title2.bold())
            .foregroundStyle(.primary)
    }
    
    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "text.document")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(payload.text)
                .font(.body)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var calloutView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(payload.text)
                .font(.callout)
        }
        .padding()
        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var hookView: some View {
        Text(payload.text)
            .font(.title3.bold())
            .foregroundStyle(.primary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.purple.opacity(0.15), .blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}

// MARK: - Code Block

struct SmartCodeBlockView: View {
    let payload: CodeBlockPayload
    let subtype: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(payload.language.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = payload.code
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(payload.code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quiz Block

/// An answerable check inside a chat lesson.
///
/// The verdict comes from the server (`checkResult`), never from comparing
/// a selection against `payload.correctIndex` — that field rides on the wire
/// for the *server's* use, and this view deliberately never reads it. See
/// web's `CheckBlock.tsx`, which documents the same rule for the same
/// reason: deciding correctness on the client is the exact failure this
/// feature exists to remove (chat praising a wrong answer).
struct SmartQuizBlockView: View {
    let payload: QuizBlockPayload
    let subtype: String?
    /// The graded verdict, once the server has returned one. nil before
    /// answering and while `onAnswer` is grading in flight.
    let checkResult: CheckAnswerResult?
    let onAnswer: ((Int) -> Void)?

    @State private var pendingIndex: Int?

    private var answered: Bool { checkResult != nil }
    private var isGrading: Bool { pendingIndex != nil && checkResult == nil }

    /// Restarts the recovery task below whenever either half of "grading in
    /// flight" changes — matches Android's `LaunchedEffect(pendingIndex,
    /// checkResult)`, which keys on both for the same reason: `.task(id:)`
    /// only restarts when its id changes, and keying on `pendingIndex` alone
    /// would leave a stale task still holding the *old* (nil) `checkResult`
    /// running after a real verdict arrives.
    private var recoveryTaskKey: String { "\(pendingIndex.map(String.init) ?? "nil")-\(answered)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            questionHeader
            optionsList
            if isGrading {
                ProgressView().frame(maxWidth: .infinity)
            }
            resultFooter
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        // Grading is normally near-instant. If the request drops (no result,
        // no error surfaced back into this view — onAnswer is fire-and-
        // forget) the option would otherwise be stuck showing a spinner
        // forever with no way to retry. Recover by re-enabling the options
        // after a timeout, same as UnifiedBlockRenderer.kt on Android.
        .task(id: recoveryTaskKey) {
            guard pendingIndex != nil, checkResult == nil else { return }
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled, checkResult == nil else { return }
            pendingIndex = nil
        }
    }

    private var questionHeader: some View {
        Text(payload.question)
            .font(.body.bold())
    }

    private var optionsList: some View {
        ForEach(Array(payload.options.enumerated()), id: \.element.id) { index, option in
            QuizOptionRow(
                option: option,
                index: index,
                checkResult: checkResult,
                isPending: pendingIndex == index && checkResult == nil
            ) {
                guard !answered, pendingIndex == nil else { return }
                pendingIndex = index
                onAnswer?(index)
            }
            .disabled(answered || pendingIndex != nil)
        }
    }

    @ViewBuilder
    private var resultFooter: some View {
        if let result = checkResult {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.bailedOut ? "No problem — here it is." : (result.correct ? "Correct." : "Not quite."))
                    .font(.caption.bold())
                    .foregroundStyle(
                        result.bailedOut
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(result.correct ? Color.green : Color.red)
                    )

                // Naming the specific confusion is the point — not just "wrong".
                if !result.correct, let misconception = result.misconception {
                    Text(misconception)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let explanation = result.explanation {
                    Text(explanation)
                        .font(.caption)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (result.correct ? Color.green : Color.red).opacity(result.bailedOut ? 0 : 0.1),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
    }
}

private struct QuizOptionRow: View {
    let option: QuizOptionPayload
    let index: Int
    let checkResult: CheckAnswerResult?
    let isPending: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                trailingIcon
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
        }
    }

    private var isChosen: Bool { checkResult?.selectedIndex == index }
    private var isCorrectAnswer: Bool { checkResult != nil && checkResult?.correctIndex == index }
    private var isWrongChoice: Bool {
        guard let result = checkResult else { return false }
        return isChosen && !result.correct && !result.bailedOut
    }

    @ViewBuilder
    private var trailingIcon: some View {
        if checkResult != nil {
            if isCorrectAnswer {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if isWrongChoice {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
        } else if isPending {
            Image(systemName: "circle.fill").foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: "circle").foregroundStyle(.secondary)
        }
    }

    private var backgroundColor: Color {
        guard checkResult != nil else {
            return isPending ? Color.accentColor.opacity(0.1) : Color(.systemGray6)
        }
        if isCorrectAnswer { return .green.opacity(0.15) }
        if isWrongChoice { return .red.opacity(0.15) }
        return Color(.systemGray6)
    }
}

// MARK: - Flashcard Block

struct SmartFlashcardBlockView: View {
    let payload: FlashcardBlockPayload
    let subtype: String?
    @State private var isFlipped = false
    
    var body: some View {
        VStack {
            Text(isFlipped ? payload.back : payload.front)
                .font(isFlipped ? .body : .headline)
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4)) { isFlipped.toggle() }
        }
    }
}

// MARK: - Data Visualization Block

struct SmartDataVizBlockView: View {
    let payload: DataVizBlockPayload
    let subtype: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = payload.title {
                Text(title).font(.subheadline.bold())
            }
            
            switch payload.format {
            case "mermaid":
                MermaidWebView(source: payload.source)
                    .frame(minHeight: 200, maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            case "math":
                Text(payload.source)
                    .font(.system(.body, design: .serif))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            default:
                // chart, table, graph — plain text fallback
                Text(payload.source)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Mermaid WKWebView

struct MermaidWebView: UIViewRepresentable {
    let source: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let escapedSource = source
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
        <style>
          body { margin: 0; padding: 8px; background: transparent; display: flex; justify-content: center; }
          .mermaid { max-width: 100%; }
        </style>
        </head>
        <body>
        <pre class="mermaid">\(escapedSource)</pre>
        <script>mermaid.initialize({startOnLoad: true, theme: 'neutral'});</script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Media Block

struct SmartMediaBlockView: View {
    let payload: MediaBlockPayload
    let subtype: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = URL(string: payload.url) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .frame(height: 100)
                    default:
                        ProgressView()
                            .frame(height: 100)
                    }
                }
            }
            
            if let caption = payload.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Progress Block

struct SmartProgressBlockView: View {
    let payload: ProgressBlockPayload
    let subtype: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = payload.label {
                Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            }
            
            ProgressView(value: Double(payload.completed), total: Double(payload.total))
                .tint(.accentColor)
            
            Text("\(payload.completed)/\(payload.total)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Interactive Block

struct SmartInteractiveBlockView: View {
    let payload: InteractiveBlockPayload
    let subtype: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = payload.title {
                Text(title).font(.subheadline.bold())
            }
            
            ForEach(Array(payload.items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.caption.bold())
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Mastery Map Block

struct SmartMasteryMapBlockView: View {
    let payload: MasteryMapBlockPayload
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(payload.title)
                .font(.headline)
            
            ForEach(payload.nodes) { node in
                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor(node.status))
                        .frame(width: 10, height: 10)
                    
                    Text(node.title)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if let level = node.masteryLevel {
                        Text("\(Int(level * 100))%")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: statusIcon(node.status))
                        .foregroundStyle(statusColor(node.status))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "current", "in_progress": return .blue
        case "locked": return .gray
        default: return .secondary
        }
    }
    
    private func statusIcon(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "current", "in_progress": return "play.circle.fill"
        case "locked": return "lock.circle"
        default: return "circle"
        }
    }
}

// MARK: - Smart Text Paragraph (markdown-aware)

private struct SmartTextParagraphView: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.body)
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}
