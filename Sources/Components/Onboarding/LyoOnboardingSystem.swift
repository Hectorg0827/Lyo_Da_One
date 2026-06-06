import SwiftUI
import Combine

// MARK: - Onboarding Models

struct OnboardingStep: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let targetView: String? // View to highlight
    let action: OnboardingAction?
    let prerequisite: OnboardingPrerequisite?
    let priority: Int // 1-5, 1 being highest
    let maxShowCount: Int // How many times to show this step
    let delayAfterPrevious: TimeInterval // Delay before showing this step

    enum OnboardingAction: String, Codable {
        case tapLyo = "tap_lyo"
        case enableVoice = "enable_voice"
        case createCourse = "create_course"
        case exploreDiscover = "explore_discover"
        case joinCommunity = "join_community"
        case customizeProfile = "customize_profile"
    }

    enum OnboardingPrerequisite: String, Codable {
        case firstLaunch = "first_launch"
        case afterFirstMessage = "after_first_message"
        case afterFirstCourse = "after_first_course"
        case after5Interactions = "after_5_interactions"
        case afterVoicePermission = "after_voice_permission"
    }
}

// MARK: - User Proficiency Level

enum UserProficiency: String, Codable {
    case newUser = "new_user"
    case beginner
    case developing
    case intermediate
    case proficient
    case advanced
    case expert
}

struct OnboardingProgress: Codable {
    var currentStep: String?
    var completedSteps: Set<String> = []
    var skippedSteps: Set<String> = []
    var stepShowCounts: [String: Int] = [:]
    var lastShownDate: [String: Date] = [:]
    var userProficiencyLevel: UserProficiency = .newUser
    var currentLevel: Int = 1 // User's current numeric level
    var onboardingCompleted: Bool = false
}

// MARK: - Progressive Feature Disclosure

struct FeatureDisclosure: Identifiable, Codable {
    let id: String
    let featureName: String
    let unlockCondition: UnlockCondition
    let announcement: FeatureAnnouncement
    let tutorialSteps: [TutorialStep]

    enum UnlockCondition: Codable {
        case interactionCount(Int)
        case completedCourse
        case usedVoiceInput
        case createdContent
        case joinedCommunity
        case userLevel(UserLevel)
        case timeSpent(TimeInterval)

        var description: String {
            switch self {
            case .interactionCount(let count):
                return "Complete \(count) conversations with Lyo"
            case .completedCourse:
                return "Complete your first course"
            case .usedVoiceInput:
                return "Try voice input with Lyo"
            case .createdContent:
                return "Create your first post or video"
            case .joinedCommunity:
                return "Join a study group"
            case .userLevel(let level):
                return "Reach level \(level.level)"
            case .timeSpent(let time):
                return "Spend \(Int(time/60)) minutes learning"
            }
        }
        
