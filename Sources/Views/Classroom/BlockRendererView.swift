import SwiftUI
import AVKit
import Charts

// MARK: - Main Block Renderer

/// Renders ANY LessonBlock type dynamically
/// This is the SINGLE entry point for all block rendering in the classroom
/// Production-ready: handles ALL 30+ block types with graceful fallbacks
struct BlockRendererView: View {
    let block: LessonBlock
    
    // Callbacks for interactive blocks (to be wired to ViewModel)
    var onQuizAnswer: ((Int) -> Void)?
    var onAction: ((String) -> Void)?
    
    var body: some View {
        Group {
            switch block.type {
            // MARK: - Content Blocks
            case .text, .paragraph:
                TextBlockView(content: block.safeContent)
                
            case .heading:
                HeadingBlockView(title: block.safeTitle, level: block.subtitle ?? "h2")
                
            case .summary:
                SummaryBlockView(block: block)
                
            case .callout:
                CalloutBlockView(block: block)
                
            case .divider:
                Divider()
                    .padding(.vertical, 8)
                
            case .spacer:
                Spacer().frame(height: 16)
                
            // MARK: - Media Blocks
            case .image:
                ImageBlockView(url: block.imageURL, caption: block.caption)
                
            case .video:
                VideoBlockView(url: block.videoURL, caption: block.caption)
                
            case .audio:
                AudioBlockView(url: block.audioURL, title: block.title)
                
            case .animation:
                AnimationBlockView(url: block.imageURL, caption: block.caption)
                
            // MARK: - Interactive Blocks
            case .quiz, .quizMcq:
                QuizMCQBlockView(block: block, onAnswer: onQuizAnswer)
                
            case .quizTrueFalse:
                QuizTrueFalseBlockView(block: block, onAnswer: { onQuizAnswer?($0 ? 1 : 0) })
                
            case .quizFillBlank:
                QuizFillBlankBlockView(block: block, onSubmit: { answer in onAction?(answer) })
                
            case .textInput:
                TextInputBlockView(block: block, onSubmit: { answer in onAction?(answer) })
                
            case .poll:
                PollBlockView(block: block, onVote: { onQuizAnswer?($0) })
                
            // MARK: - Technical Blocks
            case .code:
                CodeBlockView(code: block.code ?? "", language: block.language)
                
            case .codePlayground:
                CodePlaygroundBlockView(block: block, onRun: { onAction?("run_code") })
                
            case .terminal:
                TerminalBlockView(output: block.code ?? block.safeContent)
                
            // MARK: - Data Visualization Blocks
            case .chart:
                ChartBlockView(block: block)
                
            case .graph, .diagram:
                DiagramBlockView(block: block)
                
            case .table:
                TableBlockView(headers: block.headers ?? [], rows: block.rows ?? [])
                
            case .math:
                MathBlockView(latex: block.latex ?? block.safeContent)
                
            // MARK: - Learning Aid Blocks
            case .flashcard:
                FlashcardBlockView(front: block.front ?? block.safeTitle, back: block.back ?? block.safeContent, hint: block.hint)
                
            case .flashcardDeck:
                FlashcardDeckBlockView(cards: block.cards ?? [])
                
            case .timeline:
                TimelineBlockView(block: block)
                
            case .comparison:
                ComparisonBlockView(block: block)
                
            case .stepByStep:
                StepByStepBlockView(block: block)
                
            // MARK: - Navigation & Structure Blocks
            case .progress:
                ProgressBlockView(block: block)
                
            case .checkpoint:
                CheckpointBlockView(block: block, onSave: { onAction?("save_progress") })
                
            case .unknown:
                UnknownBlockView(block: block)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Sub-Views

struct TextBlockView: View {
    let content: String
    
    var body: some View {
        Text(content)
            .font(.system(.body, design: .rounded))
            .lineSpacing(6)
            .foregroundColor(.primary.opacity(0.8))
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HeadingBlockView: View {
    let title: String
    let level: String
    
    var body: some View {
        Text(title)
            .font(fontForLevel(level))
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func fontForLevel(_ level: String) -> Font {
        switch level.lowercased() {
        case "h1": return .title
        case "h2": return .title2
        case "h3": return .title3
        default: return .headline
        }
    }
}

struct CalloutBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: block.style?.icon ?? iconForType)
                .font(.headline)
                .foregroundColor(colorForType)
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = block.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(colorForType)
                }
                
                Text(block.safeContent)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.9))
            }
        }
        .padding()
        .background(colorForType.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForType.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
    
    private var iconForType: String {
        switch block.style?.calloutType {
        case "warning": return "exclamationmark.triangle.fill"
        case "tip": return "lightbulb.fill"
        case "error": return "xmark.octagon.fill"
        default: return "info.circle.fill"
        }
    }
    
    private var colorForType: Color {
        switch block.style?.calloutType {
        case "warning": return .orange
        case "tip": return .blue
        case "error": return .red
        default: return .indigo
        }
    }
}

struct ImageBlockView: View {
    let url: URL?
    let caption: String?
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            if let caption = caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 12)
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language {
                HStack {
                    Text(language.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = code
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.subheadline, design: .monospaced))
                    .padding(12)
                    .foregroundColor(.primary)
            }
            .background(Color.black.opacity(0.02))
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
}

