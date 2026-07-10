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
    @Published var isAISpeaking: Bool = false
    @Published var isAIThinking: Bool = false
    @Published var isAudioOutputEnabled: Bool = true
    @Published var isLiveMode: Bool = false
    @Published var lastLiveTranscript: String = ""
    @Published var showFloatingOrb: Bool = false
    @Published var userLiveAudioLevel: Float = 0.0
    @Published var aiLiveAudioLevel: Float = 0.0
    @Published var activeLiveWidget: [String: Any]? = nil
    @Published var showA2AProgressView: Bool = false
    
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

    /// Stage A.5 — multi-turn intent + slot accumulation across the
    /// active conversation. Reset on conversation clear / load.
    private var conversationState = ConversationState()

    /// Stage B5 — fires the proactive welcome-back greeting at most once
    /// per app launch. Loading a saved conversation also flips this on so
    /// we don't drop a greeting on top of restored history.
    private var hasGreetedThisSession: Bool = false
    
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

        // Stage B1 — pull the persistent learning profile so Lyo's first
        // turn can reference past sessions ("Last time we worked on X...").
        // Stage B2 — fetch active study plans so they're available to the
        // greeting + chat-context line.
        // Best-effort: 401 / unauthenticated is silently ignored.
        // Stage B5 — once both arrive, surface a context-aware greeting
        // if the chat thread is empty.
        Task { @MainActor in
            async let _profile: LearningProfile? = LearningProfileService.shared.fetchIfNeeded()
            async let _plans: [StudyPlanRecord] = StudyPlanService.shared.fetchIfNeeded()
            _ = await (_profile, _plans)
            self.maybeInjectProactiveGreeting()
        }

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

    func toggleLiveMode() {
        isLiveMode.toggle()
        if isLiveMode {
            startListening()
        } else {
            stopListening()
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
        } catch LyoError.network(.notFound) {
            // Endpoint not yet deployed — silently skip
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
        } catch LyoError.network(.notFound) {
            // Endpoint not yet deployed — silently skip
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
                learningLevel: .beginner,
                contentType: .conversation,
                source: .chat
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
        
        // Update affect signals (debounced - only every 30 seconds to prevent overwhelming server)
        if Date().timeIntervalSince(lastAffectUpdate) > 30 {
            lastAffectUpdate = Date()
            Task.detached(priority: .background) { [weak self] in
                await self?.updateAffectSignals(valence: 0.1, arousal: 0.6)
            }
        }

        let recentContext = Array(messages.dropLast())
        switch QuizExperienceFactory.classify(messageText) {
        case .create(let mode):
            let quizMessage = QuizExperienceFactory.makeQuizMessage(
                for: messageText,
                mode: mode,
                recentMessages: recentContext
            )
            withAnimation {
                messages.append(quizMessage)
            }
            suggestions = [
                SuggestionChip(id: UUID().uuidString, text: "Make Harder", icon: "flame.fill", actionType: "quiz", context: nil),
                SuggestionChip(id: UUID().uuidString, text: "Review Mistakes", icon: "arrow.counterclockwise.circle.fill", actionType: "quiz", context: nil),
                SuggestionChip(id: UUID().uuidString, text: "Start Mini Lesson", icon: "book.fill", actionType: "lesson", context: nil),
            ]
            return

        case .offer:
            let offerMessage = QuizExperienceFactory.makeOfferMessage(
                for: messageText,
                recentMessages: recentContext
            )
            withAnimation {
                messages.append(offerMessage)
            }
            suggestions = [
                SuggestionChip(id: UUID().uuidString, text: "Quick 5-question check", icon: "questionmark.circle.fill", actionType: "quiz", context: nil),
                SuggestionChip(id: UUID().uuidString, text: "Challenge quiz", icon: "person.3.fill", actionType: "quiz", context: nil),
                SuggestionChip(id: UUID().uuidString, text: "Review mistakes", icon: "arrow.counterclockwise.circle.fill", actionType: "quiz", context: nil),
            ]
            return

        case .none:
            break
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
                        label: action.type == "generate_course"
                            ? "Generate Course"
                            : action.type.replacingOccurrences(of: "_", with: " ").capitalized,
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
            
            var aiMessage = LyoMessage(
                id: UUID().uuidString,
                content: response.text,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: messageActions,
                status: .sent
            )
            aiMessage.contentTypes = response.contentTypes
            aiMessage.responseMode = response.responseMode
            aiMessage.quickExplainer = response.quickExplainer

            // Stage A.5 — multi-turn intent detection.
            // Update conversation state with the user message we just sent
            // (Stage A only saw the latest message; A.5 sees rolling state
            // across the last N turns), then build the suggested-action card
            // from the state + any detected pattern.
            let observation = conversationState.observe(userMessage: messageText)
            let aiHasCourseProposal = aiMessage.contentTypes?.contains(where: {
                if case .courseProposal = $0 { return true } else { return false }
            }) ?? false
            if let card = Self.buildSuggestedActionCard(
                state: conversationState,
                observation: observation,
                aiResponseHasCourseProposal: aiHasCourseProposal
            ) {
                if aiMessage.contentTypes == nil {
                    aiMessage.contentTypes = [.suggestedActionCard(card: card)]
                } else {
                    aiMessage.contentTypes?.append(.suggestedActionCard(card: card))
                }
                conversationState.noteCardOffered()
            }

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
                addErrorMessage(chatErrorMessage(for: error))
            }
        }
    }

    func sendMessage(mode: String) async {
        await sendMessage()
    }

    // MARK: - Stage B5: Proactive welcome-back greeting

    /// Drop a context-aware Lyo message at the top of an empty chat, using
    /// the persistent learning profile loaded by `LearningProfileService`.
    /// Fires at most once per app launch — never on top of an existing
    /// conversation thread, never if the profile has no usable signal.
    func maybeInjectProactiveGreeting() {
        guard !hasGreetedThisSession else { return }
        guard messages.isEmpty else {
            hasGreetedThisSession = true  // existing convo, suppress for this launch
            return
        }
        guard let profile = LearningProfileService.shared.current,
              profile.hasContext
        else { return }

        let greeting = Self.composeGreeting(profile: profile)
        var message = LyoMessage(
            id: UUID().uuidString,
            content: greeting.text,
            isFromUser: false,
            timestamp: Date(),
            attachments: nil,
            actions: nil,
            status: .sent
        )
        if let card = greeting.card {
            message.contentTypes = [.suggestedActionCard(card: card)]
        }

        messages.append(message)
        hasGreetedThisSession = true
    }

    private struct Greeting {
        let text: String
        let card: SuggestedActionCard?
    }

    /// Compose the greeting copy + an optional resume card.
    /// Priority: active study plan → last classroom session → struggle topics → known subjects.
    private static func composeGreeting(profile: LearningProfile) -> Greeting {
        // Path 0 (Stage B2): if there's an active study plan, surface it
        // first — deadlines are higher-priority than session history.
        if let plan = StudyPlanService.shared.activePlans.first {
            let payload = SuggestedActionCard.Payload(
                topic: plan.topics.first,
                subject: plan.subject,
                deadline: plan.deadline,
                topics: plan.topics
            )
            let deadlinePart = plan.deadline.map { " for \($0)" } ?? ""
            let card = SuggestedActionCard(
                id: UUID().uuidString,
                kind: .studyPlan,
                title: "Continue your \(plan.subject) plan?",
                subtitle: "I'll pick up your study plan\(deadlinePart) and pull up today's lesson.",
                primaryLabel: "Resume plan",
                chips: ["Show the full plan", "Quiz me on what we covered", "Edit the plan"],
                payload: payload
            )
            return Greeting(
                text: "Welcome back. You have an active \(plan.subject) plan\(deadlinePart) — want to keep going?",
                card: card
            )
        }

        // Path 1: most recent classroom session — highest signal.
        if let topic = profile.lastClassroomTopic, !topic.isEmpty {
            let payload = SuggestedActionCard.Payload(
                topic: topic, subject: nil, deadline: nil, topics: [topic]
            )
            let card = SuggestedActionCard(
                id: UUID().uuidString,
                kind: .guidedLesson,
                title: "Continue with \(topic)?",
                subtitle: "I can pick up where we left off, or quiz you on what we covered.",
                primaryLabel: "Continue lesson",
                chips: ["Quiz me on this", "Show me a summary", "Start something new"],
                payload: payload
            )
            return Greeting(
                text: "Welcome back. Last time we worked on \(topic) — want to keep going?",
                card: card
            )
        }

        // Path 2: known struggle area — offer to revisit.
        if let weak = profile.struggleTopics.first {
            let payload = SuggestedActionCard.Payload(
                topic: weak, subject: nil, deadline: nil, topics: [weak]
            )
            let card = SuggestedActionCard(
                id: UUID().uuidString,
                kind: .guidedLesson,
                title: "Revisit \(weak)?",
                subtitle: "It came up as challenging before. We can take another pass with a fresh angle.",
                primaryLabel: "Open guided lesson",
                chips: ["Try a different example", "Quiz me", "Skip for now"],
                payload: payload
            )
            return Greeting(
                text: "Welcome back. We left some things open on \(weak) — want to take another look?",
                card: card
            )
        }

        // Path 3: known subjects — generic warm greeting referencing them.
        let subjects = profile.knownSubjects.prefix(2).joined(separator: " and ")
        return Greeting(
            text: "Welcome back. We've been working on \(subjects). What's on your mind today?",
            card: nil
        )
    }

    // MARK: - Stage A.5: Suggested action card builder (state-aware)

    /// Build a `SuggestedActionCard` from the current `ConversationState` +
    /// the latest observation. Three sources of truth, in priority order:
    ///   1. Detected pattern (repeated topic / clarifying follow-ups / etc.)
    ///   2. Active intent + filled slots from the rolling state
    ///   3. Fall back to the latest classifier result
    /// Returns nil when none of the above warrants a card.
    static func buildSuggestedActionCard(
        state: ConversationState,
        observation: ConversationState.Observation,
        aiResponseHasCourseProposal: Bool
    ) -> SuggestedActionCard? {
        // Don't double-up: backend already proposed a course → no card.
        if aiResponseHasCourseProposal { return nil }
        // No-spam: a card was already offered for this active intent.
        if state.cardOfferedForCurrentIntent { return nil }

        // 1. Pattern-driven card (highest priority).
        if let pattern = observation.pattern {
            return cardFor(pattern: pattern, state: state, observation: observation)
        }

        // 2. State-driven card — use accumulated slots, not just the latest message.
        if state.activeIntent != .unknown {
            let payload = SuggestedActionCard.Payload(
                topic: state.topics.first ?? state.recentTopic,
                subject: state.subject,
                deadline: state.deadline,
                topics: state.topics
            )
            switch state.activeIntent {
            case .testPrep:
                return testPrepCard(payload: payload)
            case .confusion:
                return guidedLessonCard(payload: payload, framing: .confusion)
            case .broadLearning:
                return guidedLessonCard(payload: payload, framing: .broad)
            case .practice, .quickAnswer, .unknown:
                return nil
            }
        }

        // 3. Fallback to Stage A behavior using the latest classification.
        let latest = observation.classification
        guard latest.confidence >= 0.75 else { return nil }
        let payload = SuggestedActionCard.Payload(
            topic: latest.topics.first,
            subject: latest.subject,
            deadline: latest.deadline,
            topics: latest.topics
        )
        switch latest.intent {
        case .testPrep:      return testPrepCard(payload: payload)
        case .confusion:     return guidedLessonCard(payload: payload, framing: .confusion)
        case .broadLearning: return guidedLessonCard(payload: payload, framing: .broad)
        case .practice, .quickAnswer, .unknown: return nil
        }
    }

    /// Card construction driven by a detected conversational pattern. These
    /// are higher-quality nudges than slot-based cards because the pattern
    /// itself tells us what the user is doing.
    private static func cardFor(
        pattern: ConversationPattern,
        state: ConversationState,
        observation: ConversationState.Observation
    ) -> SuggestedActionCard? {
        switch pattern {
        case .repeatedTopic(let topic, _):
            // User has been on this topic for ≥3 turns — offer to consolidate.
            let payload = SuggestedActionCard.Payload(
                topic: topic, subject: state.subject, deadline: nil, topics: [topic]
            )
            return SuggestedActionCard(
                id: UUID().uuidString,
                kind: .guidedLesson,
                title: "We're building a lesson around \(topic).",
                subtitle: "Want me to organize what we've covered into a guided lesson with a visual and a quick check?",
                primaryLabel: "Open guided lesson",
                chips: ["Quiz me on this", "Make a diagram", "Summarize what we've learned"],
                payload: payload
            )

        case .clarifyingFollowups:
            // User hit `.confusion` ≥2 in a row. The chat back-and-forth
            // isn't working — switch surface.
            let topic = state.recentTopic ?? state.topics.first ?? "this concept"
            let payload = SuggestedActionCard.Payload(
                topic: topic, subject: state.subject, deadline: nil, topics: state.topics
            )
            return SuggestedActionCard(
                id: UUID().uuidString,
                kind: .guidedLesson,
                title: "Let me try a different approach on \(topic).",
                subtitle: "I'll open a guided lesson with simpler language, a visual, and an example. Step-by-step, no walls of text.",
                primaryLabel: "Open guided lesson",
                chips: ["Try a different example", "Use simpler words", "Show a diagram"],
                payload: payload
            )

        case .repeatedQuestion:
            // User re-asked the same thing. Don't surface a card — let the
            // AI's next reply (which will be different prose) do the work.
            return nil

        case .goalShift:
            // State has just reset; a fresh state-driven card will appear on
            // the NEXT turn once new slots fill in. Suppress for this turn.
            return nil
        }
    }

    private static func testPrepCard(
        payload: SuggestedActionCard.Payload
    ) -> SuggestedActionCard {
        var subtitle: String
        var chips: [String] = ["Quiz me first", "I know my topics", "Just teach me"]

        let subjectPart = payload.subject.map { " for your \($0) test" } ?? ""
        if let deadline = payload.deadline {
            subtitle = "I'll build a focused study plan\(subjectPart) for \(deadline). We'll figure out what's on the test, then split it across the days you have."
        } else {
            subtitle = "I'll build a focused study plan\(subjectPart). We'll figure out what's on the test and split it across the days until your deadline."
            chips.insert("When is the test?", at: 0)
        }

        return SuggestedActionCard(
            id: UUID().uuidString,
            kind: .studyPlan,
            title: "Want me to build a study plan?",
            subtitle: subtitle,
            primaryLabel: "Build study plan",
            chips: chips,
            payload: payload
        )
    }

    private enum GuidedFraming { case confusion, broad }

    private static func guidedLessonCard(
        payload: SuggestedActionCard.Payload,
        framing: GuidedFraming
    ) -> SuggestedActionCard {
        let topic = payload.topic ?? payload.subject ?? "this topic"
        let title: String
        let subtitle: String
        let chips: [String]

        switch framing {
        case .confusion:
            title = "Let's slow down on \(topic)."
            subtitle = "I can open a guided lesson with a visual and a quick check, instead of more chat back-and-forth."
            chips = ["Explain easier", "Show a diagram", "Give an example"]
        case .broad:
            title = "Open a guided lesson on \(topic)?"
            subtitle = "I'll start with a hook, walk you through the core idea with a visual, and check your understanding at the end."
            chips = ["Make it shorter", "Quiz me first", "I want a full course"]
        }

        return SuggestedActionCard(
            id: UUID().uuidString,
            kind: .guidedLesson,
            title: title,
            subtitle: subtitle,
            primaryLabel: "Open guided lesson",
            chips: chips,
            payload: payload
        )
    }

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
        case .createCourse, .createCourseA2A:
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
        let level = (data?["level"]?.lowercased()) ?? "beginner"
        print("Creating course for: \(topic) (level: \(level))")

        // When the AI proposed an OPEN_CLASSROOM payload and the user tapped
        // "Generate Course", skip the chat round-trip and start the cinematic
        // generation directly. Without this short-circuit, re-sending
        // "Create a course about X" would just trigger another OPEN_CLASSROOM
        // proposal from the backend → infinite ping-pong.
        if data?["auto_generate"] == "true" {
            Task {
                await startFullCourseGeneration(topic: topic, level: level)
            }
            return
        }

        // Legacy fallback: nudge the AI by re-asking via chat.
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

        // Stage A.5 — fresh conversation thread, fresh state. We don't
        // re-classify the loaded history (cards in old turns stay as-is);
        // we just clear the rolling window so the next user message starts
        // a clean intent.
        self.conversationState.reset()

        // Stage B5 — restored conversations already have content; suppress
        // the proactive welcome-back so we don't crown old history with a
        // synthetic Lyo message.
        self.hasGreetedThisSession = true
        
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