        // Manual Equatable conformance for associated values
        static func == (lhs: UnlockCondition, rhs: UnlockCondition) -> Bool {
            switch (lhs, rhs) {
            case (.interactionCount(let a), .interactionCount(let b)):
                return a == b
            case (.completedCourse, .completedCourse),
                 (.usedVoiceInput, .usedVoiceInput),
                 (.createdContent, .createdContent),
                 (.joinedCommunity, .joinedCommunity):
                return true
            case (.userLevel(let a), .userLevel(let b)):
                return a == b
            case (.timeSpent(let a), .timeSpent(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    struct FeatureAnnouncement: Codable {
        let title: String
        let description: String
        let icon: String
        let celebrationStyle: CelebrationStyle

        enum CelebrationStyle: String, Codable {
            case confetti, glow, pulse, bounce
        }
    }

    struct TutorialStep: Codable {
        let id: String
        let instruction: String
        let highlightTarget: String?
        let duration: TimeInterval
        
        init(id: String = UUID().uuidString, instruction: String, highlightTarget: String? = nil, duration: TimeInterval) {
            self.id = id
            self.instruction = instruction
            self.highlightTarget = highlightTarget
            self.duration = duration
        }
    }
}

// MARK: - Lyo Onboarding Manager

@MainActor
class LyoOnboardingManager: ObservableObject {
    static let shared = LyoOnboardingManager()

    @Published var currentOnboardingStep: OnboardingStep?
    @Published var progress: OnboardingProgress = OnboardingProgress()
    @Published var availableFeatures: Set<String> = ["basic_chat"]
    @Published var pendingFeatureUnlock: FeatureDisclosure?
    @Published var showOnboardingOverlay: Bool = false

    // Contextual hints
    @Published var activeHints: [ContextualHint] = []
    @Published var hintDismissalCount: [String: Int] = [:]

    private let userDefaults = UserDefaults.standard
    private let onboardingSteps: [OnboardingStep] = LyoOnboardingManager.defaultOnboardingSteps
    private let featureDisclosures: [FeatureDisclosure] = LyoOnboardingManager.defaultFeatureDisclosures

    // Interaction tracking
    @Published var interactionCount: Int = 0
    @Published var totalTimeSpent: TimeInterval = 0
    @Published var coursesCompleted: Int = 0
    @Published var voiceInputUsed: Bool = false
    @Published var contentCreated: Bool = false

    private var sessionStartTime = Date()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadProgress()
        setupProgressTracking()
        checkForPendingSteps()
    }

    // MARK: - Core Onboarding Logic

    func startOnboarding() {
        guard !progress.onboardingCompleted else { return }

        showOnboardingOverlay = true
        showNextApplicableStep()
    }

    func completeCurrentStep() {
        guard let currentStep = currentOnboardingStep else { return }

        progress.completedSteps.insert(currentStep.id)
        currentOnboardingStep = nil

        // Save progress
        saveProgress()

        // Track event
        LyoAnalyticsManager.shared.trackEvent("tutorial_step_completed", parameters: ["step_id": currentStep.id])

        // Check if onboarding is complete
        checkOnboardingCompletion()

        // Show next step after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showNextApplicableStep()
        }
    }

    func skipCurrentStep() {
        guard let currentStep = currentOnboardingStep else { return }

        progress.skippedSteps.insert(currentStep.id)
        currentOnboardingStep = nil

        saveProgress()

        // Track event
        LyoAnalyticsManager.shared.trackEvent("tutorial_step_skipped", parameters: ["step_id": currentStep.id])

        // Show next step
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showNextApplicableStep()
        }
    }

    func dismissOnboarding() {
        currentOnboardingStep = nil
        showOnboardingOverlay = false
        progress.onboardingCompleted = true
        saveProgress()
    }

    // MARK: - Progressive Feature Disclosure

    func checkFeatureUnlocks() {
        for feature in featureDisclosures {
            guard !availableFeatures.contains(feature.id) else { continue }

            if isUnlockConditionMet(feature.unlockCondition) {
                unlockFeature(feature)
            }
        }
    }

    private func isUnlockConditionMet(_ condition: FeatureDisclosure.UnlockCondition) -> Bool {
        switch condition {
        case .interactionCount(let required):
            return interactionCount >= required
        case .completedCourse:
            return coursesCompleted > 0
        case .usedVoiceInput:
            return voiceInputUsed
        case .createdContent:
            return contentCreated
        case .joinedCommunity:
            // This would be tracked separately
            return false
        case .userLevel(let required):
            // Compare numeric levels
            return progress.currentLevel >= required.level
        case .timeSpent(let required):
            return totalTimeSpent >= required
        }
    }

    private func unlockFeature(_ feature: FeatureDisclosure) {
        availableFeatures.insert(feature.id)
        pendingFeatureUnlock = feature

        // Trigger celebration
        HapticManager.shared.success()

        // Auto-dismiss after showing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.pendingFeatureUnlock = nil
        }

        saveProgress()
    }

    // MARK: - Contextual Hints

    func showContextualHint(
        _ hint: ContextualHint,
        condition: HintCondition = .always
    ) {
        // Check if we should show this hint
        guard shouldShowHint(hint, condition: condition) else { return }

        // Remove existing hint with same ID
        activeHints.removeAll { $0.id == hint.id }

        // Add new hint
        activeHints.append(hint)

        // Auto-dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.dismissHint(hint.id)
        }
    }

    func dismissHint(_ hintId: UUID) {
        activeHints.removeAll { $0.id == hintId }

        // Track dismissal
        let dismissalKey = hintId.uuidString
        hintDismissalCount[dismissalKey, default: 0] += 1
    }

