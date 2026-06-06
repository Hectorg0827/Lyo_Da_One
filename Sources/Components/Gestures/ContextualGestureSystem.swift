import SwiftUI
import UIKit

// MARK: - Gesture Models

enum SwipeDirection: CaseIterable {
    case up, down, left, right, upLeft, upRight, downLeft, downRight

    static func detectDirection(from translation: CGSize) -> SwipeDirection {
        let angle = atan2(translation.height, translation.width)
        let degrees = angle * 180 / .pi

        // Normalize to 0-360 degrees
        let normalizedDegrees = degrees < 0 ? degrees + 360 : degrees

        switch normalizedDegrees {
        case 0..<22.5, 337.5..<360:
            return .right
        case 22.5..<67.5:
            return .downRight
        case 67.5..<112.5:
            return .down
        case 112.5..<157.5:
            return .downLeft
        case 157.5..<202.5:
            return .left
        case 202.5..<247.5:
            return .upLeft
        case 247.5..<292.5:
            return .up
        case 292.5..<337.5:
            return .upRight
        default:
            return .right
        }
    }
}

enum GestureType: String, CaseIterable {
    case swipe = "swipe"
    case longPress = "long_press"
    case doubleTap = "double_tap"
    case pinch = "pinch"
    case rotation = "rotation"
    case shake = "shake"

    var accessibilityDescription: String {
        switch self {
        case .swipe:
            return "Swipe gesture"
        case .longPress:
            return "Long press gesture"
        case .doubleTap:
            return "Double tap gesture"
        case .pinch:
            return "Pinch gesture"
        case .rotation:
            return "Rotation gesture"
        case .shake:
            return "Shake gesture"
        }
    }
}

struct ContextualGesture: Identifiable {
    let id = UUID()
    let gestureType: GestureType
    let direction: SwipeDirection?
    let context: LearningContext
    let action: GestureAction
    let description: String
    let icon: String
    let isEnabled: Bool
    let priority: Int // 1-5, 1 being highest

    struct GestureAction {
        let id: String
        let title: String
        let handler: () -> Void
    }
}

// MARK: - Contextual Gesture Manager

@MainActor
class ContextualGestureManager: ObservableObject {
    static let shared = ContextualGestureManager()

    @Published var activeContext: LearningContext?
    @Published var availableGestures: [ContextualGesture] = []
    @Published var gestureHints: [GestureHint] = []
    @Published var isGestureDiscoveryMode: Bool = false
    @Published var recentGestures: [String] = []

    // Settings
    @Published var gesturesEnabled: Bool = true
    @Published var gestureHintsEnabled: Bool = true
    @Published var hapticFeedbackEnabled: Bool = true

    // Analytics
    @Published var gestureUsageCount: [String: Int] = [:]
    @Published var lastGestureTime: Date?

    private let userDefaults = UserDefaults.standard
    private let hapticManager = HapticManager.shared

    // Dependencies
    weak var orchestrator: LyoOrchestrator?

    private init() {
        loadSettings()
        setupDefaultGestures()
        setupGestureAnalytics()
    }

    // MARK: - Gesture Registration

    func updateContext(_ context: LearningContext) {
        activeContext = context
        updateAvailableGestures()
        updateGestureHints()
    }

    func handleGesture(_ gestureType: GestureType, direction: SwipeDirection? = nil, value: Any? = nil) {
        guard gesturesEnabled else { return }

        let gestureId = buildGestureId(gestureType, direction: direction)

        // Find matching contextual gesture
        if let contextualGesture = findContextualGesture(gestureType, direction: direction) {
            executeContextualGesture(contextualGesture)
        } else {
            // Fallback to general gestures
            executeGeneralGesture(gestureType, direction: direction, value: value)
        }

        // Track usage
        trackGestureUsage(gestureId)

        // Update hints
        updateGestureHints()
    }

    // MARK: - Contextual Gesture Execution

