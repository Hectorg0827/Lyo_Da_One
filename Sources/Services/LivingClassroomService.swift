import Combine
import Foundation
import SwiftUI
import os

@MainActor
class LivingClassroomService: ObservableObject {
    @Published var currentScene: SDUIScene?
    @Published var renderedComponents: [SDUIComponent] = []
    @Published var isConnected: Bool = false
    @Published var error: Error?

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

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnecting: Bool = false
    private var sessionId: String = ""
    private let logger = Logger(subsystem: "com.lyo.app", category: "LivingClassroomService")

    // MARK: - On-device engine + continuation

    private let engine = LivingClassroomEngine()
    private var topic: String = ""
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

        // Start a watchdog: if the backend doesn't deliver a first scene in time,
        // seamlessly switch to the on-device engine so the lesson never stalls.
        startStallWatchdog(timeout: firstSceneTimeout, reason: "first scene")

        Task {
            do {
                // Use Lyo JWT access token (what the backend expects)
                // Fall back to Firebase token, then guest mode
                let token: String
                if let lyoToken = await TokenManager.shared.getToken() {
                    token = lyoToken
                } else if let fbToken = try? await FirebaseAuthManager.refreshToken() {
                    token = fbToken
                    self.logger.warning("Using Firebase token for WebSocket (no Lyo JWT available)")
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

                let encodedSessionId =
                    sessionId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    ?? sessionId
                guard
                    let url = URL(
                        string:
                            "\(wsBaseString)/api/v1/classroom/ws/connect?session_id=\(encodedSessionId)"
                    )
                else {
                    self.logger.error("Invalid WebSocket URL")
                    throw URLError(.badURL)
                }

                self.logger.info("Connecting to WebSocket: \(url.absoluteString)")

                let session = URLSession(configuration: .default)
                self.urlSession = session

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
        logger.info("Disconnected from WebSocket")
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

        var payload: [String: Any] = [
            "event_type": "user_action",
            "session_id": sessionId,
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
        case "too_easy":
            recordLearnerSignal(.init(kind: .tooEasy, detail: ""))
        default:
            break
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

            Task { @MainActor in
                switch envelope.type {
                case "scene_stream", "scene_start", "SCENE_START":
                    // Backend sends scene in root-level "scene" key, not inside "data"
                    if let rootObj = try? JSONSerialization.jsonObject(with: data)
                        as? [String: Any],
                        let sceneDict = rootObj["scene"] as? [String: Any],
                        let sceneData = try? JSONSerialization.data(withJSONObject: sceneDict),
                        let scene = try? decoder.decode(SDUIScene.self, from: sceneData)
                    {
                        self.startSceneRender(scene)
                    } else {
                        self.logger.warning("scene_start: could not extract scene from message")
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

        self.currentScene = scene
        self.renderedComponents = []
        self.isGenerating = false
        self.canContinue = false
        self.statusText = nil
        logger.info(
            "Started rendering scene: \(scene.sceneType) [\(scene.id)] with \(scene.components.count) components"
        )

        // Render components embedded in the scene payload
        for component in scene.components {
            renderComponent(component)
        }

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
        // Find if component already exists - if so, skip or update it
        if !self.renderedComponents.contains(where: { $0.id == component.id }) {
            // Respect the server-side staggered delay for cinematic effect
            let delayTime = TimeInterval(component.delayMs) / 1000.0

            if delayTime > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.renderedComponents.append(component)
                    }
                }
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.renderedComponents.append(component)
                }
            }
            logger.info("Rendered component: \(component.type.rawValue) - \(component.id)")
        }
    }

    private func completeSceneRender() {
        logger.info("Completed rendering scene")
        // Backend signaled the scene is done — let the learner advance.
        isGenerating = false
        if !lessonComplete { canContinue = true }
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