    private func shouldShowHint(
        _ hint: ContextualHint,
        condition: HintCondition
    ) -> Bool {
        let dismissalKey = hint.id.uuidString
        let dismissCount = hintDismissalCount[dismissalKey, default: 0]

        // Don't show if dismissed too many times
        guard dismissCount < 3 else { return false }

        // Check condition
        switch condition {
        case .always:
            return true
        case .newUser:
            return progress.userProficiencyLevel == .newUser
        case .developing:
            return progress.userProficiencyLevel == .developing
        case .afterInteractions(let count):
            return interactionCount >= count
        case .onlyOnce:
            return dismissCount == 0
        }
    }

    enum HintCondition {
        case always
        case newUser
        case developing
        case afterInteractions(Int)
        case onlyOnce
    }

    // MARK: - Progress Tracking

    func trackInteraction() {
        interactionCount += 1

        // Update user proficiency
        updateUserProficiency()

        // Check for feature unlocks
        checkFeatureUnlocks()

        // Show contextual hints
        showApplicableHints()

        saveProgress()
    }

    func trackCourseCompletion() {
        coursesCompleted += 1
        checkFeatureUnlocks()
        saveProgress()
    }

    func trackVoiceInputUsed() {
        voiceInputUsed = true
        checkFeatureUnlocks()
        saveProgress()
    }

    func trackContentCreation() {
        contentCreated = true
        checkFeatureUnlocks()
        saveProgress()
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

        if newProficiency != progress.userProficiencyLevel {
            progress.userProficiencyLevel = newProficiency

            // Show proficiency upgrade celebration
            showProficiencyUpgrade(newProficiency)
        }
    }

    private func showProficiencyUpgrade(_ newLevel: UserProficiency) {
        let hint = ContextualHint(
            title: "Level Up! 🎉",
            description: "You've reached \(newLevel.rawValue) level with Lyo!",
            icon: "star.fill",
            action: nil,
            priority: 1
        )

        showContextualHint(hint, condition: .onlyOnce)
    }

    // MARK: - Step Management

    private func showNextApplicableStep() {
        guard !progress.onboardingCompleted else {
            showOnboardingOverlay = false
            return
        }

        // Find the next applicable step
        let applicableSteps = onboardingSteps.filter { step in
            // Not completed or skipped
            !progress.completedSteps.contains(step.id) &&
            !progress.skippedSteps.contains(step.id) &&

            // Prerequisite met
            isPrerequisiteMet(step.prerequisite) &&

            // Not shown too many times
            (progress.stepShowCounts[step.id] ?? 0) < step.maxShowCount
        }
        .sorted { $0.priority < $1.priority }

        guard let nextStep = applicableSteps.first else {
            // No more applicable steps
            progress.onboardingCompleted = true
            showOnboardingOverlay = false
            saveProgress()
            return
        }

        // Check delay
        if let lastShown = progress.lastShownDate[nextStep.id] {
            let timeSinceLastShown = Date().timeIntervalSince(lastShown)
            if timeSinceLastShown < nextStep.delayAfterPrevious {
                // Too soon, try again later
                DispatchQueue.main.asyncAfter(deadline: .now() + nextStep.delayAfterPrevious - timeSinceLastShown) {
                    self.showNextApplicableStep()
                }
                return
            }
        }

        // Show the step
        currentOnboardingStep = nextStep
        progress.stepShowCounts[nextStep.id, default: 0] += 1
        progress.lastShownDate[nextStep.id] = Date()

        saveProgress()
    }

    private func isPrerequisiteMet(_ prerequisite: OnboardingStep.OnboardingPrerequisite?) -> Bool {
        guard let prerequisite = prerequisite else { return true }

        switch prerequisite {
        case .firstLaunch:
            return interactionCount == 0
        case .afterFirstMessage:
            return interactionCount >= 1
        case .afterFirstCourse:
            return coursesCompleted >= 1
        case .after5Interactions:
            return interactionCount >= 5
        case .afterVoicePermission:
            return voiceInputUsed
        }
    }