    private func findContextualGesture(_ gestureType: GestureType, direction: SwipeDirection?) -> ContextualGesture? {
        guard let context = activeContext else { return nil }

        return availableGestures.first { gesture in
            gesture.gestureType == gestureType &&
            gesture.direction == direction &&
            gesture.context.contentType == context.contentType &&
            gesture.isEnabled
        }
    }

    private func executeContextualGesture(_ gesture: ContextualGesture) {
        if hapticFeedbackEnabled {
            provideFeedback(for: gesture.gestureType)
        }

        // Execute the action
        gesture.action.handler()

        // Show success hint if appropriate
        if gestureHintsEnabled && shouldShowSuccessHint(gesture) {
            showGestureSuccessHint(gesture)
        }

        // Track for learning
        addToRecentGestures(gesture.action.id)
    }

    private func executeGeneralGesture(_ gestureType: GestureType, direction: SwipeDirection?, value: Any?) {
        if hapticFeedbackEnabled {
            provideFeedback(for: gestureType)
        }

        switch gestureType {
        case .shake:
            handleShakeGesture()

        case .doubleTap:
            handleDoubleTap()

        case .longPress:
            handleLongPress()

        case .swipe:
            if let direction = direction {
                handleGeneralSwipe(direction)
            }

        case .pinch:
            if let scale = value as? CGFloat {
                handlePinchGesture(scale)
            }

        case .rotation:
            if let angle = value as? Angle {
                handleRotationGesture(angle)
            }
        }
    }

    // MARK: - General Gesture Handlers

    private func handleShakeGesture() {
        // Toggle accessibility features or gesture discovery
        if UIAccessibility.isVoiceOverRunning {
            toggleGestureDiscoveryMode()
        } else {
            // Normal shake action - refresh or reset
            NotificationCenter.default.post(
                name: NSNotification.Name("RefreshCurrentView"),
                object: nil
            )
        }
    }

    private func handleDoubleTap() {
        // Quick action based on context
        guard let context = activeContext else { return }

        switch context.contentType {
        case .conversation:
            // Quick repeat or ask follow-up
            NotificationCenter.default.post(
                name: NSNotification.Name("TriggerQuickAction"),
                object: nil,
                userInfo: ["action": "repeat_last"]
            )

        case .video:
            // Toggle play/pause or ask about content
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleVideoPlayback"),
                object: nil
            )

        case .course:
            // Quick quiz or next lesson
            NotificationCenter.default.post(
                name: NSNotification.Name("TriggerQuickQuiz"),
                object: nil
            )

        case .quiz:
            // Show hint or explanation
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowQuizHint"),
                object: nil
            )