@MainActor
final class SpeechToTextService: ObservableObject {
    static let shared = SpeechToTextService()

    @Published var transcribedText = ""
    @Published var isRecording = false
    var onSpeechDetected: (() -> Void)?

    private init() {}

    func requestAuthorization() {}

    func startRecording() throws {
        isRecording = true
        onSpeechDetected?()
    }

    func stopRecording() {
        isRecording = false
    }
}

@MainActor
final class LioChatService {
    static let shared = LioChatService()

    struct GreetingResponse {
        let greeting: String
        let suggestions: [String]?

        init(greeting: String, suggestions: [String]? = nil) {
            self.greeting = greeting
            self.suggestions = suggestions
        }
    }

    struct ChatAction {
        let type: String
        let parameters: [String: String]?
    }

    struct ChatResponse {
        let text: String
        let action: ChatAction?
        let suggestions: [String]?
        let contentTypes: [MessageContentType]?
        let responseMode: ResponseMode?
        let quickExplainer: QuickExplainerData?

        init(
            text: String,
            action: ChatAction?,
            suggestions: [String]?,
            contentTypes: [MessageContentType]? = nil,
            responseMode: ResponseMode? = nil,
            quickExplainer: QuickExplainerData? = nil
        ) {
            self.text = text
            self.action = action
            self.suggestions = suggestions
            self.contentTypes = contentTypes
            self.responseMode = responseMode
            self.quickExplainer = quickExplainer
        }
    }

