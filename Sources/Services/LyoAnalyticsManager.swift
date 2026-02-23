import Foundation

/// A singleton tracker that captures interaction telemetry and reports it back to the backend.
public class LyoAnalyticsManager: ObservableObject {
    public static let shared = LyoAnalyticsManager()
    
    // Configurable endpoint (use local for development)
    private var backendEndpoint: String {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8000/api/v1/classroom/analytics/event"
        #else
        // Use your real network IP or production URL here
        return "http://localhost:8000/api/v1/classroom/analytics/event"
        #endif
    }
    
    // Active session metadata
    private var currentTopic: String?
    
    // Aggregated Session Metrics for UI
    @Published public var sessionDuration: TimeInterval = 0
    @Published public var quizzesAttempted: Int = 0
    @Published public var quizzesCorrect: Int = 0
    
    private var sessionStartTime: Date?
    
    private init() {}
    
    public func startSession(topic: String) {
        self.currentTopic = topic
        self.sessionStartTime = Date()
        self.sessionDuration = 0
        self.quizzesAttempted = 0
        self.quizzesCorrect = 0
    }
    
    public func endSession() {
        if let start = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(start)
        }
    }
    
    // MARK: - Event Triggers
    
    public func trackCardView(cardId: String, duration: TimeInterval) {
        let payload: [String: Any] = [
            "event_type": "card_viewed",
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "duration_seconds": duration
        ]
        sendEvent(payload: payload)
    }
    
    public func trackQuizAttempt(cardId: String, isCorrect: Bool) {
        quizzesAttempted += 1
        if isCorrect { quizzesCorrect += 1 }
        
        let payload: [String: Any] = [
            "event_type": "quiz_answered",
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "is_correct": isCorrect
        ]
        sendEvent(payload: payload)
    }
    
    public func trackReflection(cardId: String, wordCount: Int) {
        let payload: [String: Any] = [
            "event_type": "reflection_submitted",
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "word_count": wordCount
        ]
        sendEvent(payload: payload)
    }
    
    // MARK: - Network Dispatch
    
    private func sendEvent(payload: [String: Any]) {
        guard let url = URL(string: backendEndpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("❌ Analytics Error: Failed to serialize payload. \(error)")
            return
        }
        
        // Fire and forget
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Analytics Error: Failed to send event. \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("⚠️ Analytics Warning: Server rejected event with status \(httpResponse.statusCode)")
            } else {
                // Success! (Silence is golden for analytics, uncomment for local debugging)
                // print("✅ Analytics: Event successfully dispatched.")
            }
        }
        
        task.resume()
    }
}
