import Combine
import Foundation
import SwiftUI
import os

@MainActor
class LivingClassroomService: ObservableObject {
    @Published var currentScene: SDUIScene?
    @Published var renderedComponents: [SDUIComponent] = []
    @Published var hasQueuedComponents: Bool = false
    @Published var isConnected: Bool = false
    @Published var error: Error?
    @Published private(set) var sceneRevision: Int = 0

    // MARK: - Continuous-lesson state (drives the never-dead-end experience)

    /// True while the next scene is being prepared (network or on-device engine).
    @Published var isGenerating: Bool = false
    /// True once a scene has finished revealing and the learner can advance.
    @Published var canContinue: Bool = false
    /// True when the full curriculum has been delivered.
    @Published var lessonComplete: Bool = false
    /// Whether content is currently being produced by the on-device engine.
    @Published var usingLocalEngine: Bool = false
    /// Short status string for the UI (e.g. "Designing your lesson…").
    @Published var statusText: String?

    private var componentQueue: [SDUIComponent] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnecting: Bool = false
    private var sessionId: String = ""
    private var connectedSessionId: String = ""
    private var localFallbackSceneIndex: Int = 0
    private let logger = Logger(subsystem: "com.lyo.app", category: "LivingClassroomService")

    // MARK: - On-device engine + continuation

    private let engine = LivingClassroomEngine()
    private var topic: String = ""
    /// When the current scene began rendering — used to estimate time-on-task
    /// for knowledge tracing.
    private var sceneStartedAt = Date()
    /// One-shot memory greeting composed from the mastery profile; prepended
    /// to the first scene so the mascot visibly remembers the learner.
    private var pendingMemoryGreeting: String?
    /// Whether the backend has ever delivered a scene on this connection.
    private var didReceiveBackendScene: Bool = false
    /// Watchdog that switches to the on-device engine if the backend stalls.
    private var stallTask: Task<Void, Never>?
    /// Marks the can-continue state after a scene's staggered reveal finishes.
    private var revealTask: Task<Void, Never>?

