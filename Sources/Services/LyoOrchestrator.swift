import Foundation
import SwiftUI
import Combine
import os

// MARK: - Core Models

struct LyoOrchestratedResponse: Codable {
    let primaryResponse: String
    let actions: LyoActions
    let confidence: Double
    let suggestedFollowUps: [String]
    let onboardingHints: [ContextualHint]
    let progressiveFeatures: [String]
    let emotion: LyoEmotion

    init(
        primaryResponse: String,
        actions: LyoActions = LyoActions(),
        confidence: Double = 1.0,
        suggestedFollowUps: [String] = [],
        onboardingHints: [ContextualHint] = [],
        progressiveFeatures: [String] = [],
        emotion: LyoEmotion = .friendly
    ) {
        self.primaryResponse = primaryResponse
        self.actions = actions
        self.confidence = confidence
        self.suggestedFollowUps = suggestedFollowUps
        self.onboardingHints = onboardingHints
        self.progressiveFeatures = progressiveFeatures
        self.emotion = emotion
    }
}

struct LyoActions: Codable {
    let courseCreation: CourseCreationAction?
    let quickExplainer: QuickExplainerAction?
    let contentDiscovery: ContentDiscoveryAction
    let stackItems: [StackItem]
    let quizGeneration: QuizGenerationAction?
    let socialActions: SocialActions?
    let navigationAction: NavigationAction?
    let offlineMode: Bool
    let syncWhenOnline: Bool

    init(
        courseCreation: CourseCreationAction? = nil,
        quickExplainer: QuickExplainerAction? = nil,
        contentDiscovery: ContentDiscoveryAction = ContentDiscoveryAction(),
        stackItems: [StackItem] = [],
        quizGeneration: QuizGenerationAction? = nil,
        socialActions: SocialActions? = nil,
        navigationAction: NavigationAction? = nil,
        offlineMode: Bool = false,
        syncWhenOnline: Bool = false
    ) {
        self.courseCreation = courseCreation
        self.quickExplainer = quickExplainer
        self.contentDiscovery = contentDiscovery
        self.stackItems = stackItems
        self.quizGeneration = quizGeneration
        self.socialActions = socialActions
        self.navigationAction = navigationAction
        self.offlineMode = offlineMode
        self.syncWhenOnline = syncWhenOnline
    }
}

struct ContentDiscoveryAction: Codable {
    let discoverClips: [String] // Topic keywords to search
    let communities: [String]   // Community types to suggest
    let suggestedPosts: [PostTemplate] // Templates for sharing
    let relatedCourses: [String] // Course recommendations

    init(
        discoverClips: [String] = [],
        communities: [String] = [],
        suggestedPosts: [PostTemplate] = [],
        relatedCourses: [String] = []
    ) {
        self.discoverClips = discoverClips
        self.communities = communities
        self.suggestedPosts = suggestedPosts
        self.relatedCourses = relatedCourses
    }
}

struct CourseCreationAction: Codable {
    let topic: String
    let level: String
    let estimatedDuration: String
    let outline: [String]
}

struct QuickExplainerAction: Codable {
    let topic: String
    let keyPoints: [String]
    let estimatedReadTime: Int // minutes
}

struct QuizGenerationAction: Codable {
    let topic: String
    let questionCount: Int
    let difficulty: String
    let questionTypes: [String]
}

struct SocialActions: Codable {
    let shareProgress: Bool
    let suggestCommunity: String?
    let createPost: PostTemplate?
}

struct PostTemplate: Codable {
    var id = UUID()
    let type: PostType
    let title: String
    let content: String
    let tags: [String]

    enum PostType: String, Codable {
        case progress, question, achievement, tip
    }
}

struct NavigationAction: Codable {
    let destination: String
    let context: [String: String]
    let transition: TransitionType

    enum TransitionType: String, Codable {
        case push, present, replace
    }
}

