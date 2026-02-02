import Foundation

// MARK: - WebSocket Manager
/// Manages WebSocket connections for real-time features
class WebSocketManager: NSObject, URLSessionWebSocketDelegate {

    // MARK: - Singleton
    static let shared = WebSocketManager()

    // MARK: - WebSocket Event
    enum WebSocketEvent {
        case connected
        case disconnected(Error?)
        case message(WebSocketMessage)
        case error(Error)
    }

    // MARK: - WebSocket Message
    struct WebSocketMessage: Codable {
        let type: String
        let data: [String: Any]?
        let timestamp: Date?

        enum CodingKeys: String, CodingKey {
            case type
            case data
            case timestamp
        }

        init(type: String, data: [String: Any]? = nil) {
            self.type = type
            self.data = data
            self.timestamp = Date()
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)

            // Decode data as dictionary
            if let dataDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .data) {
                data = dataDict.mapValues { $0.value }
            } else {
                data = nil
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(timestamp, forKey: .timestamp)

            if let data = data {
                let anyCodableData = data.mapValues { AnyCodable($0) }
                try container.encode(anyCodableData, forKey: .data)
            }
        }
    }

    // MARK: - Properties
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession!
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: Timer?
    private let logger = NetworkLogger()

    // Callbacks
    private var eventHandlers: [(WebSocketEvent) -> Void] = []
    private var messageHandlers: [String: [(WebSocketMessage) -> Void]] = [:]

    // MARK: - Initialization
    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }

    // MARK: - Connection Management

    /// Connect to WebSocket endpoint
    func connect(endpoint: WebSocketEndpoint) async throws {
        guard !isConnected else {
            logger.log("⚠️ Already connected to WebSocket")
            return
        }

        // Build URL with authentication
        guard let token = await TokenManager.shared.getToken() else {
            throw LyoError.network(.unauthorized)
        }

        var urlComponents = URLComponents(string: endpoint.fullURL)
        urlComponents?.queryItems = [
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = urlComponents?.url else {
            throw LyoError.network(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        logger.log("🔌 Connecting to WebSocket: \(endpoint.path)")

        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()

        // Start receiving messages
        receiveMessage()

        isConnected = true
        reconnectAttempts = 0
        notifyEvent(.connected)
    }

    /// Disconnect from WebSocket
    func disconnect() {
        logger.log("🔌 Disconnecting WebSocket")

        reconnectTimer?.invalidate()
        reconnectTimer = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false

        notifyEvent(.disconnected(nil))
    }

    /// Send message through WebSocket
    func send(message: WebSocketMessage) async throws {
        guard isConnected, let webSocket = webSocket else {
            throw LyoError.network(.connectionFailed("WebSocket not connected"))
        }

        let encoder = JSONEncoder.lyoEncoder
        let data = try encoder.encode(message)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw LyoError.network(.invalidResponse)
        }

        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)

        return try await withCheckedThrowingContinuation { continuation in
            webSocket.send(wsMessage) { error in
                if let error = error {
                    self.logger.log("❌ WebSocket send error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    self.logger.log("✅ WebSocket message sent: \(message.type)")
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Message Handling

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleReceivedMessage(message)
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                self.logger.log("❌ WebSocket receive error: \(error.localizedDescription)")
                self.handleDisconnection(error: error)
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            do {
                let decoder = JSONDecoder.lyoDecoder
                let wsMessage = try decoder.decode(WebSocketMessage.self, from: text.data(using: .utf8)!)

                logger.log("📨 WebSocket message received: \(wsMessage.type)")

                // Notify specific handlers
                if let handlers = messageHandlers[wsMessage.type] {
                    handlers.forEach { $0(wsMessage) }
                }

                // Notify general event
                notifyEvent(.message(wsMessage))

            } catch {
                logger.log("❌ Failed to decode WebSocket message: \(error)")
            }

        case .data(let data):
            do {
                let decoder = JSONDecoder.lyoDecoder
                let wsMessage = try decoder.decode(WebSocketMessage.self, from: data)

                logger.log("📨 WebSocket message received: \(wsMessage.type)")

                // Notify specific handlers
                if let handlers = messageHandlers[wsMessage.type] {
                    handlers.forEach { $0(wsMessage) }
                }

                // Notify general event
                notifyEvent(.message(wsMessage))

            } catch {
                logger.log("❌ Failed to decode WebSocket message: \(error)")
            }

        @unknown default:
            logger.log("⚠️ Unknown WebSocket message type")
        }
    }

    private func handleDisconnection(error: Error?) {
        isConnected = false
        webSocket = nil

        notifyEvent(.disconnected(error))

        // Attempt reconnection
        if reconnectAttempts < maxReconnectAttempts {
            scheduleReconnect()
        } else {
            logger.log("❌ Max reconnection attempts reached")
        }
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        reconnectAttempts += 1
        let delay = calculateBackoff(attempt: reconnectAttempts)

        logger.log("🔄 Scheduling reconnect attempt \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay)s")

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task {
                try? await self?.reconnect()
            }
        }
    }

    private func reconnect() async throws {
        // Reconnect to last endpoint (stored in UserDefaults or property)
        // For now, just log
        logger.log("🔄 Attempting to reconnect...")
        // Implementation depends on how you store last endpoint
    }

    private func calculateBackoff(attempt: Int) -> Double {
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        return min(pow(2.0, Double(attempt - 1)), 16.0)
    }

    // MARK: - Event Handlers

    /// Register event handler
    func onEvent(_ handler: @escaping (WebSocketEvent) -> Void) {
        eventHandlers.append(handler)
    }

    /// Register handler for specific message type
    func onMessage(type: String, handler: @escaping (WebSocketMessage) -> Void) {
        if messageHandlers[type] == nil {
            messageHandlers[type] = []
        }
        messageHandlers[type]?.append(handler)
    }

    private func notifyEvent(_ event: WebSocketEvent) {
        DispatchQueue.main.async {
            self.eventHandlers.forEach { $0(event) }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.log("✅ WebSocket connected")
        isConnected = true
        reconnectAttempts = 0
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.log("🔌 WebSocket closed: \(closeCode.rawValue)")
        handleDisconnection(error: nil)
    }
}

// MARK: - WebSocket Endpoints

enum WebSocketEndpoint {
    case chat(userId: String)
    case collaboration(groupId: String)
    case notifications(userId: String)
    case battle(battleId: String)

    var path: String {
        switch self {
        case .chat(let userId):
            return "/ws/chat/\(userId)"
        case .collaboration(let groupId):
            return "/ws/collaboration/\(groupId)"
        case .notifications(let userId):
            return "/ws/notifications/\(userId)"
        case .battle(let battleId):
            return "/ws/battle/\(battleId)"
        }
    }

    var fullURL: String {
        return AppConfig.wsURL + path
    }
}

// MARK: - Convenience Methods

extension WebSocketManager {

    /// Connect to chat WebSocket
    func connectToChat(userId: String) async throws {
        try await connect(endpoint: .chat(userId: userId))

        // Send authentication message
        let authMessage = WebSocketMessage(
            type: "authenticate",
            data: ["user_id": userId]
        )
        try await send(message: authMessage)
    }

    /// Send chat message
    func sendChatMessage(content: String, recipientId: String? = nil) async throws {
        let message = WebSocketMessage(
            type: "chat_message",
            data: [
                "content": content,
                "recipient_id": recipientId as Any
            ]
        )
        try await send(message: message)
    }

    /// Join collaboration room
    func joinCollaboration(groupId: String) async throws {
        try await connect(endpoint: .collaboration(groupId: groupId))

        let joinMessage = WebSocketMessage(
            type: "join_room",
            data: ["group_id": groupId]
        )
        try await send(message: joinMessage)
    }

    /// Connect to notifications
    func connectToNotifications(userId: String) async throws {
        try await connect(endpoint: .notifications(userId: userId))
    }

    /// Connect to battle
    func connectToBattle(battleId: String) async throws {
        try await connect(endpoint: .battle(battleId: battleId))
    }

    /// Send battle answer
    func sendBattleAnswer(questionId: String, answer: String) async throws {
        let message = WebSocketMessage(
            type: "battle_answer",
            data: [
                "question_id": questionId,
                "answer": answer
            ]
        )
        try await send(message: message)
    }
}
