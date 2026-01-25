import Foundation
import SwiftUI
import Combine

@MainActor
class LyoAIViewModel: ObservableObject {
    static let shared = LyoAIViewModel()
    
    // MARK: - Published State
    @Published var messages: [LyoMessage] = []
    @Published var suggestions: [SuggestionChip] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var systemStatus: String?
    
    // MARK: - Drawer State
    @Published var isDrawerOpen: Bool = false
    @Published var isDrawerPinned: Bool = false
    @Published var continueCards: [CourseCard] = []
    @Published var startedCards: [CourseCard] = []
    @Published var suggestedCards: [CourseCard] = []
    @Published var selectedDrawerTab: DrawerTab = .continue
    
    enum DrawerTab {
        case `continue`, started, suggested
    }
    
    // MARK: - Attachment State
    @Published var attachments: [MessageAttachment] = []
    @Published var isUploadingFile: Bool = false
    
    // MARK: - Multimodal State
    @Published var voiceInputLevel: Float = 0
    @Published var isRecordingVoice: Bool = false
    @Published var currentlyPlayingMessageId: String?
    @Published var playbackProgress: Double = 0
    
    // MARK: - Hybrid UI State
    @Published var scrollOffset: CGFloat = 0
    @Published var isChatOpen: Bool = false
    @Published var isVoiceActive: Bool = false
    @Published var showFloatingOrb: Bool = false
    
    // MARK: - Quiz State
    @Published var activeQuiz: Quiz?
    @Published var isQuizActive: Bool = false
    
    // MARK: - Personalization (NEXR)
    @Published var nextAction: NextActionResponse?
    @Published var masteryProfile: MasteryProfile?
    
    // MARK: - Affect Monitoring
    private var sessionStartTime = Date()
    private var interactionCount = 0
    private var lastInteractionTime = Date()
    private var lastAffectUpdate = Date.distantPast // Debounce affect updates
    
    // MARK: - Social Data (Mock)
    @Published var socialPosts: [RepoPost] = []
    @Published var suggestedUsers: [User] = []
    
    // MARK: - Dependencies
    private let repository = LyoRepository.shared 
    // private let aiService = OpenAIService.shared // Deprecated
    private let unifiedChat = UnifiedChatService.shared
    private let ttsService = TextToSpeechService.shared
    private let sttService = VoiceInputService.shared
    private let cinemaService = InteractiveCinemaService.shared 
    private let socialRepository: SocialRepository = LyoRepository.shared as SocialRepository
    private var drawerAutoCloseTimer: Timer?
    
    // MARK: - Multimodal Services
    private let voiceInputService = VoiceInputService.shared
    private let audioPlaybackService = AudioPlaybackService.shared
    private let mediaPickerService = MediaPickerService.shared
    
    // UI State reference (injected)
    var uiState: AppUIState?
    private var cancellables = Set<AnyCancellable>()
    
    // Course wizard state
    @Published var currentOutline: CourseOutline?
    @Published var isGeneratingCourse: Bool = false
    
    init(uiState: AppUIState? = nil) {
        self.uiState = uiState
        loadInitialSuggestions()
        setupBindings()
        Task {
            await loadSocialData()
            await loadCourseCards()
        }
    }
    
    private func setupBindings() {
        // Voice bindings
        sttService.$transcript
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                if self?.isVoiceActive == true && !text.isEmpty {
                    self?.inputText = text
                }
            }
            .store(in: &cancellables)
            
