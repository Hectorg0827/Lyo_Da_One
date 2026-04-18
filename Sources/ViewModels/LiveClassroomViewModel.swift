import AVFoundation
import Combine
import Foundation
import SwiftUI
import os

// MARK: - Live Classroom ViewModel

@MainActor
final class LiveClassroomViewModel: ObservableObject {

    // MARK: - Published State

    @Published var lesson: LiveLesson?
    @Published var currentBlockIndex: Int = 0
    @Published var isLioSpeaking: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Mastery Check State
    @Published var isMasteryCheckActive: Bool = false
    @Published var masteryCheckBlock: LiveLessonBlock?

    // Graph playback state (Interactive Cinema)
    @Published var playbackState: PlaybackState?

    // Quiz State
    @Published var selectedQuizOption: Int? = nil
    @Published var quizSubmitted: Bool = false
    @Published var showingExplanation: Bool = false

    /// Wall-clock time the user first saw the current quiz block. Used to report real time-on-task to the personalization engine.
    private var quizStartedAt: Date?

    // Transcript & Questions
    @Published var transcript: [TranscriptMessage] = []

    // MARK: - Magical UX State

    enum LioState: String {
        case idle, speaking, thinking, celebrating, pondering, confused

        var icon: String {
            switch self {
            case .idle: return "face.smiling"
            case .speaking: return "bubble.left.and.bubble.right.fill"
            case .thinking: return "brain.head.profile"
            case .celebrating: return "party.popper.fill"
            case .pondering: return "lightbulb.fill"
            case .confused: return "questionmark.circle.fill"
            }
        }
    }

    @Published var lioState: LioState = .idle
    @Published var currentThemeColor: Color = DesignSystem.Colors.fallbackBackground
    private var lioStateTask: Task<Void, Never>?

    @Published var showTranscriptSheet: Bool = false
    @Published var showAskQuestionSheet: Bool = false
    @Published var showEnergySheet: Bool = false
    @Published var userQuestion: String = ""
    @Published var isProcessingQuestion: Bool = false

    // Progress
    @Published var completedBlocks: Set<String> = []
    @Published var quizResults: [String: Bool] = [:]
    @Published var isLessonComplete: Bool = false
    @Published var xpGained: Int = 0

    // MARK: - Dependencies

    private let openAIService: OpenAIService
    private let apiClient = LyoAPIClient.shared
    private let cinemaService = InteractiveCinemaService.shared
    private let repository = LyoRepository.shared
    private let contentStore = GeneratedContentStore.shared
    private var cancellables = Set<AnyCancellable>()

    // TTS & Audio
    private let ttsRepository = DefaultTTSRepository()
    private var audioPlayer: AVPlayer?

    // Graph-based playback state
    private var currentCourseId: String?
    private var lessonLoadRequestKey: String?
    private var lessonLoadToken: UUID = UUID()

    private func beginLessonLoad(courseId: String, lessonId: String) -> (token: UUID, key: String)?
    {
        let key = "\(courseId)::\(lessonId)"
        if lessonLoadRequestKey == key {
            Log.classroom.info("LiveClassroom: Skipping duplicate in-flight load for \(key)")
            return nil
        }

        let token = UUID()
        lessonLoadRequestKey = key
        lessonLoadToken = token
        return (token, key)
    }

    private func isActiveLessonLoad(token: UUID, key: String) -> Bool {
        lessonLoadToken == token && lessonLoadRequestKey == key
    }

    private func endLessonLoad(token: UUID, key: String) {
        guard isActiveLessonLoad(token: token, key: key) else { return }
        lessonLoadRequestKey = nil
        isLoading = false
    }

    // MARK: - Resume Support

    /// Key for persisting the last viewed block index per course
    private func resumeKey(for courseId: String) -> String {
        "classroom_resume_\(courseId)"
    }

    /// Save current block index so user can resume later
    private func saveResumePosition() {
        guard let courseId = currentCourseId ?? lesson?.courseId else { return }
        UserDefaults.standard.set(currentBlockIndex, forKey: resumeKey(for: courseId))
    }

    /// Restore last block index for a given course
    private func restoreResumePosition(for courseId: String) -> Int {
        UserDefaults.standard.integer(forKey: resumeKey(for: courseId))
    }

    var currentBlock: LiveLessonBlock? {
        if isMasteryCheckActive {
            return masteryCheckBlock
        }

        guard let lesson = lesson,
            currentBlockIndex >= 0,
            currentBlockIndex < lesson.blocks.count
        else {
            return nil
        }
        return lesson.blocks[currentBlockIndex]
    }

    var progressPercentage: Double {
        guard let lesson = lesson, lesson.totalBlocks > 0 else { return 0 }
        return Double(currentBlockIndex + 1) / Double(lesson.totalBlocks)
    }

    var isFirstBlock: Bool {
        currentBlockIndex == 0
    }

    var isLastBlock: Bool {
        guard let lesson = lesson else { return false }
        return currentBlockIndex >= lesson.totalBlocks - 1
    }

    var canAdvance: Bool {
        guard let block = currentBlock else { return false }

        // For quiz blocks, must submit correct answer
        if block.type == .quizMcq {
            return quizSubmitted && isQuizCorrect
        }

        // For other blocks, can always advance
        return true
    }

    var isQuizCorrect: Bool {
        // Case 1: Standard Lesson Block Quiz
        if let block = currentBlock,
            let correctIndex = block.correctIndex,
            let selected = selectedQuizOption
        {
            return selected == correctIndex
        }

        return false
    }

    // MARK: - Init

    init(openAIService: OpenAIService? = nil) {
        self.openAIService = openAIService ?? OpenAIService.shared

        // Setup audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Log.classroom.error("Failed to setup audio session: \(error)")
        }

        // Observe progressive course generation: when CourseGenerationService
        // updates generatedCourse with newly-ready modules, rebuild lesson blocks.
        observeProgressiveGeneration()

