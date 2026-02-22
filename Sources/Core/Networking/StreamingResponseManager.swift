import Foundation

// MARK: - Streaming Response Manager
/// Handles Server-Sent Events (SSE) for real-time AI streaming
class StreamingResponseManager: NSObject, URLSessionDataDelegate {

    // MARK: - Stream Event
    enum StreamEvent {
        case blockEmit(content: String, blockType: String?)
        case audioReady(audioURL: String, timingsURL: String?, duration: Double?)
        case progress(percent: Int, message: String?)
        case sessionDone
        case error(Error)
    }

    // MARK: - Callback
    typealias StreamCallback = (StreamEvent) -> Void

    // MARK: - Properties
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()
    private var callback: StreamCallback?
    private let logger = NetworkLogger()

    /// Create a fresh URLSession for each stream.
    /// Reusing a session after a connection failure causes
    /// "invalid reuse after initialization failure" crashes.
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.streamTimeout
        config.timeoutIntervalForResource = AppConfig.streamTimeout
        config.httpAdditionalHeaders = [
            "Accept": "text/event-stream",
            "Cache-Control": "no-cache"
        ]
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public API

    // MARK: - Public API
    
    /// Start streaming from endpoint
    func stream(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String]? = nil,
        callback: @escaping StreamCallback
    ) async {
        self.callback = callback
        
        guard let url = URL(string: endpoint) else {
            callback(.error(LyoError.network(.invalidURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add auth token
        if let token = await TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add tenant ID
        if let tenantId = await TokenManager.shared.getTenantId() {
            request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
        }
        
        // Add API Key
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        logger.log("🌊 Starting SSE stream (\(method)): \(endpoint)")
        
        // Create fresh session (avoids "invalid reuse after initialization failure")
        session?.invalidateAndCancel()
        let newSession = makeSession()
        session = newSession
        dataTask = newSession.dataTask(with: request)
        dataTask?.resume()
    }
    
    /// Stop streaming
    func stop() {
        logger.log("🛑 Stopping SSE stream")
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        buffer = Data()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        
        // Debug: Log raw data received
        if let rawString = String(data: data, encoding: .utf8) {
            logger.log("📦 SSE received \(data.count) bytes: \(rawString.prefix(200))...")
        }
        
        // Parse SSE format
        parseSSEBuffer()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Ignore cancellation errors
            if (error as NSError).code != NSURLErrorCancelled {
                logger.log("❌ Stream error: \(error.localizedDescription)")
                callback?(.error(LyoError.from(error: error)))
            }
        } else {
            // Debug: Log HTTP response if available
            if let httpResponse = task.response as? HTTPURLResponse {
                logger.log("✅ Stream completed with status \(httpResponse.statusCode)")
            } else {
                logger.log("✅ Stream completed (no HTTP response)")
            }
            callback?(.sessionDone)
        }
        
        buffer = Data()
    }
    
    // MARK: - SSE Parsing
    
    private func parseSSEBuffer() {
        guard let string = String(data: buffer, encoding: .utf8) else { return }
        
        // Scan for double newline to separate events
        if let range = string.range(of: "\n\n") {
            let eventString = String(string[..<range.lowerBound])
            parseSSEEvent(eventString)
            
            // Keep remainder
            let remainder = String(string[range.upperBound...])
            buffer = remainder.data(using: .utf8) ?? Data()
            
            // Recursively process remainder if it contains more events
            if buffer.count > 0 {
                parseSSEBuffer()
            }
        }
    }
    
    private func parseSSEEvent(_ eventString: String) {
        let lines = eventString.components(separatedBy: "\n")
        
        var eventType: String?
        var eventData: String?
        
        for line in lines {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data: ") {
                eventData = String(line.dropFirst(6))
            }
        }
        
        guard let type = eventType, let dataString = eventData else {
            return
        }
        
        handleSSEEvent(type: type, data: dataString)
    }
    
    private func handleSSEEvent(type: String, data: String) {
        // logger.log("📨 SSE Event: \(type)") // Commented out to reduce noise
        
        switch type {
        case "message_start":
            // Acknowledge stream start - no action needed, just continue processing
            logger.log("✅ SSE stream started")
            
        case "message_delta":
            handleMessageDelta(data: data)
            
        case "message_complete":
            handleMessageComplete(data: data)
            
        case "BLOCK_EMIT":
            handleBlockEmit(data: data)
            
        case "AUDIO_READY":
            handleAudioReady(data: data)
            
        case "PROGRESS":
            handleProgress(data: data)
            
        case "SESSION_DONE", "done":
            callback?(.sessionDone)
            stop()
            
        case "error":
            // Handle error event from backend
            logger.log("❌ SSE error event received: \(data)")
            if let jsonData = data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let _ = json["error"] as? String {
                callback?(.error(LyoError.network(.serverError(500))))
            }
            stop()
            
        default:
            logger.log("⚠️ Unknown SSE event type: \(type)")
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleMessageDelta(data: String) {
        guard let jsonData = data.data(using: .utf8) else { 
            logger.log("⚠️ handleMessageDelta: Failed to convert data to UTF8")
            return 
        }
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let content = json["content"] as? String {
                logger.log("📤 Emitting delta content: '\(content)'")
                callback?(.blockEmit(content: content, blockType: "delta"))
            } else {
                logger.log("⚠️ handleMessageDelta: No 'content' field in JSON")
            }
        } catch {
            logger.log("❌ handleMessageDelta parse error: \(error)")
        }
    }
    
    private func handleMessageComplete(data: String) {
        // Treat as session done for now, or emit a special event
        callback?(.sessionDone)
    }
    
    private func handleBlockEmit(data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            if let block = json?["block"] as? String {
                let blockType = json?["block_type"] as? String
                callback?(.blockEmit(content: block, blockType: blockType))
            }
        } catch {
            logger.log("❌ Failed to parse BLOCK_EMIT: \(error)")
        }
    }
    
    private func handleAudioReady(data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            if let audioURL = json?["audio_url"] as? String {
                let timingsURL = json?["word_timings_url"] as? String
                let duration = json?["duration"] as? Double
                
                callback?(.audioReady(
                    audioURL: audioURL,
                    timingsURL: timingsURL,
                    duration: duration
                ))
            }
        } catch {
            logger.log("❌ Failed to parse AUDIO_READY: \(error)")
        }
    }
    
    private func handleProgress(data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            if let percent = json?["percent"] as? Int {
                let message = json?["message"] as? String
                callback?(.progress(percent: percent, message: message))
            }
        } catch {
            logger.log("❌ Failed to parse PROGRESS: \(error)")
        }
    }
}

// MARK: - Streaming Extensions for NetworkClient

extension NetworkClient {

    /// Stream AI session responses
    func streamSession(
        sessionId: String,
        callback: @escaping (StreamingResponseManager.StreamEvent) -> Void
    ) async -> StreamingResponseManager {

        let endpoint = "\(AppConfig.sseURL)/sessions/\(sessionId)/stream"
        let streamManager = StreamingResponseManager()

        await streamManager.stream(endpoint: endpoint, callback: callback)

        return streamManager
    }
}