struct ContextualHint: Codable, Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let icon: String
    let action: String?
    let priority: Int // 1-5, 1 being highest
}

struct LearningIntent: Codable {
    let type: IntentType
    let topic: String
    let confidence: Double
    let timestamp: Date

    enum IntentType: String, Codable {
        case courseCreation = "course_creation"
        case practice = "practice"
        case explanation = "explanation"
        case social = "social"
        case quiz = "quiz"
    }
}

enum UserInteraction: String, Codable {
    case courseCreationRequest = "course_creation_request"
    case practiceRequest = "practice_request"
    case explanationRequest = "explanation_request"
    case communityInterest = "community_interest"
    case aiSuggestedCourse = "ai_suggested_course"
    case aiChatRequest = "ai_chat_request"
    case courseCreationStarted = "course_creation_started"
    case courseCreationSuggested = "course_creation_suggested"
    case lyoTap = "lyo_tap"
    case overlayOpened = "overlay_opened"
    case overlayClosed = "overlay_closed"
    case chatOpened = "chat_opened"
}

// MARK: - LyoOrchestrator Service

@MainActor
class LyoOrchestrator: ObservableObject {
    static let shared = LyoOrchestrator()

    // MARK: - Published State
    @Published var activeContext: LearningContext?
    @Published var suggestedContent: [ContentSuggestion] = []
    @Published var activeJourney: LearningJourney?
    @Published var userProficiency: UserProficiency = .newUser
    @Published var showAdvancedFeatures: Bool = false
    @Published var contextualHints: [ContextualHint] = []
    @Published var isOffline: Bool = false
    @Published var cachedResponses: [String: LyoOrchestratedResponse] = [:]

    // Added from extension (fixing stored property error)
    @Published var detectedIntents: [LearningIntent] = []


    // MARK: - Private Services
    private let aiService = BackendAIService.shared
    private let userDefaults = UserDefaults.standard
    private var interactionCount: Int {
        get { userDefaults.integer(forKey: "lyoInteractionCount") }
        set { userDefaults.set(newValue, forKey: "lyoInteractionCount") }
    }

    private init() {
        loadUserProficiency()
        setupOfflineMonitoring()
    }

    // MARK: - Main Orchestration Method

    /// Main conversation handler that orchestrates everything
    func processUserMessage(
        _ message: String,
        currentContext: LearningContext? = nil
    ) async -> LyoOrchestratedResponse {

        // Increment interaction count for progressive disclosure
        interactionCount += 1

        // Update context if provided
        if let context = currentContext {
            activeContext = context
        }

        // Handle offline mode
        if isOffline {
            return handleOfflineInteraction(message)
        }

        do {
            // 1. Detect user experience level from conversation
            let learningLevel = detectUserExperience(message)

            // 2. Build enhanced context for AI
            let enhancedContext = buildEnhancedContext(message: message, learningLevel: learningLevel)

            // 3. Send to AI for intent detection and response
            let aiResponse = try await aiService.studySession(
                message: message,
                resourceId: enhancedContext["topic"] ?? "general",
                mode: enhancedContext["mode"] ?? "orchestrator"
            )

            // 4. Parse and enhance the response
            let orchestratedResponse = try parseAndEnhanceResponse(
                aiResponse.response,
                learningLevel: learningLevel,
                context: enhancedContext
            )


            // 5. Execute orchestrated actions
            await executeOrchestration(orchestratedResponse)

            // 6. Cache for offline use
            cacheResponse(message, orchestratedResponse)

            return orchestratedResponse

        } catch {
            // Return error response with Lyo personality
            return createErrorResponse(error: error)
        }
    }

    // MARK: - User Experience Detection

