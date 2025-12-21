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
    
    // MARK: - Social Data (Mock)
    @Published var socialPosts: [RepoPost] = []
    @Published var suggestedUsers: [User] = []
    
    // MARK: - Dependencies
    private let repository = LyoRepository.shared // Backend missing AI endpoints
    private let aiService = OpenAIService.shared // Legacy: Used for Quiz generation only
    private let ttsService = TextToSpeechService.shared
    private let sttService = SpeechToTextService.shared
    private let cinemaService = InteractiveCinemaService.shared // NEW: Graph-based courses
    private let socialRepository: SocialRepository = LyoRepository.shared as SocialRepository
    private var drawerAutoCloseTimer: Timer?
    
    // UI State reference (injected)
    var uiState: AppUIState?
    private var cancellables = Set<AnyCancellable>()
    
    // Course wizard state
    @Published var currentOutline: CourseOutline?
    @Published var isGeneratingCourse: Bool = false
    
    init(uiState: AppUIState? = nil) {
        self.uiState = uiState
        loadInitialSuggestions()
        setupVoiceBindings()
        Task {
            await loadSocialData()
            await loadCourseCards()
        }
    }
    
    private func setupVoiceBindings() {
        sttService.$transcribedText
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
            guard let self = self, self.isVoiceActive else { return }
            self.startListening()
        }
        
        // Barge-in: Stop AI speaking when user speech is detected
        sttService.onSpeechDetected = { [weak self] in
            self?.stopSpeaking()
        }
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
        
        sttService.requestAuthorization()
        do {
            try sttService.startRecording()
            isVoiceActive = true
        } catch {
            print("Failed to start recording: \(error)")
            isVoiceActive = false
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
    
    func speak(text: String) {
        ttsService.speak(text: text)
        // Ensure we are listening for barge-in
        if !sttService.isRecording {
            startListening()
        }
    }
    
    func stopSpeaking() {
        ttsService.stop()
    }
    
    // MARK: - Proactive Greeting
    
    func fetchProactiveGreeting() async {
        // Only fetch if we don't have any messages yet (new session)
        guard messages.isEmpty else { return }
        
        isLoading = true
        do {
            let response = try await LioChatService.shared.getProactiveGreeting()
            
            let greetingMessage = LyoMessage(
                id: UUID().uuidString,
                content: response.greeting,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .sent
            )
            
            withAnimation {
                messages.append(greetingMessage)
            }
            
            // If voice is active, speak the greeting
            if isVoiceActive {
                speak(text: response.greeting)
            }
        } catch {
            print("⚠️ Failed to fetch proactive greeting: \(error)")
        }
        isLoading = false
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
                        text: action.content,
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
            context: LearningContext(topic: uiState?.currentTab.displayName)
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
            inputText = action.content
            Task { await sendMessage() }
            
        case .break:
            // Show a break reminder or mindfulness view
            let breakMessage = LyoMessage(
                id: UUID().uuidString,
                content: "🧘 **Time for a quick break!**\n\n\(action.content)\n\nTaking short breaks helps maintain focus and prevents fatigue.",
                isFromUser: false,
                timestamp: Date(),
                status: .sent
            )
            withAnimation {
                messages.append(breakMessage)
            }
            
        default:
            inputText = action.content
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
    
    // MARK: - Message Handling (Delegated to LioChatService)
    
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageText = inputText
        let messageAttachments = attachments
        inputText = ""
        attachments = []
        
        // Create user message
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            content: messageText,
            isFromUser: true,
            timestamp: Date(),
            attachments: messageAttachments.isEmpty ? nil : messageAttachments,
            actions: nil,
            status: .sent
        )
        
        // Optimistically add message
        messages.append(userMessage)
        
        // Update affect signals (interaction detected)
        Task {
            await updateAffectSignals(valence: 0.1, arousal: 0.6)
        }
        
        isLoading = true
        
        do {
            // Use the SINGLE SOURCE OF TRUTH: LioChatService
            let response = try await LioChatService.shared.sendMessage(
                text: messageText,
                mode: uiState?.currentAIMode ?? "focus"
            )
            
            // Map actions from response
            var messageActions: [MessageAction]? = nil
            if let action = response.action {
                // Determine action type
                let type: MessageAction.ActionType
                switch action.type {
                case "start_tutor": type = .quickExplainer
                case "start_quiz": type = .quizMe
                case "generate_course": type = .createCourse
                case "open_course": type = .openClassroom
                default: type = .quickExplainer
                }
                
                messageActions = [
                    MessageAction(
                        id: UUID().uuidString,
                        label: action.type.replacingOccurrences(of: "_", with: " ").capitalized,
                        actionType: type,
                        data: action.parameters
                    )
                ]
                
                // If it's a course generation request, update internal state or trigger full generation if needed
                if action.type == "generate_course", let params = action.parameters, let topic = params["topic"] {
                    // Check if we need to auto-trigger something, usually we wait for user to confirm via wizard
                    _ = topic
                }
            }
            
            let aiMessage = LyoMessage(
                id: UUID().uuidString,
                content: response.text,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: messageActions,
                status: .sent
            )
            
            withAnimation {
                messages.append(aiMessage)
                isLoading = false
            }
            
            // Update suggestions if provided by service
            if let newSuggestions = response.suggestions {
                self.suggestions = newSuggestions.enumerated().map { index, text in
                    SuggestionChip(id: UUID().uuidString, text: text, icon: "sparkles")
                }
            } else {
                // Keep existing or clear? Usually keep unless wizard flow changes them.
            }
            
            // Auto-speak response if in voice mode
            if isVoiceActive {
                speak(text: response.text)
            }
            
        } catch {
            print("❌ LioChatService Error: \(error)")
            await MainActor.run {
                isLoading = false
                addErrorMessage("I'm having trouble connecting. Please try again.")
            }
        }
    }
    
    // MARK: - Full Course Generation (Only after wizard approval)
    
    private func startFullCourseGeneration(topic: String, level: String) async {
        print("🚀 Starting FULL course generation for: \(topic) at \(level) level")
        
        isGeneratingCourse = true
        
        // Update last message to show progress
        if let lastIndex = messages.indices.last {
            messages[lastIndex] = LyoMessage(
                id: messages[lastIndex].id,
                content: "🔨 Building your course on **\(topic)**... This takes about 30 seconds.",
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .sent
            )
        }
        
        do {
            // Generate graph-based course using Interactive Cinema
            print("🎬 Generating Interactive Cinema course for: \(topic)")
            let graphCourse = try await cinemaService.generateGraphCourse(
                topic: topic,
                level: level
            )
            
            print("✅ Graph course generated: \(graphCourse.title) with \(graphCourse.totalNodes) nodes")
            
            // Start cinematic playback (requires auth token)
            let playbackState = try await cinemaService.startCourse(courseId: graphCourse.id)
            
            print("✅ Cinematic playback started at node: \(playbackState.currentNode.title)")
            
            // Reset wizard
            // courseWizard.reset() // Legacy
            // intentClassifier.resetWizard() // Legacy

            
            // Create ContentItem for the course detail sheet
            let contentItem = ContentItem(
                id: graphCourse.id,
                type: .anchorCourse,
                title: graphCourse.title,
                description: graphCourse.description,
                coverImage: "book.fill",
                duration: TimeInterval(graphCourse.estimatedMinutes * 60),
                author: ContentAuthor(
                    name: "Lio AI",
                    avatar: "sparkles",
                    role: "AI Learning Assistant"
                ),
                tags: [topic, level.capitalized, "Interactive Cinema"],
                level: level.lowercased() == "advanced" ? .advanced : level.lowercased() == "intermediate" ? .intermediate : .beginner,
                stats: ContentStats(
                    views: 1,
                    likes: 0,
                    rating: 5.0
                ),
                progress: 0.0,
                childContentIds: [] // Graph courses use nodes, not modules
            )
            
            // Show success message
            let successMessage = LyoMessage(
                id: UUID().uuidString,
                content: """
                🎉 **Your Interactive Cinema course is ready!**
                
                **\(graphCourse.title)**
                \(graphCourse.totalNodes) nodes • \(graphCourse.estimatedMinutes) min
                
                Opening cinematic experience now...
                """,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: [
                    MessageAction(id: "view_course", label: "Start Experience", actionType: .openClassroom, data: ["courseId": graphCourse.id])
                ],
                status: .sent
            )
            messages.append(successMessage)
            
            // Trigger the course detail sheet via AppUIState
            if let uiState = self.uiState {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay for UX
                uiState.courseToDisplay = contentItem
                uiState.showCourseDetail = true
            }
            
        } catch {
            print("❌ Course generation failed: \(error)")
            
            // courseWizard.reset()
            // intentClassifier.resetWizard()

            
            addErrorMessage("😕 I had trouble creating that course. Let's try again - what topic would you like to learn?")
        }
        
        isGeneratingCourse = false
    }
    
    // MARK: - Helper Methods
    
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
            // Handled by parent view
            break
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
            SuggestionChip(id: "3", text: "Explain like I'm 5", icon: "face.smiling", actionType: "eli5", context: nil),
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
                let quiz = try await aiService.generateStructuredQuiz(topic: topic)
                
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
}