        case .explainer:
            // Ask for more detail
            NotificationCenter.default.post(
                name: NSNotification.Name("RequestMoreDetail"),
                object: nil
            )
        }
    }

    private func handleLongPress() {
        // Context menu or voice input
        if UIAccessibility.isVoiceOverRunning {
            // Accessible context menu
            showAccessibleContextMenu()
        } else {
            // Try voice input
            NotificationCenter.default.post(
                name: NSNotification.Name("TriggerVoiceInput"),
                object: nil
            )
        }
    }

    private func handleGeneralSwipe(_ direction: SwipeDirection) {
        guard let context = activeContext else { return }

        switch (direction, context.contentType) {
        case (.right, .course):
            // Next lesson
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToNextLesson"),
                object: nil
            )

        case (.left, .course):
            // Previous lesson
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToPreviousLesson"),
                object: nil
            )

        case (.up, .video):
            // Ask about video content
            askAboutCurrentContent()

        case (.down, .video):
            // Dismiss or minimize
            NotificationCenter.default.post(
                name: NSNotification.Name("MinimizeCurrentView"),
                object: nil
            )

        case (.left, .quiz):
            // Previous question
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToPreviousQuestion"),
                object: nil
            )

        case (.right, .quiz):
            // Next question
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToNextQuestion"),
                object: nil
            )

        case (.up, .conversation):
            // Scroll to recent messages
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollToRecentMessages"),
                object: nil
            )

        case (.down, .conversation):
            // Show suggestions
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowSuggestions"),
                object: nil
            )

        default:
            // Default swipe behaviors
            handleDefaultSwipe(direction)
        }
    }

    private func handlePinchGesture(_ scale: CGFloat) {
        if scale > 1.1 {
            // Zoom in - show details or enlarge text
            NotificationCenter.default.post(
                name: NSNotification.Name("ZoomIn"),
                object: nil
            )
        } else if scale < 0.9 {
            // Zoom out - show overview or reduce text size
            NotificationCenter.default.post(
                name: NSNotification.Name("ZoomOut"),
                object: nil
            )
        }
    }

    private func handleRotationGesture(_ angle: Angle) {
        // Rotate through related content or views
        let threshold: Double = 45 // degrees

        if abs(angle.degrees) > threshold {
            NotificationCenter.default.post(
                name: NSNotification.Name("RotateToRelatedContent"),
                object: nil,
                userInfo: ["direction": angle.degrees > 0 ? "clockwise" : "counterclockwise"]
            )
        }
    }

    private func handleDefaultSwipe(_ direction: SwipeDirection) {
        switch direction {
        case .left:
            // Go back or previous item
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateBack"),
                object: nil
            )

        case .right:
            // Go forward or next item
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateForward"),
                object: nil
            )

        case .up:
            // Show more options or details
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowMoreOptions"),
                object: nil
            )

        case .down:
            // Minimize or close
            NotificationCenter.default.post(
                name: NSNotification.Name("MinimizeCurrentView"),
                object: nil
            )

        default:
            break
        }
    }

    // MARK: - Helper Methods

    private func askAboutCurrentContent() {
        guard let context = activeContext else { return }

        var message = "Tell me more about this content"

        if context.clipId != nil {
            message = "Explain what's happening in this video"
        }

        Task {
            await orchestrator?.processUserMessage(message, currentContext: context)
        }
    }

    private func showAccessibleContextMenu() {
        let availableActions = availableGestures.map { gesture in
            "\(gesture.description): \(gesture.gestureType.accessibilityDescription)"
        }

        let announcement = "Available gestures: \(availableActions.joined(separator: ", "))"

        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
    }

    // MARK: - Gesture Setup

    private func setupDefaultGestures() {
        // This will be populated based on context
        updateAvailableGestures()
    }

    private func updateAvailableGestures() {
        guard let context = activeContext else {
            availableGestures = []
            return
        }

        var gestures: [ContextualGesture] = []

        // Add context-specific gestures
        switch context.contentType {
        case .course:
            gestures.append(contentsOf: getCourseGestures(context))

        case .video:
            gestures.append(contentsOf: getVideoGestures(context))

        case .quiz:
            gestures.append(contentsOf: getQuizGestures(context))

        case .conversation:
            gestures.append(contentsOf: getConversationGestures(context))

        case .explainer:
            gestures.append(contentsOf: getExplainerGestures(context))
        }

        // Add universal gestures
        gestures.append(contentsOf: getUniversalGestures(context))

        // Sort by priority and filter enabled gestures
        availableGestures = gestures
            .filter { $0.isEnabled }
            .sorted { $0.priority < $1.priority }
    }

    // MARK: - Context-Specific Gestures

    private func getCourseGestures(_ context: LearningContext) -> [ContextualGesture] {
        return [
            ContextualGesture(
                gestureType: .swipe,
                direction: .right,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "next_lesson",
                    title: "Next Lesson",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToNextLesson"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe right for next lesson",
                icon: "arrow.right",
                isEnabled: true,
                priority: 1
            ),
            ContextualGesture(
                gestureType: .swipe,
                direction: .left,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "previous_lesson",
                    title: "Previous Lesson",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToPreviousLesson"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe left for previous lesson",
                icon: "arrow.left",
                isEnabled: true,
                priority: 2
            ),
            ContextualGesture(
                gestureType: .doubleTap,
                direction: nil,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "quick_quiz",
                    title: "Quick Quiz",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TriggerQuickQuiz"),
                            object: nil
                        )
                    }
                ),
                description: "Double tap for quick quiz",
                icon: "questionmark.circle",
                isEnabled: true,
                priority: 3
            )
        ]
    }

    private func getVideoGestures(_ context: LearningContext) -> [ContextualGesture] {
        return [
            ContextualGesture(
                gestureType: .swipe,
                direction: .up,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "ask_about_video",
                    title: "Ask About Video",
                    handler: { [weak self] in
                        self?.askAboutCurrentContent()
                    }
                ),
                description: "Swipe up to ask about video content",
                icon: "questionmark.bubble",
                isEnabled: true,
                priority: 1
            ),
            ContextualGesture(
                gestureType: .doubleTap,
                direction: nil,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "toggle_playback",
                    title: "Toggle Playback",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ToggleVideoPlayback"),
                            object: nil
                        )
                    }
                ),
                description: "Double tap to play/pause",
                icon: "play.pause",
                isEnabled: true,
                priority: 2
            ),
            ContextualGesture(
                gestureType: .swipe,
                direction: .left,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "previous_video",
                    title: "Previous Video",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToPreviousVideo"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe left for previous video",
                icon: "backward.fill",
                isEnabled: true,
                priority: 3
            ),
            ContextualGesture(
                gestureType: .swipe,
                direction: .right,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "next_video",
                    title: "Next Video",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToNextVideo"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe right for next video",
                icon: "forward.fill",
                isEnabled: true,
                priority: 4
            )
        ]
    }

    private func getQuizGestures(_ context: LearningContext) -> [ContextualGesture] {
        return [
            ContextualGesture(
                gestureType: .swipe,
                direction: .right,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "next_question",
                    title: "Next Question",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToNextQuestion"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe right for next question",
                icon: "arrow.right",
                isEnabled: true,
                priority: 1
            ),
            ContextualGesture(
                gestureType: .swipe,
                direction: .left,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "previous_question",
                    title: "Previous Question",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToPreviousQuestion"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe left for previous question",
                icon: "arrow.left",
                isEnabled: true,
                priority: 2
            ),
            ContextualGesture(
                gestureType: .doubleTap,
                direction: nil,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "show_hint",
                    title: "Show Hint",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowQuizHint"),
                            object: nil
                        )
                    }
                ),
                description: "Double tap for hint",
                icon: "lightbulb",
                isEnabled: true,
                priority: 3
            ),
            ContextualGesture(
                gestureType: .swipe,
                direction: .up,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "explain_question",
                    title: "Explain Question",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExplainCurrentQuestion"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe up to explain question",
                icon: "doc.text",
                isEnabled: true,
                priority: 4
            )
        ]
    }

    private func getConversationGestures(_ context: LearningContext) -> [ContextualGesture] {
        return [
            ContextualGesture(
                gestureType: .swipe,
                direction: .down,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "show_suggestions",
                    title: "Show Suggestions",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowSuggestions"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe down for suggestions",
                icon: "list.bullet",
                isEnabled: true,
                priority: 1
            ),
            ContextualGesture(
                gestureType: .swipe,
                direction: .up,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "scroll_to_recent",
                    title: "Recent Messages",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ScrollToRecentMessages"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe up to see recent messages",
                icon: "arrow.up.doc",
                isEnabled: true,
                priority: 2
            ),
            ContextualGesture(
                gestureType: .longPress,
                direction: nil,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "voice_input",
                    title: "Voice Input",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TriggerVoiceInput"),
                            object: nil
                        )
                    }
                ),
                description: "Long press for voice input",
                icon: "mic",
                isEnabled: true,
                priority: 3
            )
        ]
    }

    private func getExplainerGestures(_ context: LearningContext) -> [ContextualGesture] {
        return [
            ContextualGesture(
                gestureType: .doubleTap,
                direction: nil,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "more_detail",
                    title: "More Detail",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RequestMoreDetail"),
                            object: nil
                        )
                    }
                ),
                description: "Double tap for more detail",
                icon: "plus.magnifyingglass",
                isEnabled: true,
                priority: 1
            ),
            ContextualGesture(
                gestureType: .swipe,
                direction: .right,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "next_concept",
                    title: "Next Concept",
                    handler: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToNextConcept"),
                            object: nil
                        )
                    }
                ),
                description: "Swipe right for next concept",
                icon: "arrow.right",
                isEnabled: true,
                priority: 2
            )
        ]
    }

    private func getUniversalGestures(_ context: LearningContext) -> [ContextualGesture] {
        return [
            ContextualGesture(
                gestureType: .shake,
                direction: nil,
                context: context,
                action: ContextualGesture.GestureAction(
                    id: "refresh",
                    title: "Refresh",
                    handler: { [weak self] in
                        self?.handleShakeGesture()
                    }
                ),
                description: "Shake to refresh or access help",
                icon: "arrow.clockwise",
                isEnabled: true,
                priority: 10
            )
        ]
    }

    // MARK: - Gesture Hints

    private func updateGestureHints() {
        guard gestureHintsEnabled && shouldShowHints() else {
            gestureHints = []
            return
        }

        var hints: [GestureHint] = []

        // Show hints for unused gestures
        let unusedGestures = availableGestures.filter { gesture in
            let usageCount = gestureUsageCount[gesture.action.id] ?? 0
            return usageCount < 2 && gesture.priority <= 3
        }

        for gesture in unusedGestures.prefix(2) {
            hints.append(GestureHint(
                id: gesture.action.id,
                description: gesture.description,
                icon: gesture.icon,
                gestureType: gesture.gestureType,
                priority: gesture.priority
            ))
        }

        gestureHints = hints
    }

    private func shouldShowHints() -> Bool {
        // Show hints for new users or when learning new contexts
        let totalGestureUsage = gestureUsageCount.values.reduce(0, +)
        return totalGestureUsage < 20 || hasNewContext()
    }

    private func hasNewContext() -> Bool {
        guard let context = activeContext else { return false }

        let contextKey = "\(context.contentType.rawValue)_\(context.source.rawValue)"
        let lastSeenTime = userDefaults.double(forKey: "lastSeenContext_\(contextKey)")

        if lastSeenTime == 0 {
            userDefaults.set(Date().timeIntervalSince1970, forKey: "lastSeenContext_\(contextKey)")
            return true
        }

        let timeSinceLastSeen = Date().timeIntervalSince1970 - lastSeenTime
        return timeSinceLastSeen > 86400 // 24 hours
    }

    private func showGestureSuccessHint(_ gesture: ContextualGesture) {
        let hint = GestureHint(
            id: "\(gesture.action.id)_success",
            description: "Great! \(gesture.description) worked perfectly.",
            icon: "checkmark.circle",
            gestureType: gesture.gestureType,
            priority: 1
        )

        // Show temporarily
        gestureHints.insert(hint, at: 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.gestureHints.removeAll { $0.id == hint.id }
        }
    }

    private func shouldShowSuccessHint(_ gesture: ContextualGesture) -> Bool {
        let usageCount = gestureUsageCount[gesture.action.id] ?? 0
        return usageCount == 1 // Show success hint on first use
    }

    // MARK: - Analytics and Learning

    private func trackGestureUsage(_ gestureId: String) {
        gestureUsageCount[gestureId, default: 0] += 1
        lastGestureTime = Date()

        // Update recent gestures
        addToRecentGestures(gestureId)

        // Save analytics
        saveGestureAnalytics()
    }

    private func addToRecentGestures(_ gestureId: String) {
        recentGestures.insert(gestureId, at: 0)

        // Keep only recent 10 gestures
        if recentGestures.count > 10 {
            recentGestures = Array(recentGestures.prefix(10))
        }
    }

    private func buildGestureId(_ gestureType: GestureType, direction: SwipeDirection?) -> String {
        if let direction = direction {
            return "\(gestureType.rawValue)_\(direction)"
        } else {
            return gestureType.rawValue
        }
    }

    // MARK: - Feedback

    private func provideFeedback(for gestureType: GestureType) {
        guard hapticFeedbackEnabled else { return }

        switch gestureType {
        case .swipe:
            hapticManager.light()
        case .doubleTap:
            hapticManager.medium()
        case .longPress:
            hapticManager.heavy()
        case .pinch:
            hapticManager.light()
        case .rotation:
            hapticManager.light()
        case .shake:
            hapticManager.heavy()
        }
    }

    // MARK: - Discovery Mode

    func toggleGestureDiscoveryMode() {
        isGestureDiscoveryMode.toggle()

        if isGestureDiscoveryMode {
            announceAvailableGestures()
        }

        // Auto-disable after 30 seconds
        if isGestureDiscoveryMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.isGestureDiscoveryMode = false
            }
        }
    }

    private func announceAvailableGestures() {
        let gestureDescriptions = availableGestures.prefix(5).map { $0.description }
        let announcement = "Gesture discovery mode enabled. Available gestures: \(gestureDescriptions.joined(separator: ", "))"

        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
    }

    // MARK: - Persistence

    private func setupGestureAnalytics() {
        // Load existing analytics
        if let data = userDefaults.data(forKey: "gestureUsageCount"),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            gestureUsageCount = counts
        }

        if let gestures = userDefaults.stringArray(forKey: "recentGestures") {
            recentGestures = gestures
        }
    }

    private func saveGestureAnalytics() {
        if let data = try? JSONEncoder().encode(gestureUsageCount) {
            userDefaults.set(data, forKey: "gestureUsageCount")
        }

        userDefaults.set(recentGestures, forKey: "recentGestures")
    }

    private func loadSettings() {
        gesturesEnabled = userDefaults.object(forKey: "gesturesEnabled") as? Bool ?? true
        gestureHintsEnabled = userDefaults.object(forKey: "gestureHintsEnabled") as? Bool ?? true
        hapticFeedbackEnabled = userDefaults.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
    }

    func saveSettings() {
        userDefaults.set(gesturesEnabled, forKey: "gesturesEnabled")
        userDefaults.set(gestureHintsEnabled, forKey: "gestureHintsEnabled")
        userDefaults.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
    }
}