    private func detectUserExperience(_ message: String) -> LearningLevel {
        let lowercaseMessage = message.lowercased()

        // Advanced indicators
        if lowercaseMessage.contains("optimize") ||
           lowercaseMessage.contains("algorithm") ||
           lowercaseMessage.contains("architecture") ||
           lowercaseMessage.contains("best practices") {
            return .advanced
        }

        // Intermediate indicators
        if lowercaseMessage.contains("explain") ||
           lowercaseMessage.contains("how does") ||
           lowercaseMessage.contains("why") {
            return .intermediate
        }

        // Beginner indicators (default)
        return .beginner
    }

    private func buildEnhancedContext(message: String, learningLevel: LearningLevel) -> [String: String] {
        var context: [String: String] = [
            "mode": "orchestrator",
            "user_level": learningLevel.rawValue,
            "interaction_count": String(interactionCount),
            "show_hints": shouldShowHints().description
        ]


        if let activeContext = activeContext {
            context["topic"] = activeContext.topic
            context["content_type"] = activeContext.contentType.rawValue
            context["source"] = activeContext.source.rawValue
        }

        return context
    }

    // MARK: - Response Processing

    private func parseAndEnhanceResponse(
        _ response: String,
        learningLevel: LearningLevel,
        context: [String: String]
    ) throws -> LyoOrchestratedResponse {

        // Try to parse JSON response first
        if let jsonResponse = parseJSONResponse(response) {
            return enhanceWithUXFeatures(jsonResponse, learningLevel: learningLevel)
        }

        // Fallback: Create orchestrated response from plain text
        return createFallbackResponse(response, learningLevel: learningLevel, context: context)
    }


    private func parseJSONResponse(_ response: String) -> LyoOrchestratedResponse? {
        // Look for JSON in response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(response[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8) else { return nil }

        do {
            return try JSONDecoder().decode(LyoOrchestratedResponse.self, from: data)
        } catch {
            Log.net.error("Failed to parse JSON response: \(error)")
            return nil
        }
    }

    private func createFallbackResponse(
        _ response: String,
        learningLevel: LearningLevel,
        context: [String: String]
    ) -> LyoOrchestratedResponse {

        // Analyze response content to determine actions
        let actions = inferActionsFromResponse(response, learningLevel: learningLevel)
        let hints = generateContextualHints(for: response, learningLevel: learningLevel)
        let followUps = generateFollowUpSuggestions(for: response)

        return LyoOrchestratedResponse(
            primaryResponse: response,
            actions: actions,
            confidence: 0.8,
            suggestedFollowUps: followUps,
            onboardingHints: hints,
            progressiveFeatures: getUnlockedFeatures(learningLevel),
            emotion: inferEmotionFromResponse(response)
        )
    }


    private func enhanceWithUXFeatures(
        _ response: LyoOrchestratedResponse,
        learningLevel: LearningLevel
    ) -> LyoOrchestratedResponse {

        let enhancedHints = generateContextualHints(
            for: response.primaryResponse,
            learningLevel: learningLevel
        )

        return LyoOrchestratedResponse(
            primaryResponse: response.primaryResponse,
            actions: response.actions,
            confidence: response.confidence,
            suggestedFollowUps: response.suggestedFollowUps,
            onboardingHints: enhancedHints,
            progressiveFeatures: getUnlockedFeatures(learningLevel),
            emotion: response.emotion
        )
    }


    // MARK: - Action Inference

    private func inferActionsFromResponse(_ response: String, learningLevel: LearningLevel) -> LyoActions {
        var actions = LyoActions()
        let lowercaseResponse = response.lowercased()

        // Course creation indicators
        if lowercaseResponse.contains("course") || lowercaseResponse.contains("learn") {
            // Infer course creation need
            if let topic = extractTopic(from: response) {
                actions = LyoActions(
                    courseCreation: CourseCreationAction(
                        topic: topic,
                        level: learningLevel.rawValue,

                        estimatedDuration: "4-6 lessons",
                        outline: ["Introduction", "Core Concepts", "Practice", "Assessment"]
                    ),
                    contentDiscovery: ContentDiscoveryAction(
                        discoverClips: [topic],
                        communities: ["\(topic) study group"],
                        relatedCourses: [topic]
                    )
                )
            }
        }

        // Quiz indicators
        if lowercaseResponse.contains("quiz") || lowercaseResponse.contains("test") {
            if let topic = extractTopic(from: response) {
                actions = LyoActions(
                    quizGeneration: QuizGenerationAction(
                        topic: topic,
                        questionCount: 5,
                        difficulty: learningLevel.rawValue,
                        questionTypes: ["multiple_choice", "short_answer"]
                    )

                )
            }
        }

        return actions
    }