    /// How long to wait for the backend to deliver the *first* scene before the
    /// on-device engine takes over.
    private let firstSceneTimeout: TimeInterval = 8.0
    /// How long to wait for the backend to deliver the *next* scene (after the
    /// learner taps Continue) before the on-device engine takes over.
    private let nextSceneTimeout: TimeInterval = 6.0

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
    }

    private func normalizedSessionId(from rawSessionId: String) -> String {
        rawSessionId.hasPrefix("GENERATE:")
            ? String(rawSessionId.dropFirst("GENERATE:".count))
            : rawSessionId
    }

    /// Connects to the real-time Server-Driven UI WebSockets.
    /// - Parameters:
    ///   - sessionId: The classroom session / course identifier.
    ///   - topic: Human-readable lesson topic used by the on-device engine if the
    ///     backend is unavailable or stalls. Defaults to the sessionId.
    func connect(sessionId: String, topic: String? = nil) {
        self.topic = (topic?.isEmpty == false ? topic! : sessionId)

        guard webSocketTask == nil, !isConnecting else {
            logger.info(
                "WebSocket is already connecting or connected. Ignoring duplicate connect request.")
            return
        }

        isConnecting = true
        self.sessionId = sessionId
        self.isGenerating = true
        self.statusText = "Connecting to your live classroom…"

        // Load the persisted mastery profile so on-device generation starts
        // where the learner actually is. Fire-and-forget: a miss just means
        // prompts run without prior-session context.
        Task { [weak self] in
            if let profile = try? await PersonalizationService.shared.getMasteryProfile() {
                self?.engine.setMasteryContext(profile)
                self?.pendingMemoryGreeting = Self.composeMemoryGreeting(
                    from: profile, topic: self?.topic ?? "")
            }
        }

        // Start a watchdog: if the backend doesn't deliver a first scene in time,
        // seamlessly switch to the on-device engine so the lesson never stalls.
        startStallWatchdog(timeout: firstSceneTimeout, reason: "first scene")

        Task {
            do {
                // Use Lyo JWT access token (what the backend expects).
                // If the access token is absent, try refreshing via stored refresh token,
                // then try exchanging the Firebase token for a Lyo JWT.
                let token: String
                if let lyoToken = await TokenManager.shared.getToken() {
                    token = lyoToken
                } else if await TokenManager.shared.getRefreshToken() != nil,
                          let freshToken = try? await DefaultAuthRepository().refreshToken() {
                    token = freshToken
                    self.logger.info("Obtained fresh Lyo JWT via refresh token")
                } else if let fbToken = try? await FirebaseAuthManager.refreshToken(),
                          (try? await LyoRepository.shared.loginWithGoogle(idToken: fbToken)) != nil,
                          let freshToken = await TokenManager.shared.getToken() {
                    token = freshToken
                    self.logger.info("Re-exchanged Firebase token for Lyo JWT")
                } else {
                    token = "guest"
                    self.logger.warning("No auth token available — connecting as guest")
                }

                // Formulate WebSocket URL from the base API URL
                let baseUrlString = AppConfig.baseURL
                let wsBaseString =
                    baseUrlString
                    .replacingOccurrences(of: "https://", with: "wss://")
                    .replacingOccurrences(of: "http://", with: "ws://")

                // Strip "GENERATE:" prefix — pass just the topic as the session_id
                let resolvedSessionId = self.normalizedSessionId(from: sessionId)
                self.connectedSessionId = resolvedSessionId

                let encodedSessionId =
                    resolvedSessionId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    ?? resolvedSessionId
                let encodedToken =
                    token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    ?? token

                // Topic: use passed topic, fall back to session_id itself
                let resolvedTopic = topic ?? resolvedSessionId
                let encodedTopic =
                    resolvedTopic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    ?? resolvedTopic

                // Backend WebSocket auth requires token as query param (not header)
                guard
                    let url = URL(
                        string:
                            "\(wsBaseString)/api/v1/classroom/ws/connect?session_id=\(encodedSessionId)&token=\(encodedToken)&topic=\(encodedTopic)"
                    )
                else {
                    self.logger.error("Invalid WebSocket URL")
                    throw URLError(.badURL)
                }

                self.logger.info("Connecting to WebSocket: \(url.absoluteString)")

                let session = URLSession(configuration: .default)
                self.urlSession = session

                // Send the token both as a query param (required) and as a header for
                // backends that also honor Authorization.
                var request = URLRequest(url: url)
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                self.webSocketTask = session.webSocketTask(with: request)
                self.webSocketTask?.resume()
                self.isConnected = true
                self.isConnecting = false
                self.error = nil

                self.receiveMessages()
            } catch {
                self.logger.error("Failed to connect: \(error.localizedDescription)")
                self.isConnected = false
                self.isConnecting = false
                self.webSocketTask = nil
                // Don't surface the error or dead-end — run the on-device lesson.
                self.startLocalLesson()
            }
        }
    }

    /// Gracefully closes the connection
    func disconnect() {
        stallTask?.cancel()
        stallTask = nil
        revealTask?.cancel()
        revealTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnected = false
        isConnecting = false
        connectedSessionId = ""
        localFallbackSceneIndex = 0
        logger.info("Disconnected from WebSocket")
    }

    /// Re-establishes the WebSocket using the previously stored sessionId. Used by the UI's reconnect banner.
    func reconnect() {
        guard !sessionId.isEmpty else {
            logger.warning("Cannot reconnect — no sessionId stored")
            return
        }
        logger.info("\u{1F501} Reconnecting WebSocket for session \(self.sessionId)")
        // Clear any half-open task before reconnecting.
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnecting = false
        error = nil
        connect(sessionId: sessionId)
    }

    /// Sends a user action (e.g. button tap) back to the backend.
    /// Also captures the interaction for the on-device engine so the lesson can
    /// adapt to the learner (and so it works even with no backend).
    func sendUserAction(actionIntent: String, componentId: String, actionData: [String: Any]? = nil)
    {
        captureLearnerInteraction(
            actionIntent: actionIntent, componentId: componentId, actionData: actionData)

        guard let task = webSocketTask else {
            logger.info("WebSocket not connected — handling action on-device")
            return
        }

        let outboundSessionId = connectedSessionId.isEmpty
            ? normalizedSessionId(from: sessionId)
            : connectedSessionId

        var payload: [String: Any] = [
            "event_type": "user_action",
            "session_id": outboundSessionId,
            "action_intent": actionIntent,
            "component_id": componentId,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]

        if let actionData = actionData {
            payload["answer_data"] = actionData
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
            let jsonString = String(data: data, encoding: .utf8)
        else {
            logger.error("Failed to serialize user action payload")
            return
        }

        task.send(.string(jsonString)) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.logger.error("Failed to send user action: \(error.localizedDescription)")
                } else {
                    self?.logger.info("📤 Sent user action: \(actionIntent)")
                }
            }
        }
    }

    var nextQueuedComponent: SDUIComponent? {
        componentQueue.first
    }

    func showLocalFallbackScene(topic: String) {
        localFallbackSceneIndex += 1
        let scene = makeLocalFallbackScene(topic: topic, sceneIndex: localFallbackSceneIndex)
        logger.warning("Using local classroom fallback scene \(self.localFallbackSceneIndex) for \(topic)")
        startSceneRender(scene)
    }

    func showLocalQuickCheck(topic: String, focusText: String? = nil) {
        localFallbackSceneIndex += 1
        let scene = makeLocalQuickCheckScene(
            topic: topic,
            focusText: focusText,
            sceneIndex: localFallbackSceneIndex
        )
        logger.info("Using local classroom quick check \(self.localFallbackSceneIndex) for \(topic)")
        startSceneRender(scene)
    }

    /// Translate a UI action into an engine learner-signal and, in on-device mode,
    /// drive the lesson accordingly (answer questions immediately, adapt to quiz).
    private func captureLearnerInteraction(
        actionIntent: String, componentId: String, actionData: [String: Any]?
    ) {
        switch actionIntent {
        case "quiz_answer":
            let selectedId = actionData?["selected_option_id"] as? String
            let selectedLabel = (actionData?["selected_option_label"] as? String) ?? selectedId ?? ""
            // Determine correctness from the component's known answer, if present.
            var correct = false
            if let component = renderedComponents.first(where: { $0.id == componentId }),
                let answerId = component.actionPayload?["answer_option_id"] {
                correct = (answerId == selectedId)
            }
            recordLearnerSignal(
                .init(kind: .answeredQuiz(correct: correct, choice: selectedLabel),
                      detail: selectedLabel))
            // Persist to the backend mastery profile (Deep Knowledge Tracing).
            traceQuizOutcome(componentId: componentId, correct: correct)

        case "user_message", "ask_question":
            let message = (actionData?["message"] as? String) ?? ""
            guard !message.isEmpty else { return }
            recordLearnerSignal(.init(kind: .askedQuestion(message), detail: message))
            // In on-device mode, answer the question right away as a new scene.
            if usingLocalEngine, !isGenerating {
                isGenerating = true
                canContinue = false
                statusText = "Thinking about your question…"
                produceLocalScene()
            }

        case "confused":
            recordLearnerSignal(.init(kind: .confused, detail: ""))
            reportAffect(valence: -0.5, arousal: 0.6, source: "classroom_confused")
        case "too_easy":
            recordLearnerSignal(.init(kind: .tooEasy, detail: ""))
            reportAffect(valence: 0.2, arousal: -0.3, source: "classroom_too_easy")
        default:
            break
        }
    }

    /// Composes a short spoken-style welcome that references the learner's
    /// persisted mastery, so returning learners are greeted by name-of-skill
    /// rather than a cold start. Returns nil for brand-new learners.
    static func composeMemoryGreeting(from profile: MasteryProfile, topic: String) -> String? {
        guard !profile.skills.isEmpty else { return nil }
        let strength = profile.strengths.first
        let weakness = (profile.recommendedFocus.first ?? profile.weaknesses.first)
        let topicLine = topic.isEmpty ? "" : " Today we're on \(topic) — let's make it count."

        switch (strength, weakness) {
        case let (s?, w?) where s.caseInsensitiveCompare(w) != .orderedSame:
            return "Welcome back! Last time you showed real strength in \(s), and \(w) put up a fight — if it comes up today, we'll hit it from a new angle.\(topicLine)"
        case let (_, w?):
            return "Welcome back! I remember \(w) gave us a good challenge last time — watch how today's ideas connect back to it.\(topicLine)"
        case let (s?, _):
            return "Welcome back! You've been on a roll with \(s).\(topicLine)"
        default:
            return "Welcome back!\(topicLine)"
        }
    }

    // MARK: - Learner model persistence

    /// Sends a quiz outcome to the backend knowledge tracer so mastery survives
    /// the session. Fire-and-forget: a failure must never disturb the lesson.
    private func traceQuizOutcome(componentId: String, correct: Bool) {
        let skill = topic.isEmpty ? "general" : topic
        let timeTaken = min(max(Date().timeIntervalSince(sceneStartedAt), 0), 600)
        Task { [weak self] in
            guard let learnerId = await TokenManager.shared.getUserId() else { return }
            do {
                try await PersonalizationService.shared.traceKnowledge(
                    trace: KnowledgeTraceRequest(
                        learnerId: learnerId,
                        skillId: skill,
                        itemId: componentId,
                        correct: correct,
                        timeTakenSeconds: timeTaken
                    ))
                self?.logger.info("🧠 Traced quiz outcome (\(correct ? "correct" : "incorrect")) for skill \(skill)")
            } catch {
                self?.logger.warning("Knowledge trace failed (lesson unaffected): \(error.localizedDescription)")
            }
        }
    }

    /// Reports an affect signal (confusion / boredom) to the learner state so
    /// future sessions can adjust pacing. Fire-and-forget.
    private func reportAffect(valence: Double, arousal: Double, source: String) {
        Task {
            guard let learnerId = await TokenManager.shared.getUserId() else { return }
            try? await PersonalizationService.shared.updateState(
                update: PersonalizationStateUpdate(
                    learnerId: learnerId,
                    affect: AffectSignals(
                        valence: valence, arousal: arousal, confidence: 0.7,
                        source: [source]
                    )
                ))
        }
    }

    /// Constantly listens for incoming WebSocket messages
    private func receiveMessages() {
        guard let task = webSocketTask else { return }

        task.receive { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.logger.debug("Received message: \(text)")
                        self.handleWebSocketMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleWebSocketMessage(text)
                        }
                    @unknown default:
                        self.logger.warning("Received unknown WebSocket message type")
                    }

                    // Continue listening
                    self.receiveMessages()

                case .failure(let error):
                    self.logger.error("WebSocket receiving error: \(error.localizedDescription)")
                    self.isConnected = false
                    self.isConnecting = false
                    self.webSocketTask = nil
                    // Never dead-end: if the lesson isn't finished, continue on-device.
                    if !self.lessonComplete && !self.usingLocalEngine {
                        self.startLocalLesson()
                    }
                }
            }
        }
    }

    /// Parses the JSON payload and routes events for SDUI streaming
    private func handleWebSocketMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }

        do {
            let decoder = JSONDecoder()
            // The top level wrapper maps to WebSocketEnvelope to get the type and session
            let envelope = try decoder.decode(WebSocketEnvelope.self, from: data)
            if let serverSessionId = envelope.sessionId, !serverSessionId.isEmpty {
                let normalized = normalizedSessionId(from: serverSessionId)
                if connectedSessionId != normalized {
                    connectedSessionId = normalized
                    logger.info("Using backend classroom session id: \(normalized)")
                }
            }

            Task { @MainActor in
                switch envelope.type {
                case "scene_stream", "scene_start", "SCENE_START":
                    // Backend may send scene at root["scene"] or nested under root["data"]["scene"]
                    if let rootObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let sceneDict =
                            (rootObj["scene"] as? [String: Any])
                            ?? (rootObj["data"] as? [String: Any]).flatMap { $0["scene"] as? [String: Any] }
                        if let sceneDict = sceneDict,
                           let sceneData = try? JSONSerialization.data(withJSONObject: sceneDict),
                           let scene = try? decoder.decode(SDUIScene.self, from: sceneData)
                        {
                            self.startSceneRender(scene)
                        } else {
                            self.logger.warning("scene_start: could not extract scene from message")
                        }
                    }

                case "component_stream", "component_render", "COMPONENT_RENDER":
                    // For component streams, decode the `component` portion (backend sends "data": {} empty)
                    if let rootObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    {
                        let componentObj =
                            (rootObj["component"] as? [String: Any])
                            ?? (rootObj["data"] as? [String: Any]).flatMap({ $0.isEmpty ? nil : $0 }
                            ) ?? rootObj
                        if let componentData = try? JSONSerialization.data(
                            withJSONObject: componentObj)
                        {
                            do {
                                let component = try decoder.decode(
                                    SDUIComponent.self, from: componentData)
                                self.renderComponent(component)
                            } catch {
                                self.logger.error(
                                    "❌ Failed to decode component: \(error.localizedDescription)")
                                if let raw = String(data: componentData, encoding: .utf8) {
                                    self.logger.error("Raw component JSON: \(raw)")
                                }
                            }
                        }
                    }

                case "scene_complete", "SCENE_COMPLETE":
                    self.completeSceneRender()

                case "system_state":
                    self.logger.info(
                        "Received system_state message - fully connected to Live Classroom stream")

                case "control":
                    self.logger.info("Received control message")
                case "error":
                    self.logger.error("Received server error stream event")
                default:
                    self.logger.warning("Unknown message type: \(envelope.type)")
                }
            }
        } catch {
            logger.error("Failed to decode WebSocket message: \(error.localizedDescription)")
            logger.error("Raw message: \(message)")
        }
    }

    // MARK: - Handlers

    private func startSceneRender(_ scene: SDUIScene) {
        // A scene arrived (from backend or engine) — cancel any stall watchdog.
        stallTask?.cancel()
        stallTask = nil
        didReceiveBackendScene = didReceiveBackendScene || !usingLocalEngine

        self.sceneRevision += 1
        self.sceneStartedAt = Date()
        self.currentScene = scene

        // First scene of the session: lead with the memory greeting so the
        // mascot visibly remembers the learner. Flows through the normal
        // component-reveal pipeline; consumed exactly once.
        var components = scene.components
        if self.sceneRevision == 1, let greeting = pendingMemoryGreeting {
            pendingMemoryGreeting = nil
            components.insert(
                SDUIComponent(
                    id: "memory-greeting",
                    type: .teacherMessage,
                    content: greeting,
                    animation: "fade_in",
                    emotion: "warm"
                ), at: 0)
        }

        self.renderedComponents = []
        self.componentQueue = components
        self.hasQueuedComponents = !self.componentQueue.isEmpty
        self.isGenerating = false
        self.canContinue = false
        self.statusText = nil

        logger.info(
            "Started rendering scene: \(scene.sceneType) [\(scene.id)] with \(scene.components.count) components"
        )

        // Auto-reveal the first chunk (staggered, teacher-paced)
        revealNextComponent()
        // Once the staggered reveal completes, allow the learner to continue.
        scheduleCanContinue(after: scene)
    }

    /// Computes when the last component will have appeared and flips `canContinue`.
    private func scheduleCanContinue(after scene: SDUIScene) {
        revealTask?.cancel()
        let maxDelayMs = scene.components.map { $0.delayMs }.max() ?? 0
        let totalDelay = TimeInterval(maxDelayMs) / 1000.0 + 0.6
        revealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if !self.lessonComplete { self.canContinue = true }
            }
        }
    }

    private func renderComponent(_ component: SDUIComponent) {
        // If it's already on screen, update it seamlessly
        if let index = self.renderedComponents.firstIndex(where: { $0.id == component.id }) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.renderedComponents[index] = component
            }
            logger.info("Updated visible component: \(component.type.rawValue) - \(component.id)")
        }
        // If it's still in the queue, update its data so it's ready when revealed
        else if let index = self.componentQueue.firstIndex(where: { $0.id == component.id }) {
            self.componentQueue[index] = component
            logger.info("Updated queued component: \(component.type.rawValue) - \(component.id)")
        }
        // If it's completely new, add it to the queue
        else {
            self.componentQueue.append(component)
            self.hasQueuedComponents = true
            logger.info("Queued new component: \(component.type.rawValue) - \(component.id)")

            if self.renderedComponents.isEmpty {
                revealNextComponent()
            }
        }
    }

    /// Pulls the next component from the queue and displays it.
    /// Manages the auto-pacing simulation of a "teacher teaching".
    func revealNextComponent() {
        guard !componentQueue.isEmpty else { return }

        let component = componentQueue.removeFirst()
        self.hasQueuedComponents = !componentQueue.isEmpty

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            self.renderedComponents.append(component)
        }

        // Simulate teacher pacing: Auto-reveal the next component after a reading delay,
        // UNLESS the next component requires explicit user interaction.
        if !componentQueue.isEmpty {
            let nextComponent = componentQueue[0]

            let requiresPause = nextComponent.type == .studentPrompt
                             || nextComponent.type == .quizCard
                             || nextComponent.type == .ctaButton

            if !requiresPause {
                // Calculate realistic reading delay (approx 50ms per character)
                let charCount = max(component.content.count, 40)
                let delay = Double(charCount) * 0.05
                let cappedDelay = min(max(delay, 1.0), 5.0)

                DispatchQueue.main.asyncAfter(deadline: .now() + cappedDelay) {
                    // Only auto-reveal if the user hasn't manually tapped ahead
                    if self.hasQueuedComponents && self.componentQueue.first?.id == nextComponent.id {
                        self.revealNextComponent()
                    }
                }
            }
        }
    }

    private func completeSceneRender() {
        logger.info("Completed rendering scene")
        // Backend signaled the scene is done — let the learner advance.
        isGenerating = false
        if !lessonComplete { canContinue = true }
    }

    private func makeLocalFallbackScene(topic: String, sceneIndex: Int) -> SDUIScene {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "this topic"
            : topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let phase = (sceneIndex - 1) % 4
        let prefix = "local_\(sceneIndex)"

        let messages: [String]
        switch phase {
        case 0:
            messages = [
                "Let's start for real. \(cleanTopic) is not about memorizing harder; it is about choosing the right kind of effort at the right time.",
                "The first move is attention. Before you study, decide what you are trying to understand, then remove one distraction that would split your focus.",
                "The second move is active recall. After a short study pass, close the notes and pull the idea back from memory in your own words. That retrieval is where learning gets stronger."
            ]
        case 1:
            messages = [
                "Now let's make it practical. Strong learners use short cycles: learn, test, correct, then repeat.",
                "If something feels familiar while you read it, that is not proof you know it. Proof comes when you can explain it without looking.",
                "A useful rule is simple: if you cannot teach the idea in one minute, you have found the next thing to practice."
            ]
        case 2:
            messages = [
                "Here is the common trap: rereading feels productive because it is comfortable, but it often hides weak memory.",
                "Better practice feels slightly harder. Mix old and new ideas, answer questions, and let mistakes show you where to focus next.",
                "This is called desirable difficulty: the work is challenging enough to build memory, but not so hard that you cannot recover."
            ]
        default:
            messages = [
                "Let's lock this in. For \(cleanTopic), your study system should have three parts: focus, recall, and feedback.",
                "Focus helps the idea enter clearly. Recall makes the memory stronger. Feedback shows what needs another pass.",
                "Next, I can turn this into a quick classroom challenge so you can prove what you remember."
            ]
        }

        var components = messages.enumerated().map { index, text in
            SDUIComponent(
                id: "\(prefix)_teacher_\(index + 1)",
                type: .teacherMessage,
                content: text,
                delayMs: index == 0 ? 0 : 650,
                animation: "fade_in",
                emotion: index == 0 ? "encouraging" : "focused"
            )
        }

        if phase == 3 {
            components.append(
                SDUIComponent(
                    id: "\(prefix)_quiz",
                    type: .quizCard,
                    content: "Quick check",
                    delayMs: 650,
                    animation: "fade_in",
                    emotion: "challenge",
                    question: "Which study move best proves you actually understand an idea?",
                    options: [
                        SDUIQuizOption(id: "a", label: "Rereading the same notes many times"),
                        SDUIQuizOption(id: "b", label: "Explaining it from memory without looking"),
                        SDUIQuizOption(id: "c", label: "Highlighting the longest paragraph"),
                        SDUIQuizOption(id: "d", label: "Waiting until the test to practice")
                    ],
                    actionIntent: "submit_answer",
                    actionPayload: ["correct_option_id": "b"]
                )
            )
        }

        components.append(
            SDUIComponent(
                id: "\(prefix)_continue",
                type: .ctaButton,
                content: phase == 3 ? "Keep Practicing" : "Continue",
                delayMs: 500,
                animation: "fade_in",
                actionIntent: "continue",
                actionPayload: ["source": "local_fallback", "scene_index": String(sceneIndex)]
            )
        )

        return SDUIScene(
            id: "local_fallback_scene_\(sceneIndex)",
            sceneType: phase == 3 ? "quiz" : "instruction",
            components: components
        )
    }

    private func makeLocalQuickCheckScene(
        topic: String,
        focusText: String?,
        sceneIndex: Int
    ) -> SDUIScene {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "this topic"
            : topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFocus = focusText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let focus = cleanFocus?.isEmpty == false ? cleanFocus! : "the idea we just discussed"
        let prefix = "quick_check_\(sceneIndex)"

        let components: [SDUIComponent] = [
            SDUIComponent(
                id: "\(prefix)_teacher",
                type: .teacherMessage,
                content: "Checkpoint time. I made a quick question from \(cleanTopic) so you can test the idea instead of just rereading it.",
                delayMs: 0,
                animation: "fade_in",
                emotion: "challenge"
            ),
            SDUIComponent(
                id: "\(prefix)_quiz",
                type: .quizCard,
                content: "Quick check",
                delayMs: 400,
                animation: "fade_in",
                emotion: "challenge",
                question: "What should you do next if \(focus.lowercased()) still feels unclear?",
                options: [
                    SDUIQuizOption(id: "a", label: "Move on and hope it clicks later"),
                    SDUIQuizOption(id: "b", label: "Explain it from memory, then fix the weak part"),
                    SDUIQuizOption(id: "c", label: "Only reread the same paragraph"),
                    SDUIQuizOption(id: "d", label: "Skip practice until the final test")
                ],
                actionIntent: "submit_answer",
                actionPayload: ["correct_option_id": "b", "source": "local_quick_check"]
            ),
            SDUIComponent(
                id: "\(prefix)_continue",
                type: .ctaButton,
                content: "Continue",
                delayMs: 500,
                animation: "fade_in",
                actionIntent: "continue",
                actionPayload: ["source": "local_quick_check", "scene_index": String(sceneIndex)]
            )
        ]

        return SDUIScene(
            id: "local_quick_check_scene_\(sceneIndex)",
            sceneType: "quiz",
            components: components
        )
    }

    // MARK: - Continuation Loop (the core "never dead-ends" fix)

    /// Advance the lesson. Called when the learner taps "Continue".
    /// Prefers the backend, but falls back to the on-device engine if the backend
    /// stalls — guaranteeing the lesson always progresses.
    func requestNextScene() {
        guard !isGenerating, !lessonComplete else { return }
        canContinue = false
        isGenerating = true
        statusText = "Preparing the next part…"

        if usingLocalEngine {
            produceLocalScene()
            return
        }

        // Ask the backend for the next scene…
        sendUserAction(actionIntent: "next_scene", componentId: "continue")
        // …but don't trust it to answer. If it stalls, the engine takes over.
        startStallWatchdog(timeout: nextSceneTimeout, reason: "next scene")
    }

    /// Allow the learner to jump straight into the on-device, unlimited lesson.
    func switchToLocalLesson() {
        guard !usingLocalEngine else { return }
        startLocalLesson()
    }

    // MARK: - On-device engine driving

    private func startStallWatchdog(timeout: TimeInterval, reason: String) {
        stallTask?.cancel()
        stallTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                guard !self.usingLocalEngine else { return }
                self.logger.warning("Backend stalled (\(reason)) — switching to on-device classroom engine")
                self.startLocalLesson()
            }
        }
    }

    private func startLocalLesson() {
        stallTask?.cancel()
        stallTask = nil
        usingLocalEngine = true
        isGenerating = true
        canContinue = false
        statusText = "Designing your lesson…"

        // Capture whatever the backend already showed so the engine can continue
        // the thread instead of starting over.
        let priorContent = renderedComponents
            .filter { $0.type == .teacherMessage || $0.type == .textBlock }
            .map { $0.content }

        Task { [weak self] in
            guard let self else { return }
            if !self.engine.isReady {
                await self.engine.bootstrap(topic: self.topic)
                if self.didReceiveBackendScene {
                    self.engine.primePriorKnowledge(priorContent)
                }
            }
            await self.produceNextLocalSceneAsync()
        }
    }

    private func produceLocalScene() {
        Task { [weak self] in
            await self?.produceNextLocalSceneAsync()
        }
    }

    private func produceNextLocalSceneAsync() async {
        isGenerating = true
        statusText = "Lyo is teaching…"
        if let scene = await engine.generateNextScene() {
            startSceneRender(scene)
        } else {
            // Curriculum complete.
            isGenerating = false
            canContinue = false
            lessonComplete = true
            statusText = nil
            logger.info("On-device lesson complete for topic: \(self.topic)")
        }
    }

    /// Feed learner interactions into the engine for adaptivity.
    func recordLearnerSignal(_ signal: LivingClassroomEngine.LearnerSignal) {
        engine.record(signal)
    }
}