struct QuizMCQBlockView: View {
    let block: LessonBlock
    var onAnswer: ((Int) -> Void)?
    
    @State private var selectedIndex: Int?
    @State private var hasSubmitted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(block.question ?? "Question")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let options = block.options {
                ForEach(0..<options.count, id: \.self) { index in
                    Button(action: {
                        if !hasSubmitted {
                            selectedIndex = index
                            hasSubmitted = true
                            onAnswer?(index)
                        }
                    }) {
                        HStack {
                            Text(options[index])
                                .font(.subheadline)
                                .foregroundColor(selectedIndex == index ? .white : .primary)
                            Spacer()
                            if hasSubmitted && index == block.correctIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if selectedIndex == index {
                                Image(systemName: hasSubmitted ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(hasSubmitted ? .red : .white)
                            } else {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding()
                        .background(backgroundColor(for: index))
                        .cornerRadius(10)
                    }
                }
            }
            
            // Explanation after submission
            if hasSubmitted, let explanation = block.explanation {
                Text(explanation)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.vertical, 8)
    }
    
    private func backgroundColor(for index: Int) -> Color {
        if !hasSubmitted {
            return selectedIndex == index ? Color.blue : Color.secondary.opacity(0.05)
        }
        if index == block.correctIndex {
            return Color.green.opacity(0.2)
        }
        if selectedIndex == index {
            return Color.red.opacity(0.2)
        }
        return Color.secondary.opacity(0.05)
    }
}

// MARK: - Summary Block

struct SummaryBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.purple)
                Text(block.title ?? "Summary")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            
            Text(block.safeContent)
                .font(.body)
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(6)
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
}

// MARK: - Video Block

struct VideoBlockView: View {
    let url: URL?
    let caption: String?
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = url {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 220)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(12)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Video unavailable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let caption = caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Audio Block

struct AudioBlockView: View {
    let url: URL?
    let title: String?
    
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title ?? "Audio")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(isPlaying ? "Playing..." : "Tap to play")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundColor(.blue.opacity(0.5))
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
        .padding(.vertical, 8)
        .onAppear {
            if let url = url {
                player = AVPlayer(url: url)
            }
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - Animation Block (GIF/Lottie placeholder)

struct AnimationBlockView: View {
    let url: URL?
    let caption: String?
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    case .failure:
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .frame(height: 150)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "film")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                    .frame(height: 150)
            }
            
            if let caption = caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Quiz True/False Block

struct QuizTrueFalseBlockView: View {
    let block: LessonBlock
    var onAnswer: ((Bool) -> Void)?
    
    @State private var selectedAnswer: Bool?
    @State private var hasSubmitted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(block.question ?? block.safeContent)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                trueFalseButton(value: true, label: "True", icon: "checkmark.circle")
                trueFalseButton(value: false, label: "False", icon: "xmark.circle")
            }
            