// MARK: - Gesture Hint Model

struct GestureHint: Identifiable {
    let id: String
    let description: String
    let icon: String
    let gestureType: GestureType
    let priority: Int
}

// MARK: - Gesture View Modifier

struct ContextualGestureViewModifier: ViewModifier {
    @StateObject private var gestureManager = ContextualGestureManager.shared
    let context: LearningContext?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if let context = context {
                    gestureManager.updateContext(context)
                }
            }
            .onChange(of: context) { _, newContext in
                if let newContext = newContext {
                    gestureManager.updateContext(newContext)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let direction = SwipeDirection.detectDirection(from: value.translation)
                        gestureManager.handleGesture(.swipe, direction: direction)
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        gestureManager.handleGesture(.doubleTap)
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.0)
                    .onEnded { _ in
                        gestureManager.handleGesture(.longPress)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onEnded { scale in
                        gestureManager.handleGesture(.pinch, value: scale)
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onEnded { angle in
                        gestureManager.handleGesture(.rotation, value: angle)
                    }
            )
            .overlay(
                Group {
                    if !gestureManager.gestureHints.isEmpty {
                        VStack {
                            Spacer()

                            ForEach(gestureManager.gestureHints) { hint in
                                GestureHintView(hint: hint)
                            }
                        }
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gestureManager.gestureHints.count)
    }
}

// MARK: - Gesture Hint View

struct GestureHintView: View {
    let hint: GestureHint
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hint.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "6366F1"))

            Text(hint.description)
                .font(.caption)
                .foregroundColor(.white)

            Spacer()

            Text(hint.gestureType.accessibilityDescription)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }

            // Auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hint.description)
        .accessibilityHint("Gesture hint. \(hint.gestureType.accessibilityDescription)")
    }
}

// MARK: - Extension

extension View {
    func contextualGestures(_ context: LearningContext?) -> some View {
        modifier(ContextualGestureViewModifier(context: context))
    }
}