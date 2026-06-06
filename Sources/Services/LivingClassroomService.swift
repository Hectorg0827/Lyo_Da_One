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

    private var componentQueue: [SDUIComponent] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnecting: Bool = false
    private var sessionId: String = ""
    private var connectedSessionId: String = ""
    private var localFallbackSceneIndex: Int = 0
    private let logger = Logger(subsystem: "com.lyo.app", category: "LivingClassroomService")

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
    }

    private func normalizedSessionId(from rawSessionId: String) -> String {
        rawSessionId.hasPrefix("GENERATE:")
            ? String(rawSessionId.dropFirst("GENERATE:".count))
            : rawSessionId
    }

    /// Connects to the real-time Server-Driven UI WebSockets
    func connect(sessionId: String, topic: String? = nil) {
        guard webSocketTask == nil, !isConnecting else {
            logger.info(
                "WebSocket is already connecting or connected. Ignoring duplicate connect request.")
            return
        }

        isConnecting = true
        self.sessionId = sessionId

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

                let request = URLRequest(url: url)

                self.webSocketTask = session.webSocketTask(with: request)
                self.webSocketTask?.resume()
                self.isConnected = true
                self.isConnecting = false
                self.error = nil

                self.receiveMessages()
            } catch {
                self.logger.error("Failed to connect: \(error.localizedDescription)")
                self.error = error
                self.isConnected = false
                self.isConnecting = false
                self.webSocketTask = nil
            }
        }
    }

    /// Gracefully closes the connection
    func disconnect() {
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

    /// Sends a user action (e.g. button tap) back to the backend
    func sendUserAction(actionIntent: String, componentId: String, actionData: [String: Any]? = nil)
    {
        guard let task = webSocketTask else {
            logger.warning("Cannot send user action — WebSocket not connected")
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
                    self.error = error
                    self.webSocketTask = nil
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
        self.sceneRevision += 1
        self.currentScene = scene
        self.renderedComponents = []
        self.componentQueue = scene.components
        self.hasQueuedComponents = !self.componentQueue.isEmpty

        logger.info(
            "Started rendering scene: \(scene.sceneType) [\(scene.id)] with \(scene.components.count) components"
        )

        // Auto-reveal the first chunk
        revealNextComponent()
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
        // Can trigger any completion logic here, like haptics or auto-scroll
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
}
