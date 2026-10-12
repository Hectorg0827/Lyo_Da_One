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

    // MARK: - Shared lesson state

    /// True while the server is preparing the next scene.
    @Published var isGenerating: Bool = false
    /// True once a scene has finished revealing and the learner can advance.
    @Published var canContinue: Bool = false
    /// True when the full curriculum has been delivered.
    @Published var lessonComplete: Bool = false
    /// Short status string for the UI (e.g. "Designing your lesson…").
    @Published var statusText: String?

    // MARK: - Waiting, and waiting too long

    /// How far past "the next step is coming" the current wait has gone.
    /// Waiting is the one classroom state with no natural end: every other
    /// one is left by something the learner or the teacher does, so when a
    /// generation fails the class does not break, it simply stops, with a
    /// "preparing the next step…" line that is true forever.
    @Published private(set) var stallPhase: ClassroomStallPhase = .none
    /// Something the classroom reported and is carrying on from. Distinct
    /// from `error`, which means the class itself is over.
    @Published var notice: String?
    /// True when this class picked up a session the learner had already
    /// started, so the opening can say so.
    @Published private(set) var resumedSession: Bool = false
    /// A session the learner could still return to, if they want it.
    @Published private(set) var resumableSession: ClassroomSavedSession?
    /// The cover page: what this class is, before any of it is taught.
    @Published private(set) var opening: ClassroomOpening?

    private var componentQueue: [SDUIComponent] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var activityUpdates: [String: [String: Any]] = [:]
    private var activitySaveTask: Task<Void, Never>?
    private var urlSession: URLSession?
    private var isConnecting: Bool = false
    private var sessionId: String = ""
    private var courseId: String = ""
    private var lessonId: String?
    private var requestedLanguage: String = "auto"
    private var requestedMode: String = "solo"
    private var requestedReviewConceptId: String?
    private var requestedDurationMinutes: Int?
    private var requestedRecordScope: String = "topic"
    private var connectedSessionId: String = ""
    private var requestedDifficulty: String?
    private var courseKey: String = ""
    private let sessionStore: ClassroomSessionStore
    private let actionSender: ((String) -> Void)?
    private let now: () -> Date
    private var stallTimer: Timer?
    private var waitingSince: Date?
    private var stallNudged: Bool = false
    private let logger = Logger(subsystem: "com.lyo.app", category: "LivingClassroomService")

    init(
        sessionStore: ClassroomSessionStore = ClassroomSessionStore(),
        actionSender: ((String) -> Void)? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.sessionStore = sessionStore
        self.actionSender = actionSender
        self.now = now
    }

    // MARK: - Lesson identity

    private var topic: String = ""

    // MARK: Voice tutoring
    /// When on, teacher messages are spoken aloud as they reveal, making the
    /// lesson a listen-along. Persisted across sessions.
    @Published var voiceModeEnabled: Bool = {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "classroom_voice_mode") != nil else { return true }
        return defaults.bool(forKey: "classroom_voice_mode")
    }() {
        didSet {
            UserDefaults.standard.set(voiceModeEnabled, forKey: "classroom_voice_mode")
            if !voiceModeEnabled { TextToSpeechService.shared.stop() }
        }
    }

    /// Speaks a component if voice mode is on and the content is spoken-style
    /// prose (backend teacher messages can carry JSON director turns — those
    /// are skipped rather than read aloud).
    private func narrateIfEnabled(_ component: SDUIComponent) {
        guard voiceModeEnabled,
            component.type == .teacherMessage,
            !component.content.isEmpty
        else { return }
        let trimmed = component.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("["), !trimmed.hasPrefix("{") else { return }
        TextToSpeechService.shared.enqueue(
            trimmed,
            language: component.languageCode ?? "auto"
        )
    }

    /// Barge-in: the learner started talking — stop talking over them.
    func bargeIn() {
        TextToSpeechService.shared.stop()
    }

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
        // The run loop holds the wait watchdog, not this object, so it has to
        // be told to stop rather than released with everything else.
        stallTimer?.invalidate()
    }

    private func normalizedSessionId(from rawSessionId: String) -> String {
        ClassroomSessionContract.normalizedSessionId(rawSessionId)
    }

    /// Connects to the real-time Server-Driven UI WebSockets.
    /// - Parameters:
    ///   - sessionId: The classroom session / course identifier.
    ///   - topic: Human-readable lesson topic sent to the shared backend.
    func connect(
        sessionId: String,
        courseId: String? = nil,
        lessonId: String? = nil,
        topic: String? = nil,
        language: String = "auto",
        durationMinutes: Int? = nil,
        recordScope: String = "topic",
        mode: String = "solo",
        reviewConceptId: String? = nil,
        difficulty: String? = nil,
        resume: Bool = false,
        resumeSession: ClassroomSavedSession? = nil
    ) {
        self.topic = (topic?.isEmpty == false ? topic! : sessionId)

        guard webSocketTask == nil, !isConnecting else {
            logger.info(
                "WebSocket is already connecting or connected. Ignoring duplicate connect request.")
            return
        }

        isConnecting = true
        self.courseId = courseId ?? sessionId
        self.requestedDifficulty = difficulty

        // Which session this is. The course's history decides whether this is
        // a new class or the old one carried on — opening a topic a second
        // time used to hand back the session the learner left, mid-unit, with
        // no opening and no way to ask for a clean start.
        self.courseKey = ClassroomSessionContract.courseKey(
            courseId: courseId, topic: self.topic
        )
        // Starting a class overwrites the stored record, so by the time the
        // learner reads "pick up where you left off" the storage no longer
        // holds the session that offer is about — it has to be carried.
        let saved = resumeSession ?? sessionStore.saved(courseKey: courseKey)
        let start = ClassroomSessionContract.sessionStart(
            courseKey: courseKey, saved: saved, resume: resume, now: now()
        )
        sessionStore.save(
            ClassroomSavedSession(
                id: start.sessionId, startedAt: now(), generation: start.generation
            ),
            courseKey: courseKey
        )
        self.sessionId = start.sessionId
        self.resumedSession = start.resumed
        self.resumableSession =
            (!start.resumed && ClassroomSessionContract.canResume(saved, now: now())) ? saved : nil
        self.notice = nil
        self.lessonComplete = false

        // The cover page goes up before the socket does. A learner should
        // never be looking at a blank stage wondering whether the class has
        // begun, and after a resume they should be told that it is the middle
        // of one rather than left to infer it from the teacher's first line.
        self.opening = ClassroomSessionContract.opening(
            topic: self.topic,
            objective: nil,
            durationMinutes: durationMinutes,
            difficulty: difficulty,
            mode: mode,
            resumed: start.resumed
        )
        self.lessonId = lessonId
        self.requestedLanguage = language
        self.requestedMode = ["solo", "classroom", "challenge", "review"].contains(mode) ? mode : "solo"
        self.requestedReviewConceptId = reviewConceptId?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requestedDurationMinutes = durationMinutes
        self.requestedRecordScope = recordScope == "unit" ? "unit" : "topic"
        self.isGenerating = true
        self.statusText = "Connecting to your live classroom…"
        startStallWatch()

        // An injected transport owns its connection/authentication. The same
        // action and incoming-message paths still drive the lesson state.
        if actionSender != nil {
            self.isConnected = true
            self.isConnecting = false
            return
        }

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
                    throw URLError(.userAuthenticationRequired)
                }

                // Formulate WebSocket URL from the base API URL
                let baseUrlString = AppConfig.baseURL
                let wsBaseString =
                    baseUrlString
                    .replacingOccurrences(of: "https://", with: "wss://")
                    .replacingOccurrences(of: "http://", with: "ws://")

                // The session this entry resolved to (see ClassroomSessionContract),
                // already free of any "GENERATE:" prefix. Not the raw argument:
                // sending that back is what made every class a resume.
                let resolvedSessionId = self.normalizedSessionId(from: self.sessionId)
                self.connectedSessionId = resolvedSessionId

                // Topic: what the learner asked to be taught. Never the
                // resolved session id, which carries a generation suffix for
                // a second class and would teach "Minecraft~2".
                let resolvedTopic = self.topic
                guard var urlComponents = URLComponents(
                    string: "\(wsBaseString)/api/v1/classroom/ws/connect"
                ) else {
                    self.logger.error("Invalid WebSocket URL")
                    throw URLError(.badURL)
                }
                urlComponents.queryItems = [
                    URLQueryItem(name: "session_id", value: resolvedSessionId),
                    URLQueryItem(name: "course_id", value: self.courseId),
                    URLQueryItem(name: "client_contract_version", value: "2"),
                    URLQueryItem(name: "token", value: token),
                    URLQueryItem(name: "topic", value: resolvedTopic),
                    URLQueryItem(name: "language", value: language),
                    URLQueryItem(name: "mode", value: self.requestedMode),
                    URLQueryItem(name: "record_scope", value: self.requestedRecordScope),
                    // The Director plans a lesson to fit this. A scheduled
                    // study session carries its own length, and sending 10 for
                    // a 45-minute slot has the server plan a quarter of the
                    // work the learner was told to expect. Clamped to the
                    // range the backend accepts.
                    URLQueryItem(
                        name: "duration_minutes",
                        value: String(min(max(durationMinutes ?? 10, 3), 60))
                    ),
                ]
                if let lessonId = self.lessonId, !lessonId.isEmpty {
                    urlComponents.queryItems?.append(
                        URLQueryItem(name: "lesson_id", value: lessonId)
                    )
                }
                if let reviewConceptId = self.requestedReviewConceptId,
                   !reviewConceptId.isEmpty {
                    urlComponents.queryItems?.append(
                        URLQueryItem(name: "review_concept_id", value: reviewConceptId)
                    )
                }
                // The level the opening card names is the level the engine is
                // asked for, so the cover page cannot promise a lesson
                // different from the one planned.
                if let difficulty = self.requestedDifficulty, !difficulty.isEmpty {
                    urlComponents.queryItems?.append(
                        URLQueryItem(name: "difficulty", value: difficulty)
                    )
                }
                guard let url = urlComponents.url else {
                    self.logger.error("Invalid WebSocket URL components")
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
                self.isGenerating = false
                self.statusText = nil
                self.error = error
            }
        }
    }

    /// Gracefully closes the connection
    func disconnect() {
        flushActivityUpdates()
        stopStallWatch()
        stallPhase = .none
        TextToSpeechService.shared.stop()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnected = false
        isConnecting = false
        connectedSessionId = ""
        logger.info("Disconnected from WebSocket")
    }

    // MARK: - The watchdog

    /// One tick of the wait watchdog.
    ///
    /// A wait that is merely slow is said out loud and left alone. A wait
    /// that passes the recovery threshold is asked after once, with
    /// `continue` — the one intent that cannot be mistaken for a second
    /// answer — and only if that second wait also runs out does the class
    /// admit the step is not coming and put recovery controls in front of
    /// the learner.
    ///
    /// It ticks rather than arming a timer at each of the places a wait
    /// begins: a wait that started without arming its own timer is exactly
    /// the wait nobody would notice was never ending.
    func stallTick(now: Date = Date()) {
        guard isGenerating, isConnected, !lessonComplete else {
            waitingSince = nil
            stallNudged = false
            if stallPhase != .none { stallPhase = .none }
            return
        }
        guard let since = waitingSince else {
            waitingSince = now
            return
        }
        let waited = now.timeIntervalSince(since)
        if waited >= ClassroomSessionContract.stallRecoverySeconds {
            if !stallNudged {
                // One unprompted ask, then the learner decides. Resending the
                // learner's own answer here would risk grading it twice, so
                // the nudge is always `continue`.
                if sendUserAction(actionIntent: "continue", componentId: "continue") {
                    // sendUserAction starts a fresh wait for learner actions.
                    // This send is the one automatic recovery, so restore its
                    // history after the shared send path resets the wait.
                    stallNudged = true
                    waitingSince = now
                    if stallPhase != .slow { stallPhase = .slow }
                } else {
                    stallPhase = .stalled
                }
                return
            }
            if stallPhase != .stalled { stallPhase = .stalled }
            return
        }
        if waited >= ClassroomSessionContract.stallNoticeSeconds, stallPhase == .none {
            stallPhase = .slow
        }
    }

    private func startStallWatch() {
        stopStallWatch()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.stallTick(now: self.now())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        stallTimer = timer
    }

    private func stopStallWatch() {
        stallTimer?.invalidate()
        stallTimer = nil
        waitingSince = nil
        stallNudged = false
    }

    /// Content arrived: the wait is over now, not on the next tick.
    private func clearWait() {
        waitingSince = nil
        stallNudged = false
        if stallPhase != .none { stallPhase = .none }
    }

    // MARK: - Recovery

    /// The step did not come; ask for it again.
    ///
    /// Always `continue`, never the learner's own submission replayed. A
    /// resent answer is a second answer as far as the grader is concerned,
    /// and a learner who waited out a slow network must not pay for it with
    /// a duplicate attempt on their record.
    func nudgeTeacher() {
        notice = nil
        guard sendUserAction(actionIntent: "continue", componentId: "continue") else { return }
        isGenerating = true
        waitingSince = now()
        stallNudged = true
        stallPhase = .slow
    }

    /// Leave a stuck session behind and teach this topic from the top.
    ///
    /// The server holds the learner's place inside the session, so a session
    /// that cannot produce its next step cannot be argued out of it — the
    /// only real recovery is a different session. Evidence already earned is
    /// filed against the concept, not the session, so nothing demonstrated
    /// is lost by starting the teaching again.
    func restartLesson() {
        reconnect(resume: false)
    }

    /// Return to the session this learner left part-way through.
    func resumeLesson() {
        guard let seat = resumableSession else { return }
        reconnect(resume: true, resumeSession: seat)
    }

    /// Re-establishes the WebSocket using the previously stored sessionId. Used by the UI's reconnect banner.
    func reconnect(resume: Bool? = nil, resumeSession: ClassroomSavedSession? = nil) {
        guard !sessionId.isEmpty else {
            logger.warning("Cannot reconnect — no sessionId stored")
            return
        }
        logger.info("\u{1F501} Reconnecting WebSocket for session \(self.sessionId)")
        // Clear any half-open task before reconnecting.
        stopStallWatch()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnecting = false
        error = nil
        stallPhase = .none
        // A plain reconnect is the same class carried on, so it asks for the
        // seat it already has. Restarting and resuming say so explicitly.
        connect(
            sessionId: sessionId,
            courseId: courseId,
            lessonId: lessonId,
            topic: topic,
            language: requestedLanguage,
            durationMinutes: requestedDurationMinutes,
            recordScope: requestedRecordScope,
            mode: requestedMode,
            reviewConceptId: requestedReviewConceptId,
            difficulty: requestedDifficulty,
            resume: resume ?? true,
            resumeSession: resumeSession
        )
    }

    /// Sends a user action (e.g. button tap) back to the authoritative backend.
    /// Returns false when the action cannot even be queued, so the UI can leave
    /// a checkpoint editable instead of inventing offline progress.
    @discardableResult
    func sendUserAction(
        actionIntent: String,
        componentId: String,
        actionData: [String: Any]? = nil
    ) -> Bool {
        // Any learner action owns the floor immediately and invalidates speech
        // from the previous scene. The backend is the only teaching and
        // assessment authority for the live classroom.
        if actionIntent != "update_activity" {
            flushActivityUpdates()
            bargeIn()
        }

        guard isConnected, webSocketTask != nil || actionSender != nil else {
            logger.warning("WebSocket not connected — learner action was not sent")
            isGenerating = false
            statusText = nil
            error = URLError(.notConnectedToInternet)
            return false
        }

        let outboundSessionId = connectedSessionId.isEmpty
            ? normalizedSessionId(from: sessionId)
            : connectedSessionId

        var payload: [String: Any] = [
            "event_type": "user_action",
            "session_id": outboundSessionId,
            "action_intent": actionIntent,
            "component_id": componentId,
            "timestamp": ISO8601DateFormatter().string(from: now()),
        ]

        if let actionData = actionData {
            payload["answer_data"] = actionData
        }

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            logger.error("Failed to serialize user action payload: \(error.localizedDescription)")
            isGenerating = false
            statusText = nil
            self.error = error
            return false
        }
        // JSONSerialization emits UTF-8 JSON bytes by contract.
        let jsonString = String(decoding: data, as: UTF8.self)

        // Every learner action but an activity nudge expects a new screen
        // back, so the class is waiting from here until one arrives.
        //
        // This lives in the one place every action goes through, rather than
        // in each handler. The quiz, transfer, hint, skip and prompt paths
        // all call straight through to here, and none of them set it: after
        // a scene had rendered `isGenerating` was false, so the watchdog
        // treated the whole lesson as idle and cleared its own timer on
        // every tick. The slow and stalled states could only ever appear for
        // the opening connection, which is the one wait they were least
        // needed for.
        if actionIntent != "update_activity" {
            if lessonComplete {
                // A follow-up challenge starts another wait, while the saved
                // lesson remains finished for future resume decisions.
                lessonComplete = false
                startStallWatch()
            }
            isGenerating = true
            waitingSince = now()
            stallNudged = false
            if stallPhase != .none { stallPhase = .none }
        }

        let completion: (Error?) -> Void = { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.logger.error("Failed to send user action: \(error.localizedDescription)")
                    self?.isGenerating = false
                    self?.clearWait()
                    self?.statusText = nil
                    self?.error = error
                    // Rebuild the active lesson with the same server scene so
                    // any optimistic answer/skip becomes retryable.
                    self?.sceneRevision += 1
                } else {
                    self?.logger.info("📤 Sent user action: \(actionIntent)")
                }
            }
        }
        if let actionSender {
            actionSender(jsonString)
        } else {
            webSocketTask?.send(.string(jsonString), completionHandler: completion)
        }
        return true
    }

    @discardableResult
    func updateActivity(id: String, values: [String: Any]) -> Bool {
        guard isConnected else { error = URLError(.notConnectedToInternet); return false }
        activityUpdates[id] = values
        activitySaveTask?.cancel()
        activitySaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            self?.flushActivityUpdates()
        }
        return true
    }

    private func flushActivityUpdates() {
        activitySaveTask?.cancel()
        activitySaveTask = nil
        let updates = activityUpdates
        activityUpdates.removeAll()
        for (id, values) in updates {
            sendUserAction(actionIntent: "update_activity", componentId: id, actionData: values)
        }
    }

    var nextQueuedComponent: SDUIComponent? {
        componentQueue.first
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
                    self.isGenerating = false
                    self.statusText = nil
                    self.error = error
                }
            }
        }
    }

    /// Parses the JSON payload and routes events for SDUI streaming
    func handleWebSocketMessage(_ message: String) {
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

                case "session_end":
                    self.markLessonComplete()

                case "system_state":
                    self.logger.info(
                        "Received system_state message - fully connected to Live Classroom stream")

                case "control":
                    self.logger.info("Received control message")
                case "error":
                    // The classroom saying something went wrong is not the
                    // same as the class being over, so this is a notice
                    // rather than a fatal error — but it stops being
                    // invisible. It used to reach the log alone, while the
                    // learner watched a board that had simply stopped.
                    self.logger.error("Received server error stream event")
                    var reported = "The classroom hit a snag."
                    if let rootObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = rootObj["message"] as? String,
                       !message.isEmpty {
                        reported = message
                    }
                    self.notice = reported

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
        // A new scene invalidates any queued or playing narration.
        TextToSpeechService.shared.stop()
        self.sceneRevision += 1
        self.currentScene = scene

        self.renderedComponents = []
        self.componentQueue = scene.components
        self.hasQueuedComponents = !self.componentQueue.isEmpty
        self.isGenerating = false
        self.clearWait()
        self.canContinue = false
        self.statusText = nil
        if scene.metadata?.courseComplete == true {
            markLessonComplete()
        }
        for component in scene.components {
            recordCompletion(in: component)
        }

        logger.info(
            "Started rendering scene: \(scene.sceneType) [\(scene.id)] with \(scene.components.count) components"
        )

        // Auto-reveal the first chunk (staggered, teacher-paced)
        revealNextComponent()
    }

    private func renderComponent(_ component: SDUIComponent) {
        recordCompletion(in: component)
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
            self.clearWait()
            logger.info("Queued new component: \(component.type.rawValue) - \(component.id)")

            if self.renderedComponents.isEmpty {
                revealNextComponent()
            }
        }
    }

    private func recordCompletion(in component: SDUIComponent) {
        if component.type == .ctaButton, component.actionIntent == "end_lesson" {
            markLessonComplete()
            return
        }
        guard component.type == .teacherMessage,
              let data = component.content.data(using: .utf8),
              let turns = try? JSONDecoder().decode([ActiveLessonAdapter.DirectorTurn].self, from: data),
              turns.contains(where: { $0.type == "session_end" }) else { return }
        markLessonComplete()
    }

    private func markLessonComplete() {
        lessonComplete = true
        isGenerating = false
        canContinue = false
        statusText = nil
        resumableSession = nil
        clearWait()
        stopStallWatch()
        sessionStore.markFinished(sessionId: sessionId, courseKey: courseKey)
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

        // Voice tutoring: read teacher messages aloud as they reveal.
        narrateIfEnabled(component)

        if component.type == .ctaButton {
            canContinue = true
        } else if component.type == .quizCard || component.type == .inputField {
            canContinue = false
            // A real learner checkpoint is a hard boundary. The next component
            // cannot appear until their answer produces a new server scene.
            return
        }

        // Reveal the complete teaching beat, including its checkpoint. Once an
        // interactive component is visible, no timer advances the lesson.
        if !componentQueue.isEmpty {
            let nextComponent = componentQueue[0]
            let charCount = max(component.content.count, 20)
            let delay = component.type == .teacherMessage
                ? min(max(Double(charCount) * 0.035, 0.8), 2.0)
                : 0.35

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if self.hasQueuedComponents && self.componentQueue.first?.id == nextComponent.id {
                    self.revealNextComponent()
                }
            }
        }
    }

    private func completeSceneRender() {
        logger.info("Completed rendering scene")
        isGenerating = false
        clearWait()
    }

    func requestNextScene() {
        guard !isGenerating, !lessonComplete else { return }
        canContinue = false
        isGenerating = true
        statusText = "Preparing the next part…"

        sendUserAction(actionIntent: "continue", componentId: "continue")
    }

    /// The session's checkpoint questions, packaged for a friend challenge.
    /// Intervention cards are excluded; the correct answer is recovered from
    /// the component's action payload.
    func challengeQuestions() -> [ChallengeQuestion] {
        renderedComponents.compactMap { component in
            guard component.type == .quizCard,
                component.actionIntent != "intervention_choice",
                let options = component.options, options.count >= 2
            else { return nil }
            let questionText = component.question ?? component.content
            guard !questionText.isEmpty else { return nil }
            let answerId = component.actionPayload?["answer_option_id"]
            let answerIndex = options.firstIndex(where: { $0.id == answerId }) ?? 0
            return ChallengeQuestion(
                question: questionText,
                options: options.map(\.label),
                answerIndex: answerIndex
            )
        }
    }

    /// Data for the shareable end-of-lesson recap card, derived only from the
    /// same server-authored components every platform received.
    func lessonRecap() -> (topic: String, points: [String]) {
        let points = renderedComponents
            .filter { $0.type == .teacherMessage || $0.type == .textBlock }
            .map { String($0.content.prefix(120)) }
        return (topic: topic, points: Array(points.suffix(4)))
    }
}