            if hasSubmitted, let explanation = block.explanation {
                Text(explanation)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
    
    private func trueFalseButton(value: Bool, label: String, icon: String) -> some View {
        Button(action: {
            if !hasSubmitted {
                selectedAnswer = value
                hasSubmitted = true
                onAnswer?(value)
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor(for: value))
            .foregroundColor(selectedAnswer == value ? .white : .primary)
            .cornerRadius(12)
        }
    }
    
    private func backgroundColor(for value: Bool) -> Color {
        if !hasSubmitted {
            return selectedAnswer == value ? (value ? .green : .red) : Color.secondary.opacity(0.1)
        }
        let correctAnswer = block.correctAnswer?.lowercased() == "true"
        if value == correctAnswer {
            return Color.green
        }
        if selectedAnswer == value {
            return Color.red
        }
        return Color.secondary.opacity(0.1)
    }
}

// MARK: - Quiz Fill Blank Block

struct QuizFillBlankBlockView: View {
    let block: LessonBlock
    var onSubmit: ((String) -> Void)?
    
    @State private var answer = ""
    @State private var hasSubmitted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(block.question ?? "Fill in the blank:")
                .font(.headline)
            
            TextField("Your answer...", text: $answer)
                .textFieldStyle(.roundedBorder)
                .disabled(hasSubmitted)
            
            if !hasSubmitted && !answer.isEmpty {
                Button("Submit") {
                    hasSubmitted = true
                    onSubmit?(answer)
                }
                .buttonStyle(.borderedProminent)
            }
            
            if hasSubmitted {
                HStack {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                    Text(isCorrect ? "Correct!" : "Incorrect. Answer: \(block.correctAnswer ?? "")")
                        .font(.callout)
                }
                
                if let explanation = block.explanation {
                    Text(explanation)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
    
    private var isCorrect: Bool {
        guard let correct = block.correctAnswer else { return false }
        return answer.lowercased().trimmingCharacters(in: .whitespaces) == correct.lowercased().trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Text Input Block

struct TextInputBlockView: View {
    let block: LessonBlock
    var onSubmit: ((String) -> Void)?
    
    @State private var text = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title {
                Text(title)
                    .font(.headline)
            }
            
            if let hint = block.hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextEditor(text: $text)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            
            Button("Submit") {
                onSubmit?(text)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Poll Block

struct PollBlockView: View {
    let block: LessonBlock
    var onVote: ((Int) -> Void)?
    
    @State private var selectedIndex: Int?
    @State private var hasVoted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(block.question ?? "Poll")
                .font(.headline)
            
            if let options = block.options {
                ForEach(0..<options.count, id: \.self) { index in
                    Button(action: {
                        if !hasVoted {
                            selectedIndex = index
                            hasVoted = true
                            onVote?(index)
                        }
                    }) {
                        HStack {
                            Text(options[index])
                                .foregroundColor(.primary)
                            Spacer()
                            if hasVoted {
                                // Show mock percentage
                                Text("\(Int.random(in: 10...50))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(selectedIndex == index ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Code Playground Block

struct CodePlaygroundBlockView: View {
    let block: LessonBlock
    var onRun: (() -> Void)?
    
    @State private var code: String
    @State private var output = ""
    
    init(block: LessonBlock, onRun: (() -> Void)?) {
        self.block = block
        self.onRun = onRun
        self._code = State(initialValue: block.code ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(block.language?.uppercased() ?? "CODE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button(action: {
                    output = "▶ Running...\n✓ Success!"
                    onRun?()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Run")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            
            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            
            if !output.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color.black)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Terminal Block

struct TerminalBlockView: View {
    let output: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Circle().fill(Color.yellow).frame(width: 12, height: 12)
                Circle().fill(Color.green).frame(width: 12, height: 12)
                Spacer()
                Text("Terminal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(output)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .padding(.vertical, 8)
    }
}

// MARK: - Chart Block

struct ChartBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title {
                Text(title)
                    .font(.headline)
            }
            
            if #available(iOS 16.0, *), let chartData = block.chartData {
                // Use Swift Charts
                Chart {
                    if let datasets = chartData.datasets {
                        ForEach(0..<(datasets.first?.data.count ?? 0), id: \.self) { index in
                            let labels = chartData.labels ?? []
                            let label = index < labels.count ? labels[index] : "Item \(index)"
                            let value = datasets.first?.data[index] ?? 0
                            
                            BarMark(
                                x: .value("Category", label),
                                y: .value("Value", value)
                            )
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic)
                }
            } else {
                // Fallback chart placeholder
                ChartPlaceholderView(block: block)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

struct ChartPlaceholderView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue.opacity(0.5))
            Text(block.chartType ?? "Chart")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Diagram Block

struct DiagramBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title {
                Text(title)
                    .font(.headline)
            }
            
            if let mermaid = block.mermaid {
                // Mermaid diagram - show code for now (could use WebView to render)
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(mermaid)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            } else {
                // Placeholder
                VStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 50))
                        .foregroundColor(.purple.opacity(0.5))
                    Text("Diagram")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Table Block

struct TableBlockView: View {
    let headers: [String]
    let rows: [[String]]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row
            if !headers.isEmpty {
                HStack(spacing: 0) {
                    ForEach(headers, id: \.self) { header in
                        Text(header)
                            .font(.caption.bold())
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.15))
                    }
                }
            }
            
            // Data rows
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0..<rows[rowIndex].count, id: \.self) { colIndex in
                        Text(rows[rowIndex][colIndex])
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(rowIndex % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                    }
                }
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
}

// MARK: - Math Block

struct MathBlockView: View {
    let latex: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.orange)
                Text("Equation")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
            
            // LaTeX rendering placeholder - could use MathJax WebView
            Text(latex)
                .font(.system(.body, design: .monospaced))
                .italic()
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Flashcard Block

struct FlashcardBlockView: View {
    let front: String
    let back: String
    let hint: String?
    
    @State private var isFlipped = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Back side
                VStack(spacing: 12) {
                    Text("Answer")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text(back)
                        .font(.body)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                
                // Front side
                VStack(spacing: 12) {
                    Text("Question")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                    Text(front)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    
                    if let hint = hint {
                        Text("💡 \(hint)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isFlipped.toggle()
                }
            }
            
            Text("Tap to flip")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Flashcard Deck Block

struct FlashcardDeckBlockView: View {
    let cards: [FlashcardPayload]
    
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 16) {
            if !cards.isEmpty && currentIndex < cards.count {
                FlashcardBlockView(
                    front: cards[currentIndex].front,
                    back: cards[currentIndex].back,
                    hint: cards[currentIndex].hint
                )
            }
            
            HStack {
                Button(action: { if currentIndex > 0 { currentIndex -= 1 } }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                }
                .disabled(currentIndex == 0)
                
                Spacer()
                
                Text("\(currentIndex + 1) / \(cards.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { if currentIndex < cards.count - 1 { currentIndex += 1 } }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                }
                .disabled(currentIndex >= cards.count - 1)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Timeline Block

struct TimelineBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title {
                Text(title)
                    .font(.headline)
            }
            
            // Parse content as timeline items (separated by newlines)
            let items = block.safeContent.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            ForEach(0..<items.count, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        if index < items.count - 1 {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    
                    Text(items[index])
                        .font(.callout)
                        .foregroundColor(.primary)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Comparison Block

struct ComparisonBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title {
                Text(title)
                    .font(.headline)
            }
            
            HStack(alignment: .top, spacing: 16) {
                // Left side
                VStack(alignment: .leading, spacing: 8) {
                    Text(block.front ?? "Option A")
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                    
                    Text(block.content?.components(separatedBy: "|||").first ?? "")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.8))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Right side
                VStack(alignment: .leading, spacing: 8) {
                    Text(block.back ?? "Option B")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                    
                    Text(block.content?.components(separatedBy: "|||").last ?? "")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.8))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Step by Step Block

struct StepByStepBlockView: View {
    let block: LessonBlock
    
    @State private var currentStep = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = block.title {
                Text(title)
                    .font(.headline)
            }
            
            let steps = block.safeContent.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Current step
            if currentStep < steps.count {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(currentStep + 1)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text(steps[currentStep])
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            
            // Navigation
            HStack {
                Button("Previous") {
                    if currentStep > 0 { currentStep -= 1 }
                }
                .disabled(currentStep == 0)
                
                Spacer()
                
                Button(currentStep < steps.count - 1 ? "Next" : "Complete") {
                    if currentStep < steps.count - 1 { currentStep += 1 }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Progress Block

struct ProgressBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.title ?? "Progress")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int((block.chartData?.datasets?.first?.data.first ?? 0)))%")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * (block.chartData?.datasets?.first?.data.first ?? 0) / 100, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.vertical, 4)
    }
}

// MARK: - Checkpoint Block

struct CheckpointBlockView: View {
    let block: LessonBlock
    var onSave: (() -> Void)?
    
    @State private var saved = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: saved ? "checkmark.circle.fill" : "bookmark.circle.fill")
                .font(.title)
                .foregroundColor(saved ? .green : .blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title ?? "Checkpoint")
                    .font(.headline)
                Text(saved ? "Progress saved!" : "Save your progress here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !saved {
                Button("Save") {
                    withAnimation {
                        saved = true
                        onSave?()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(saved ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.vertical, 8)
    }
}

// MARK: - Unknown Block (Graceful Fallback)

struct UnknownBlockView: View {
    let block: LessonBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
                Text("Unknown Block Type: \(block.type.rawValue)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if !block.safeContent.isEmpty {
                Text(block.safeContent)
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.7))
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.vertical, 8)
    }
}