    private func checkOnboardingCompletion() {
        let essentialSteps = onboardingSteps.filter { $0.priority <= 2 }
        let completedEssential = essentialSteps.filter { progress.completedSteps.contains($0.id) }

        if completedEssential.count >= essentialSteps.count - 1 {
            progress.onboardingCompleted = true
            showOnboardingOverlay = false
        }
    }

    private func showApplicableHints() {
        // Show hints based on interaction count
        if interactionCount == 1 {
            showContextualHint(
                ContextualHint(
                    title: "Voice Input Available",
                    description: "Hold the Lyo button to speak instead of typing",
                    icon: "mic.fill",
                    action: "enable_voice",
                    priority: 2
                ),
                condition: .onlyOnce
            )
        }

        if interactionCount == 3 {
            showContextualHint(
                ContextualHint(
                    title: "Course Creation",
                    description: "I can create complete learning courses for you",
                    icon: "book.fill",
                    action: "create_course",
                    priority: 2
                ),
                condition: .onlyOnce
            )
        }

        if interactionCount == 5 {
            showContextualHint(
                ContextualHint(
                    title: "Discover Content",
                    description: "Explore videos and content from other learners",
                    icon: "play.rectangle.fill",
                    action: "explore_discover",
                    priority: 3
                ),
                condition: .onlyOnce
            )
        }
    }

    // MARK: - Persistence

    private func setupProgressTracking() {
        // Track session time
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.totalTimeSpent += 60
                self.saveProgress()
            }
            .store(in: &cancellables)
    }

    private func checkForPendingSteps() {
        // Check if we should show onboarding on launch
        if !progress.onboardingCompleted && progress.completedSteps.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startOnboarding()
            }
        } else {
            // Check for contextual hints
            showApplicableHints()
        }
    }

    private func loadProgress() {
        if let data = userDefaults.data(forKey: "LyoOnboardingProgress"),
           let decodedProgress = try? JSONDecoder().decode(OnboardingProgress.self, from: data) {
            progress = decodedProgress
        }

        // Load tracking data
        interactionCount = userDefaults.integer(forKey: "lyoInteractionCount")
        totalTimeSpent = userDefaults.double(forKey: "lyoTotalTimeSpent")
        coursesCompleted = userDefaults.integer(forKey: "lyoCoursesCompleted")
        voiceInputUsed = userDefaults.bool(forKey: "lyoVoiceInputUsed")
        contentCreated = userDefaults.bool(forKey: "lyoContentCreated")

        // Load available features
        if let features = userDefaults.array(forKey: "lyoAvailableFeatures") as? [String] {
            availableFeatures = Set(features)
        }

        // Load hint dismissal counts
        if let dismissals = userDefaults.dictionary(forKey: "lyoHintDismissals") as? [String: Int] {
            hintDismissalCount = dismissals
        }
    }

    private func saveProgress() {
        // Save progress
        if let data = try? JSONEncoder().encode(progress) {
            userDefaults.set(data, forKey: "LyoOnboardingProgress")
        }

        // Save tracking data
        userDefaults.set(interactionCount, forKey: "lyoInteractionCount")
        userDefaults.set(totalTimeSpent, forKey: "lyoTotalTimeSpent")
        userDefaults.set(coursesCompleted, forKey: "lyoCoursesCompleted")
        userDefaults.set(voiceInputUsed, forKey: "lyoVoiceInputUsed")
        userDefaults.set(contentCreated, forKey: "lyoContentCreated")

        // Save available features
        userDefaults.set(Array(availableFeatures), forKey: "lyoAvailableFeatures")

        // Save hint dismissal counts
        userDefaults.set(hintDismissalCount, forKey: "lyoHintDismissals")
    }
}

// MARK: - Default Onboarding Steps

