import Foundation
import Combine

/// Service to handle real-time streaming updates for A2UI components
/// Used for "ChatGPT-style" text streaming and live data updates
class A2UIStreamService: ObservableObject {
    static let shared = A2UIStreamService()
    
    // Dependencies
    private let wsManager = WebSocketManager.shared
    
    // State
    // Map of StreamID -> Current Content
    @Published var activeStreams: [String: String] = [:]
    
    private var streamSubjects: [String: PassthroughSubject<String, Never>] = [:]
    
    private init() {
        setupWebSocketListeners()
    }
    
    /// Get a publisher for a specific stream ID
    func stream(for id: String) -> AnyPublisher<String, Never> {
        if streamSubjects[id] == nil {
            streamSubjects[id] = PassthroughSubject<String, Never>()
        }
        return streamSubjects[id]!.eraseToAnyPublisher()
    }
    
    /// Request the backend to start streaming for a component
    func subscribe(to streamId: String) {
        // Send subscription message to backend
        print("🔌 Subscribing to A2UI stream: \(streamId)")
        
        Task {
            do {
                // Assuming we use the generalized 'collaboration' endpoint or similar for now
                // In a real app, might be a dedicated stream endpoint
                // wsManager.joinChannel(streamId)
            }
        }
        
        // Setup publisher
        if streamSubjects[streamId] == nil {
            streamSubjects[streamId] = PassthroughSubject<String, Never>()
        }
    }
    
    private func setupWebSocketListeners() {
        wsManager.onMessage(type: "a2ui_stream_update") { [weak self] message in
            guard let self = self,
                  let data = message.data,
                  let streamId = data["stream_id"] as? String,
                  let chunk = data["chunk"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                // Update local cache
                let current = self.activeStreams[streamId] ?? ""
                self.activeStreams[streamId] = current + chunk
                
                // Notify subscribers
                self.streamSubjects[streamId]?.send(self.activeStreams[streamId]!)
            }
        }
        
        wsManager.onMessage(type: "a2ui_stream_complete") { [weak self] message in
             guard let self = self,
                  let data = message.data,
                  let streamId = data["stream_id"] as? String else {
                return
            }
            
            // Cleanup if needed
            print("✅ Stream complete: \(streamId)")
            // self?.streamSubjects[streamId]?.send(completion: .finished)
        }
    }
    
    // Test helper to simulate streaming
    func simulateStream(id: String, fullText: String) {
        subscribe(to: id)
        
        var currentDelay: Double = 0
        let chars = Array(fullText)
        
        for char in chars {
            currentDelay += Double.random(in: 0.02...0.05)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                let chunk = String(char)
                let current = self.activeStreams[id] ?? ""
                let new = current + chunk
                self.activeStreams[id] = new
                self.streamSubjects[id]?.send(new)
            }
        }
    }
}