    // Decoded shape of the backend `/api/v1/chat/greeting` response.
    // (Codable rather than Decodable because NetworkClient.request requires it.)
    private struct GreetingDTO: Codable {
        let greeting: String?
        let suggestions: [String]?
    }

    // Decoded shape of items inside `uiComponent` returned by `/api/v1/ai/chat`.
    // Only the fields we actually consume on this surface are decoded.
    private struct UIComponentDTO: Codable {
        let type: String?
        let suggestions: [String]?
    }

    // Full chat response from `/api/v1/ai/chat` — superset of the typed
    // `BackendAIChatResponse` so we can also pluck suggestion chips out of
    // the embedded `uiComponent` array without changing that model.
    private struct ChatEnvelope: Codable {
        let response: String?
        let content: String?
        let uiComponent: [UIComponentDTO]?
    }

    private init() {}

    func getProactiveGreeting() async throws -> GreetingResponse {
        let endpoint = DynamicEndpoint(
            urlString: "\(AppConfig.baseURL)/api/v1/chat/greeting",
            method: .get,
            body: nil,
            requiresAuth: false
        )

        do {
            let dto: GreetingDTO = try await NetworkClient.shared.request(endpoint)
            let text = dto.greeting?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let text, !text.isEmpty {
                return GreetingResponse(greeting: text, suggestions: dto.suggestions)
            }
        } catch {
            print("⚠️ Proactive greeting fetch failed, using fallback: \(error)")
        }

        return GreetingResponse(
            greeting: "Hi, I'm Lio. What would you like to learn?",
            suggestions: nil
        )
    }