extension LyoOnboardingManager {
    static let defaultOnboardingSteps: [OnboardingStep] = [
        OnboardingStep(
            id: "welcome",
            title: "Welcome to Lyo! 👋",
            description: "I'm your AI learning companion. I can teach you anything, create courses, and help you study!",
            icon: "hand.wave.fill",
            targetView: nil,
            action: .tapLyo,
            prerequisite: .firstLaunch,
            priority: 1,
            maxShowCount: 1,
            delayAfterPrevious: 0
        ),
        OnboardingStep(
            id: "voice_input",
            title: "Try Voice Input 🎤",
            description: "Hold my button to speak instead of typing. Much faster for questions!",
            icon: "mic.fill",
            targetView: "lyo_avatar",
            action: .enableVoice,
            prerequisite: .afterFirstMessage,
            priority: 2,
            maxShowCount: 2,
            delayAfterPrevious: 30
        ),
        OnboardingStep(
            id: "course_creation",
            title: "I Can Create Courses! 📚",
            description: "Just say 'teach me [topic]' and I'll create a complete learning course for you.",
            icon: "book.fill",
            targetView: nil,
            action: .createCourse,
            prerequisite: .after5Interactions,
            priority: 2,
            maxShowCount: 1,
            delayAfterPrevious: 60
        ),
        OnboardingStep(
            id: "discover_content",
            title: "Discover Learning Content 🎥",
            description: "Explore videos, posts, and content created by other learners in the Discover tab.",
            icon: "play.rectangle.fill",
            targetView: "discover_tab",
            action: .exploreDiscover,
            prerequisite: .after5Interactions,
            priority: 3,
            maxShowCount: 1,
            delayAfterPrevious: 120
        ),
        OnboardingStep(
            id: "community",
            title: "Join Study Groups 👥",
            description: "Connect with other learners and join study groups in the Community section.",
            icon: "person.3.fill",
            targetView: "community_tab",
            action: .joinCommunity,
            prerequisite: .after5Interactions,
            priority: 4,
            maxShowCount: 1,
            delayAfterPrevious: 300
        ),
        OnboardingStep(
            id: "profile_customization",
            title: "Customize Your Profile ⚙️",
            description: "Set your learning preferences and track your progress in your profile.",
            icon: "person.circle.fill",
            targetView: "profile_tab",
            action: .customizeProfile,
            prerequisite: .after5Interactions,
            priority: 5,
            maxShowCount: 1,
            delayAfterPrevious: 600
        )
    ]

    static let defaultFeatureDisclosures: [FeatureDisclosure] = [
        FeatureDisclosure(
            id: "voice_input",
            featureName: "Voice Input",
            unlockCondition: .interactionCount(3),
            announcement: FeatureDisclosure.FeatureAnnouncement(
                title: "🎤 Voice Input Unlocked!",
                description: "You can now hold the Lyo button to speak your questions",
                icon: "mic.fill",
                celebrationStyle: .glow
            ),
            tutorialSteps: [
                FeatureDisclosure.TutorialStep(
                    instruction: "Hold the Lyo button",
                    highlightTarget: "lyo_avatar",
                    duration: 3.0
                ),
                FeatureDisclosure.TutorialStep(
                    instruction: "Speak your question clearly",
                    highlightTarget: nil,
                    duration: 3.0
                ),
                FeatureDisclosure.TutorialStep(
                    instruction: "Release when done speaking",
                    highlightTarget: "lyo_avatar",
                    duration: 2.0
                )
            ]
        ),
        FeatureDisclosure(
            id: "course_creation",
            featureName: "Course Creation",
            unlockCondition: .interactionCount(5),
            announcement: FeatureDisclosure.FeatureAnnouncement(
                title: "📚 Course Creation Unlocked!",
                description: "I can now create complete learning courses for you",
                icon: "book.fill",
                celebrationStyle: .confetti
            ),
            tutorialSteps: []
        ),
        FeatureDisclosure(
            id: "advanced_features",
            featureName: "Advanced Features",
            unlockCondition: .interactionCount(10),
            announcement: FeatureDisclosure.FeatureAnnouncement(
                title: "🚀 Advanced Features Unlocked!",
                description: "Access to premium AI capabilities and advanced customization",
                icon: "sparkles",
                celebrationStyle: .pulse
            ),
            tutorialSteps: []
        ),
        FeatureDisclosure(
            id: "content_creation",
            featureName: "Content Creation Tools",
            unlockCondition: .completedCourse,
            announcement: FeatureDisclosure.FeatureAnnouncement(
                title: "🎨 Content Creation Unlocked!",
                description: "Create and share your own learning content",
                icon: "plus.app.fill",
                celebrationStyle: .bounce
            ),
            tutorialSteps: []
        )
    ]
}