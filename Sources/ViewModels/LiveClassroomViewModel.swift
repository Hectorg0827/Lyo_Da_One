import Foundation
import SwiftUI
import Combine
import AVFoundation
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
    @Published var masteryCheckBlock: LessonBlock?
    
    // Graph playback state (Interactive Cinema)
    @Published var playbackState: PlaybackState?
    
    // Quiz State
    @Published var selectedQuizOption: Int? = nil
    @Published var quizSubmitted: Bool = false
    @Published var showingExplanation: Bool = false
    
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
    
    var currentBlock: LessonBlock? {
        if isMasteryCheckActive {
            return masteryCheckBlock
        }
        
        guard let lesson = lesson,
              currentBlockIndex >= 0,
              currentBlockIndex < lesson.blocks.count else {
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
           let selected = selectedQuizOption {
            return selected == correctIndex
        }
        
        // Case 2: A2UI Quiz (Fallback for dynamic elements)
        if let a2ui = a2uiComponent,
           case .quiz(let quiz) = a2ui.payload,
           let selected = selectedQuizOption,
           selected < quiz.options.count {
            return selected == quiz.correctIndex
        }
        
        return false
    }
    
    // MARK: - Init
    
    init(openAIService: OpenAIService? = nil) {
        self.openAIService = openAIService ?? OpenAIService.shared
        
        // Setup audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Log.classroom.error("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Load a lesson by course and lesson ID
    func loadLesson(courseId: String, lessonId: String) async {
        isLoading = true
        errorMessage = nil
        
        // 🚀 GeneratedContentStore-first: serve cached content instantly
        let cacheKey = "\(courseId)_\(lessonId)"
        if let cached = contentStore.retrieve(id: cacheKey) {
            Log.classroom.info("⚡ Cache hit for \(courseId)/\(lessonId) — serving instantly")
            
            // If we have A2UI component JSON, we could use it in the future
            // For now, use the agent blocks or raw content to build the lesson
            if let agentBlocks = cached.agentBlocks, !agentBlocks.isEmpty {
                let blocks = agentBlocks.map { agentBlock in
                    LessonBlock(
                        id: agentBlock.id,
                        type: agentBlock.blockType == AgentBlockType.checkpoint ? .quizMcq : .text,
                        title: agentBlock.blockType.rawValue.capitalized,
                        content: agentBlock.content
                    )
                }
                
                self.lesson = LiveLesson(
                    courseId: courseId,
                    lessonId: lessonId,
                    title: cached.title,
                    blocks: blocks
                )
                
                isLoading = false
                Log.classroom.info("⚡ Served \(blocks.count) blocks from GeneratedContentStore")
                
                if currentBlock != nil {
                    await speakCurrentBlock()
                }
                return
            }
        }
        
        // Check for Generated Course (mock_, gen_, etc.)
        // These courses were already generated and cached in CourseGenerationService
        if courseId.starts(with: "mock_") || courseId.starts(with: "gen_") || courseId.starts(with: "temp_") {
            Log.classroom.info("🎨 LiveClassroom: Loading generated course: \(courseId)")
            
            do {
                // Start playback from the cached/generated course
                let playbackState = try await cinemaService.startCourse(courseId: courseId)
                currentCourseId = courseId
                
                // Convert PlaybackState to LiveLesson for compatibility
                self.lesson = convertPlaybackToLesson(
                    playbackState: playbackState,
                    courseTitle: playbackState.currentNode.title
                )
                
                Log.classroom.info("LiveClassroom: Loaded generated course with \(self.lesson?.blocks.count ?? 0) blocks")
                
                // Restore resume position
                let resumeBlock = restoreResumePosition(for: courseId)
                if resumeBlock > 0, resumeBlock < (lesson?.totalBlocks ?? 0) {
                    currentBlockIndex = resumeBlock
                    Log.classroom.info("▶️ Resuming from block \(resumeBlock)")
                }
                
            } catch {
                Log.classroom.error("LiveClassroom: Failed to load generated course: \(error.localizedDescription)")
                errorMessage = "Failed to load course. Please try again."
                isLoading = false
                return
            }
            
            isLoading = false
            if currentBlock != nil {
                await speakCurrentBlock()
            }
            return
        }
        
        // Check for Generation Request (Legacy support for GENERATE: prefix)
        if courseId.hasPrefix("GENERATE:") {
            let topic = String(courseId.dropFirst(9))
            
            //  FIX: Always generate FULL course content, don't just use the placeholder cache
            // The cached course from chat only contains objectives, not actual lesson content
            Log.classroom.info("🎨 LiveClassroom: Generating FULL course for topic: \(topic)")
            
            do {
                // Generate FULL course via CourseGenerationService (uses AI to create rich content)
                let fullCourse = try await CourseGenerationService.shared.generateCourse(
                    topic: topic,
                    level: "beginner",
                    outcomes: nil,
                    teachingStyle: "interactive"
                )
                
                Log.classroom.info("Generated full course: \(fullCourse.title) with \(fullCourse.modules.count) modules")
                
                // Now use this full course for the lesson
                let firstLessonId = fullCourse.modules.first?.lessons.first?.id ?? "intro"
                
                // Create a dummy playback state to use the converter
                let dummyPlayback = PlaybackState(
                    courseId: fullCourse.courseId,
                    currentNodeId: firstLessonId,
                    currentNode: LearningNodeWithAssets(
                        id: firstLessonId,
                        nodeType: "intro",
                        title: fullCourse.title,
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
                    playbackState: dummyPlayback,
                    courseTitle: fullCourse.title
                )
                
                Log.classroom.info("LiveClassroom: Created lesson with \(self.lesson?.blocks.count ?? 0) blocks")
                if let lessonData = lesson {
                    Log.classroom.info("   📋 Lesson ID: \(lessonData.lessonId)")
                    Log.classroom.info("   📋 Title: \(lessonData.title)")
                    Log.classroom.info("   📋 Blocks: \(lessonData.blocks.map { $0.title ?? "untitled" })")
                }
                Log.classroom.info("   📋 currentBlockIndex: \(self.currentBlockIndex)")
                Log.classroom.info("   📋 currentBlock: \(self.currentBlock?.title ?? "nil")")
                
                // Cache in GeneratedContentStore for instant re-access
                if let lessonData = lesson {
                    cacheLesson(lessonData, courseId: courseId, lessonId: lessonId)
                }
                
            } catch {
                Log.classroom.error("LiveClassroom: Course generation failed: \(error.localizedDescription)")
                Log.classroom.error("Full error: \(error)")
                errorMessage = "Failed to generate course: \(error.localizedDescription)"
                isLoading = false
                return
            }
            
            isLoading = false
            Log.classroom.info("🏁 LiveClassroom: isLoading set to false, currentBlock = \(self.currentBlock?.title ?? "nil")")
            if currentBlock != nil {
                await speakCurrentBlock()
            }
            return
        }

        do {
            // Try to fetch from backend
            lesson = try await apiClient.fetchLiveLesson(courseId: courseId, lessonId: lessonId)
        } catch {
            Log.classroom.error("LiveClassroom: Failed to fetch lesson from API: \(error.localizedDescription)")
            
            // Only fall back to mock data if explicitly allowed
            if AppConfig.allowMockFallbacks {
                Log.classroom.info("   Using mock lesson (LYO_ALLOW_MOCKS=1)")
                lesson = LyoAPIClient.mockLiveLesson(courseId: courseId, lessonId: lessonId)
            } else {
                // Surface the real error to user
                if case APIError.unauthorized = error {
                    errorMessage = "Please log in to access lessons"
                } else {
                    errorMessage = "Failed to load lesson. Please check your connection."
                }
            }
        }
        
        isLoading = false
        
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
            a2uiComponentJSON: nil,
            createdAt: Date(),
            lastAccessedAt: Date(),
            metadata: nil
        )
        contentStore.store(entry)
        Log.classroom.info("💾 Cached lesson \(lessonId) in GeneratedContentStore")
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
                currentThemeColor = .purple.opacity(0.8) // Near completion
            } else if progress > 0.4 {
                currentThemeColor = .blue.opacity(0.8) // Middle
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
            currentThemeColor = .purple.opacity(0.8) // Near completion
        } else if progress > 0.4 {
            currentThemeColor = .blue.opacity(0.8) // Middle
        }
        
        Task {
            await speakCurrentBlock()
        }
    }
    
    /// Submit a quiz answer
    func submitQuizAnswer(_ optionIndex: Int) {
        guard let block = currentBlock,
              block.type == .quizMcq else { return }
        
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
                "feedback": block.explanation ?? ""
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
                    timeTakenSeconds: 15.0, // TODO: measure actual time
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
            appendToTranscript(isUser: false, text: "✅ Correct! " + (block.explanation ?? "Great job!"))
            
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
        lioState = .idle // Reset Lio's state after retry
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
        setLioState(.thinking) // Long-running, no auto-reset until response
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
            appendToTranscript(isUser: false, text: "I'm having trouble answering that right now. Let's continue with the lesson.")
            setLioState(.confused, duration: 2.0)
            isProcessingQuestion = false
        }
    }
    
    // MARK: - Mastery Check
    
    private func triggerMasteryCheck() async {
        guard let memory = SmartMemoryService.shared.memory,
              let struggle = memory.struggles.filter({ !$0.resolved }).randomElement() else {
            return
        }
        
        Log.classroom.info("Triggering Mastery Check for: \(struggle.topic)")
        setLioState(.pondering)
        
        // Randomize quiz type (weighted towards MCQ for safety, but includes variety)
        let quizType = [LessonBlockType.quizMcq, .quizMcq, .quizTrueFalse, .quizFillBlank].randomElement() ?? .quizMcq
        
        do {
            let prompt: String
            switch quizType {
            case .quizTrueFalse:
                prompt = "Generate a single True/False question to test if a user understands '\(struggle.topic)'. Return only a JSON object with keys: 'question' (statement), 'correct_answer' ('True' or 'False'), 'explanation'."
            case .quizFillBlank:
                prompt = "Generate a single Fill-in-the-Blank question to test if a user understands '\(struggle.topic)'. Return only a JSON object with keys: 'question' (sentence with a blank ____), 'correct_answer' (word/phrase to fill), 'explanation'."
            default: // MCQ
                prompt = "Generate a single multiple-choice question to test if a user has mastered '\(struggle.topic)'. Return only a JSON object with keys: 'question', 'options' (array of 4), 'correct_index' (0-3), and 'explanation'."
            }
            
            let response = try await openAIService.sendMessage(message: prompt)
            
            // Basic extraction
            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let question = json["question"] as? String,
               let explanation = json["explanation"] as? String {
                
                var block = LessonBlock(
                    id: "mastery_\(UUID().uuidString)",
                    type: quizType,
                    title: "🧠 Mastery Check: \(struggle.topic)",
                    content: question,
                    explanation: explanation
                )
                
                // Parse specific fields based on type
                if quizType == .quizMcq,
                   let options = json["options"] as? [String],
                   let correctIndex = json["correct_index"] as? Int {
                    block = LessonBlock(
                        id: block.id,
                        type: quizType,
                        title: block.title,
                        content: question,
                        options: options,
                        correctIndex: correctIndex,
                        explanation: explanation
                    )
                } else if quizType == .quizTrueFalse || quizType == .quizFillBlank,
                          let correctAnswer = json["correct_answer"] as? String {
                    block = LessonBlock(
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
                }
                
                let introText = "Hey! Before we continue, let's see if you remember '\(struggle.topic)'..."
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
        
        let text = isCorrect ? "Excellent! You've clearly mastered that. Let's get back to our lesson." : "No worries, we'll keep practicing that topic later! Back to the lesson."
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
        setLioState(.idle)
    }
    
    private func speakCurrentBlock() async {
        guard let block = currentBlock else { return }
        
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
    
    /// Helper to synthesize and play text using Backend Neural TTS
    /// - Parameters:
    ///   - text: The text to speak
    ///   - type: Context for voice selection (optional future enhancement)
    private func speakText(_ text: String, type: TTSVoiceType = .explanation) async throws {
        isLioSpeaking = true
        lioState = .speaking
        
        // 1. Generate Audio via Backend
        // 'nova' is a great energetic voice for Lio. 'alloy' is good for neutral.
        let voice: TTSVoice = .nova
        
        let result = try await ttsRepository.generate(
            text: text,
            voice: voice,
            speed: 1.0, // Normal speed for clarity
            withTimings: false // We don't need word timings yet
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
            let observation = NotificationCenter.default.addObserver(
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
            appendToTranscript(isUser: false, text: "No worries! Let me explain that differently...")
            setLioState(.pondering)
            // Actually re-explain via AI
            if let block = currentBlock {
                do {
                    let prompt = "The student is confused about the following content. Re-explain it in simpler terms with an analogy:\n\n\(block.safeContent)"
                    let explanation = try await openAIService.sendMessage(message: prompt)
                    appendToTranscript(isUser: false, text: explanation)
                    setLioState(.speaking, duration: 3.0)
                } catch {
                    appendToTranscript(isUser: false, text: "Let me try again: \(block.safeContent)")
                    setLioState(.idle)
                }
            }
            
        case .slower:
            appendToTranscript(isUser: false, text: "I'll slow down. Take your time with this concept.")
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
        let blocks: [LessonBlock] = [
            LessonBlock(
                type: .paragraph,
                title: "Introduction",
                content: "Welcome to this lesson! Today we'll explore the fundamentals of this topic. By the end, you'll have a solid understanding of the key concepts."
            ),
            LessonBlock(
                type: .paragraph,
                title: "Core Concept",
                content: "The main idea here is that understanding the basics deeply allows you to build more complex knowledge on top. Think of it like building blocks."
            ),
            LessonBlock(
                type: .image,
                title: "Visual Diagram",
                content: "This diagram shows how the concepts connect together.",
                imageURL: nil
            ),
            LessonBlock(
                type: .code,
                title: "Worked Example",
                content: "Let's work through a practical example. Suppose we have a scenario where... By applying what we learned, we can solve it step by step."
            ),
            LessonBlock(
                type: .quizMcq,
                title: "What is the main benefit of understanding fundamentals?",
                options: [
                    "It's easier to memorize",
                    "You can build complex knowledge on top",
                    "It takes less time",
                    "You don't need practice"
                ],
                correctIndex: 1,
                explanation: "Understanding fundamentals provides a solid foundation that allows you to build more complex knowledge. It's like building blocks - the stronger the base, the higher you can build."
            ),
            LessonBlock(
                type: .summary,
                title: "Key Takeaways",
                content: "Today we covered: 1) The importance of fundamentals, 2) How concepts connect together, 3) A practical example, and 4) Tested your understanding. Great job completing this lesson!"
            )
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
        if lesson.courseId.hasPrefix("mock_") || lesson.courseId.hasPrefix("temp_") || lesson.courseId.hasPrefix("gen_") {
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
                    moduleProgress: [:], // Not using module-based tracking
                    overallProgress: overallProgress,
                    startedAt: Date(),
                    lastAccessedAt: Date(),
                    completedAt: nil
                )
            )
            Log.classroom.info("Synced progress to backend: \(self.completedBlocks.count)/\(lesson.totalBlocks) blocks")
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
            for (index, courseLesson) in module.lessons.enumerated() {
                if foundCurrent {
                    // This is the next lesson!
                    Log.classroom.info("Found next lesson: \(courseLesson.title)")
                    loadLessonFromGenerated(courseLesson, moduleTitle: module.title)
                    return
                }
                
                if courseLesson.id == currentLesson.lessonId {
                    foundCurrent = true
                    Log.classroom.info("📍 Found current lesson at module: \(module.title), lesson index: \(index)")
                    // Check if there's a next lesson in this module
                    if index + 1 < module.lessons.count {
                        let nextLesson = module.lessons[index + 1]
                        Log.classroom.info("Next lesson in same module: \(nextLesson.title)")
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
    private func loadLessonFromGenerated(_ courseLesson: GenerationCourseLesson, moduleTitle: String) {
        Log.classroom.info("📚 Loading lesson: \(courseLesson.title)")
        
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
        appendToTranscript(isUser: false, text: """
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
    
    private func convertPlaybackToLesson(playbackState: PlaybackState, courseTitle: String) -> LiveLesson {
        var blocks: [LessonBlock] = []
        
        // STEP 1: Check if we have a generated course in cache with FULL content
        // This is the key fix - use the FULL generated course, not just playback nodes
        if let generatedCourse = CourseGenerationService.shared.generatedCourse {
            Log.classroom.info("🎬 Converting FULL generated course to LiveLesson: \(generatedCourse.title)")
            Log.classroom.info("   Modules: \(generatedCourse.modules.count)")
            
            // Iterate through ALL modules and lessons
            for (moduleIndex, module) in generatedCourse.modules.enumerated() {
                // Add module header
                blocks.append(LessonBlock(
                    id: "mod_header_\(moduleIndex)",
                    type: .paragraph,
                    title: "📚 \(module.title)",
                    content: module.description
                ))
                
                for lesson in module.lessons {
                    // Add lesson introduction
                    blocks.append(LessonBlock(
                        id: "intro_\(lesson.id)",
                        type: .paragraph,
                        title: lesson.title,
                        content: lesson.content
                    ))
                    
                    // Add visual break every other lesson
                    if lesson.order % 2 == 0 {
                        blocks.append(LessonBlock(
                            id: "visual_\(lesson.id)",
                            type: .image,
                            title: "Key Insight",
                            imageURL: nil
                        ))
                    }
                }
                
                // Add quiz at the end of each module
                blocks.append(LessonBlock(
                    id: "quiz_mod_\(moduleIndex)",
                    type: .quizMcq,
                    title: "Quick Check: \(module.title)",
                    content: "Let's make sure you understood the key concepts!",
                    options: [
                        "I understand the key concepts",
                        "I need more examples",
                        "I have questions",
                        "Ready for next module"
                    ],
                    correctIndex: 0,
                    explanation: "Great job! You've completed this module."
                ))
            }
            
            // Add final summary
            blocks.append(LessonBlock(
                id: "final_summary",
                type: .summary,
                title: "🎉 Course Complete!",
                content: "Congratulations! You've completed '\(generatedCourse.title)'. You covered \(generatedCourse.modules.count) modules and learned the fundamentals. Keep practicing!"
            ))
            
            Log.classroom.info("Created \(blocks.count) blocks from generated course")
            
            return LiveLesson(
                courseId: playbackState.courseId,
                lessonId: generatedCourse.modules.first?.lessons.first?.id ?? "generated",
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
            blocks.append(LessonBlock(
                id: currentNode.id,
                type: .paragraph,
                title: content["title"]?.value as? String ?? currentNode.title,
                content: text
            ))
        } else if let narration = content["narration"]?.value as? String {
            blocks.append(LessonBlock(
                id: currentNode.id,
                type: .paragraph,
                title: currentNode.title,
                content: narration
            ))
        } else if currentNode.nodeType == "interaction",
                  let prompt = content["prompt"]?.value as? String,
                  let optionsArray = content["options"]?.value as? [[String: Any]] {
            let optionLabels = optionsArray.compactMap { $0["label"] as? String }
            let correctIdx = optionsArray.firstIndex { ($0["is_correct"] as? Bool) == true }
            let explanation = content["explanation"]?.value as? String
            
            blocks.append(LessonBlock(
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
            if let text = nodeContent["text"]?.value as? String, !text.isEmpty {
                blocks.append(LessonBlock(
                    id: nextNode.id,
                    type: .paragraph,
                    title: nodeContent["title"]?.value as? String ?? nextNode.title,
                    content: text
                ))
            } else if let narration = nodeContent["narration"]?.value as? String {
                blocks.append(LessonBlock(
                    id: nextNode.id,
                    type: .paragraph,
                    title: nextNode.title,
                    content: narration
                ))
            }
        }
        
        // Add a completion block if we have content
        if !blocks.isEmpty {
            blocks.append(LessonBlock(
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
            blocks: blocks.isEmpty ? [LessonBlock(id: "empty", type: .paragraph, title: "Loading...", content: "Please wait while we prepare your lesson.")] : blocks,
            estimatedDuration: 15
        )
    }
    
    // MARK: - A2UI Classroom Support
    
    /// Legacy DynamicComponent A2UI (kept for backwards compatibility)
    @Published var a2uiComponent: DynamicComponent?
    
    /// Full A2UIComponent rendered with the complete A2UIRenderer (120+ types)
    @Published var fullA2UIComponent: A2UIComponent?
    
    /// Load lesson UI from backend using A2UI (optional enhancement - won't override existing lesson)
    func loadLessonUI(_ lessonId: String) async {
        // Don't reset loading state if we already have lesson content - A2UI is optional upgrade
        let hadLessonAtStart = lesson != nil
        if !hadLessonAtStart {
            isLoading = true
        }
        
        a2uiComponent = nil
        fullA2UIComponent = nil
        
        do {
            // Try to decode directly as A2UIComponent first (preferred path)
            let fullComponent = try await fetchLessonUIAsA2UIComponent(lessonId)
            self.fullA2UIComponent = fullComponent
            Log.classroom.info("🎨 A2UI lesson loaded directly: \(fullComponent.type.rawValue)")
            
            if !hadLessonAtStart {
                self.isLoading = false
            }
        } catch {
            // A2UI is optional — only set error if we STILL don't have lesson content.
            // Re-check self.lesson NOW (not the stale hadLessonAtStart captured earlier)
            // because loadLesson() may have completed in parallel while A2UI was fetching.
            let hasLessonNow = self.lesson != nil
            if !hasLessonNow {
                self.errorMessage = "Failed to load lesson: \(error.localizedDescription)"
                self.isLoading = false
            }
            Log.classroom.warning("⚠️ A2UI not available for lesson \(lessonId): \(error.localizedDescription)")
        }
    }
    
    /// Handle A2UI action callbacks (button taps, etc.)
    func handleA2UIAction(_ actionId: String) async {
        Log.classroom.info("A2UI Action: \(actionId)")
        
        switch actionId {
        case "load_next_lesson":
            moveToNextLesson()
            
        case "load_previous_lesson":
            goToPreviousBlock()
            Log.classroom.info("⬅️ Navigated to previous block")
            
        case "complete_course":
            showCourseCompletion()
            
        case let quizAction where quizAction.hasPrefix("quiz_answer_"):
            // Extract answer index from action ID
            if let indexStr = quizAction.split(separator: "_").last,
               let index = Int(indexStr) {
                handleQuizAnswer(index)
            }
            
        default:
            Log.classroom.warning("Unhandled action: \(actionId)")
        }
    }
    
    /// Fetch lesson UI from backend and decode as A2UIComponent directly
    private func fetchLessonUIAsA2UIComponent(_ lessonId: String) async throws -> A2UIComponent {
        // Use typed endpoint for proper SaaS headers (X-API-Key, X-Tenant-Id, Authorization)
        let endpoint = Endpoints.Classroom.getLessonUI(lessonId: lessonId)
        
        // The backend returns { "lessonId": "...", "a2ui": { ... A2UIComponent ... }, "metadata": { ... } }
        // We decode a2ui directly as A2UIComponent for the full renderer
        struct LessonUIResponse: Codable {
            let lessonId: String
            let a2ui: A2UIComponent
            let metadata: LessonUIMetadata?
            
            struct LessonUIMetadata: Codable {
                let estimatedDuration: Int?
                let difficulty: String?
                let nodeType: String?
                let courseId: String?
                let courseTitle: String?
            }
        }
        
        let response: LessonUIResponse = try await NetworkClient.shared.request(endpoint)
        
        Log.classroom.info("🎨 Loaded A2UI for lesson: \(response.lessonId) (type: \(response.a2ui.type.rawValue))")
        return response.a2ui
    }
    
    /// Handle quiz answer selection
    private func handleQuizAnswer(_ index: Int) {
        Log.classroom.info("Quiz answer selected: Option \(index)")
        selectedQuizOption = index
        quizSubmitted = true
        
        // 🔥 CRITICAL: isQuizCorrect now evaluates based on selectedQuizOption/current state
        let isCorrect = self.isQuizCorrect
        quizResults["a2ui_\(index)"] = isCorrect
        
        // Report to Personalization Engine
        let result = CinemaInteraction(
            isCorrect: isCorrect,
            responseTime: 0,
            attempts: 1,
            metadata: ["a2ui_quiz_index": "\(index)"]
        )
        LyoAIViewModel.shared.handleCinemaInteractionResult(result, nodeId: "a2ui_quiz")
        
        if isCorrect {
            setLioState(.celebrating, duration: 3.0)
            HapticManager.shared.success()
            
            // Sync progress
            Task {
                await syncProgressToBackend()
            }
        } else {
            setLioState(.pondering, duration: 3.0)
            showingExplanation = true
            HapticManager.shared.medium()
        }
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
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        resumeOnce()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        resumeOnce()
    }
}