        // Observe scene-based classroom events from A2ACourseService
        observeSceneBlocks()
    }

    /// Whether this lesson was loaded via the GENERATE: flow
    private var isGenerateFlow: Bool = false
    /// Track a content fingerprint to detect meaningful changes (not just count)
    private var lastProgressiveFingerprint: String = ""
    /// Whether the hydration (final truth) pass has refreshed content
    private var hasHydrationRefreshed: Bool = false
    /// Hash of draft content before hydration, to detect new content
    private var initialDraftContentHash: Int?

    /// Build a fingerprint representing the current state of modules.
    /// Changes when: a module transitions state, or when new lesson content arrives.
    private func buildProgressiveFingerprint(_ course: GeneratedCourse) -> String {
        course.modules.map { m in
            let lessonCount = m.lessons?.count ?? 0
            let contentLen = m.lessons?.reduce(0) { $0 + ($1.content?.count ?? 0) } ?? 0
            return "\(m.index):\(m.state):\(lessonCount):\(contentLen)"
        }.joined(separator: "|")
    }

    /// Observe `CourseGenerationService.shared.$generatedCourse` for progressive module updates
    private func observeProgressiveGeneration() {
        CourseGenerationService.shared.$generatedCourse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedCourse in
                guard let self,
                    self.isGenerateFlow,
                    let updatedCourse
                else { return }

                // Build a fingerprint of current module states + content
                let fingerprint = self.buildProgressiveFingerprint(updatedCourse)

                // Only rebuild when something actually changed
                guard fingerprint != self.lastProgressiveFingerprint else { return }
                self.lastProgressiveFingerprint = fingerprint

                let activeModules = updatedCourse.modules.filter { $0.state != .locked }
                Log.classroom.info(
                    "🔄 Progressive update: \(activeModules.count) modules active — rebuilding lesson blocks"
                )
                self.rebuildLessonFromProgressiveCourse(updatedCourse)
            }
            .store(in: &cancellables)

        // Also observe generation state for completion/failure
        CourseGenerationService.shared.$generationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, self.isGenerateFlow else { return }
                switch state {
                case .complete:
                    Log.classroom.info("🎉 Progressive generation complete")
                    if let course = CourseGenerationService.shared.generatedCourse {
                        self.rebuildLessonFromProgressiveCourse(course)
                    }
                case .failed(let msg):
                    Log.classroom.error("🚨 Progressive generation failed: \(msg)")
                    self.errorMessage = msg
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    /// Observe scene-based classroom blocks from A2ACourseService
    private func observeSceneBlocks() {
        A2ACourseService.shared.sceneBlocksPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blocks in
                guard let self else { return }
                Log.classroom.info("🎬 Scene blocks received: \(blocks.count) blocks")
                self.lesson = LiveLesson(
                    courseId: self.lesson?.courseId ?? "scene",
                    lessonId: self.lesson?.lessonId ?? "scene_lesson",
                    title: self.lesson?.title ?? "Live Scene",
                    blocks: blocks
                )
                self.currentBlockIndex = 0
            }
            .store(in: &cancellables)
    }

    /// Rebuild lesson blocks from the progressive GeneratedCourse as modules arrive
    private func rebuildLessonFromProgressiveCourse(_ course: GeneratedCourse) {
        let readyModules = course.modules.filter {
            $0.state == .ready && ($0.lessons?.isEmpty == false)
        }

        let savedBlockIndex = currentBlockIndex
        var blocks: [LiveLessonBlock] = []

        for module in course.modules {
            switch module.state {
            case .ready:
                // Only show full content if we actually have lessons
                guard let lessons = module.lessons, !lessons.isEmpty else {
                    // Ready on server but no content fetched yet — show loading
                    blocks.append(
                        LiveLessonBlock(
                            id: "loading_\(module.index)",
                            type: .paragraph,
                            title: "⏳ \(module.title)",
                            content: "Loading module content..."
                        ))
                    continue
                }

                // Module intro — use hook if available, otherwise engaging header
                let hookText = module.hook ?? module.summary ?? module.title
                blocks.append(
                    LiveLessonBlock(
                        id: "mod_header_\(module.index)",
                        type: .hook,
                        title: module.title,
                        subtitle: "Module \(module.index + 1)",
                        lyoCommentary: hookText,
                        mood: "enthusiastic"
                    ))

                for lesson in lessons {
                    // Parse lesson content into rich typed blocks
                    let contentBlocks = Self.parseMarkdownIntoBlocks(
                        lessonId: lesson.id,
                        title: lesson.title,
                        content: lesson.content ?? lesson.summary ?? ""
                    )
                    blocks.append(contentsOf: contentBlocks)

                    // Add quiz for this lesson (if available from backend)
                    if let quiz = lesson.quiz {
                        // Quiz transition — give the user a breather
                        blocks.append(
                            LiveLessonBlock(
                                id: "quiz_intro_\(lesson.id)",
                                type: .revelation,
                                title: "Quick Check ✨",
                                content:
                                    "Let's see what you picked up from \(lesson.title ?? "this lesson"). No pressure — this is just to help it stick!",
                                mood: "encouraging"
                            ))
                        // The actual quiz
                        blocks.append(
                            LiveLessonBlock(
                                id: "quiz_\(lesson.id)",
                                type: .quizMcq,
                                question: quiz.question,
                                options: quiz.options,
                                correctIndex: quiz.correctIndex,
                                explanation: quiz.explanation
                            ))
                    }
                }

                blocks.append(
                    LiveLessonBlock(
                        id: "check_mod_\(module.index)",
                        type: .celebration,
                        title: "Module Complete! 🎉",
                        content:
                            "You've finished \(module.title). That's real progress — let's keep going!"
                    ))
            case .building:
                blocks.append(
                    LiveLessonBlock(
                        id: "building_\(module.index)",
                        type: .paragraph,
                        title: "⏳ \(module.title)",
                        content:
                            "This module is being created by AI right now. It will appear here momentarily..."
                    ))
            case .locked:
                blocks.append(
                    LiveLessonBlock(
                        id: "locked_\(module.index)",
                        type: .paragraph,
                        title: "🔒 \(module.title)",
                        content: "Coming up next"
                    ))
            case .failed:
                blocks.append(
                    LiveLessonBlock(
                        id: "failed_\(module.index)",
                        type: .paragraph,
                        title: "⚠️ \(module.title)",
                        content: "This module could not be generated. Tap to retry."
                    ))
            }
        }

        // Add final summary only when all modules are done
        let allDone = course.modules.allSatisfy { $0.state == .ready || $0.state == .failed }
        if allDone {
            blocks.append(
                LiveLessonBlock(
                    id: "final_summary",
                    type: .celebration,
                    title: "🎉 Course Complete!",
                    content:
                        "Congratulations! You've completed '\(course.title)'. You covered \(course.modules.count) modules. Time to put it all into practice!"
                ))
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            self.lesson = LiveLesson(
                courseId: self.lesson?.courseId ?? course.id,
                lessonId: self.lesson?.lessonId ?? "progressive",
                title: course.title,
                subtitle: "Interactive Course",
                blocks: blocks
            )
            self.currentBlockIndex = min(savedBlockIndex, max(0, blocks.count - 1))
        }

        Log.classroom.info(
            "✅ Progressive rebuild: \(blocks.count) blocks (\(readyModules.count) ready modules, was at block \(savedBlockIndex))"
        )
    }

    // MARK: - Markdown Content Parser

    /// Parses markdown lesson content into multiple typed LiveLessonBlocks.
    /// Transforms a wall of text into digestible, visually varied cards.
    static func parseMarkdownIntoBlocks(lessonId: String, title: String?, content: String)
        -> [LiveLessonBlock]
    {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var blocks: [LiveLessonBlock] = []
        let lines = content.components(separatedBy: "\n")
        var currentParagraph: [String] = []
        var blockIndex = 0

        func nextId(_ suffix: String) -> String {
            blockIndex += 1
            return "\(lessonId)_\(suffix)\(blockIndex)"
        }

        func flushParagraph() {
            let text = currentParagraph.joined(separator: "\n").trimmingCharacters(
                in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("p"),
                        type: .paragraph,
                        content: text
                    ))
            }
            currentParagraph = []
        }

        // Add lesson title as a heading block
        if let title = title, !title.isEmpty {
            blocks.append(
                LiveLessonBlock(
                    id: nextId("title"),
                    type: .heading,
                    title: title,
                    subtitle: "h2"
                ))
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // --- Headings ---
            if trimmed.hasPrefix("### ") {
                flushParagraph()
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("h"),
                        type: .heading,
                        title: String(trimmed.dropFirst(4)),
                        subtitle: "h3"
                    ))
                i += 1
                continue
            }
            if trimmed.hasPrefix("## ") {
                flushParagraph()
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("h"),
                        type: .heading,
                        title: String(trimmed.dropFirst(3)),
                        subtitle: "h2"
                    ))
                i += 1
                continue
            }
            if trimmed.hasPrefix("# ") {
                flushParagraph()
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("h"),
                        type: .heading,
                        title: String(trimmed.dropFirst(2)),
                        subtitle: "h1"
                    ))
                i += 1
                continue
            }

            // --- Code blocks ---
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count
                    && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```")
                {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }  // skip closing ```
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("code"),
                        type: .code,
                        code: codeLines.joined(separator: "\n"),
                        language: lang.isEmpty ? nil : lang
                    ))
                continue
            }

            // --- Blockquotes / Callouts ---
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                var calloutLines: [String] = [String(trimmed.dropFirst(2))]
                i += 1
                while i < lines.count {
                    let nextTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.hasPrefix("> ") {
                        calloutLines.append(String(nextTrimmed.dropFirst(2)))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("callout"),
                        type: .callout,
                        content: calloutLines.joined(separator: "\n")
                    ))
                continue
            }

            // --- Numbered lists (step-by-step) ---
            if trimmed.count > 2,
                let firstChar = trimmed.first, firstChar.isNumber,
                trimmed.dropFirst().hasPrefix(". ")
                    || (trimmed.count > 3
                        && trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)...].hasPrefix(
                            ". "))
            {
                flushParagraph()
                var stepLines: [String] = [trimmed]
                i += 1
                while i < lines.count {
                    let nextTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.isEmpty {
                        // Check if list continues after blank line
                        if i + 1 < lines.count {
                            let afterBlank = lines[i + 1].trimmingCharacters(in: .whitespaces)
                            if let fc = afterBlank.first, fc.isNumber, afterBlank.contains(". ") {
                                i += 1
                                continue
                            }
                        }
                        break
                    }
                    if let fc = nextTrimmed.first, fc.isNumber, nextTrimmed.contains(". ") {
                        stepLines.append(nextTrimmed)
                        i += 1
                    } else if nextTrimmed.hasPrefix("   ") || nextTrimmed.hasPrefix("-") {
                        // Continuation or sub-list
                        stepLines.append(nextTrimmed)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("steps"),
                        type: .stepByStep,
                        content: stepLines.joined(separator: "\n")
                    ))
                continue
            }

            // --- Bullet lists ---
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                var bulletLines: [String] = [trimmed]
                i += 1
                while i < lines.count {
                    let nextTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.hasPrefix("- ") || nextTrimmed.hasPrefix("* ")
                        || nextTrimmed.hasPrefix("  ")
                    {
                        bulletLines.append(nextTrimmed)
                        i += 1
                    } else if nextTrimmed.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(
                    LiveLessonBlock(
                        id: nextId("list"),
                        type: .paragraph,
                        content: bulletLines.joined(separator: "\n")
                    ))
                continue
            }

            // --- Horizontal rules ---
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                i += 1
                continue
            }

            // --- Empty lines flush paragraphs ---
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // --- Regular text ---
            currentParagraph.append(line)
            i += 1
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Public Methods

    /// Load a lesson by course and lesson ID
    func loadLesson(courseId: String, lessonId: String) async {
        guard let request = beginLessonLoad(courseId: courseId, lessonId: lessonId) else { return }
        let loadToken = request.token
        let loadKey = request.key
        defer { endLessonLoad(token: loadToken, key: loadKey) }

        isLoading = true
        errorMessage = nil

        // 🚀 GeneratedContentStore-first: serve cached content instantly
        let cacheKey = "\(courseId)_\(lessonId)"
        if let cached = contentStore.retrieve(id: cacheKey) {
            Log.classroom.info("⚡ Cache hit for \(courseId)/\(lessonId) — serving instantly")

            // If we have cached component JSON, we could use it in the future
            // For now, use the agent blocks or raw content to build the lesson
            if let agentBlocks = cached.agentBlocks, !agentBlocks.isEmpty {
                // FIX (cache-render): each agentBlock.content is a markdown
                // string. Previously we wrapped it in a single .text block,
                // so returning users with a populated GeneratedContentStore
                // saw literal '## Heading' / fenced code instead of rendered
                // blocks. Run each block through the canonical markdown
                // parser, except checkpoints which stay as quiz cards.
                var parsedBlocks: [LiveLessonBlock] = []
                for agentBlock in agentBlocks {
                    if agentBlock.blockType == .checkpoint {
                        parsedBlocks.append(
                            LiveLessonBlock(
                                id: agentBlock.id,
                                type: .quizMcq,
                                title: agentBlock.blockType.rawValue.capitalized,
                                content: agentBlock.content
                            ))
                        continue
                    }
                    let parsed = Self.parseMarkdownIntoBlocks(
                        lessonId: agentBlock.id,
                        title: nil,
                        content: agentBlock.content
                    )
                    if parsed.isEmpty {
                        // Fall back to wrapping the raw content rather than
                        // dropping the block entirely.
                        parsedBlocks.append(
                            LiveLessonBlock(
                                id: agentBlock.id,
                                type: .text,
                                title: agentBlock.blockType.rawValue.capitalized,
                                content: agentBlock.content
                            ))
                    } else {
                        parsedBlocks.append(contentsOf: parsed)
                    }
                }

                self.lesson = LiveLesson(
                    courseId: courseId,
                    lessonId: lessonId,
                    title: cached.title,
                    blocks: parsedBlocks
                )

                Log.classroom.info(
                    "⚡ Served \(parsedBlocks.count) parsed blocks from GeneratedContentStore (\(agentBlocks.count) agent blocks)"
                )

                if currentBlock != nil {
                    await speakCurrentBlock()
                }
                return
            }
        }

        // Check for Generated Course (mock_, gen_, etc.)
        // These courses were already generated and cached in CourseGenerationService
        if courseId.starts(with: "mock_") || courseId.starts(with: "gen_")
            || courseId.starts(with: "temp_")
        {
            Log.classroom.info("🎨 LiveClassroom: Loading generated course: \(courseId)")

            // Mark as generate flow to watch for hydration updates
            isGenerateFlow = true
            hasHydrationRefreshed = false

            // Capture the draft content hash before converting
            if let draft = CourseGenerationService.shared.generatedCourse {
                initialDraftContentHash =
                    draft.modules
                    .flatMap { ($0.lessons ?? []).compactMap { $0.content } }
                    .joined()
                    .hashValue
            }

            do {
                // Start playback from the cached/generated course
                let playbackState = try await cinemaService.startCourse(courseId: courseId)
                guard isActiveLessonLoad(token: loadToken, key: loadKey) else {
                    Log.classroom.info(
                        "LiveClassroom: Ignoring stale generated-course load for \(loadKey)")
                    return
                }
                currentCourseId = courseId

                // Convert PlaybackState to LiveLesson for compatibility
                self.lesson = convertPlaybackToLesson(
                    playbackState: playbackState,
                    courseTitle: playbackState.currentNode.title
                )

                Log.classroom.info(
                    "LiveClassroom: Loaded generated course with \(self.lesson?.blocks.count ?? 0) blocks"
                )

                // Restore resume position
                let resumeBlock = restoreResumePosition(for: courseId)
                if resumeBlock > 0, resumeBlock < (lesson?.totalBlocks ?? 0) {
                    currentBlockIndex = resumeBlock
                    Log.classroom.info("▶️ Resuming from block \(resumeBlock)")
                }

            } catch {
                Log.classroom.error(
                    "LiveClassroom: Failed to load generated course: \(error.localizedDescription)")
                if isActiveLessonLoad(token: loadToken, key: loadKey) {
                    errorMessage = "Failed to load course. Please try again."
                }
                return
            }

            if currentBlock != nil {
                await speakCurrentBlock()
            }
            return
        }

        // Check for Generation Request — PROGRESSIVE FLOW
        // Uses the new 3-phase approach: instant payload → engagement → polling
        if courseId.hasPrefix("GENERATE:") {
            let topic = String(courseId.dropFirst(9))

            Log.classroom.info(
                "🚀 LiveClassroom: Starting PROGRESSIVE course generation for: \(topic)")

            // Mark as generate flow so observers fire
            isGenerateFlow = true
            lastProgressiveFingerprint = ""

            // Phase A: startCourseGeneration returns in <5 seconds with instant payload
            // Phase C polling starts automatically inside CourseGenerationService
            await CourseGenerationService.shared.startCourseGeneration(topic: topic)

            guard isActiveLessonLoad(token: loadToken, key: loadKey) else {
                Log.classroom.info(
                    "LiveClassroom: Ignoring stale progressive generation for \(loadKey)")
                return
            }

            // Build initial lesson blocks from the instant payload (syllabus placeholders)
            if let instantCourse = CourseGenerationService.shared.generatedCourse {
                rebuildLessonFromProgressiveCourse(instantCourse)
                Log.classroom.info(
                    "📋 Instant payload displayed: \(instantCourse.modules.count) module placeholders"
                )
            } else {
                errorMessage = "Failed to start course generation"
            }

            // The progressive observer (observeProgressiveGeneration) will automatically
            // rebuild the lesson as each module flips to .ready state

            if currentBlock != nil {
                await speakCurrentBlock()
            }
            return
        }

        do {
            // Try to fetch from backend
            let fetchedLesson = try await apiClient.fetchLiveLesson(
                courseId: courseId, lessonId: lessonId)
            guard isActiveLessonLoad(token: loadToken, key: loadKey) else {
                Log.classroom.info("LiveClassroom: Ignoring stale backend lesson for \(loadKey)")
                return
            }
            lesson = fetchedLesson
        } catch {
            Log.classroom.error(
                "LiveClassroom: Failed to fetch lesson from API: \(error.localizedDescription)")

            // Surface the real error to user
            if error is CancellationError {
                Log.classroom.warning("LiveClassroom: lesson fetch cancelled")
                if recoverFromLatestGeneratedCourse(courseId: courseId, lessonId: lessonId) {
                    Log.classroom.info(
                        "LiveClassroom: Recovered cancelled fetch from local generated course")
                }
            } else if case APIError.unauthorized = error {
                if isActiveLessonLoad(token: loadToken, key: loadKey) {
                    errorMessage = "Please log in to access lessons"
                }
            } else {
                if isActiveLessonLoad(token: loadToken, key: loadKey) {
                    errorMessage = "Failed to load lesson. Please check your connection."
                }
            }
        }

        // Restore resume position for standard courses too
        let resumeBlock = restoreResumePosition(for: courseId)
        if resumeBlock > 0, resumeBlock < (lesson?.totalBlocks ?? 0) {
            currentBlockIndex = resumeBlock
            Log.classroom.info("▶️ Resuming from block \(resumeBlock)")
        }

        // Start speaking first block
        if currentBlock != nil {
            await speakCurrentBlock()
        }
    }

    /// Cache lesson content in GeneratedContentStore for instant re-access
    private func cacheLesson(_ lesson: LiveLesson, courseId: String, lessonId: String) {
        let entry = StoredContentEntry(
            id: "\(courseId)_\(lessonId)",
            courseId: courseId,
            lessonId: lessonId,
            title: lesson.title,
            content: lesson.blocks.compactMap { $0.content }.joined(separator: "\n\n"),
            agentBlocks: nil,
            smartBlocks: nil,
            createdAt: Date(),
            lastAccessedAt: Date(),
            metadata: nil
        )
        contentStore.store(entry)
        Log.classroom.info("💾 Cached lesson \(lessonId) in GeneratedContentStore")
    }

    /// Recover lesson blocks from the most recent generated course when network tasks are cancelled.
    @discardableResult
    private func recoverFromLatestGeneratedCourse(courseId: String, lessonId: String) -> Bool {
        guard let generated = CourseGenerationService.shared.generatedCourse,
            !generated.modules.isEmpty
        else {
            return false
        }

        let firstLessonId = generated.modules.first?.lessons?.first?.id ?? lessonId
        let playback = PlaybackState(
            courseId: generated.courseId,
            currentNodeId: firstLessonId,
            currentNode: LearningNodeWithAssets(
                id: firstLessonId,
                nodeType: "intro",
                title: generated.title,
                content: [:],
                orderIndex: 0,
                assets: nil
            ),
            nextNodes: [],
            completedNodes: [],
            progressPercent: 0.0,
            totalTimeSeconds: 0,
            canGoBack: false,
            isAtInteraction: false
        )

        self.lesson = convertPlaybackToLesson(
            playbackState: playback,
            courseTitle: generated.title
        )

        if let recoveredLesson = self.lesson {
            cacheLesson(recoveredLesson, courseId: courseId, lessonId: lessonId)
        }

        return self.lesson != nil
    }

    /// Move to the next block
    func advanceToNextBlock() {
        guard canAdvance, let lesson = lesson else { return }

        // Mark current block as completed
        if let block = currentBlock {
            completedBlocks.insert(block.id)

            // 🔥 BACKEND SYNC: Mark lesson progress
            Task {
                await syncProgressToBackend()
            }
        }

        // Reset quiz state
        resetQuizState()

        // Advance
        if currentBlockIndex < lesson.totalBlocks - 1 {
            currentBlockIndex += 1
            HapticManager.shared.light()

            // Save resume position so user can come back
            saveResumePosition()

            // Update UIStackStore progress for the Focus screen
            if let courseId = currentCourseId ?? self.lesson?.courseId {
                let progress = Double(currentBlockIndex + 1) / Double(lesson.totalBlocks)
                UIStackStore.shared.updateCourseProgress(
                    courseId: courseId,
                    progress: progress,
                    completedLessons: completedBlocks.count
                )
            }

            // Trigger "Next Topic" state safely
            setLioState(.thinking, duration: 1.5)

            // Update theme color based on progress (subtle shift)
            let progress = Double(currentBlockIndex) / Double(lesson.totalBlocks)
            if progress > 0.8 {
                currentThemeColor = .purple.opacity(0.8)  // Near completion
            } else if progress > 0.4 {
                currentThemeColor = .blue.opacity(0.8)  // Middle
            }

            // Speak new block
            Task {
                await speakCurrentBlock()

                // 🧠 Trigger Mastery Check occasionally
                if Int.random(in: 1...5) == 3 {
                    await triggerMasteryCheck()
                }
            }

            // 🔮 Personalization: fetch next recommended action after each block
            Task {
                await LyoAIViewModel.shared.fetchNextAction(
                    lessonId: lesson.lessonId,
                    currentSkill: lesson.title
                )
            }
        } else {
            // Lesson completed
            Task { await markLessonCompleted() }
        }
    }

    /// Move to the previous block
    func goToPreviousBlock() {
        guard !isFirstBlock else { return }

        resetQuizState()
        currentBlockIndex -= 1
        HapticManager.shared.light()
        saveResumePosition()

        // Trigger "Next Topic" state safely
        setLioState(.thinking, duration: 1.5)

        // Update theme color based on progress (subtle shift)
        let progress = Double(currentBlockIndex) / Double(lesson?.totalBlocks ?? 1)
        if progress > 0.8 {
            currentThemeColor = .purple.opacity(0.8)  // Near completion
        } else if progress > 0.4 {
            currentThemeColor = .blue.opacity(0.8)  // Middle
        }

        Task {
            await speakCurrentBlock()
        }
    }

    /// Submit a quiz answer
    func submitQuizAnswer(_ optionIndex: Int) {
        guard let block = currentBlock,
            block.type == .quizMcq
        else { return }

        selectedQuizOption = optionIndex
        quizSubmitted = true

        let isCorrect = optionIndex == block.correctIndex
        quizResults[block.id] = isCorrect

        // Report to Personalization Engine for Dynamic Remediation
        let result = CinemaInteraction(
            isCorrect: isCorrect,
            responseTime: 0,
            attempts: 1,
            metadata: [
                "blockId": block.id,
                "lessonId": lesson?.lessonId ?? "",
                "feedback": block.explanation ?? "",
            ]
        )
        LyoAIViewModel.shared.handleCinemaInteractionResult(result, nodeId: block.id)

        // 🧠 Trace knowledge mastery to personalization engine
        Task {
            if let learnerId = await TokenManager.shared.getUserId() {
                let trace = KnowledgeTraceRequest(
                    learnerId: learnerId,
                    skillId: lesson?.lessonId ?? "unknown_skill",
                    itemId: block.id,
                    correct: isCorrect,
                    timeTakenSeconds: max(
                        0.0,
                        quizStartedAt.map { Date().timeIntervalSince($0) } ?? 0.0
                    ),
                    hintsUsed: showingExplanation ? 1 : 0,
                    attemptNumber: 1
                )
                try? await PersonalizationService.shared.traceKnowledge(trace: trace)
            }
        }

        if isCorrect {
            HapticManager.shared.success()
            setLioState(.celebrating, duration: 3.0)
            // Add to transcript
            appendToTranscript(
                isUser: false, text: "✅ Correct! " + (block.explanation ?? "Great job!"))

            // 🔥 Close Mastery Check if active
            if isMasteryCheckActive {
                completeMasteryCheck(isCorrect: true)
            }
        } else {
            HapticManager.shared.medium()
            showingExplanation = true
            setLioState(.pondering, duration: 3.0)
            // Add explanation to transcript
            if let explanation = block.explanation {
                appendToTranscript(isUser: false, text: "❌ Not quite. \(explanation) Try again!")
            }

            // 🔥 Close Mastery Check if active (even on failure after one attempt for flow)
            if isMasteryCheckActive {
                completeMasteryCheck(isCorrect: false)
            }
        }
    }

    /// Retry a quiz (after wrong answer)
    func retryQuiz() {
        selectedQuizOption = nil
        quizSubmitted = false
        showingExplanation = false
        HapticManager.shared.light()
        lioState = .idle  // Reset Lio's state after retry
    }

    /// Send a sentiment signal
    func sendSentimentSignal(_ signal: SentimentSignal) {
        HapticManager.shared.medium()

        appendToTranscript(isUser: true, text: signal.displayLabel)

        Task {
            await handleSentimentSignal(signal)
        }
    }

    /// Ask a question
    func askQuestion(_ question: String) async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isProcessingQuestion = true
        setLioState(.thinking)  // Long-running, no auto-reset until response
        appendToTranscript(isUser: true, text: question)

        // Get AI response
        do {
            let contextPrompt = buildQuestionContext()
            let fullQuestion = "\(contextPrompt)\n\nUser question: \(question)"
            let response = try await openAIService.sendMessage(
                message: fullQuestion
            )
            appendToTranscript(isUser: false, text: response)

            // Speak the AI response using Neural TTS
            isProcessingQuestion = false
            showAskQuestionSheet = false

            try await speakText(response, type: .explanation)

        } catch {
            appendToTranscript(
                isUser: false,
                text: "I'm having trouble answering that right now. Let's continue with the lesson."
            )
            setLioState(.confused, duration: 2.0)
            isProcessingQuestion = false
        }
    }

    // MARK: - Mastery Check

    private func triggerMasteryCheck() async {
        guard let memory = SmartMemoryService.shared.memory,
            let struggle = memory.struggles.filter({ !$0.resolved }).randomElement()
        else {
            return
        }

        Log.classroom.info("Triggering Mastery Check for: \(struggle.topic)")
        setLioState(.pondering)

        // Randomize quiz type (weighted towards MCQ for safety, but includes variety)
        let quizType =
            [LessonBlockType.quizMcq, .quizMcq, .quizTrueFalse, .quizFillBlank].randomElement()
            ?? .quizMcq

        do {
            let prompt: String
            switch quizType {
            case .quizTrueFalse:
                prompt =
                    "Generate a single True/False question to test if a user understands '\(struggle.topic)'. Return only a JSON object with keys: 'question' (statement), 'correct_answer' ('True' or 'False'), 'explanation'."
            case .quizFillBlank:
                prompt =
                    "Generate a single Fill-in-the-Blank question to test if a user understands '\(struggle.topic)'. Return only a JSON object with keys: 'question' (sentence with a blank ____), 'correct_answer' (word/phrase to fill), 'explanation'."
            default:  // MCQ
                prompt =
                    "Generate a single multiple-choice question to test if a user has mastered '\(struggle.topic)'. Return only a JSON object with keys: 'question', 'options' (array of 4), 'correct_index' (0-3), and 'explanation'."
            }

            let response = try await openAIService.sendMessage(message: prompt)

            // Basic extraction
            if let data = response.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let question = json["question"] as? String,
                let explanation = json["explanation"] as? String
            {

                var block = LiveLessonBlock(
                    id: "mastery_\(UUID().uuidString)",
                    type: quizType,
                    title: "🧠 Mastery Check: \(struggle.topic)",
                    content: question,
                    explanation: explanation
                )

                // Parse specific fields based on type
                if quizType == .quizMcq,
                    let options = json["options"] as? [String],
                    let correctIndex = json["correct_index"] as? Int
                {
                    block = LiveLessonBlock(
                        id: block.id,
                        type: quizType,
                        title: block.title,
                        content: question,
                        options: options,
                        correctIndex: correctIndex,
                        explanation: explanation
                    )
                } else if quizType == .quizTrueFalse || quizType == .quizFillBlank,
                    let correctAnswer = json["correct_answer"] as? String
                {
                    block = LiveLessonBlock(
                        id: block.id,
                        type: quizType,
                        title: block.title,
                        content: question,
                        correctAnswer: correctAnswer,
                        explanation: explanation
                    )
                }

                withAnimation {
                    self.masteryCheckBlock = block
                    self.isMasteryCheckActive = true
                    self.quizStartedAt = Date()
                }

                let introText =
                    "Hey! Before we continue, let's see if you remember '\(struggle.topic)'..."
                appendToTranscript(isUser: false, text: introText)
                try await speakText(introText, type: .question)
            }
        } catch {
            Log.classroom.warning("Failed to generate mastery check: \(error)")
            setLioState(.confused, duration: 2.0)
        }

        // Return to idle after a short delay if not speaking
        if lioState != .speaking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.lioState = .idle
            }
        }
    }

    func completeMasteryCheck(isCorrect: Bool) {
        withAnimation {
            self.isMasteryCheckActive = false
            self.masteryCheckBlock = nil
        }

        let text =
            isCorrect
            ? "Excellent! You've clearly mastered that. Let's get back to our lesson."
            : "No worries, we'll keep practicing that topic later! Back to the lesson."
        appendToTranscript(isUser: false, text: text)

        Task {
            try? await speakText(text, type: .feedback)
        }

        setLioState(isCorrect ? .celebrating : .pondering, duration: 2.5)
    }

    // MARK: - Private Methods

    private func resetQuizState() {
        selectedQuizOption = nil
        quizSubmitted = false
        showingExplanation = false
        quizStartedAt = nil
        setLioState(.idle)
    }

    private func speakCurrentBlock() async {
        guard let block = currentBlock else { return }

        // Start the quiz timer the moment the user first sees the quiz.
        if block.type == .quizMcq, quizStartedAt == nil {
            quizStartedAt = Date()
        }

        // Stop any existing playback
        audioPlayer?.pause()

        // Determine text to speak based on block type
        let textToSpeak: String
        let voiceType: TTSVoiceType

        switch block.type {
        case .text, .paragraph:
            textToSpeak = block.safeContent
            voiceType = .explanation
        case .heading:
            textToSpeak = "Next up: \(block.safeTitle). " + block.safeContent
            voiceType = .narrative
        case .callout:
            textToSpeak = block.safeContent
            voiceType = .highlight
        case .image:
            textToSpeak = block.title ?? "Take a look at this visual."
            voiceType = .narrative
        case .video:
            textToSpeak = "Watch this video to learn more."
            voiceType = .narrative
        case .quiz, .quizMcq:
            textToSpeak = "Quick check! \(block.question ?? block.title ?? "")"
            voiceType = .question
        case .code:
            textToSpeak = "Here's a code snippet in \(block.language ?? "code"). Listen closely."
            voiceType = .technical
        case .summary:
            textToSpeak = "Let's recap what we've learned today."
            voiceType = .summary
        default:
            textToSpeak = block.safeContent
            voiceType = .explanation
        }

        guard !textToSpeak.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        appendToTranscript(isUser: false, text: textToSpeak)

        do {
            try await speakText(textToSpeak, type: voiceType)
        } catch {
            Log.classroom.error("Failed to speak block: \(error)")
            // Fallback to idle if speech fails
            setLioState(.idle)
        }

        // After speaking, go back to idle or listening (if we implement conversational mode fully)
        setLioState(.idle)
    }

    // MARK: - TTS Markdown Sanitizer

    /// Strips markdown syntax that would be read aloud literally by TTS (e.g. "hashtag hashtag", "asterisk asterisk")
    private func sanitizeForTTS(_ raw: String) -> String {
        var clean = raw
        // Remove heading markers (###, ##, #)
        clean = clean.replacingOccurrences(of: #"#{1,6}\s*"#, with: "", options: .regularExpression)
        // Un-bold/un-italic: **text** -> text, *text* -> text, __text__ -> text
        clean = clean.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(
            of: #"__(.+?)__"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(
            of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"_(.+?)_"#, with: "$1", options: .regularExpression)
        // Remove inline code backticks: `code` -> code
        clean = clean.replacingOccurrences(of: #"`(.+?)`"#, with: "$1", options: .regularExpression)
        // Remove code fences
        clean = clean.replacingOccurrences(
            of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        // Remove markdown links: [text](url) -> text
        clean = clean.replacingOccurrences(
            of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)
        // Collapse multiple newlines to a single space for natural speech flow
        clean = clean.replacingOccurrences(of: #"\n+"#, with: " ", options: .regularExpression)
        // Remove bullet markers (-, *, +) at line starts
        clean = clean.replacingOccurrences(
            of: #"(?m)^[\-\*\+]\s+"#, with: "", options: .regularExpression)
        // Remove numbered list markers (1., 2., etc.)
        clean = clean.replacingOccurrences(
            of: #"(?m)^\d+\.\s+"#, with: "", options: .regularExpression)
        // Collapse multiple spaces
        clean = clean.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Helper to synthesize and play text using Backend Neural TTS
    /// - Parameters:
    ///   - text: The text to speak
    ///   - type: Context for voice selection (optional future enhancement)
    private func speakText(_ text: String, type: TTSVoiceType = .explanation) async throws {
        isLioSpeaking = true
        lioState = .speaking

        // 1. Sanitize markdown so TTS doesn't read "hashtag hashtag" or "asterisk asterisk"
        let cleanText = sanitizeForTTS(text)
        guard !cleanText.isEmpty else {
            Log.app.warning("⚡️ speakText: sanitized text is empty, skipping TTS")
            isLioSpeaking = false
            lioState = .idle
            return
        }

        // 2. Generate Audio via Backend
        // 'nova' is a great energetic voice for Lio. 'alloy' is good for neutral.
        let voice: TTSVoice = .nova

        let result = try await ttsRepository.generate(
            text: cleanText,
            voice: voice,
            speed: 1.0,  // Normal speed for clarity
            withTimings: false  // We don't need word timings yet
        )

        guard let url = URL(string: result.audioURL) else {
            throw LyoError.network(.invalidURL)
        }

        // 2. Play Audio via AVPlayer
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.audioPlayer = player

        // Play and wait for completion
        player.play()

        // Wait for playback to finish
        // We use a continuation to bridge the notification to async/await
        await withCheckedContinuation { continuation in
            _ = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                continuation.resume()
            }

            // Store observation token if needed, or rely on the single-fire nature here
            // For robustness, we could use a stored cancellable in a real app
        }

        isLioSpeaking = false
    }

    // Enum to help categorize speech context (for future voice variations)
    private enum TTSVoiceType {
        case narrative
        case explanation
        case question
        case technical
        case highlight
        case summary
        case feedback
    }

    private func handleSentimentSignal(_ signal: SentimentSignal) async {
        isLioSpeaking = true
        lioState = .speaking

        switch signal {
        case .confused:
            appendToTranscript(
                isUser: false, text: "No worries! Let me explain that differently...")
            setLioState(.pondering)
            // Actually re-explain via AI
            if let block = currentBlock {
                do {
                    let prompt =
                        "The student is confused about the following content. Re-explain it in simpler terms with an analogy:\n\n\(block.safeContent)"
                    let explanation = try await openAIService.sendMessage(message: prompt)
                    appendToTranscript(isUser: false, text: explanation)
                    setLioState(.speaking, duration: 3.0)
                } catch {
                    appendToTranscript(
                        isUser: false, text: "Let me try again: \(block.safeContent)")
                    setLioState(.idle)
                }
            }

        case .slower:
            appendToTranscript(
                isUser: false, text: "I'll slow down. Take your time with this concept.")
            // Re-read the current block content for emphasis
            if let block = currentBlock {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                appendToTranscript(isUser: false, text: "📝 Key point: \(block.safeContent)")
            }

        case .tooEasy:
            appendToTranscript(isUser: false, text: "Got it! Let's skip ahead.")
            // Actually advance to the next block
            advanceToNextBlock()

        case .quizMe:
            appendToTranscript(isUser: false, text: "Sure! Let me quiz you on what we've covered.")
            setLioState(.thinking)
            // Trigger a real mastery check
            await triggerMasteryCheck()
        }

        isLioSpeaking = false
    }

    private func appendToTranscript(isUser: Bool, text: String) {
        let turn = TranscriptMessage(isUser: isUser, text: text)
        transcript.append(turn)
    }

    private func buildQuestionContext() -> String {
        guard let lesson = lesson, let block = currentBlock else {
            return ""
        }

        return """
            Course: \(lesson.courseId)
            Lesson: \(lesson.title)
            Current topic: \(block.title ?? "General")
            Content: \(block.body ?? "")
            """
    }

    private func generateMockLesson(courseId: String, lessonId: String) async {
        // Generate a sample lesson for demo purposes
        let blocks: [LiveLessonBlock] = [
            LiveLessonBlock(
                type: .paragraph,
                title: "Introduction",
                content:
                    "Welcome to this lesson! Today we'll explore the fundamentals of this topic. By the end, you'll have a solid understanding of the key concepts."
            ),
            LiveLessonBlock(
                type: .paragraph,
                title: "Core Concept",
                content:
                    "The main idea here is that understanding the basics deeply allows you to build more complex knowledge on top. Think of it like building blocks."
            ),
            LiveLessonBlock(
                type: .image,
                title: "Visual Diagram",
                content: "This diagram shows how the concepts connect together.",
                imageURL: nil
            ),
            LiveLessonBlock(
                type: .code,
                title: "Worked Example",
                content:
                    "Let's work through a practical example. Suppose we have a scenario where... By applying what we learned, we can solve it step by step."
            ),
            LiveLessonBlock(
                type: .quizMcq,
                title: "What is the main benefit of understanding fundamentals?",
                options: [
                    "It's easier to memorize",
                    "You can build complex knowledge on top",
                    "It takes less time",
                    "You don't need practice",
                ],
                correctIndex: 1,
                explanation:
                    "Understanding fundamentals provides a solid foundation that allows you to build more complex knowledge. It's like building blocks - the stronger the base, the higher you can build."
            ),
            LiveLessonBlock(
                type: .summary,
                title: "Key Takeaways",
                content:
                    "Today we covered: 1) The importance of fundamentals, 2) How concepts connect together, 3) A practical example, and 4) Tested your understanding. Great job completing this lesson!"
            ),
        ]

        lesson = LiveLesson(
            courseId: courseId,
            lessonId: lessonId,
            title: "Understanding the Basics",
            subtitle: "Building a strong foundation",
            blocks: blocks,
            estimatedDuration: 10
        )
    }

    // MARK: - Helper: Convert PlaybackState to LiveLesson (for compatibility)

    // MARK: - Backend Progress Sync

    /// Sync progress to backend (called on each block completion)
    private func syncProgressToBackend() async {
        guard let lesson = lesson else { return }

        // Fix 404: Do not sync progress for mock or temp (shell) courses
        // But DO save progress locally so it persists across app restarts
        if lesson.courseId.hasPrefix("mock_") || lesson.courseId.hasPrefix("temp_")
            || lesson.courseId.hasPrefix("gen_")
        {
            Log.classroom.info("Saving progress locally for generated course: \(lesson.courseId)")
            let progress = LessonProgress(
                lessonId: lesson.lessonId,
                moduleProgress: [:],
                overallProgress: Double(completedBlocks.count) / Double(max(lesson.totalBlocks, 1)),
                startedAt: Date(),
                lastAccessedAt: Date(),
                completedAt: nil
            )
            // Persist to UserDefaults so progress survives app close
            if let data = try? JSONEncoder().encode(progress) {
                UserDefaults.standard.set(data, forKey: "lesson_progress_\(lesson.lessonId)")
            }
            return
        }

        // Calculate overall progress as percentage
        let overallProgress = Double(completedBlocks.count) / Double(max(lesson.totalBlocks, 1))

        do {
            // Use simplified progress tracking - the repository handles the actual format
            try await repository.saveClassroomProgress(
                sessionId: lesson.lessonId,
                progress: LessonProgress(
                    lessonId: lesson.lessonId,
                    moduleProgress: [:],  // Not using module-based tracking
                    overallProgress: overallProgress,
                    startedAt: Date(),
                    lastAccessedAt: Date(),
                    completedAt: nil
                )
            )
            Log.classroom.info(
                "Synced progress to backend: \(self.completedBlocks.count)/\(lesson.totalBlocks) blocks"
            )
        } catch {
            Log.classroom.warning("Failed to sync progress: \(error.localizedDescription)")
            // Don't show error to user - continue with local tracking
        }
    }

    /// Mark lesson as completed (called when reaching final block)
    private func markLessonCompleted() async {
        guard let lesson = lesson else { return }

        Log.classroom.info("🎉 Lesson Completed!")

        // Update UI
        await MainActor.run {
            withAnimation { isLessonComplete = true }
        }

        // Clear resume position — course is done
        if let courseId = currentCourseId ?? self.lesson?.courseId {
            UserDefaults.standard.removeObject(forKey: resumeKey(for: courseId))
            UIStackStore.shared.updateCourseProgress(
                courseId: courseId,
                progress: 1.0,
                completedLessons: completedBlocks.count
            )
        }

        // Show completion celebration
        await MainActor.run {
            appendToTranscript(isUser: false, text: "🎉 Lesson Complete! Great work!")
            setLioState(.celebrating, duration: 5.0)
            HapticManager.shared.success()
        }

        // If lesson from generated course, trigger next lesson

        // Mark complete in backend (include score if we have quiz results)
        let totalQuizzes = quizResults.count
        let correctQuizzes = quizResults.values.filter { $0 }.count
        if totalQuizzes > 0 {
            let score = Int((Double(correctQuizzes) / Double(totalQuizzes)) * 100)
            do {
                _ = try await repository.markLessonComplete(lessonId: lesson.lessonId, score: score)
            } catch {
                Log.classroom.error("Failed to mark lesson as complete: \(error)")
            }
        } else {
            do {
                _ = try await repository.markLessonComplete(lessonId: lesson.lessonId)
            } catch {
                Log.classroom.error("Failed to mark lesson as complete: \(error)")
            }
        }
    }

    // MARK: - Lesson/Module Navigation

    /// Move to the next lesson in the course
    func moveToNextLesson() {
        guard let generatedCourse = CourseGenerationService.shared.generatedCourse else {
            Log.classroom.warning("No generated course available")
            return
        }

        guard let currentLesson = lesson else {
            Log.classroom.warning("No current lesson")
            return
        }

        Log.classroom.debug("Looking for next lesson after: \(currentLesson.lessonId)")

        // Find current lesson position in course structure
        var foundCurrent = false

        for module in generatedCourse.modules {
            let moduleLessons = module.lessons ?? []
            for (index, courseLesson) in moduleLessons.enumerated() {
                if foundCurrent {
                    // This is the next lesson!
                    Log.classroom.info("Found next lesson: \(courseLesson.title ?? "Untitled")")
                    loadLessonFromGenerated(courseLesson, moduleTitle: module.title)
                    return
                }

                if courseLesson.id == currentLesson.lessonId {
                    foundCurrent = true
                    Log.classroom.info(
                        "📍 Found current lesson at module: \(module.title), lesson index: \(index)")
                    // Check if there's a next lesson in this module
                    if index + 1 < moduleLessons.count {
                        let nextLesson = moduleLessons[index + 1]
                        Log.classroom.info(
                            "Next lesson in same module: \(nextLesson.title ?? "Untitled")")
                        loadLessonFromGenerated(nextLesson, moduleTitle: module.title)
                        return
                    }
                }
            }
        }

        // No more lessons - course complete!
        Log.classroom.info("All lessons completed!")
        showCourseCompletion()
    }

    /// Load a lesson from the generated course
    private func loadLessonFromGenerated(_ courseLesson: ProgressiveLesson, moduleTitle: String) {
        Log.classroom.info("📚 Loading lesson: \(courseLesson.title ?? "Untitled")")

        // Reset state
        currentBlockIndex = 0
        completedBlocks.removeAll()
        quizResults.removeAll()
        transcript.removeAll()
        resetQuizState()

        // Lio is thinking while loading the next lesson
        setLioState(.thinking)

        // Convert to LiveLesson
        let liveLesson = CourseGenerationService.shared.createLiveLessonFromGenerated(
            lesson: courseLesson,
            moduleTitle: moduleTitle
        )

        lesson = liveLesson

        // Speak first block
        Task {
            await speakCurrentBlock()
        }
    }

    /// Show course completion celebration
    private func showCourseCompletion() {
        appendToTranscript(
            isUser: false,
            text: """
                🎉 **Congratulations!**

                You've completed the entire course!

                🌟 Amazing dedication and effort
                📚 New knowledge acquired
                🚀 Ready for your next challenge

                Keep up the great work!
                """)
        setLioState(.celebrating, duration: 5.0)

        // Optionally dismiss classroom or show completion screen
        Log.classroom.info("Course completion celebration triggered")

        // Could navigate back to course library or show achievements
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.lioState = .idle
        }
    }

    private func convertPlaybackToLesson(playbackState: PlaybackState, courseTitle: String)
        -> LiveLesson
    {
        var blocks: [LiveLessonBlock] = []

        // STEP 1: Check if we have a generated course in cache with FULL content
        // This is the key fix - use the FULL generated course, not just playback nodes
        if let generatedCourse = CourseGenerationService.shared.generatedCourse {
            Log.classroom.info(
                "🎬 Converting FULL generated course to LiveLesson: \(generatedCourse.title)")
            Log.classroom.info("   Modules: \(generatedCourse.modules.count)")

            // Iterate through ALL modules and lessons
            for (moduleIndex, module) in generatedCourse.modules.enumerated() {
                // Module intro — use hook for engaging, topic-specific intro
                let hookText = module.hook ?? module.summary ?? module.description
                blocks.append(
                    LiveLessonBlock(
                        id: "mod_header_\(moduleIndex)",
                        type: .hook,
                        title: module.title,
                        subtitle: "Module \(moduleIndex + 1)",
                        lyoCommentary: hookText,
                        mood: "enthusiastic"
                    ))

                for lesson in module.lessons ?? [] {
                    // Parse lesson markdown content into rich typed blocks
                    let contentBlocks = Self.parseMarkdownIntoBlocks(
                        lessonId: lesson.id,
                        title: lesson.title,
                        content: lesson.content ?? ""
                    )
                    blocks.append(contentsOf: contentBlocks)

                    // Add quiz for this lesson (if available)
                    if let quiz = lesson.quiz {
                        blocks.append(
                            LiveLessonBlock(
                                id: "quiz_intro_\(lesson.id)",
                                type: .revelation,
                                title: "Quick Check ✨",
                                content:
                                    "Let's see what you picked up from \(lesson.title ?? "this lesson"). No pressure — this is just to help it stick!",
                                mood: "encouraging"
                            ))
                        blocks.append(
                            LiveLessonBlock(
                                id: "quiz_\(lesson.id)",
                                type: .quizMcq,
                                question: quiz.question,
                                options: quiz.options,
                                correctIndex: quiz.correctIndex,
                                explanation: quiz.explanation
                            ))
                    }
                }

                // Module completion
                blocks.append(
                    LiveLessonBlock(
                        id: "check_mod_\(moduleIndex)",
                        type: .celebration,
                        title: "Module Complete! 🎉",
                        content:
                            "You've finished \(module.title) with \(module.lessons?.count ?? 0) lessons. That's real progress!"
                    ))
            }

            // Add final summary
            blocks.append(
                LiveLessonBlock(
                    id: "final_summary",
                    type: .summary,
                    title: "🎉 Course Complete!",
                    content:
                        "Congratulations! You've completed '\(generatedCourse.title)'. You covered \(generatedCourse.modules.count) modules and learned the fundamentals. Keep practicing!"
                ))

            Log.classroom.info("Created \(blocks.count) blocks from generated course")

            return LiveLesson(
                courseId: playbackState.courseId,
                lessonId: generatedCourse.modules.first?.lessons?.first?.id ?? "generated",
                title: courseTitle,
                subtitle: "Interactive Course",
                blocks: blocks,
                estimatedDuration: generatedCourse.estimatedDuration
            )
        }

        // FALLBACK: Extract from playback state nodes (limited content)
        Log.classroom.warning("No cached generated course, using playback nodes")

        let currentNode = playbackState.currentNode
        let content = currentNode.content

        // Current node content
        if let text = content["text"]?.value as? String, !text.isEmpty {
            blocks.append(
                LiveLessonBlock(
                    id: currentNode.id,
                    type: .paragraph,
                    title: content["title"]?.value as? String ?? currentNode.title,
                    content: text
                ))
        } else if let narration = content["narration"]?.value as? String {
            blocks.append(
                LiveLessonBlock(
                    id: currentNode.id,
                    type: .paragraph,
                    title: currentNode.title,
                    content: narration
                ))
        } else if currentNode.nodeType == "interaction",
            let prompt = content["prompt"]?.value as? String,
            let optionsArray = content["options"]?.value as? [[String: Any]]
        {
            let optionLabels = optionsArray.compactMap { $0["label"] as? String }
            let correctIdx = optionsArray.firstIndex { ($0["is_correct"] as? Bool) == true }
            let explanation = content["explanation"]?.value as? String

            blocks.append(
                LiveLessonBlock(
                    id: currentNode.id,
                    type: .quizMcq,
                    title: prompt,
                    options: optionLabels,
                    correctIndex: correctIdx,
                    explanation: explanation
                ))
        }

        // Add FULL content from nextNodes (not just placeholders)
        for nextNode in playbackState.nextNodes {
            let nodeContent = nextNode.content

            // Map the generic node type to our LessonBlockType
            let blockType: LessonBlockType
            switch nextNode.nodeType {
            case "heading": blockType = .heading
            case "image": blockType = .image
            case "code": blockType = .code
            case "quiz", "interaction": blockType = .quizMcq
            case "callout": blockType = .callout
            case "summary": blockType = .summary
            case "video": blockType = .video
            default: blockType = .paragraph
            }

            if nextNode.nodeType == "interaction" || nextNode.nodeType == "quiz",
                let prompt = nodeContent["prompt"]?.value as? String,
                let optionsArray = nodeContent["options"]?.value as? [[String: Any]]
            {

                let optionLabels = optionsArray.compactMap { $0["label"] as? String }
                let correctIdx = optionsArray.firstIndex { ($0["is_correct"] as? Bool) == true }
                let explanation = nodeContent["explanation"]?.value as? String

                blocks.append(
                    LiveLessonBlock(
                        id: nextNode.id,
                        type: .quizMcq,
                        title: prompt,
                        options: optionLabels,
                        correctIndex: correctIdx,
                        explanation: explanation
                    ))
            } else if let text = nodeContent["text"]?.value as? String, !text.isEmpty {
                blocks.append(
                    LiveLessonBlock(
                        id: nextNode.id,
                        type: blockType,
                        title: nodeContent["title"]?.value as? String ?? nextNode.title,
                        content: text,
                        imageURL: (nodeContent["imageUrl"]?.value as? String).flatMap {
                            URL(string: $0)
                        },
                        language: nodeContent["language"]?.value as? String
                    ))
            } else if let narration = nodeContent["narration"]?.value as? String {
                blocks.append(
                    LiveLessonBlock(
                        id: nextNode.id,
                        type: blockType,
                        title: nextNode.title,
                        content: narration
                    ))
            }
        }

        // Add a completion block if we have content
        if !blocks.isEmpty {
            blocks.append(
                LiveLessonBlock(
                    id: "completion",
                    type: .summary,
                    title: "Lesson Complete",
                    content: "Great job completing this lesson! You're making excellent progress."
                ))
        }

        return LiveLesson(
            courseId: playbackState.courseId,
            lessonId: currentNode.id,
            title: courseTitle,
            subtitle: "Interactive Cinema Experience",
            blocks: blocks.isEmpty
                ? [
                    LiveLessonBlock(
                        id: "empty", type: .paragraph, title: "Loading...",
                        content: "Please wait while we prepare your lesson.")
                ] : blocks,
            estimatedDuration: 15
        )
    }

    // MARK: - Magical UX Management

    private func setLioState(_ state: LioState, duration: TimeInterval? = nil) {
        lioStateTask?.cancel()
        lioState = state

        if let duration = duration {
            lioStateTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                if !Task.isCancelled {
                    // Only return to idle if we aren't currently speaking
                    if !isLioSpeaking {
                        withAnimation {
                            lioState = .idle
                        }
                    }
                }
            }
        }
    }
}

// MARK: - TTS Completion Helper

/// Lightweight delegate that calls a closure when speech finishes.
/// Used by LiveClassroomViewModel for async/await TTS integration.
/// Thread-safe: guarantees the continuation is resumed exactly once.
private class SpeechCompletionDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: () -> Void
    /// Atomic flag: ensures we only call onFinish once, preventing double-resume crashes.
    private let hasResumed = OSAllocatedUnfairLock(initialState: false)

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    private func resumeOnce() {
        let alreadyResumed = hasResumed.withLock { done -> Bool in
            if done { return true }
            done = true
            return false
        }
        guard !alreadyResumed else { return }
        onFinish()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        resumeOnce()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
        resumeOnce()
    }
}
