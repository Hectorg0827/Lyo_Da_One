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
    
    // Graph playback state (Interactive Cinema)
    @Published var playbackState: PlaybackState?
    
    // Quiz State
    @Published var selectedQuizOption: Int? = nil
    @Published var quizSubmitted: Bool = false
    @Published var showingExplanation: Bool = false
    
    // Transcript & Questions
    @Published var transcript: [ChatTurn] = []
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
    
    // MARK: - Computed Properties
    
    var currentBlock: LessonBlock? {
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
        guard let block = currentBlock,
              let correctIndex = block.correctIndex,
              let selected = selectedQuizOption else {
            return false
        }
        return selected == correctIndex
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
        
        // Check for Generation Request
        if courseId.hasPrefix("GENERATE:") {
            let topic = String(courseId.dropFirst(9))
            print("🎨 LiveClassroom: Generating GRAPH-BASED course for topic: \(topic)")
            
            do {
                // Generate Graph Course via Interactive Cinema Service
                let graphCourse = try await cinemaService.generateGraphCourse(topic: topic, level: "beginner")
                
                print("✅ Generated graph course: \(graphCourse.title) with \(graphCourse.totalNodes) nodes")
                
                // Start playback immediately (requires auth token)
                let playbackState = try await cinemaService.startCourse(courseId: graphCourse.id)
                
                currentCourseId = graphCourse.id
                
                // Convert PlaybackState to LiveLesson for compatibility
                self.lesson = convertPlaybackToLesson(
                    playbackState: playbackState,
                    courseTitle: graphCourse.title
                )
                
                print("✅ LiveClassroom: Started cinematic playback for: \(graphCourse.title)")
                
            } catch {
                print("❌ LiveClassroom: Graph generation failed: \(error.localizedDescription)")
                if let cinemaError = error as? CinemaError,
                   case .unauthorized = cinemaError {
                    errorMessage = "Please log in to start the interactive course"
                } else if let cinemaError = error as? CinemaError {
                    #if DEBUG
                    // In debug builds, surface decoding details so backend/iOS contract issues are visible
                    // directly in-app without requiring Xcode logs.
                    errorMessage = cinemaError.errorDescription ?? "Failed to generate course. Please try again."
                    #else
                    errorMessage = "Failed to generate course. Please try again."
                    #endif
                } else {
                    errorMessage = "Failed to generate course. Please try again."
                }
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
            
            // Speak new block
            Task {
                await speakCurrentBlock()
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
            // Add to transcript
            appendToTranscript(isUser: false, text: "✅ Correct! " + (block.explanation ?? "Great job!"))
        } else {
            HapticManager.shared.medium()
            showingExplanation = true
            // Add explanation to transcript
            if let explanation = block.explanation {
                appendToTranscript(isUser: false, text: "❌ Not quite. \(explanation) Try again!")
            }
        }
    }
    
    /// Retry a quiz (after wrong answer)
    func retryQuiz() {
        selectedQuizOption = nil
        quizSubmitted = false
        showingExplanation = false
        HapticManager.shared.light()
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
        appendToTranscript(isUser: true, text: question)
        
        // Get AI response
        do {
            let contextPrompt = buildQuestionContext()
            let fullQuestion = "\(contextPrompt)\n\nUser question: \(question)"
            let response = try await openAIService.sendMessage(
                message: fullQuestion
            )
            appendToTranscript(isUser: false, text: response)
        } catch {
            appendToTranscript(isUser: false, text: "I'm having trouble answering that right now. Let's continue with the lesson.")
        }
        
        userQuestion = ""
        isProcessingQuestion = false
        showAskQuestionSheet = false
    }
    
    // MARK: - Private Methods
    
    private func resetQuizState() {
        selectedQuizOption = nil
        quizSubmitted = false
        showingExplanation = false
    }
    
    private func speakCurrentBlock() async {
        guard let block = currentBlock else { return }
        
        isLioSpeaking = true
        
        // Simulate Lio speaking the content
        let speakText: String
        switch block.type {
        case .explain:
            speakText = block.body ?? block.title ?? ""
        case .example:
            speakText = "Let me show you an example. \(block.body ?? "")"
        case .image:
            speakText = block.title ?? "Take a look at this visual."
        case .quizMcq:
            speakText = "Quick check! \(block.title ?? "")"
        case .summary:
            speakText = "Let's recap. \(block.body ?? "")"
        }
        
        appendToTranscript(isUser: false, text: speakText)
        
        // Simulate speaking duration
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isLioSpeaking = false
    }
    
    private func handleSentimentSignal(_ signal: SentimentSignal) async {
        isLioSpeaking = true
        
        var response: String
        switch signal {
        case .confused:
            response = "No worries! Let me explain that differently..."
            // In production, would regenerate explanation
        case .slower:
            response = "I'll slow down. Take your time with this concept."
        case .tooEasy:
            response = "Got it! Let's pick up the pace."
            // Could skip to next block or harder content
        case .quizMe:
            response = "Sure! Let me quiz you on what we've covered."
            // Could insert a quiz block
        }
        
        appendToTranscript(isUser: false, text: response)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        isLioSpeaking = false
    }
    
    private func appendToTranscript(isUser: Bool, text: String) {
        let turn = ChatTurn(isUser: isUser, text: text)
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
                type: .explain,
                title: "Introduction",
                body: "Welcome to this lesson! Today we'll explore the fundamentals of this topic. By the end, you'll have a solid understanding of the key concepts."
            ),
            LessonBlock(
                type: .explain,
                title: "Core Concept",
                body: "The main idea here is that understanding the basics deeply allows you to build more complex knowledge on top. Think of it like building blocks."
            ),
            LessonBlock(
                type: .image,
                title: "Visual Diagram",
                body: "This diagram shows how the concepts connect together.",
                assetURL: nil
            ),
            LessonBlock(
                type: .example,
                title: "Worked Example",
                body: "Let's work through a practical example. Suppose we have a scenario where... By applying what we learned, we can solve it step by step."
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
                body: "Today we covered: 1) The importance of fundamentals, 2) How concepts connect together, 3) A practical example, and 4) Tested your understanding. Great job completing this lesson!"
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
        
        // Calculate score based on quiz results
        let totalQuizzes = quizResults.count
        let correctQuizzes = quizResults.values.filter { $0 }.count
        let score = totalQuizzes > 0 ? Int((Double(correctQuizzes) / Double(totalQuizzes)) * 100) : 100
        
        do {
            let response = try await repository.markLessonComplete(lessonId: lesson.lessonId, score: score)
            print("✅ Lesson completed! XP earned: \(response.xpAwarded)")
            
            // Award XP locally for immediate feedback
            // Backend already awarded XP, just update UI
        } catch {
            print("⚠️ Failed to mark lesson complete: \(error.localizedDescription)")
            // Continue - user still completed locally
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
                    type: .explain,
                    title: "📚 \(module.title)",
                    body: module.description
                ))
                
                for lesson in module.lessons {
                    // Add lesson introduction
                    blocks.append(LessonBlock(
                        id: "intro_\(lesson.id)",
                        type: .explain,
                        title: lesson.title,
                        body: lesson.content
                    ))
                    
                    // Add visual break every other lesson
                    if lesson.order % 2 == 0 {
                        blocks.append(LessonBlock(
                            id: "visual_\(lesson.id)",
                            type: .image,
                            title: "Key Insight",
                            assetURL: URL(string: "LyoThinking")
                        ))
                    }
                }
                
                // Add quiz at the end of each module
                blocks.append(LessonBlock(
                    id: "quiz_mod_\(moduleIndex)",
                    type: .quizMcq,
                    title: "Quick Check: \(module.title)",
                    body: "Let's make sure you understood the key concepts!",
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
                body: "Congratulations! You've completed '\(generatedCourse.title)'. You covered \(generatedCourse.modules.count) modules and learned the fundamentals. Keep practicing!"
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
                type: .explain,
                title: content["title"]?.value as? String ?? currentNode.title,
                body: text
            ))
        } else if let narration = content["narration"]?.value as? String {
            blocks.append(LessonBlock(
                id: currentNode.id,
                type: .explain,
                title: currentNode.title,
                body: narration
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
                    type: .explain,
                    title: nodeContent["title"]?.value as? String ?? nextNode.title,
                    body: text
                ))
            } else if let narration = nodeContent["narration"]?.value as? String {
                blocks.append(LessonBlock(
                    id: nextNode.id,
                    type: .explain,
                    title: nextNode.title,
                    body: narration
                ))
            }
        }
        
        // Add a completion block if we have content
        if !blocks.isEmpty {
            blocks.append(LessonBlock(
                id: "completion",
                type: .summary,
                title: "Lesson Complete",
                body: "Great job completing this lesson! You're making excellent progress."
            ))
        }
        
        return LiveLesson(
            courseId: playbackState.courseId,
            lessonId: currentNode.id,
            title: courseTitle,
            subtitle: "Interactive Cinema Experience",
            blocks: blocks.isEmpty ? [LessonBlock(id: "empty", type: .explain, title: "Loading...", body: "Please wait while we prepare your lesson.")] : blocks,
            estimatedDuration: 15
        )
    }
}