    private func extractTopic(from response: String) -> String? {
        // Simple topic extraction - in production, use NLP
        let words = response.components(separatedBy: .whitespacesAndNewlines)

        // Look for common learning topics
        let topics = ["calculus", "physics", "chemistry", "biology", "history", "programming", "swift", "python"]

        for word in words {
            if topics.contains(word.lowercased()) {
                return word.lowercased()
            }
        }

        return activeContext?.topic ?? "general"
    }

    // MARK: - Contextual Hints & Progressive Disclosure

    private func generateContextualHints(
        for response: String,
        learningLevel: LearningLevel
    ) -> [ContextualHint] {

        var hints: [ContextualHint] = []

        // Only show hints for new users
        guard userProficiency == .newUser || userProficiency == .developing else {
            return hints
        }

        // Interaction-based hints
        if interactionCount <= 3 {
            hints.append(ContextualHint(
                title: "Voice Input",
                description: "Hold the Lyo button to speak instead of typing",
                icon: "mic.fill",
                action: "enable_voice",
                priority: 1
            ))
        }

        if interactionCount <= 5 && response.contains("course") {
            hints.append(ContextualHint(
                title: "Course Creation",
                description: "I can create complete courses for any topic you want to learn",
                icon: "book.fill",
                action: "show_course_features",
                priority: 2
            ))
        }

        if interactionCount <= 7 && response.contains("explain") {
            hints.append(ContextualHint(
                title: "Quick Explainers",
                description: "Ask me for quick explanations when you need fast answers",
                icon: "lightbulb.fill",
                action: "show_explainer_examples",
                priority: 3
            ))
        }

        return hints.sorted { $0.priority < $1.priority }
    }

    private func shouldShowHints() -> Bool {
        return interactionCount < 10 && (userProficiency == .newUser || userProficiency == .developing)
    }

    private func getUnlockedFeatures(_ learningLevel: LearningLevel) -> [String] {
        var features: [String] = ["basic_chat", "quick_explainer"]

        if interactionCount >= 3 {
            features.append("voice_input")
        }

        if interactionCount >= 5 {
            features.append("course_creation")
        }

        if interactionCount >= 10 {
            features.append("advanced_features")
            showAdvancedFeatures = true
        }

        if learningLevel == .advanced {
            features.append(contentsOf: ["api_access", "custom_prompts"])
        }


        return features
    }

    // MARK: - Orchestration Execution

    private func executeOrchestration(_ response: LyoOrchestratedResponse) async {
        let actions = response.actions

        // Course Creation
        if let courseAction = actions.courseCreation {
            await createCourseFlow(courseAction)
        }

        // Content Discovery
        if !actions.contentDiscovery.discoverClips.isEmpty {
            await discoverRelatedContent(actions.contentDiscovery)
        }

        // Stack Management
        for stackItem in actions.stackItems {
            await addToStack(stackItem)
        }

        // Quiz Generation
        if let quizAction = actions.quizGeneration {
            await generateQuiz(quizAction)
        }

        // Social Actions
        if let socialAction = actions.socialActions {
            await handleSocialActions(socialAction)
        }

        // Navigation
        if let navAction = actions.navigationAction {
            await handleNavigation(navAction)
        }
    }

    // MARK: - Action Handlers