        sttService.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: &$isVoiceActive)
            
        // Continuous Conversation: Start listening when AI finishes speaking
        ttsService.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.currentlyPlayingMessageId = nil // Reset playing state
            
            if self.isVoiceActive {
                self.startListening()
            }
        }
        
        // SYNC WITH UNIFIED CHAT
        unifiedChat.$messages
            .receive(on: RunLoop.main)
            .assign(to: &$messages)
            
        unifiedChat.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: &$isLoading)
            
        unifiedChat.$suggestions
            .receive(on: RunLoop.main)
            .assign(to: &$suggestions)
            
        // Handle Course Navigation from Unified Chat
        unifiedChat.$shouldNavigateToClassroom
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldNavigate in
                if shouldNavigate, let course = self?.unifiedChat.pendingCourse {
                    print("🚀 ViewModel received navigation to course: \(course.title)")
                    // Bridge properly to AICommandHandler to trigger the centralized navigation logic (Notification + State)
                    let payload = CoursePayload(
                        id: course.id,
                        title: course.title,
                        topic: course.topic,
                        level: course.level,
                        language: "English",
                        duration: "\(course.modules.count) modules",
                        objectives: course.modules.map { $0.title }
                    )
                    
                    // CALL handleOpenClassroom instead of setting state variables directly.
                    // This ensures the Notification is actually posted to move MainTabView.
                    let commandPayload = AICommandPayload(stackItem: nil, course: payload)
                    _ = AICommandHandler.shared.handleOpenClassroom(commandPayload)
                    
                    self?.unifiedChat.clearNavigation()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Voice Control
    
    func toggleVoiceMode() {
        if isVoiceActive {
            stopListening()
        } else {
            startListening()
        }
    }
    
    func startListening() {
        // For barge-in, we don't stop TTS here. We let it play.
        // If user speaks, onSpeechDetected will stop TTS.
        
        sttService.checkPermissions()
        Task {
            do {
                try await sttService.startRecording()
                isVoiceActive = true
            } catch {
                print("Failed to start recording: \(error)")
                isVoiceActive = false
            }
        }
    }
    
    func stopListening() {
        sttService.stopRecording()
        isVoiceActive = false
        stopSpeaking() // Also stop TTS if we are fully stopping voice mode
        
        // If we have text, send it automatically in conversational mode
        if !inputText.isEmpty {
            Task {
                await sendMessage()
            }
        }
    }
    
    func speak(text: String, messageId: String? = nil) {
        ttsService.speak(text: text)
        // Update state if a specific message is being read
        if let messageId = messageId {
            currentlyPlayingMessageId = messageId
        }
        
        // Ensure we are listening for barge-in
        if !sttService.isRecording {
            startListening()
        }
    }
    
    func stopSpeaking() {
        ttsService.stop()
        currentlyPlayingMessageId = nil
    }
    
    // MARK: - Proactive Greeting
    
    func fetchProactiveGreeting() async {
        // Delegate to Unified Chat Service
        await unifiedChat.fetchProactiveGreeting()
        
        // Voice is handled by observing changes in messages via binding
        // Logic for auto-speaking is effectively handled in sendMessage() for now,
        // but for initial greeting, we might need a reaction.
        // However, since we sink $messages in setupBindings(),
        // we can add side-effects there if needed.
        
        // For now, if we want to speak the greeting explicitly here:
        if isVoiceActive, let last = unifiedChat.messages.last, !last.isFromUser {
             speak(text: last.content)
        }
    }
    
    // MARK: - Next Best Action (NEXR)
    
    func fetchNextAction(lessonId: String? = nil, currentSkill: String? = nil) async {
        do {
            let action = try await PersonalizationService.shared.getNextAction(
                lessonId: lessonId,
                currentSkill: currentSkill
            )
            
            withAnimation {
                self.nextAction = action
                
                // Optionally add a suggestion chip based on the next action
                if action.confidence > 0.7 {
                    let chip = SuggestionChip(
                        id: UUID().uuidString,
                        text: action.contentString,
                        icon: nil,
                        actionType: action.actionType.rawValue,
                        context: nil
                    )
                    // Avoid duplicates
                    if !suggestions.contains(where: { $0.text == chip.text }) {
                        suggestions.insert(chip, at: 0)
                    }
                }
            }
        } catch {
            print("⚠️ Failed to fetch next action: \(error)")
        }
    }
    
    func fetchMasteryProfile() async {
        do {
            let profile = try await PersonalizationService.shared.getMasteryProfile()
            withAnimation {
                self.masteryProfile = profile
            }
        } catch {
            print("⚠️ Failed to fetch mastery profile: \(error)")
        }
    }
    
    func updateAffectSignals(valence: Double = 0.0, arousal: Double = 0.5) async {
        guard let userId = await TokenManager.shared.getUserId() else { return }
        
        let duration = Int(Date().timeIntervalSince(sessionStartTime) / 60)
        let fatigue = min(1.0, Double(duration) / 60.0) // Simple fatigue model: 1.0 after 60 mins
        
        let update = PersonalizationStateUpdate(
            learnerId: userId,
            affect: AffectSignals(valence: valence, arousal: arousal, confidence: 0.8, source: ["app_interaction"]),
            session: SessionState(fatigue: fatigue, focus: 0.9, durationMinutes: duration),
            context: LearningContext(
                topic: uiState?.currentTab.displayName ?? "General",
                learningLevel: .intermediate,
                contentType: .conversation,
                source: .chat,
                timestamp: Date(),
                clipId: nil,
                complexity: .moderate,
                lessonId: nil,
                skill: nil
            )
        )
        
        do {
            try await PersonalizationService.shared.updateState(update: update)
        } catch {
            print("⚠️ Failed to update affect state: \(error)")
        }
    }
    
    func handleNextAction() {
        guard let action = nextAction else { return }
        
        // Clear the action after handling
        self.nextAction = nil
        
        switch action.actionType {
        case .practiceQuestion, .review, .challenge:
            // If it's a learning action, we might want to trigger a specific flow
            // For now, we'll send it as a message to let the Intent Architecture handle it
            inputText = action.contentString
            Task { await sendMessage() }
            
        case .break:
            // Show a break reminder or mindfulness view
            let breakMessage = LyoMessage(
                id: UUID().uuidString,
                content: "🧘 **Time for a quick break!**\n\n\(action.contentString)\n\nTaking short breaks helps maintain focus and prevents fatigue.",
                isFromUser: false,
                timestamp: Date(),
                status: .sent
            )
            withAnimation {
                messages.append(breakMessage)
            }
            
        default:
            inputText = action.contentString
            Task { await sendMessage() }
        }
    }
    
    // MARK: - Dynamic Remediation Bridge
    
    func handleCinemaInteractionResult(_ result: CinemaInteraction, nodeId: String) {
        if !result.isCorrect {
            // Trigger Lio intervention for remediation
            let feedback = result.metadata["feedback"] ?? "I noticed that last question was a bit tricky."
            let remediationMessage = LyoMessage(
                id: UUID().uuidString,
                content: "👋 Hey! \(feedback)\n\nWould you like me to explain this concept in a different way?",
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: [
                    MessageAction(id: "explain_remediation", label: "Yes, explain please", actionType: .quickExplainer, data: ["nodeId": nodeId]),
                    MessageAction(id: "skip_remediation", label: "I'll try again", actionType: .openDrawer, data: [:])
                ],
                status: .sent
            )
            
            withAnimation {
                messages.append(remediationMessage)
                // If chat isn't open, maybe show a notification or the floating orb
                if !isChatOpen {
                    showFloatingOrb = true
                }
            }
            
            // Speak the intervention if voice is active
            if isVoiceActive {
                speak(text: "I noticed that was tricky. Want me to explain it differently?")
            }
        } else if result.celebrationTriggered == true {
            // Trigger a celebration message
            let celebrationMessage = LyoMessage(
                id: UUID().uuidString,
                content: "🌟 **Amazing job!** You've mastered this concept. \(result.feedback ?? "")",
                isFromUser: false,
                timestamp: Date(),
                status: .sent
            )
            withAnimation {
                messages.append(celebrationMessage)
            }
        }
    }
    
    // MARK: - Message Handling (Intent-Based Architecture)
    
    // MARK: - Message Handling (Delegated to UnifiedChatService)
    
    func sendMessage(mode: String? = nil) async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageText = inputText
        let messageAttachments = attachments
        inputText = ""
        attachments = []
        
        // Update affect signals (debounced)
        if Date().timeIntervalSince(lastAffectUpdate) > 30 {
            lastAffectUpdate = Date()
            Task.detached(priority: .background) { [weak self] in
                await self?.updateAffectSignals(valence: 0.1, arousal: 0.6)
            }
        }
        
        // No manual loading state needed, observed from service
        
        // Delegate to Unified Chat Service
        let responseText = await unifiedChat.sendMessage(
            messageText,
            attachments: messageAttachments,
            context: nil, // Can be improved to pass current context
            mode: mode ?? uiState?.currentAIMode ?? "focus"
        )
        
        // Auto-speak response if in voice mode
        if isVoiceActive, let text = responseText {
            speak(text: text)
        }
    }
    
    // MARK: - A2UI Interactions
    
    func onA2UICourseStart(course: CourseCreationData) {
        print("🚀 LyoAIViewModel: Starting A2UI course -> \(course.title)")
        HapticManager.shared.playSuccess()
        unifiedChat.pendingCourse = course
        unifiedChat.triggerCourseNavigation()
    }
    
    func onA2UIQuizAnswer(question: String, answerIndex: Int) {
        print("✍️ LyoAIViewModel: Quiz answer -> \(answerIndex)")
        HapticManager.shared.playLightImpact()
        // Send answer to AI
        inputText = "My answer to '\(question)' is option \(answerIndex + 1)"
        Task { await sendMessage() }
    }
    
    // MARK: - A2UI Action Handler (DISABLED - A2UI Parser not currently in build)
    
    // @MainActor
    // private func handleA2UIAction(_ action: A2UIAction) async {
    //     switch action {
    //     case .openClassroom(let payload):
    //         print("🎬 A2UI Trigger: Opening Classroom for \(payload.title)")
    //         // Tell Orchestrator to start the show
    //         // This triggers the view transition via NotificationCenter
    //         await CourseOrchestrator.shared.execute(proposal: payload)
    //         
    //     case .addToStack(let item):
    //          print("📚 A2UI Trigger: Added to stack \(item.title)")
    //          // Implementation for stack addition would go here
    //          
    //     case .navigate(let destination):
    //          print("🧭 A2UI Trigger: Navigating to \(destination)")
    //     }
    // }


    private func chatErrorMessage(for error: Error) -> String {
        let lyoError = LyoError.from(error: error)

        switch lyoError {
        case .network(.unauthorized):
            return "You're signed out. Please log in to chat."

        case .network(.noInternetConnection):
            return "No internet connection. Please try again."

        case .network(.timeout):
            return "The request timed out. Please try again."

        case .network(.serverError):
            return "The server is having trouble right now. Please try again in a bit."

        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."

        case .network(.connectionFailed):
            return "I'm having trouble reaching the server. Please try again."

        default:
            return "Something went wrong. Please try again."
        }
    }
    
    // MARK: - Full Course Generation (Only after wizard approval)
    
    private func startFullCourseGeneration(topic: String, level: String) async {
        print("🚀 Starting course generation for: \(topic)")
        isGeneratingCourse = true
        
        // Update last message to show progress
        if let lastIndex = messages.indices.last {
            messages[lastIndex] = LyoMessage(
                id: messages[lastIndex].id,
                content: "🔨 Creating your course on **\(topic)**...",
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .sent
            )
        }
        
        do {
            // Use InteractiveCinemaService which has proper fallback chain:
            // Backend → OpenAI → Mock (all via CourseGenerationService)
            print("🎬 Generating course via InteractiveCinemaService")
            let graphCourse = try await cinemaService.generateGraphCourse(
                topic: topic,
                level: level
            )
            
            print("✅ Course generated: \(graphCourse.title)")
            
            // Navigate using the ACTUAL course ID (mock_ if backend failed, gen_ if succeeded)
            // This ensures LiveClassroomViewModel can find it in CourseGenerationService.shared.generatedCourse
            let payload = CoursePayload(
                id: graphCourse.id,
                title: graphCourse.title,
                topic: topic,
                level: level,
                language: "English",
                duration: "\(graphCourse.estimatedMinutes) min",
                objectives: []
            )
            
            // Navigate to classroom
            let commandPayload = AICommandPayload(stackItem: nil, course: payload)
            _ = AICommandHandler.shared.handleOpenClassroom(commandPayload)
            
            // Show success message
            let successMessage = LyoMessage(
                id: UUID().uuidString,
                content: """
                ✅ **Course Ready: \(graphCourse.title)**
                
                Opening classroom now...
                """,
                isFromUser: false,
                timestamp: Date(),
                status: .sent
            )
            messages.append(successMessage)
            
        } catch {
            print("❌ Course generation failed completely: \(error)")
            addErrorMessage("I had trouble creating that course. Please try again.")
        }
        
        isGeneratingCourse = false
    }
    
    // MARK: - A2A Multi-Agent Course Generation
    
    /// Generate a course using the A2A multi-agent pipeline
    /// This uses 5 specialized AI agents: Pedagogy, Cinematic Director, Visual Director, Voice Agent, QA Checker
    @Published var showA2AProgressView: Bool = false
    @Published var a2aGenerationTopic: String = ""
    @Published var a2aGenerationTier: CourseQualityTier = .standard
    
    func startA2ACourseGeneration(topic: String, qualityTier: CourseQualityTier = .standard) {
        print("🤖 Starting A2A multi-agent course generation for: \(topic)")
        
        a2aGenerationTopic = topic
        a2aGenerationTier = qualityTier
        isGeneratingCourse = true
        
        // Show progress message
        let startMessage = LyoMessage(
            id: UUID().uuidString,
            content: """
            🤖 **Starting Multi-Agent Course Generation**
            
            I'm assembling a team of AI experts to create your course:
            
            📚 **Pedagogy Agent** - Learning science & structure
            🎬 **Cinematic Director** - Story & scene design
            🎨 **Visual Director** - Image & diagram specs
            🔊 **Voice Agent** - Audio & narration
            ✅ **QA Checker** - Quality validation
            
            This usually takes 2-3 minutes for the best results...
            """,
            isFromUser: false,
            timestamp: Date(),
            status: .sent
        )
        messages.append(startMessage)
        
        // Show the A2A progress view
        showA2AProgressView = true
    }
    
    func handleA2AGenerationComplete(course: A2AGeneratedCourse) {
        print("✅ A2A course generation complete: \(course.title)")
        
        isGeneratingCourse = false
        showA2AProgressView = false
        
        // Convert A2A course to legacy format for compatibility
        _ = A2ACourseService.shared.convertToLegacyFormat(course)
        
        // Create success message with course details
        let successMessage = LyoMessage(
            id: UUID().uuidString,
            content: """
            🎉 **Your Multi-Agent Course is Ready!**
            
            **\(course.title)**
            \(course.modules.count) modules • \(course.estimatedDuration) min
            
            This course was crafted by 5 AI agents working together to ensure the highest quality learning experience.
            """,
            isFromUser: false,
            timestamp: Date(),
            actions: [
                MessageAction(
                    id: "start_a2a_course",
                    label: "🎬 Start Learning",
                    actionType: .openClassroom,
                    data: ["courseId": course.id]
                )
            ],
            status: .sent
        )
        messages.append(successMessage)
        
        // Trigger the course detail sheet via AppUIState
        if let uiState = self.uiState {
            let contentItem = ContentItem(
                id: course.id,
                type: .anchorCourse,
                title: course.title,
                description: course.description,
                coverImage: "sparkles",
                duration: TimeInterval(course.estimatedDuration * 60),
                author: ContentAuthor(
                    name: "A2A Multi-Agent System",
                    avatar: "sparkles",
                    role: "AI Course Generation Pipeline"
                ),
                tags: [a2aGenerationTopic, "A2A", "Multi-Agent"],
                level: course.difficulty == "advanced" ? .advanced : course.difficulty == "intermediate" ? .intermediate : .beginner,
                stats: ContentStats(views: 1, likes: 0, rating: 5.0),
                progress: 0.0,
                childContentIds: []
            )
            
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                uiState.courseToDisplay = contentItem
                uiState.showCourseDetail = true
            }
        }
    }
    
    func handleA2AGenerationCancelled() {
        print("⚠️ A2A course generation cancelled")
        
        isGeneratingCourse = false
        showA2AProgressView = false
        
        let cancelMessage = LyoMessage(
            id: UUID().uuidString,
            content: "Course generation cancelled. Let me know when you'd like to try again!",
            isFromUser: false,
            timestamp: Date(),
            status: .sent
        )
        messages.append(cancelMessage)
    }
    
    // MARK: - Helper Methods
    
    private func convertAction(_ action: LioChatAction) -> [MessageAction] {
        var actionType: MessageAction.ActionType
        
        switch action.type {
        case "open_classroom":
            actionType = .openClassroom
        case "create_course":
            actionType = .createCourse
        case "start_quiz":
            actionType = .quizMe
        case "open_drawer":
            actionType = .openDrawer
        default:
            // Fallback for unknown actions or map to a generic type
            actionType = .openDrawer
        }
        
        return [
            MessageAction(
                id: UUID().uuidString,
                label: "Action", // Could improve label based on type
                actionType: actionType,
                data: action.parameters
            )
        ]
    }
    
    // addWizardResponse removed (legacy)

    
    private func addErrorMessage(_ text: String) {
        let errorMessage = LyoMessage(
            id: UUID().uuidString,
            content: text,
            isFromUser: false,
            timestamp: Date(),
            attachments: nil,
            actions: nil,
            status: .sent
        )
        messages.append(errorMessage)
    }

    // MARK: - Data Loading
    
    func loadSocialData() async {
        do {
            // Load Posts
            let feedResponse = try await socialRepository.getPosts(page: 1, limit: 10, algorithm: nil)
            self.socialPosts = feedResponse.posts
            
            // Load Suggested Users (Mock)
             let users = [
                User(id: 2001, email: "sarah@example.com", name: "Sarah Chen", avatarURL: nil, createdAt: Date(), level: 12, xp: 4500, streak: 15, totalLessonsCompleted: 42, achievements: []),
                User(id: 2002, email: "mike@example.com", name: "Mike Ross", avatarURL: nil, createdAt: Date(), level: 8, xp: 2100, streak: 3, totalLessonsCompleted: 18, achievements: []),
                User(id: 2003, email: "jess@example.com", name: "Jessica Pearson", avatarURL: nil, createdAt: Date(), level: 25, xp: 15000, streak: 140, totalLessonsCompleted: 300, achievements: [])
            ]
            self.suggestedUsers = users
            
        } catch {
            print("❌ Error loading social data: \(error)")
        }
    }
    
    // Helper to detect actionable content in AI responses
    private func detectActions(in response: String) -> [MessageAction]? {
        var actions: [MessageAction] = []
        let lowercased = response.lowercased()
        
        if lowercased.contains("course") || lowercased.contains("curriculum") {
            actions.append(MessageAction(
                        id: "action_create_\(UUID().uuidString)",
                        label: "Create Course",
                        actionType: .createCourse,
                        data: nil
                    ))
        }
        
        if lowercased.contains("quiz") || lowercased.contains("test") || lowercased.contains("question") {
            actions.append(MessageAction(
                        id: "action_quiz_\(UUID().uuidString)",
                        label: "Start Quiz",
                        actionType: .quizMe,
                        data: nil
                    ))
        }
        
        if lowercased.contains("flashcard") {
            actions.append(MessageAction(
                id: "flashcards",
                label: "Make Flashcards",
                actionType: .makeFlashcards,
                data: nil
            ))
        }
        
        return actions.isEmpty ? nil : actions
    }
    
    func executeAction(_ action: MessageAction) {
        switch action.actionType {
        case .createCourse:
            createCourse(with: action.data)
        case .createCourseA2A:
            // A2A Multi-Agent Course Generation
            let topic = action.data?["topic"] ?? messages.last(where: { $0.isFromUser })?.content ?? "General Knowledge"
            startA2ACourseGeneration(topic: topic)
        case .quizMe:
            startQuiz(with: action.data)
        case .addToLibrary:
            addToLibrary(with: action.data)
        case .openDrawer:
            openDrawer()
        case .generateSyllabus:
            generateSyllabus(with: action.data)
        case .quickExplainer:
            requestQuickExplainer(with: action.data)
        case .makeFlashcards:
            makeFlashcards(with: action.data)
        case .extractKeyPoints:
            extractKeyPoints(with: action.data)
        case .openClassroom:
            // Extract details from action data
            guard let data = action.data, 
                  let courseId = data["courseId"] else {
                print("⚠️ openClassroom action missing courseId")
                return
            }
            
            let title = data["courseTitle"] ?? "New Course"
            let topic = data["topic"] ?? "Learning"
            let levelStr = data["level"] ?? "beginner"
            
            // Create a ContentItem to trigger the detail sheet
            // We use .anchorCourse as the type for now
            let contentItem = ContentItem(
                id: courseId,
                type: .anchorCourse,
                title: title,
                description: "Interactive course on \(topic)",
                coverImage: "book.fill", // Default icon
                duration: 1200, // Default 20 mins
                author: ContentAuthor(
                    name: "Lio AI",
                    avatar: "sparkles",
                    role: "AI Learning Assistant"
                ),
                tags: [topic, levelStr.capitalized],
                level: levelStr.lowercased() == "advanced" ? .advanced : levelStr.lowercased() == "intermediate" ? .intermediate : .beginner,
                stats: ContentStats(views: 0, likes: 0, rating: 0),
                progress: 0.0,
                childContentIds: []
            )
            
            print("📱 Opening classroom for course: \(courseId)")
            
            DispatchQueue.main.async {
                if let uiState = self.uiState {
                    uiState.courseToDisplay = contentItem
                    uiState.showCourseDetail = true
                }
            }
        }
    }
    
    func executeSuggestion(_ chip: SuggestionChip) {
        inputText = chip.text
        Task {
            await sendMessage()
        }
    }
    
    // MARK: - Drawer Management
    
    func toggleDrawer() {
        if isDrawerOpen {
            closeDrawer()
        } else {
            openDrawer()
        }
    }
    
    func openDrawer() {
        isDrawerOpen = true
        if !isDrawerPinned {
            startAutoCloseTimer()
        }
    }
    
    func closeDrawer() {
        isDrawerOpen = false
        drawerAutoCloseTimer?.invalidate()
        drawerAutoCloseTimer = nil
    }
    
    func toggleDrawerPin() {
        isDrawerPinned.toggle()
        if isDrawerPinned {
            drawerAutoCloseTimer?.invalidate()
            drawerAutoCloseTimer = nil
        } else if isDrawerOpen {
            startAutoCloseTimer()
        }
    }
    
    private func startAutoCloseTimer() {
        drawerAutoCloseTimer?.invalidate()
        drawerAutoCloseTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.closeDrawer()
            }
        }
    }
    
    func continueCourse(_ card: CourseCard) {
        closeDrawer()
        // Navigate to course - would be handled by navigation coordinator
        print("Continuing course: \(card.title)")
    }
    
    // MARK: - Attachment Handling
    
    func addAttachment(_ attachment: MessageAttachment) {
        attachments.append(attachment)
        updateSuggestionsForUpload()
    }
    
    func removeAttachment(_ attachment: MessageAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        if attachments.isEmpty {
            loadInitialSuggestions()
        }
    }
    
    func uploadFile(url: URL) async {
        isUploadingFile = true
        do {
            let attachment = try await repository.uploadFile(url: url)
            addAttachment(attachment)
        } catch {
            print("Error uploading file: \(error)")
        }
        isUploadingFile = false
    }
    
    // MARK: - Suggestions
    
    func loadInitialSuggestions() {
        suggestions = [
            SuggestionChip(id: "1", text: "Teach me something new", icon: "sparkles", actionType: "learn", context: nil),
            SuggestionChip(id: "2", text: "Create a course for me", icon: "plus.circle", actionType: "create_course", context: nil),
            SuggestionChip(id: "3", text: "🤖 Multi-Agent Course", icon: "cpu", actionType: "create_course_a2a", context: nil),
            SuggestionChip(id: "4", text: "Quiz me on a topic", icon: "questionmark.circle", actionType: "quiz", context: nil)
        ]
    }
    
    func updateSuggestionsForUpload() {
        suggestions = [
            SuggestionChip(id: "u1", text: "Extract key points", icon: "list.star", actionType: "extract", context: nil),
            SuggestionChip(id: "u2", text: "Turn into a course", icon: "plus.circle", actionType: "create_course", context: nil),
            SuggestionChip(id: "u3", text: "Quiz me on this", icon: "questionmark.circle", actionType: "quiz", context: nil),
            SuggestionChip(id: "u4", text: "Make flashcards", icon: "rectangle.stack", actionType: "flashcards", context: nil)
        ]
    }
    
    // MARK: - Course Cards
    
    func loadCourseCards() async {
        do {
            let chatCourses = try await repository.getChatCourses()
            let cards: [CourseCard] = chatCourses.map { course in
                let tags = [course.topic, course.difficulty].filter { !$0.isEmpty }
                let timeLeft: String?
                if let hours = course.estimatedHours {
                    timeLeft = String(format: "%.1fh", hours)
                } else {
                    timeLeft = nil
                }

                return CourseCard(
                    id: course.id,
                    title: course.title,
                    description: course.description ?? course.topic,
                    coverURL: nil,
                    progress: nil,
                    timeLeft: timeLeft,
                    lastOpened: course.updatedAt,
                    tags: tags,
                    status: course.isPublished ? .started : .suggested
                )
            }

            self.startedCards = cards.filter { $0.status == .started }
            self.suggestedCards = cards.filter { $0.status == .suggested }
            self.continueCards = []
        } catch {
            print("Error loading course cards: \(error)")

            if AppConfig.allowMockFallbacks {
                self.startedCards = [
                    CourseCard(
                        id: "c1",
                        title: "Python for Data Science",
                        description: "Master Python libraries for data analysis",
                        coverURL: nil,
                        progress: 0.45,
                        timeLeft: "2h left",
                        lastOpened: Date(),
                        tags: ["Python", "Data"],
                        status: .started
                    )
                ]
                self.suggestedCards = [
                    CourseCard(
                        id: "c2",
                        title: "SwiftUI Mastery",
                        description: "Build beautiful iOS apps",
                        coverURL: nil,
                        progress: 0,
                        timeLeft: "10h",
                        lastOpened: nil,
                        tags: ["iOS", "Swift"],
                        status: .suggested
                    )
                ]
                self.continueCards = []
            } else {
                self.startedCards = []
                self.suggestedCards = []
                self.continueCards = []
            }
        }
    }
    
    // MARK: - Action Implementations
    
    private func createCourse(with data: [String: String]?) {
        let topic = data?["topic"] ?? messages.last(where: { $0.isFromUser })?.content ?? "General Knowledge"
        print("Creating course for: \(topic)")
        
        // Trigger the standard course creation wizard flow via implicit message
        inputText = "Create a course about \(topic)"
        Task {
            await sendMessage()
        }
    }
    
    private func startQuiz(with data: [String: String]?) {
        print("Starting quiz with data: \(data ?? [:])")
        
        Task {
            await MainActor.run { isLoading = true }
            
            let topic = data?["topic"] ?? messages.last(where: { $0.isFromUser })?.content ?? "General Knowledge"
            
            do {
                // Generate structured quiz
                let quiz = try await OpenAIService.shared.generateStructuredQuiz(topic: topic)
                
                await MainActor.run {
                    self.activeQuiz = quiz
                    self.isQuizActive = true
                    
                    let message = LyoMessage(
                        id: UUID().uuidString,
                        content: "I've prepared a quiz on **\(topic)** for you! Good luck! 🍀",
                        isFromUser: false,
                        timestamp: Date(),
                        attachments: nil,
                        actions: nil,
                        status: .sent
                    )
                    messages.append(message)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.addErrorMessage("I couldn't generate the quiz right now. Please try again.")
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addToLibrary(with data: [String: String]?) {
        print("Adding to library: \(data ?? [:])")
        guard let topic = data?["topic"] else { return }
        
        Task {
            await MainActor.run { isLoading = true }
            
            do {
                // Generate graph-based course using Interactive Cinema
                print("🎬 [Library] Generating Interactive Cinema course for: \(topic)")
                let graphCourse = try await cinemaService.generateGraphCourse(
                    topic: topic,
                    level: "beginner"
                )
                
                print("✅ [Library] Graph course generated: \(graphCourse.title)")
                
                // Convert GraphCourseItem to ContentItem
                let course = ContentItem(
                    id: graphCourse.id,
                    type: .anchorCourse,
                    title: graphCourse.title,
                    description: graphCourse.description,
                    coverImage: "book.fill",
                    duration: TimeInterval(graphCourse.estimatedMinutes * 60), // Convert minutes to seconds
                    author: ContentAuthor(
                        name: "Lio AI",
                        avatar: "sparkles",
                        role: "AI Learning Assistant"
                    ),
                    tags: [topic, graphCourse.gradeBand, "Interactive Cinema"],
                    level: graphCourse.gradeBand.lowercased() == "advanced" ? .advanced : graphCourse.gradeBand.lowercased() == "intermediate" ? .intermediate : .beginner,
                    stats: ContentStats(
                        views: 1,
                        likes: 0,
                        rating: 5.0
                    ),
                    progress: 0.0,
                    childContentIds: [] // Graph courses don't have child IDs in the same way
                )
                
                await MainActor.run {
                    let successMsg = LyoMessage(
                        id: UUID().uuidString,
                        content: "✅ Course '**\(course.title)**' has been created! Opening course details...",
                        isFromUser: false,
                        timestamp: Date(),
                        attachments: nil,
                        actions: [
                            MessageAction(id: "view_course", label: "View Course", actionType: .openDrawer, data: ["courseId": course.id])
                        ],
                        status: .sent
                    )
                    messages.append(successMsg)
                    isLoading = false
                    
                    // Display course in detail sheet
                    uiState?.courseToDisplay = course
                    uiState?.showCourseDetail = true
                    
                    // Refresh cards
                    Task { await loadCourseCards() }
                }
            } catch {
                await MainActor.run {
                    let errorMsg = LyoMessage(
                        id: UUID().uuidString,
                        content: "Failed to create the course. Please try again. Error: \(error.localizedDescription)",
                        isFromUser: false,
                        timestamp: Date(),
                        attachments: nil,
                        actions: nil,
                        status: .failed
                    )
                    messages.append(errorMsg)
                    isLoading = false
                }
            }
        }
    }
    
    private func generateSyllabus(with data: [String: String]?) {
        print("Generating syllabus with data: \(data ?? [:])")
    }
    
    private func requestQuickExplainer(with data: [String: String]?) {
        print("Requesting quick explainer: \(data ?? [:])")
    }
    
    private func makeFlashcards(with data: [String: String]?) {
        print("Making flashcards: \(data ?? [:])")
    }
    
    private func extractKeyPoints(with data: [String: String]?) {
        print("Extracting key points: \(data ?? [:])")
    }
    
    
    // MARK: - History Loading
    
    @available(iOS 17.0, *)
    func loadHistory(from session: ChatSession) {
        isLoading = true
        
        // Convert stored ChatMessages to ViewModel LyoMessages
        let historyMessages = session.messages.sorted { $0.timestamp < $1.timestamp }.map { storedMsg -> LyoMessage in
            // Reconstruct actions if any (we store them as nil in simple mock usually, but ideally should be persisted)
            // For now, simple text reconstruction
            return LyoMessage(
                id: storedMsg.id.uuidString,
                content: storedMsg.text,
                isFromUser: storedMsg.isUser,
                timestamp: storedMsg.timestamp,
                attachments: nil, // Attachments persistence pending
                actions: nil, // Action persistence pending
                status: .sent
            )
        }
        
        self.messages = historyMessages
        self.isLoading = false
        
        // If empty (shouldn't be), add a starter
        if self.messages.isEmpty {
            self.messages.append(LyoMessage(
                id: UUID().uuidString,
                content: session.lastMessage,
                isFromUser: false,
                timestamp: session.timestamp,
                attachments: nil,
                actions: nil,
                status: .sent
            ))
        }
    }
    
    // MARK: - Multimodal Voice Input
    
    func startVoiceRecording() {
        Task {
            do {
                try await voiceInputService.startRecording()
                isRecordingVoice = true
                HapticManager.shared.playRecordingStarted()
                
                // Bind audio level for waveform visualization
                voiceInputService.$audioLevel
                    .receive(on: RunLoop.main)
                    .assign(to: &$voiceInputLevel)
            } catch {
                print("❌ Failed to start voice recording: \(error)")
                isRecordingVoice = false
            }
        }
    }
    
    func stopVoiceRecording() {
        Task {
            voiceInputService.stopRecording()
            isRecordingVoice = false
            HapticManager.shared.playRecordingStopped()
            
            // Get transcript from the service's published property
            let text = voiceInputService.transcript
            if !text.isEmpty {
                inputText = text
            }
        }
    }
    
    func cancelVoiceRecording() {
        voiceInputService.cancelRecording()
        isRecordingVoice = false
        HapticManager.shared.playLightImpact()
    }
    
    // MARK: - Multimodal TTS Playback
    
    func playMessageAudio(messageId: String, text: String) {
        // Use local TTS instead of AudioPlaybackService for reliability
        speak(text: text, messageId: messageId)
    }
    
    func stopMessageAudio() {
        stopSpeaking()
    }
    
    func toggleMessageAudio(messageId: String, text: String) {
        if currentlyPlayingMessageId == messageId {
            stopSpeaking()
        } else {
            stopSpeaking() // Stop any previous
            playMessageAudio(messageId: messageId, text: text)
        }
    }
    
    // MARK: - Multimodal Media Handling
    
    func handlePickedMedia(_ media: PickedMedia) {
        Task {
            isUploadingFile = true
            
            do {
                let attachment = try await mediaPickerService.uploadMedia(media)
                addAttachment(attachment)
                HapticManager.shared.playSuccess()
            } catch {
                print("❌ Media upload failed: \(error)")
                addErrorMessage("Failed to upload \(media.type.rawValue). Please try again.")
                HapticManager.shared.playError()
            }
            
            isUploadingFile = false
        }
    }
    
    func sendMessageWithAttachments(text: String, attachments: [MessageAttachment]) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty else { return }
        
        inputText = ""
        self.attachments = []
        
        // Delegate to UnifiedChatService
        let responseText = await unifiedChat.sendMessage(
            text,
            attachments: attachments,
            context: nil,
            mode: uiState?.currentAIMode ?? "focus"
        )
        
        HapticManager.shared.playMessageSent()
        
        // Auto-speak response if in voice mode
        if isVoiceActive, let text = responseText {
            speak(text: text)
        }
    }
    // MARK: - Navigation Triggers
    
    func openCourse(id: String) {
        print("🚀 Opening course: \(id)")
        
        let placeholderItem = ContentItem(
            id: id,
            type: .anchorCourse,
            title: "Loading Course...",
            description: "Preparing your personalized curriculum...",
            coverImage: "book.fill",
            duration: 0,
            author: ContentAuthor(name: "Lio AI", avatar: "sparkles", role: "AI"),
            tags: ["AI Generated"],
            level: .beginner,
            stats: ContentStats(views: 0, likes: 0, rating: 0),
            progress: 0,
            childContentIds: []
        )
        
        Task { @MainActor in
            self.uiState?.courseToDisplay = placeholderItem
            self.uiState?.showCourseDetail = true
        }
    }

}


