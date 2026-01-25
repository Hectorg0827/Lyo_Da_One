import SwiftUI
import AVKit
import WebKit

// MARK: - Advanced A2UI Component Renderers

@available(iOS 15.0, *)
struct AdvancedA2UIRenderer: View {
    let component: DynamicComponent

    var body: some View {
        switch component.type {
        case .videoPlayer:
            if case .videoPlayer(let payload) = component.payload {
                VideoPlayerRenderer(payload: payload)
            }
        case .codeEditor:
            if case .codeEditor(let payload) = component.payload {
                CodeEditorRenderer(payload: payload)
            }
        case .codeSandbox:
            if case .codeSandbox(let payload) = component.payload {
                CodeSandboxRenderer(payload: payload)
            }
        case .collaborationSpace:
            if case .collaborationSpace(let payload) = component.payload {
                CollaborationSpaceRenderer(payload: payload)
            }
        case .whiteboard:
            if case .whiteboard(let payload) = component.payload {
                WhiteboardRenderer(payload: payload)
            }
        case .simulation:
            if case .simulation(let payload) = component.payload {
                SimulationRenderer(payload: payload)
            }
        case .gameBasedLearning:
            if case .gameBasedLearning(let payload) = component.payload {
                GameBasedLearningRenderer(payload: payload)
            }
        default:
            Text("Advanced component not supported")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Video Player Renderer

@available(iOS 15.0, *)
struct VideoPlayerRenderer: View {
    let payload: VideoPlayerPayload
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showControls = true

    var body: some View {
        VStack(spacing: 12) {
            // Video Title
            if let title = payload.title {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            // Video Player
            GeometryReader { geometry in
                ZStack {
                    // Video View
                    if let player = player {
                        VideoPlayer(player: player)
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(12)
                            .onTapGesture {
                                showControls.toggle()
                            }
                    } else {
                        // Thumbnail placeholder
                        AsyncImage(url: URL(string: payload.thumbnailUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white)
                                )
                        }
                        .cornerRadius(12)
                        .onTapGesture {
                            initializePlayer()
                        }
                    }

                    // Custom Controls Overlay
                    if showControls && player != nil {
                        VStack {
                            Spacer()

                            HStack {
                                // Play/Pause Button
                                Button(action: togglePlayback) {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }

                                // Progress Slider
                                Slider(value: $currentTime, in: 0...duration) { _ in
                                    seekTo(currentTime)
                                }
                                .accentColor(.white)

                                // Duration Label
                                Text(formatTime(currentTime) + " / " + formatTime(duration))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                        .padding()
                    }

                    // Interactive Elements Overlay
                    ForEach(payload.interactiveElements.indices, id: \.self) { index in
                        let element = payload.interactiveElements[index]
                        if shouldShowInteractiveElement(element) {
                            InteractiveElementOverlay(element: element)
                        }
                    }
                }
            }
            .frame(height: 220)

            // Video Description
            if let description = payload.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Chapters List
            if !payload.chapters.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text("Chapters")
                        .font(.headline)

                    ForEach(payload.chapters.indices, id: \.self) { index in
                        let chapter = payload.chapters[index]
                        ChapterRow(chapter: chapter) {
                            seekToChapter(chapter)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .onAppear {
            if payload.autoPlay {
                initializePlayer()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func initializePlayer() {
        guard let url = URL(string: payload.videoUrl) else { return }
        player = AVPlayer(url: url)

        // Setup observers
        setupPlayerObservers()

        if payload.autoPlay {
            player?.play()
            isPlaying = true
        }
    }

    private func setupPlayerObservers() {
        guard let player = player else { return }

        // Duration observer
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { time in
            currentTime = time.seconds
            if let duration = player.currentItem?.duration {
                self.duration = duration.seconds
            }
        }

        // Playback status observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            // Handle completion
            if let quizAction = payload.quizOnCompletion {
                // Trigger quiz action
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

    private func seekTo(_ time: Double) {
        guard let player = player else { return }
        let seekTime = CMTime(seconds: time, preferredTimescale: 1)
        player.seek(to: seekTime)
    }

    private func seekToChapter(_ chapter: [String: Any]) {
        if let timestamp = chapter["timestamp"] as? Double {
            seekTo(timestamp)
        }
    }

    private func shouldShowInteractiveElement(_ element: [String: Any]) -> Bool {
        guard let timestamp = element["timestamp"] as? Double else { return false }
        return abs(currentTime - timestamp) < 2.0 // Show within 2 seconds of timestamp
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Code Editor Renderer

struct CodeEditorRenderer: View {
    let payload: CodeEditorPayload
    @State private var code: String
    @State private var isEditing = false

    init(payload: CodeEditorPayload) {
        self.payload = payload
        self._code = State(initialValue: payload.content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Editor Header
            HStack {
                Text(payload.language.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)

                Spacer()

                // Action Buttons
                HStack(spacing: 8) {
                    if let runAction = payload.runCodeAction {
                        Button("Run") {
                            // Trigger run action
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }

                    if payload.allowCopy {
                        Button(action: copyCode) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            // Code Editor
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 8) {
                    // Line Numbers
                    if payload.lineNumbers {
                        VStack(alignment: .trailing, spacing: lineHeight) {
                            ForEach(1...max(1, code.components(separatedBy: "\n").count), id: \.self) { lineNumber in
                                Text("\(lineNumber)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 30, alignment: .trailing)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Code Text
                    ZStack(alignment: .topLeading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(payload.theme == "dark" ? Color.black : Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        // Text Editor
                        TextEditor(text: $code)
                            .font(.system(size: CGFloat(payload.fontSize), design: .monospaced))
                            .foregroundColor(payload.theme == "dark" ? .white : .primary)
                            .background(Color.clear)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                    }
                    .frame(minHeight: 200)
                }
            }

            // Editor Status
            HStack {
                Text("Lines: \(code.components(separatedBy: "\n").count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if isEditing {
                    Text("Editing...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onChange(of: code) { _ in
            isEditing = true

            // Debounce editing state
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isEditing = false
            }
        }
    }

    private var lineHeight: CGFloat {
        CGFloat(payload.fontSize + 4)
    }

    private func copyCode() {
        UIPasteboard.general.string = code
    }
}

// MARK: - Code Sandbox Renderer

struct CodeSandboxRenderer: View {
    let payload: CodeSandboxPayload
    @State private var code: String
    @State private var output = ""
    @State private var isRunning = false
    @State private var showHints = false

    init(payload: CodeSandboxPayload) {
        self.payload = payload
        self._code = State(initialValue: payload.initialCode)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Sandbox Header
            HStack {
                VStack(alignment: .leading) {
                    Text(payload.title)
                        .font(.headline)

                    if let description = payload.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Controls
                HStack(spacing: 8) {
                    if !payload.hints.isEmpty {
                        Button("Hints") {
                            showHints.toggle()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(isRunning ? "Running..." : "Run") {
                        runCode()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                }
            }

            // Code Editor
            CodeEditorRenderer(payload: CodeEditorPayload(
                language: payload.language.rawValue,
                content: code,
                theme: "dark",
                fontSize: 14,
                tabSize: payload.language == .python ? 4 : 2,
                lineNumbers: true,
                autoComplete: payload.autoComplete,
                syntaxHighlighting: payload.syntaxHighlighting
            ))

            // Output Panel
            if !output.isEmpty || isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.headline)

                    ScrollView {
                        Text(isRunning ? "Running code..." : output)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(isRunning ? .blue : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 150)
                }
            }

            // Test Results
            if payload.autoGrade && !payload.testCases.isEmpty {
                TestResultsView(testCases: payload.testCases, code: code)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .sheet(isPresented: $showHints) {
            HintsSheet(hints: payload.hints)
        }
    }

    private func runCode() {
        isRunning = true
        output = ""

        // Simulate code execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isRunning = false
            output = "Code executed successfully!\nResult: Hello, World!"

            // In real implementation, this would execute code in a secure sandbox
        }
    }
}

// MARK: - Collaboration Space Renderer

struct CollaborationSpaceRenderer: View {
    let payload: CollaborationSpacePayload
    @State private var isConnected = false
    @State private var participants: [[String: Any]] = []

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(payload.title)
                    .font(.headline)

                Spacer()

                // Connection Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Participants
            if !participants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(participants.indices, id: \.self) { index in
                            let participant = participants[index]
                            ParticipantAvatarView(participant: participant)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Collaboration Tools
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(payload.collaborationTypes, id: \.self) { type in
                    CollaborationToolButton(type: type.rawValue)
                }
            }

            // Join/Leave Button
            Button(isConnected ? "Leave Session" : "Join Session") {
                toggleConnection()
            }
            .buttonStyle(.borderedProminent)
            .foregroundColor(isConnected ? .red : .blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            // Simulate initial participants
            participants = [
                ["name": "Alice", "active": true],
                ["name": "Bob", "active": true]
            ]
        }
    }

    private func toggleConnection() {
        withAnimation {
            isConnected.toggle()
        }
    }
}

// MARK: - Whiteboard Renderer

struct WhiteboardRenderer: View {
    let payload: WhiteboardPayload
    @State private var drawings: [Drawing] = []
    @State private var currentPath = Path()
    @State private var selectedTool = "pen"

    struct Drawing {
        let path: Path
        let color: Color
        let lineWidth: CGFloat
    }

    var body: some View {
        VStack(spacing: 12) {
            // Toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(payload.availableTools, id: \.self) { tool in
                        Button(action: {
                            selectedTool = tool
                        }) {
                            Image(systemName: iconForTool(tool))
                                .font(.title3)
                                .foregroundColor(selectedTool == tool ? .white : .blue)
                                .frame(width: 40, height: 40)
                                .background(selectedTool == tool ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }

                    Divider()

                    // Clear button
                    Button("Clear") {
                        drawings.removeAll()
                    }
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
            }

            // Canvas
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(payload.backgroundColor))
                    .overlay(
                        // Grid background
                        payload.backgroundGrid ? GridView() : nil
                    )

                // Drawings
                ForEach(drawings.indices, id: \.self) { index in
                    drawings[index].path
                        .stroke(drawings[index].color, lineWidth: drawings[index].lineWidth)
                }

                // Current drawing
                currentPath
                    .stroke(Color.blue, lineWidth: 2)
            }
            .frame(width: CGFloat(payload.width), height: CGFloat(payload.height))
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if selectedTool == "pen" || selectedTool == "pencil" {
                            let point = value.location
                            if currentPath.isEmpty {
                                currentPath.move(to: point)
                            } else {
                                currentPath.addLine(to: point)
                            }
                        }
                    }
                    .onEnded { _ in
                        if !currentPath.isEmpty {
                            let drawing = Drawing(
                                path: currentPath,
                                color: .blue,
                                lineWidth: selectedTool == "pencil" ? 1 : 2
                            )
                            drawings.append(drawing)
                            currentPath = Path()
                        }
                    }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func iconForTool(_ tool: String) -> String {
        switch tool {
        case "pen": return "pencil"
        case "pencil": return "pencil.tip"
        case "highlighter": return "highlighter"
        case "eraser": return "eraser"
        case "text": return "textformat"
        case "shapes": return "rectangle"
        case "sticky_notes": return "note.text"
        default: return "pencil"
        }
    }
}

// MARK: - Supporting Views

struct ChapterRow: View {
    let chapter: [String: Any]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(chapter["title"] as? String ?? "Chapter")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                if let timestamp = chapter["timestamp"] as? Double {
                    Text(formatTime(timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct InteractiveElementOverlay: View {
    let element: [String: Any]

    var body: some View {
        VStack {
            Text(element["content"] as? String ?? "Interactive Element")
                .padding()
                .background(Color.blue.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(8)

            if element["type"] as? String == "question" {
                Button("Answer") {
                    // Handle question interaction
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ParticipantAvatarView: View {
    let participant: [String: Any]

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String((participant["name"] as? String ?? "U").prefix(1)))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )

            Text(participant["name"] as? String ?? "User")
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct CollaborationToolButton: View {
    let type: String

    var body: some View {
        Button(action: {
            // Handle tool selection
        }) {
            VStack(spacing: 8) {
                Image(systemName: iconForType(type))
                    .font(.title2)

                Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.blue)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "real_time_editing": return "doc.text"
        case "whiteboard": return "scribble"
        case "voice_chat": return "mic"
        case "video_chat": return "video"
        case "screen_share": return "rectangle.on.rectangle"
        case "annotation": return "note.text"
        default: return "questionmark"
        }
    }
}

struct GridView: View {
    var body: some View {
        Path { path in
            let spacing: CGFloat = 20

            // Vertical lines
            for x in stride(from: 0, to: 1200, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: 800))
            }

            // Horizontal lines
            for y in stride(from: 0, to: 800, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: 1200, y: y))
            }
        }
        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
    }
}

struct TestResultsView: View {
    let testCases: [[String: Any]]
    let code: String
    @State private var results: [Bool] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Results")
                .font(.headline)

            ForEach(testCases.indices, id: \.self) { index in
                let testCase = testCases[index]
                HStack {
                    Image(systemName: results.indices.contains(index) && results[index] ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(results.indices.contains(index) && results[index] ? .green : .red)

                    Text(testCase["description"] as? String ?? "Test \(index + 1)")
                        .font(.subheadline)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            runTests()
        }
    }

    private func runTests() {
        // Simulate test execution
        results = testCases.map { _ in Bool.random() }
    }
}

struct HintsSheet: View {
    let hints: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(hints.indices, id: \.self) { index in
                Text(hints[index])
                    .padding(.vertical, 4)
            }
            .navigationTitle("Hints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Placeholder renderers for other advanced components
struct SimulationRenderer: View {
    let payload: Any

    var body: some View {
        Text("Simulation Component")
            .font(.headline)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
    }
}

struct GameBasedLearningRenderer: View {
    let payload: Any

    var body: some View {
        Text("Game-Based Learning Component")
            .font(.headline)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Payload Definitions for Advanced Components

struct VideoPlayerPayload: Codable {
    let videoUrl: String
    let videoType: String
    let title: String?
    let description: String?
    let thumbnailUrl: String?
    let durationSeconds: Int?
    let chapters: [[String: Any]]
    let interactiveElements: [[String: Any]]
    let captionsUrl: String?
    let transcriptUrl: String?
    let autoPlay: Bool
    let showControls: Bool
    let allowFullscreen: Bool
    let playbackRates: [Double]
    let trackProgress: Bool
    let requireCompletion: Bool
    let quizOnCompletion: String?
    let keyboardNavigation: Bool
    let screenReaderCompatible: Bool

    enum CodingKeys: String, CodingKey {
        case videoUrl = "video_url"
        case videoType = "video_type"
        case title, description
        case thumbnailUrl = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case chapters
        case interactiveElements = "interactive_elements"
        case captionsUrl = "captions_url"
        case transcriptUrl = "transcript_url"
        case autoPlay = "auto_play"
        case showControls = "show_controls"
        case allowFullscreen = "allow_fullscreen"
        case playbackRates = "playback_rates"
        case trackProgress = "track_progress"
        case requireCompletion = "require_completion"
        case quizOnCompletion = "quiz_on_completion"
        case keyboardNavigation = "keyboard_navigation"
        case screenReaderCompatible = "screen_reader_compatible"
    }
}

struct CodeEditorPayload: Codable {
    let language: String
    let content: String
    let theme: String
    let fontSize: Int
    let tabSize: Int
    let wordWrap: Bool
    let lineNumbers: Bool
    let autoComplete: Bool
    let syntaxHighlighting: Bool
    let errorHighlighting: Bool
    let bracketMatching: Bool
    let highContrast: Bool
    let keyboardShortcuts: Bool
    let screenReaderSupport: Bool
    let runCodeAction: String?
    let saveAction: String?
    let shareAction: String?
    let allowCopy: Bool

    enum CodingKeys: String, CodingKey {
        case language, content, theme
        case fontSize = "font_size"
        case tabSize = "tab_size"
        case wordWrap = "word_wrap"
        case lineNumbers = "line_numbers"
        case autoComplete = "auto_complete"
        case syntaxHighlighting = "syntax_highlighting"
        case errorHighlighting = "error_highlighting"
        case bracketMatching = "bracket_matching"
        case highContrast = "high_contrast"
        case keyboardShortcuts = "keyboard_shortcuts"
        case screenReaderSupport = "screen_reader_support"
        case runCodeAction = "run_code_action"
        case saveAction = "save_action"
        case shareAction = "share_action"
        case allowCopy = "allow_copy"
    }
}

struct CodeSandboxPayload: Codable {
    let language: String
    let title: String
    let description: String?
    let initialCode: String
    let solutionCode: String?
    let testCases: [[String: Any]]
    let allowFileUpload: Bool
    let allowPackageInstall: Bool
    let executionTimeout: Int
    let memoryLimitMb: Int
    let hints: [String]
    let stepByStepGuidance: Bool
    let autoComplete: Bool
    let syntaxHighlighting: Bool
    let allowCollaboration: Bool
    let maxCollaborators: Int
    let autoGrade: Bool
    let rubric: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case language, title, description
        case initialCode = "initial_code"
        case solutionCode = "solution_code"
        case testCases = "test_cases"
        case allowFileUpload = "allow_file_upload"
        case allowPackageInstall = "allow_package_install"
        case executionTimeout = "execution_timeout"
        case memoryLimitMb = "memory_limit_mb"
        case hints
        case stepByStepGuidance = "step_by_step_guidance"
        case autoComplete = "auto_complete"
        case syntaxHighlighting = "syntax_highlighting"
        case allowCollaboration = "allow_collaboration"
        case maxCollaborators = "max_collaborators"
        case autoGrade = "auto_grade"
        case rubric
    }
}

struct CollaborationSpacePayload: Codable {
    let sessionId: String
    let title: String
    let maxParticipants: Int
    let currentParticipants: [[String: Any]]
    let collaborationTypes: [String]
    let realTimeCursor: Bool
    let realTimeSelection: Bool
    let activityAwareness: Bool
    let chatEnabled: Bool
    let voiceEnabled: Bool
    let videoEnabled: Bool
    let moderatorControls: Bool
    let participantPermissions: [String: Bool]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case title
        case maxParticipants = "max_participants"
        case currentParticipants = "current_participants"
        case collaborationTypes = "collaboration_types"
        case realTimeCursor = "real_time_cursor"
        case realTimeSelection = "real_time_selection"
        case activityAwareness = "activity_awareness"
        case chatEnabled = "chat_enabled"
        case voiceEnabled = "voice_enabled"
        case videoEnabled = "video_enabled"
        case moderatorControls = "moderator_controls"
        case participantPermissions = "participant_permissions"
    }
}

struct WhiteboardPayload: Codable {
    let width: Int
    let height: Int
    let availableTools: [String]
    let multiUser: Bool
    let realTimeSync: Bool
    let cursorTracking: Bool
    let backgroundColor: String
    let backgroundGrid: Bool
    let infiniteCanvas: Bool
    let exportFormats: [String]
    let templates: [[String: Any]]

    enum CodingKeys: String, CodingKey {
        case width, height
        case availableTools = "available_tools"
        case multiUser = "multi_user"
        case realTimeSync = "real_time_sync"
        case cursorTracking = "cursor_tracking"
        case backgroundColor = "background_color"
        case backgroundGrid = "background_grid"
        case infiniteCanvas = "infinite_canvas"
        case exportFormats = "export_formats"
        case templates
    }
}