    private func createCourseFlow(_ action: CourseCreationAction) async {
        // Trigger course creation UI
        NotificationCenter.default.post(
            name: NSNotification.Name("TriggerCourseCreation"),
            object: nil,
            userInfo: [
                "topic": action.topic,
                "level": action.level,
                "outline": action.outline
            ]
        )
    }

    private func discoverRelatedContent(_ action: ContentDiscoveryAction) async {
        // Update suggested content
        var suggestions: [ContentSuggestion] = []

        for clip in action.discoverClips {
            suggestions.append(ContentSuggestion(
                type: .clip,
                topic: clip,
                title: "Videos about \(clip)",
                priority: .high
            ))
        }

        for community in action.communities {
            suggestions.append(ContentSuggestion(
                type: .community,
                topic: community,
                title: community,
                priority: .medium
            ))
        }

        suggestedContent = suggestions
    }

    private func addToStack(_ item: StackItem) async {
        // Add to UI stack - convert StackItem to UIStackItem
        let uiItem = UIStackItem(
            id: item.id,
            type: .course, // Default type for now
            title: item.title,
            subtitle: item.subtitle,
            updatedAt: Date()
        )
        UIStackStore.shared.upsert(uiItem)
    }

    private func generateQuiz(_ action: QuizGenerationAction) async {
        // Trigger quiz generation
        NotificationCenter.default.post(
            name: NSNotification.Name("TriggerQuizGeneration"),
            object: nil,
            userInfo: [
                "topic": action.topic,
                "questionCount": action.questionCount,
                "difficulty": action.difficulty
            ]
        )
    }

    private func handleSocialActions(_ action: SocialActions) async {
        if action.shareProgress {
            NotificationCenter.default.post(
                name: NSNotification.Name("TriggerProgressShare"),
                object: nil
            )
        }

        if let community = action.suggestCommunity {
            NotificationCenter.default.post(
                name: NSNotification.Name("SuggestCommunity"),
                object: nil,
                userInfo: ["community": community]
            )
        }
    }

    private func handleNavigation(_ action: NavigationAction) async {
        NotificationCenter.default.post(
            name: NSNotification.Name("LyoNavigation"),
            object: nil,
            userInfo: [
                "destination": action.destination,
                "context": action.context,
                "transition": action.transition.rawValue
            ]
        )
    }

    // MARK: - Offline Handling

    private func setupOfflineMonitoring() {
        // Monitor network status
        // In production, use Network framework
    }

    private func handleOfflineInteraction(_ message: String) -> LyoOrchestratedResponse {
        // Check for similar cached response
        if let cached = findSimilarCachedResponse(message) {
            return cached.adaptedForOffline()
        }

        // Generate helpful offline response
        return LyoOrchestratedResponse(
            primaryResponse: "I'm offline right now, but I can still help! Here's what I know about this topic from my cached knowledge...",
            actions: LyoActions(
                offlineMode: true,
                syncWhenOnline: true
            ),
            onboardingHints: [
                ContextualHint(
                    title: "Offline Mode",
                    description: "I'll sync with my cloud brain when you're back online",
                    icon: "wifi.slash",
                    action: nil,
                    priority: 1
                )
            ],
            emotion: .apologetic
        )
    }

    private func findSimilarCachedResponse(_ message: String) -> LyoOrchestratedResponse? {
        // Simple similarity check - in production, use vector similarity
        let lowercaseMessage = message.lowercased()

        for (cachedMessage, response) in cachedResponses {
            if lowercaseMessage.contains(cachedMessage.lowercased()) ||
               cachedMessage.lowercased().contains(lowercaseMessage) {
                return response
            }
        }

        return nil
    }

