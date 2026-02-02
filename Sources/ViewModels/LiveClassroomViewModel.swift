import Foundation
import SwiftUI
import Combine

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
    @Published var userQuestion: String = ""
    @Published var isProcessingQuestion: Bool = false
    
    // Progress
    @Published var completedBlocks: Set<String> = []
    @Published var quizResults: [String: Bool] = [:]
    
    // MARK: - Dependencies
    
    private let openAIService: OpenAIService
    private let apiClient = LyoAPIClient.shared
    private let cinemaService = InteractiveCinemaService.shared
    private let tokenManager = TokenManager.shared
    private let repository = LyoRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Graph-based playback state
    private var currentCourseId: String?
    
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
    }
    
    // MARK: - Public Methods
    
    /// Load a lesson by course and lesson ID
    func loadLesson(courseId: String, lessonId: String) async {
        isLoading = true
        errorMessage = nil
        
        // Check for Generated Course (mock_, gen_, etc.)
        // These courses were already generated and cached in CourseGenerationService
        if courseId.starts(with: "mock_") || courseId.starts(with: "gen_") || courseId.starts(with: "temp_") {
            print("🎨 LiveClassroom: Loading generated course: \(courseId)")
            
            do {
                // Start playback from the cached/generated course
                let playbackState = try await cinemaService.startCourse(courseId: courseId)
                currentCourseId = courseId
                
                // Convert PlaybackState to LiveLesson for compatibility
                self.lesson = convertPlaybackToLesson(
                    playbackState: playbackState,
                    courseTitle: playbackState.currentNode.title
                )
                
                print("✅ LiveClassroom: Loaded generated course with \(lesson?.blocks.count ?? 0) blocks")
                
            } catch {
                print("❌ LiveClassroom: Failed to load generated course: \(error.localizedDescription)")
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
            
            // � FIX: Always generate FULL course content, don't just use the placeholder cache
            // The cached course from chat only contains objectives, not actual lesson content
            print("🎨 LiveClassroom: Generating FULL course for topic: \(topic)")
            
            do {
                // Generate FULL course via CourseGenerationService (uses AI to create rich content)
                let fullCourse = try await CourseGenerationService.shared.generateCourse(
                    topic: topic,
                    level: "beginner",
                    outcomes: nil,
                    teachingStyle: "interactive"
                )
                
                print("✅ Generated full course: \(fullCourse.title) with \(fullCourse.modules.count) modules")
                
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
                
                print("✅ LiveClassroom: Created lesson with \(lesson?.blocks.count ?? 0) blocks")
                
            } catch {
                print("❌ LiveClassroom: Course generation failed: \(error.localizedDescription)")
                errorMessage = "Failed to generate course. Please try again."
                isLoading = false
                return
            }
            
            isLoading = false
            if currentBlock != nil {
                await speakCurrentBlock()
            }
            return
        }

        do {
            // Try to fetch from backend
            lesson = try await apiClient.fetchLiveLesson(courseId: courseId, lessonId: lessonId)
        } catch {
            print("LiveClassroom: Failed to fetch lesson from API: \(error.localizedDescription)")
            
            // Only fall back to mock data if explicitly allowed
            if AppConfig.allowMockFallbacks {
                print("   Using mock lesson (LYO_ALLOW_MOCKS=1)")
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
        
        // Start speaking first block
        if currentBlock != nil {
            await speakCurrentBlock()
        }
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
        } else {
            // 🔥 FINAL BLOCK: Mark lesson as completed
            Task {
                await markLessonCompleted()
            }
        }
    }
    
    /// Move to the previous block
    func goToPreviousBlock() {
        guard !isFirstBlock else { return }
        
        resetQuizState()
        currentBlockIndex -= 1
        HapticManager.shared.light()
        
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
            setLioState(.speaking, duration: 3.0)
        } catch {
            appendToTranscript(isUser: false, text: "I'm having trouble answering that right now. Let's continue with the lesson.")
            setLioState(.confused, duration: 2.0)
        }
        
        userQuestion = ""
        isProcessingQuestion = false
        showAskQuestionSheet = false
    }
    
    // MARK: - Mastery Check
    
    private func triggerMasteryCheck() async {
        guard let memory = SmartMemoryService.shared.memory,
              let struggle = memory.struggles.filter({ !$0.resolved }).randomElement() else {
            return
        }
        
        print("🤖 Triggering Mastery Check for: \(struggle.topic)")
        setLioState(.pondering)
        
        do {
            let prompt = "Generate a single multiple-choice question to test if a user has mastered '\(struggle.topic)'. Return only a JSON object with keys: 'question', 'options' (array of 4), 'correct_index' (0-3), and 'explanation'."
            
            let response = try await openAIService.sendMessage(message: prompt)
            
            // Basic extraction (Assuming OpenAI returns clean JSON or we wrap it)
            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let question = json["question"] as? String,
               let options = json["options"] as? [String],
               let correctIndex = json["correct_index"] as? Int,
               let explanation = json["explanation"] as? String {
                
                let block = LessonBlock(
                    id: "mastery_\(UUID().uuidString)",
                    type: .quizMcq,
                    title: "🧠 Mastery Check: \(struggle.topic)",
                    content: question,
                    options: options,
                    correctIndex: correctIndex,
                    explanation: explanation
                )
                
                withAnimation {
                    self.masteryCheckBlock = block
                    self.isMasteryCheckActive = true
                }
                
                appendToTranscript(isUser: false, text: "Hey! Before we continue, let's see if you remember '\(struggle.topic)'...")
                setLioState(.speaking, duration: 3.0)
            }
        } catch {
            print("⚠️ Failed to generate mastery check: \(error)")
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
        
        appendToTranscript(isUser: false, text: isCorrect ? "Excellent! You've clearly mastered that. Let's get back to our lesson." : "No worries, we'll keep practicing that topic later! Back to the lesson.")
        
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
        
        isLioSpeaking = true
        lioState = .speaking
        
        // Simulate Lio speaking the content
        let speakText: String
        switch block.type {
        case .text, .paragraph:
            speakText = block.safeContent
        case .heading:
            speakText = "Next, let's look at: \(block.safeTitle)"
        case .callout:
            speakText = block.safeContent
        case .image:
            speakText = block.title ?? "Take a look at this visual."
        case .video:
            speakText = "Watch this video to learn more."
        case .quiz, .quizMcq:
            speakText = "Quick check! \(block.question ?? block.title ?? "")"
        case .code:
            speakText = "Here's a code example in \(block.language ?? "this language")."
        case .summary:
            speakText = "Let's recap what we've learned."
        default:
            speakText = block.safeContent
        }
        
        appendToTranscript(isUser: false, text: speakText)
        
        // Simulate speaking duration
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isLioSpeaking = false
        setLioState(.idle)
    }
    
    private func handleSentimentSignal(_ signal: SentimentSignal) async {
        isLioSpeaking = true
        lioState = .speaking
        
        var response: String
        switch signal {
        case .confused:
            response = "No worries! Let me explain that differently..."
            lioState = .pondering // Lio is pondering how to re-explain
            // In production, would regenerate explanation
        case .slower:
            response = "I'll slow down. Take your time with this concept."
        case .tooEasy:
            response = "Got it! Let's pick up the pace."
            // Could skip to next block or harder content
        case .quizMe:
            response = "Sure! Let me quiz you on what we've covered."
            setLioState(.thinking)
            // Could insert a quiz block
        }
        
        appendToTranscript(isUser: false, text: response)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        isLioSpeaking = false
        
        // Return to idle after a short delay
        setLioState(.idle, duration: 1.0)
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
        if lesson.courseId.hasPrefix("mock_") || lesson.courseId.hasPrefix("temp_") || lesson.courseId.hasPrefix("gen_") {
            print("🚫 Skipping backend sync for local/mock course: \(lesson.courseId)")
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
            print("✅ Synced progress to backend: \(completedBlocks.count)/\(lesson.totalBlocks) blocks")
        } catch {
            print("⚠️ Failed to sync progress: \(error.localizedDescription)")
            // Don't show error to user - continue with local tracking
        }
    }
    
    /// Mark lesson as completed (called when reaching final block)
    private func markLessonCompleted() async {
        guard let lesson = lesson else { return }
        
        // Show completion celebration
        await MainActor.run {
            appendToTranscript(isUser: false, text: "🎉 Lesson Complete! Great work!")
            setLioState(.celebrating, duration: 5.0)
        }
        
        // Check if there's a next lesson
        if let generatedCourse = CourseGenerationService.shared.generatedCourse {
            print("✅ Lesson completed, checking for next lesson...")
            // Give user option to continue
            await MainActor.run {
                // The UI will show "Next Lesson" button which calls moveToNextLesson()
            }
        }
        
        // If lesson from generated course, trigger next lesson
        let totalQuizzes = quizResults.count
        let correctQuizzes = quizResults.values.filter { $0 }.count
        let score = totalQuizzes > 0 ? Int((Double(correctQuizzes) / Double(totalQuizzes)) * 100) : 100
        // Mark complete in backend
        do {
            try await repository.markLessonComplete(lessonId: lesson.lessonId)
        } catch {
            print("❌ Failed to mark lesson as complete: \(error)")
        }
    }
    
    // MARK: - Lesson/Module Navigation
    
    /// Move to the next lesson in the course
    func moveToNextLesson() {
        guard let generatedCourse = CourseGenerationService.shared.generatedCourse else {
            print("⚠️ No generated course available")
            return
        }
        
        guard let currentLesson = lesson else {
            print("⚠️ No current lesson")
            return
        }
        
        print("🔍 Looking for next lesson after: \(currentLesson.lessonId)")
        
        // Find current lesson position in course structure
        var foundCurrent = false
        
        for module in generatedCourse.modules {
            for (index, courseLesson) in module.lessons.enumerated() {
                if foundCurrent {
                    // This is the next lesson!
                    print("✅ Found next lesson: \(courseLesson.title)")
                    loadLessonFromGenerated(courseLesson, moduleTitle: module.title)
                    return
                }
                
                if courseLesson.id == currentLesson.lessonId {
                    foundCurrent = true
                    print("📍 Found current lesson at module: \(module.title), lesson index: \(index)")
                    // Check if there's a next lesson in this module
                    if index + 1 < module.lessons.count {
                        let nextLesson = module.lessons[index + 1]
                        print("✅ Next lesson in same module: \(nextLesson.title)")
                        loadLessonFromGenerated(nextLesson, moduleTitle: module.title)
                        return
                    }
                }
            }
        }
        
        // No more lessons - course complete!
        print("🎉 All lessons completed!")
        showCourseCompletion()
    }
    
    /// Load a lesson from the generated course
    private func loadLessonFromGenerated(_ courseLesson: GenerationCourseLesson, moduleTitle: String) {
        print("📚 Loading lesson: \(courseLesson.title)")
        
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
        print("🎊 Course completion celebration triggered")
        
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
            print("🎬 Converting FULL generated course to LiveLesson: \(generatedCourse.title)")
            print("   Modules: \(generatedCourse.modules.count)")
            
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
                            imageURL: URL(string: "LyoThinking")
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
            
            print("✅ Created \(blocks.count) blocks from generated course")
            
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
        print("⚠️ No cached generated course, using playback nodes")
        
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
    
    /// A2UI component fetched from backend
    @Published var a2uiComponent: DynamicComponent?
    
    /// Load lesson UI from backend using A2UI
    func loadLessonUI(_ lessonId: String) async {
        isLoading = true
        errorMessage = nil
        a2uiComponent = nil
        
        do {
            let component = try await fetchLessonUIFromBackend(lessonId)
            self.a2uiComponent = component
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to load lesson: \(error.localizedDescription)"
            self.isLoading = false
            print("❌ Error loading lesson UI: \(error)")
        }
    }
    
    /// Handle A2UI action callbacks (button taps, etc.)
    func handleA2UIAction(_ actionId: String) async {
        print("🎯 A2UI Action: \(actionId)")
        
        switch actionId {
        case "load_next_lesson":
            await moveToNextLesson()
            
        case "load_previous_lesson":
            // TODO: Implement previous lesson navigation
            print("⬅️ Previous lesson requested")
            
        case "complete_course":
            showCourseCompletion()
            
        case let quizAction where quizAction.hasPrefix("quiz_answer_"):
            // Extract answer index from action ID
            if let indexStr = quizAction.split(separator: "_").last,
               let index = Int(indexStr) {
                handleQuizAnswer(index)
            }
            
        default:
            print("⚠️ Unhandled action: \(actionId)")
        }
    }
    
    /// Fetch lesson UI from backend endpoint
    private func fetchLessonUIFromBackend(_ lessonId: String) async throws -> DynamicComponent {
        guard let token = await tokenManager.getToken() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No valid token"])
        }
        
        guard let url = URL(string: "\(AppConfig.baseURL)/api/v1/classroom/lesson/\(lessonId)/ui") else {
            throw NSError(domain: "URL", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, httpUrlResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = httpUrlResponse as? HTTPURLResponse else {
            throw NSError(domain: "Network", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTP", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned \(httpResponse.statusCode)"])
        }
        
        // Parse response
        struct LessonUIResponse: Codable {
            let lessonId: String
            let a2ui: DynamicComponent
            let metadata: Metadata?
            
            struct Metadata: Codable {
                let estimatedDuration: Int?
                let difficulty: String?
            }
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let finalResponse = try decoder.decode(LessonUIResponse.self, from: data)
        
        print("✅ Loaded A2UI for lesson: \(finalResponse.lessonId)")
        return finalResponse.a2ui
    }
    
    /// Handle quiz answer selection
    private func handleQuizAnswer(_ index: Int) {
        print("📝 Quiz answer selected: Option \(index)")
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
