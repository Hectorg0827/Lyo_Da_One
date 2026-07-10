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

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnecting: Bool = false
    private var sessionId: String = ""
    private let logger = Logger(subsystem: "com.lyo.app", category: "LivingClassroomService")

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
    }

    /// Connects to the real-time Server-Driven UI WebSockets
    func connect(sessionId: String) {
        guard webSocketTask == nil, !isConnecting else {
            logger.info(
                "WebSocket is already connecting or connected. Ignoring duplicate connect request.")
            return
        }

        isConnecting = true
        self.sessionId = sessionId

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
        self.currentScene = scene
        self.renderedComponents = []
        logger.info(
            "Started rendering scene: \(scene.sceneType) [\(scene.id)] with \(scene.components.count) components"
        )

        // Render components embedded in the scene payload
        for component in scene.components {
            renderComponent(component)
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
        // Can trigger any completion logic here, like haptics or auto-scroll
    }
}