    private func cacheResponse(_ message: String, _ response: LyoOrchestratedResponse) {
        let key = String(message.prefix(50)) // Cache key
        cachedResponses[key] = response

        // Limit cache size
        if cachedResponses.count > 100 {
            let oldestKeys = Array(cachedResponses.keys.prefix(20))
            for key in oldestKeys {
                cachedResponses.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Utility Methods

    private func generateFollowUpSuggestions(for response: String) -> [String] {
        var suggestions: [String] = []

        if response.contains("course") {
            suggestions.append("Can you make this course more advanced?")
            suggestions.append("What prerequisites do I need?")
        }

        if response.contains("explain") {
            suggestions.append("Can you give me an example?")
            suggestions.append("How is this used in real life?")
        }

        if response.contains("quiz") {
            suggestions.append("Make the questions harder")
            suggestions.append("Focus on practical applications")
        }

        return Array(suggestions.prefix(3)) // Limit to 3 suggestions
    }

    private func inferEmotionFromResponse(_ response: String) -> LyoEmotion {
        let lowercaseResponse = response.lowercased()

        if lowercaseResponse.contains("congratulations") || lowercaseResponse.contains("great job") {
            return .proud
        }

        if lowercaseResponse.contains("sorry") || lowercaseResponse.contains("apologize") {
            return .apologetic
        }

        if lowercaseResponse.contains("exciting") || lowercaseResponse.contains("amazing") {
            return .excited
        }

        if lowercaseResponse.contains("let me think") || lowercaseResponse.contains("hmm") {
            return .thoughtful
        }

        return .friendly
    }

    private func createErrorResponse(error: Error) -> LyoOrchestratedResponse {
        return LyoOrchestratedResponse(
            primaryResponse: "Oops! I encountered an issue: \(error.localizedDescription). Let me try to help in a different way!",
            actions: LyoActions(),
            confidence: 0.5,
            onboardingHints: [
                ContextualHint(
                    title: "Error Recovery",
                    description: "Try rephrasing your question or check your connection",
                    icon: "exclamationmark.triangle",
                    action: "retry",
                    priority: 1
                )
            ],
            emotion: .apologetic
        )
    }

    private func loadUserProficiency() {
        if let storedProficiency = UserDefaults.standard.string(forKey: "userProficiency"),
           let proficiency = UserProficiency(rawValue: storedProficiency) {
            self.userProficiency = proficiency
        }

        // Update proficiency based on interaction count
        updateUserProficiency()
    }

    private func updateUserProficiency() {
        let newProficiency: UserProficiency

        switch interactionCount {
        case 0...10:
            newProficiency = .newUser
        case 11...50:
            newProficiency = .developing
        case 51...200:
            newProficiency = .proficient
        default:
            newProficiency = .expert
        }

        if newProficiency != userProficiency {
            userProficiency = newProficiency
            UserDefaults.standard.set(newProficiency.rawValue, forKey: "userProficiency")
        }
    }
}

// MARK: - Supporting Models

struct ContentSuggestion: Identifiable {
    let id = UUID()
    let type: ContentType
    let topic: String
    let title: String
    let priority: Priority

    enum ContentType {
        case clip, course, community, quiz
    }

    enum Priority {
        case low, medium, high
    }
}

struct LearningJourney: Identifiable {
    let id = UUID()
    let topic: String
    let currentStep: Int
    let totalSteps: Int
    let nextAction: NextAction

    enum NextAction {
        case openCourse(String)
        case showQuickExplainer(String)
        case suggestCommunity(String)
        case createPost(PostTemplate)
    }
}

// MARK: - Extensions

extension LyoOrchestrator {
    /// Store detected learning intent for processing
    func storeDetectedIntent(_ intent: LearningIntent) {
        detectedIntents.append(intent)
        Log.net.info("LyoOrchestrator: Stored intent - \(intent.type.rawValue) for \(intent.topic)")

        // Keep only recent intents (last hour)
        let oneHourAgo = Date().addingTimeInterval(-3600)
        detectedIntents = detectedIntents.filter { $0.timestamp > oneHourAgo }
    }

    /// Get recent intents within a time window
    func getRecentIntents(within timeInterval: TimeInterval) -> [LearningIntent] {
        let cutoff = Date().addingTimeInterval(-timeInterval)
        return detectedIntents.filter { $0.timestamp > cutoff }
    }

    /// Generate content suggestions based on learning context
    func generateContentSuggestions(basedOn context: LearningContext) async {
        // Create suggestions based on context
        var newSuggestions: [ContentSuggestion] = []

        // Topic-based suggestions
        newSuggestions.append(ContentSuggestion(
            type: .course,
            topic: context.topic,
            title: "Continue learning \(context.topic)",
            priority: .high
        ))

        // Level-appropriate suggestions
        switch context.learningLevel {
        case .beginner:
            newSuggestions.append(ContentSuggestion(
                type: .course,
                topic: context.topic,
                title: "Fundamentals of \(context.topic)",
                priority: .medium
            ))
        case .intermediate:
            newSuggestions.append(ContentSuggestion(
                type: .clip,
                topic: context.topic,
                title: "Advanced \(context.topic) techniques",
                priority: .medium
            ))
        case .advanced:
            newSuggestions.append(ContentSuggestion(
                type: .quiz,
                topic: context.topic,
                title: "Master-level \(context.topic) challenges",
                priority: .medium
            ))
        }

        // Update suggestions
        DispatchQueue.main.async {
            self.suggestedContent = newSuggestions
        }
    }

    /// Add a content suggestion
    func addContentSuggestion(_ suggestion: ContentSuggestion) {
        DispatchQueue.main.async {
            self.suggestedContent.append(suggestion)
            // Keep only the most relevant suggestions
            self.suggestedContent = Array(self.suggestedContent.sorted { 
                switch ($0.priority, $1.priority) {
                case (.high, .high), (.medium, .medium), (.low, .low): return false
                case (.high, _): return true
                case (.medium, .low): return true
                default: return false
                }
            }.prefix(10))
        }
    }

    /// Initialize with UI state
    func initialize(uiState: AppUIState) {
        // Connect to UI state for cross-app context
        Log.net.info("LyoOrchestrator: Initialized with UI state")
    }

    /// Track user interactions for learning analytics
    func trackUserInteraction(_ interaction: UserInteraction) {
        Log.net.info("LyoOrchestrator: Tracking interaction - \(interaction.rawValue)")

        // Update user proficiency based on interaction patterns
        updateProficiencyFromInteraction(interaction)
    }

    /// Update user proficiency based on interaction patterns
    private func updateProficiencyFromInteraction(_ interaction: UserInteraction) {
        switch interaction {
        case .courseCreationRequest, .courseCreationStarted:
            // User creating courses shows advanced behavior
            if userProficiency == .newUser {
                userProficiency = .beginner
            } else if userProficiency == .beginner {
                userProficiency = .intermediate
            }

        case .practiceRequest, .explanationRequest:
            // Regular learning behavior
            if userProficiency == .newUser {
                userProficiency = .beginner
            }

        default:
            break
        }
    }
}

extension LyoOrchestratedResponse {
    func adaptedForOffline() -> LyoOrchestratedResponse {
        return LyoOrchestratedResponse(
            primaryResponse: "📱 Offline: \(self.primaryResponse)",
            actions: LyoActions(
                offlineMode: true,
                syncWhenOnline: true
            ),
            confidence: self.confidence * 0.8, // Lower confidence for offline
            suggestedFollowUps: self.suggestedFollowUps,
            onboardingHints: self.onboardingHints + [
                ContextualHint(
                    title: "Offline Mode",
                    description: "Limited features available. Full functionality returns when online.",
                    icon: "wifi.slash",
                    action: nil,
                    priority: 1
                )
            ],
            progressiveFeatures: self.progressiveFeatures,
            emotion: .apologetic
        )
    }
}