    func sendMessage(text: String, mode: String) async throws -> ChatResponse {
        // Stage B1 — pull the user's learning profile context (if available)
        // so Lyo can reference past sessions / struggle topics / interests.
        // Stage B2 — same idea for active study plans, so Lyo can ground
        // its replies in the plan's deadline + topics.
        // We must complete B1/B2 before sending the AI request (Stage C)
        // so the prompt is not missing the latest persisted study plan context.
        async let _profile: LearningProfile? = LearningProfileService.shared.fetchIfNeeded()
        async let _plans: [StudyPlanRecord] = StudyPlanService.shared.fetchIfNeeded()
        _ = await (_profile, _plans)

        let extraContext: String? = await MainActor.run {
            let parts: [String] = [
                LearningProfileService.shared.chatContextLine(),
                StudyPlanService.shared.chatContextLine(),
            ].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: ". ")
        }
        let profileContext = extraContext

        // 1) Primary path: the typed `BackendAIService.studySession` call which
        //    already manages conversation history and posts to `/api/v1/ai/chat`.
        do {
            let result = try await BackendAIService.shared.studySession(
                message: text,
                mode: mode,
                additionalContext: profileContext
            )
            let trimmed = result.response.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return Self.buildChatResponse(raw: trimmed, envelopeSuggestions: nil)
            }
        } catch {
            print("⚠️ BackendAIService.studySession failed, falling back to raw call: \(error)")
        }

        // 2) Fallback: raw decode against `/api/v1/ai/chat` so a schema drift in
        //    `BackendAIChatResponse` (e.g. new fields) never silently turns into
        //    a placeholder reply. We also use this branch to recover any
        //    suggestion chips embedded in the `uiComponent` payload.
        var fallbackContext = "Mode: \(mode)\nTopic: general_learning"
        if let extra = profileContext, !extra.isEmpty {
            fallbackContext += "\nLearner profile: \(extra)"
        }
        let body = BackendAIChatRequest(
            message: text,
            conversationHistory: nil,
            context: fallbackContext,
            modeHint: mode
        )

        let endpoint = DynamicEndpoint(
            urlString: "\(AppConfig.baseURL)/api/v1/ai/chat",
            method: .post,
            body: body,
            requiresAuth: false
        )

        let envelope: ChatEnvelope = try await NetworkClient.shared.request(endpoint)
        let raw = (envelope.response ?? envelope.content ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let suggestionChips = envelope.uiComponent?
            .compactMap { $0.suggestions }
            .flatMap { $0 }

        guard !raw.isEmpty else {
            throw BackendAIError.serverError("Empty AI response")
        }

        return Self.buildChatResponse(raw: raw, envelopeSuggestions: suggestionChips)
    }

    /// Maps raw `/api/v1/ai/chat` text into learner-friendly prose, optional course action,
    /// structured `contentTypes`, and heuristic explainer payloads.
    private static func buildChatResponse(raw: String, envelopeSuggestions: [String]?) -> ChatResponse {
        let enrichment = EducationChatEnrichment.enrich(rawAssistantText: raw)
        let chips = envelopeSuggestions?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let suggestions: [String]?
        if let chips, !chips.isEmpty {
            suggestions = chips
        } else {
            suggestions = nil
        }

        let mappedAction = enrichment.action.map {
            ChatAction(type: $0.type, parameters: $0.parameters)
        }
        return ChatResponse(
            text: enrichment.displayText,
            action: mappedAction,
            suggestions: suggestions,
            contentTypes: enrichment.contentTypes.isEmpty ? nil : enrichment.contentTypes,
            responseMode: enrichment.responseMode,
            quickExplainer: enrichment.quickExplainer
        )
    }
}

extension LyoAIViewModel {
    func onCourseStart(course: CourseProposalData) {
        inputText = "Start course: \(course.title)"
    }
}
