import Foundation
import Combine
import SwiftUI

/// Service responsible for streaming real-time generated cards from the Lyo Backend via WebSocket.
@MainActor
public class LyoClassroomService: ObservableObject {
    public static let shared = LyoClassroomService()
    
    @Published public var cards: [any LyoCard] = []
    @Published public var metadata: LyoLessonMetadata?
    @Published public var isGenerating = false
    @Published public var streamComplete = false
    @Published public var error: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Default to localhost for testing, but in production use environment variable or config
    private let baseURL = "ws://localhost:8000/api/v1/classroom/ws/lesson/"
    
    private init() {}
    
    /// Starts a streaming session for a new lesson topic.
    public func startLessonStream(topic: String) {
        // Reset state
        cards.removeAll()
        metadata = nil
        isGenerating = true
        streamComplete = false
        error = nil
        
        let formattedTopic = topic.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? topic
        guard let url = URL(string: "\(baseURL)\(formattedTopic)") else {
            self.error = "Invalid URL"
            self.isGenerating = false
            return
        }
        
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessages()
    }
    
    public func stopStream() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isGenerating = false
    }
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                Task { @MainActor in
                    self.error = "Connection error: \(error.localizedDescription)"
                    self.isGenerating = false
                }
                
            case .success(let message):
                switch message {
                case .string(let text):
                    self.processJSONPayload(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.processJSONPayload(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving if not complete
                if !self.streamComplete {
                    self.receiveMessages()
                }
            }
        }
    }
    
    private func processJSONPayload(_ jsonString: String) {
        Task { @MainActor in
            guard let data = jsonString.data(using: .utf8) else { return }
            
            do {
                let decoder = JSONDecoder()
                
                // Check if it's an error from the backend instead of a chunk
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = dict["error"] as? String {
                    self.error = err
                    self.isGenerating = false
                    self.stopStream()
                    return
                }
                
                let chunk = try decoder.decode(LyoStreamChunk.self, from: data)
                
                if let newMetadata = chunk.metadata {
                    self.metadata = newMetadata
                }
                
                if let wrapper = chunk.card {
                    self.cards.append(wrapper.card)
                    
                    // Simple optional haptic on receiving a card
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
                if chunk.isComplete {
                    self.streamComplete = true
                    self.isGenerating = false
                    self.stopStream()
                }
                
            } catch {
                print("Failed to decode chunk: \(error)")
                self.error = "Failed to parse stream data."
            }
        }
    }
}
