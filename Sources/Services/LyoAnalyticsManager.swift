import Foundation
import FirebaseAnalytics

/// A singleton tracker that captures interaction telemetry and reports it back to the backend.
public class LyoAnalyticsManager: ObservableObject {
    public static let shared = LyoAnalyticsManager()
    
    // Configurable endpoint (use local for development)
    // Base endpoint for backend telemetry
    private var backendEndpoint: String {
        return AppConfig.baseURL + "/api/v1/classroom/analytics/event"
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
    
    // MARK: - Public API
    
    public func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        var payload: [String: Any] = ["event_type": name]
        if let params = parameters {
            payload.merge(params) { (_, new) in new }
        }
        sendEvent(payload: payload)
        
        // Firebase Mirror
        let firebaseParams = parameters?.mapValues { value -> Any in
            if let date = value as? Date { return date.timeIntervalSince1970 }
            return value
        }
        Analytics.logEvent(name, parameters: firebaseParams)
    }
    
    public func trackCardView(cardId: String, duration: TimeInterval) {
        let payload: [String: Any] = [
            "event_type": "card_viewed",
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "duration_seconds": duration
        ]
        sendEvent(payload: payload)
        
        // Firebase Mirror
        Analytics.logEvent("card_viewed", parameters: [
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "duration": duration
        ])
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
        
        // Firebase Mirror
        Analytics.logEvent("quiz_answered", parameters: [
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "is_correct": isCorrect ? 1 : 0
        ])
    }
    
    public func trackReflection(cardId: String, wordCount: Int) {
        let payload: [String: Any] = [
            "event_type": "reflection_submitted",
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "word_count": wordCount
        ]
        sendEvent(payload: payload)
        
        // Firebase Mirror
        Analytics.logEvent("reflection_submitted", parameters: [
            "card_id": cardId,
            "topic": currentTopic ?? "Unknown",
            "word_count": wordCount
        ])
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
