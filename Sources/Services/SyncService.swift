import Foundation
import Combine
import os

// MARK: - Sync Event

/// One event from the cross-device sync channel.
struct SyncEvent {
    let eventType: String
    let payload: [String: Any]

    /// This device's server-assigned id (present on the "connected" event).
    var deviceId: String? { payload["device_id"] as? String }
}

// MARK: - Sync Service

/// Cross-device sync client for the backend's Multi-Device Sync service
/// (LyoBackendJune `lyo_app/routers/sync.py`) — the iOS counterpart of the
/// web client's `lib/sync.ts` and Android's `SyncClient.kt`.
///
/// Connects a websocket to `/api/v1/sync/ws` so this device receives
/// real-time events when the same account acts on another platform
/// (web, Android, or another iOS device). Connect on login, disconnect
/// on logout; consume `events` to refresh screens live.
///
/// All connection state is MainActor-isolated so connect/reconnect/teardown
/// can never race each other and leak a second websocket.
@MainActor
final class SyncService {

    static let shared = SyncService()

    // MARK: - Public surface

    /// Fires on the main actor for every event received from the sync channel.
    let events = PassthroughSubject<SyncEvent, Never>()

    /// This device's id, assigned by the server on connect.
    private(set) var deviceId: String?

    /// Start (or restart) the sync connection. Safe to call repeatedly.
    func connect() {
        shouldRun = true
        open()
    }

    /// Stop syncing (e.g. on logout).
    func disconnect() {
        shouldRun = false
        teardown()
    }

    /// Tell other devices this one is (or stopped) typing.
    func sendTyping(_ isTyping: Bool) {
        send(["type": "typing", "is_typing": isTyping])
    }

    // MARK: - Internals

    private var task: URLSessionWebSocketTask?
    private var connectTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTimer: Timer?
    private var reconnectAttempt = 0
    private var shouldRun = false

    private let heartbeatInterval: TimeInterval = 30
    private let reconnectBase: TimeInterval = 2
    private let reconnectMax: TimeInterval = 60

    private let session = URLSession(configuration: .default)

    private func open() {
        // A live socket or an in-flight connect attempt means nothing to do.
        guard shouldRun, task == nil, connectTask == nil else { return }

        connectTask = Task { [weak self] in
            let token = await TokenManager.shared.getToken()
            guard let self else { return }
            self.connectTask = nil
            guard self.shouldRun, self.task == nil else { return }
            guard let token else {
                // Auth state can flip before the keychain token is readable;
                // retry with backoff instead of staying offline until re-login.
                Log.net.info("Sync: no auth token yet, will retry")
                self.scheduleReconnect()
                return
            }

            let wsBase = AppConfig.baseURL
                .replacingOccurrences(of: "https://", with: "wss://")
                .replacingOccurrences(of: "http://", with: "ws://")
            var components = URLComponents(string: "\(wsBase)/api/v1/sync/ws")
            components?.queryItems = [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "device_type", value: "mobile_ios"),
                URLQueryItem(name: "device_name", value: "LYO iOS"),
            ]
            guard let url = components?.url else { return }

            let wsTask = self.session.webSocketTask(with: url)
            self.task = wsTask
            wsTask.resume()
            Log.net.info("Sync: connecting websocket")

            self.startHeartbeat()
            self.receiveLoop(on: wsTask)
        }
    }

    private func receiveLoop(on wsTask: URLSessionWebSocketTask) {
        wsTask.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handle(text: text)
                    }
                    // Keep listening as long as this task is still current.
                    if self.task === wsTask {
                        self.receiveLoop(on: wsTask)
                    }
                case .failure(let error):
                    Log.net.info("Sync: socket closed (\(error.localizedDescription))")
                    self.onSocketClosed(wsTask)
                }
            }
        }
    }

    private func handle(text: String) {
        guard
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let eventType = json["event_type"] as? String
        else { return }

        reconnectAttempt = 0
        if eventType == "connected" {
            deviceId = json["device_id"] as? String
            Log.net.info("Sync: connected as device \(self.deviceId ?? "?")")
        }
        events.send(SyncEvent(eventType: eventType, payload: json))
    }

    private func send(_ payload: [String: Any]) {
        guard
            let task,
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let text = String(data: data, encoding: .utf8)
        else { return }
        task.send(.string(text)) { _ in }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: heartbeatInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.send(["type": "heartbeat"])
            }
        }
    }

    private func onSocketClosed(_ wsTask: URLSessionWebSocketTask) {
        guard task === wsTask else { return }
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        task = nil
        deviceId = nil
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard shouldRun, reconnectTask == nil else { return }

        let delay = min(reconnectBase * pow(2, Double(reconnectAttempt)), reconnectMax)
        reconnectAttempt += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.reconnectTask = nil
            self.open()
        }
    }

    private func teardown() {
        connectTask?.cancel()
        connectTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        deviceId = nil
    }
}
