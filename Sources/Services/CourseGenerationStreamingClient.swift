//
//  CourseGenerationStreamingClient.swift
//  Lyo
//
//  SSE client for streaming course generation progress
//

import Foundation
import os

/// Streaming client for Server-Sent Events from course generation
@MainActor
class CourseGenerationStreamingClient: ObservableObject {
    @Published var currentEvent: CourseGenerationEvent?
    @Published var state: StreamingState = .idle
    @Published var errorMessage: String?  // Changed from Error? to String?
    
    private var task: Task<Void, Never>?
    
    var isStreaming: Bool {
        state.isActive
    }
    
    func startStreaming(
        topic: String,
        options: CourseGenerationOptions,
        onEvent: @escaping (CourseGenerationEvent) -> Void
    ) {
        // Cancel any existing stream
        stopStreaming()
        
        state = .connecting
        
        task = Task {
            do {
                try await streamGeneration(topic: topic, options: options, onEvent: onEvent)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.state = .failed(error)
                }
            }
        }
    }
    
    func stopStreaming() {
        task?.cancel()
        task = nil
        if state.isActive {
            state = .cancelled
        }
    }
    
    private func streamGeneration(
        topic: String,
        options: CourseGenerationOptions,
        onEvent: @escaping (CourseGenerationEvent) -> Void
    ) async throws {
        
        let (bytes, response) = try await NetworkClient.shared.stream(Endpoints.CourseGenerationV2.stream(topic: topic, options: options))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        await MainActor.run {
            self.state = .streaming
        }
        
        // Parse SSE stream
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        for try await line in bytes.lines {
            // Check for cancellation
            if Task.isCancelled {
                break
            }
            
            // SSE format: "data: {json}"
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                // Skip empty lines or comments
                if jsonString.isEmpty || jsonString.hasPrefix(":") {
                    continue
                }
                
                // Try to parse event
                if let data = jsonString.data(using: .utf8) {
                    do {
                        let event = try decoder.decode(CourseGenerationEvent.self, from: data)
                        
                        Log.course.info("📥 SSE Event: \(event.type.rawValue) - \(event.message) (\(event.progress)%)")
                        
                        await MainActor.run {
                            self.currentEvent = event
                        }
                        
                        // Call event handler
                        onEvent(event)
                        
                        // Handle completion or error
                        if event.type == .completed {
                            await MainActor.run {
                                self.state = .completed
                            }
                            break
                        } else if event.type == .error {
                            let errorMsg = event.data?.error ?? event.message
                            let error = NSError(
                                domain: "CourseGeneration",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: errorMsg]
                            )
                            await MainActor.run {
                                self.errorMessage = error.localizedDescription
                                self.state = .failed(error)
                            }
                            break
                        }
                    } catch {
                        Log.course.warning("Failed to decode SSE event: \(error)")
                        // Continue streaming despite decode errors
                    }
                }
            } else if line.hasPrefix("event: ") {
                // Backend might send event type separately
                let eventType = String(line.dropFirst(7))
                Log.course.info("SSE Event Type: \(eventType)")
            }
        }
        
        // Clean up
        await MainActor.run {
            if self.state == .streaming {
                self.state = .completed
            }
        }
        
        Log.course.info("SSE stream ended")
    }
}
