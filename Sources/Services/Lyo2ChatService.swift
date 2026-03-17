import Foundation
import os

@MainActor
class Lyo2ChatService: ObservableObject {
    static let shared = Lyo2ChatService()
    
    // Dependencies
    private let tokenManager = TokenManager.shared
    
    /// Retained so ARC doesn't deallocate the manager before the stream completes.
    private var activeStreamManager: Lyo2StreamingManager?
    
    /// Safety timeout — if no .done/.error arrives within this interval, force-clear loading state.
    private var safetyTimeoutTask: Task<Void, Never>?
    private static let streamTimeoutSeconds: TimeInterval = 90
    
    // MARK: - API
    
    func sendMessageStreaming(
        text: String,
        media: [Lyo2MediaRef]? = nil,
        attachmentIds: [String]? = nil,
        activeArtifact: Lyo2ActiveArtifactContext? = nil,
        forcedIntent: String? = nil,
        stateSummary: [String: AnyCodable] = [:],
        conversationHistory: [Lyo2ConversationTurn]? = nil,
        onEvent: @escaping (Lyo2StreamEvent) -> Void
    ) {
        // Cancel any in-flight stream before starting a new one
        activeStreamManager?.cancel()
        activeStreamManager = nil
        safetyTimeoutTask?.cancel()
        
        let userId = AuthService.shared.currentUserEmail.isEmpty
            ? "ios_guest"
            : AuthService.shared.currentUserEmail
        
        let routerRequest = Lyo2RouterRequest(
            userId: userId,
            text: text,
            media: media,
            attachmentIds: attachmentIds,
            activeArtifact: activeArtifact,
            forcedIntent: forcedIntent,
            stateSummary: stateSummary,
            conversationHistory: conversationHistory
        )
        
        let baseURL = NetworkClient.baseURL
        Log.ai.info("Lyo2ChatService: using baseURL = \(baseURL)")
        
        guard let url = URL(string: "\(baseURL)/api/v1/lyo2/chat/stream") else {
            onEvent(.error(message: "Invalid URL"))
            return
        }
        
        guard let body = try? JSONEncoder().encode(routerRequest) else {
            onEvent(.error(message: "Failed to encode request"))
            return
        }
        
        let streamManager = Lyo2StreamingManager()
        self.activeStreamManager = streamManager   // retain so ARC keeps it alive
        
        // Start stream — this pre-fetches auth headers, then opens the connection
        streamManager.startStream(url: url, body: body) { [weak self] event in
            onEvent(event)
            // Release the manager once the stream is finished
            switch event {
            case .done, .error:
                self?.activeStreamManager = nil
                self?.safetyTimeoutTask?.cancel()
            default:
                break
            }
        }
        
        // Safety timeout: if the stream hangs forever, fire .error + .done so UI unblocks
        safetyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.streamTimeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if self?.activeStreamManager != nil {
                Log.ai.info("⏰ Lyo2ChatService: stream timed out after \(Self.streamTimeoutSeconds)s — forcing cleanup")
                self?.activeStreamManager?.cancel()
                onEvent(.error(message: "Request timed out. Please try again."))
                self?.activeStreamManager = nil
            }
        }
    }
}

// MARK: - Streaming Manager (retained by Lyo2ChatService)

class Lyo2StreamingManager: NSObject, URLSessionDataDelegate {
    
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()
    private var callback: ((Lyo2StreamEvent) -> Void)?
    
    /// Last SSE event ID received — used for reconnection replay
    private(set) var lastEventId: String?
    
    /// Tracks whether the stream delivered any real content events (answer, artifact, clarification, etc.).
    /// When the stream completes with zero content events, we surface an error instead of a silent blank.
    private var didReceiveContentEvent = false
    
    /// Tracks whether we already fired .done (from SSE [DONE] line).
    /// Prevents the URLSession delegate from firing a second .done.
    private var hasCompletedStream = false
    
    /// Create a fresh URLSession for each stream.
    /// Reusing a session after a connection failure causes
    /// "invalid reuse after initialization failure" crashes.
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 200 // Increased from 60 to allow for complex planning/execution
        config.httpAdditionalHeaders = [
            "Accept": "text/event-stream",
            "Cache-Control": "no-cache"
        ]
        // CRITICAL: Use OperationQueue.main so delegate callbacks fire on the
        // main thread.  The callback chain passes through @MainActor-isolated
        // types (ChatRouter, UnifiedChatService), so firing from a background
        // thread caused Tasks to be silently lost.  SSE payloads are small
        // (< 1 KB typically) so main-thread parsing is negligible.
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    /// Cancel the active stream (if any).
    func cancel() {
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        callback = nil
    }
    
    /// Pre-fetch auth headers, build the request, then fire the URLSession data task.
    /// Uses a Task internally but captures everything needed before launching.
    func startStream(url: URL, body: Data, onEvent: @escaping (Lyo2StreamEvent) -> Void) {
        self.callback = onEvent
        self.didReceiveContentEvent = false
        self.hasCompletedStream = false
        
        // Fetch auth token + tenant ID asynchronously, THEN create the request
        Task { [weak self] in
            guard let self else { return }
            
            // 1. Pre-fetch SaaS credentials
            let apiKey = AppConfig.apiKey
            let token = await TokenManager.shared.getToken()
            let tenantId = await TokenManager.shared.getTenantId()
            
            // 2. Build URLRequest with all headers baked in
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            request.setValue("iOS", forHTTPHeaderField: "X-Platform")
            request.setValue(AppConfig.version, forHTTPHeaderField: "X-App-Version")
            request.setValue(
                Bundle.main.bundleIdentifier ?? "com.lyo.app",
                forHTTPHeaderField: "X-Bundle-Id"
            )
            request.setValue(
                ClientCapabilities.shared.versionHeader,
                forHTTPHeaderField: "X-Client-Version"
            )
            request.setValue(
                ClientCapabilities.shared.componentsHeader,
                forHTTPHeaderField: "X-Client-Capabilities"
            )
            if let tenantId {
                request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
            }
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            Log.ai.info("Lyo2 stream: POST \(url.absoluteString)")
            
            // 3. Create fresh session & fire the data task
            //    (avoids "invalid reuse after initialization failure")
            self.session?.invalidateAndCancel()
            let newSession = self.makeSession()
            self.session = newSession
            let task = newSession.dataTask(with: request)
            self.dataTask = task
            task.resume()
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            Log.ai.info("Lyo2 stream HTTP status: \(httpResponse.statusCode)")
            if !(200..<300).contains(httpResponse.statusCode) {
                callback?(.error(message: "Server returned HTTP \(httpResponse.statusCode)"))
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let chunk = String(data: data, encoding: .utf8) ?? "(non-utf8)"
        Log.ai.info("📥 Lyo2 SSE: received \(data.count) bytes, buffer now \(self.buffer.count + data.count) bytes")
        Log.ai.info("📥 Lyo2 SSE chunk: \(chunk.prefix(200))")
        buffer.append(data)
        parseSSEBuffer()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Log.ai.error("🏁 Lyo2 SSE: didCompleteWithError called, error=\(String(describing: error)), callback is \(self.callback == nil ? "nil" : "set"), remaining buffer=\(self.buffer.count) bytes")
        // Parse any remaining buffered data before completing
        if buffer.count > 0 {
            Log.ai.info("🏁 Lyo2 SSE: flushing remaining buffer")
            parseSSEBuffer()
        }
        if let error = error {
            if (error as NSError).code != NSURLErrorCancelled {
                Log.ai.error("Lyo2 stream error: \(error.localizedDescription)")
                callback?(.error(message: error.localizedDescription))
            }
        } else if !didReceiveContentEvent {
            // Stream completed with zero content events — the backend returned
            // an empty SSE stream.  Surface this as an error so the UI doesn't
            // silently go blank.
            Log.ai.error("⚠️ Lyo2 SSE: stream completed with NO content events — treating as error")
            callback?(.error(message: "No response received. Please try again."))
        } else if !hasCompletedStream {
            // Only fire .done if the SSE parser didn't already fire it from [DONE]
            hasCompletedStream = true
            Log.ai.info("🏁 Lyo2 SSE: stream completed successfully, firing .done")
            callback?(.done)
        } else {
            Log.ai.info("🏁 Lyo2 SSE: stream delegate completed — .done already fired by SSE parser, skipping")
        }
        self.callback = nil
    }
    
    // MARK: - SSE Parsing
    
    private func parseSSEBuffer() {
        guard let string = String(data: buffer, encoding: .utf8) else {
            Log.ai.warning("Lyo2 SSE: buffer is not valid UTF-8 (\(self.buffer.count) bytes)")
            return
        }
        
        if let range = string.range(of: "\n\n") {
            let eventString = String(string[..<range.lowerBound])
            Log.ai.info("📨 Lyo2 SSE event raw: \(eventString.prefix(200))")
            parseSSEEvent(eventString)
            
            let remainder = String(string[range.upperBound...])
            buffer = remainder.data(using: .utf8) ?? Data()
            
            if buffer.count > 0 {
                parseSSEBuffer()
            }
        } else {
            Log.ai.info("Lyo2 SSE buffer waiting for \\n\\n (\(self.buffer.count) bytes): \(string.prefix(100))")
        }
    }
    
    private func parseSSEEvent(_ eventString: String) {
        let lines = eventString.components(separatedBy: "\n")
        var data: String?
        
        for line in lines {
            if line.hasPrefix("data: ") {
                data = String(line.dropFirst(6))
            } else if line.hasPrefix("id: ") {
                // Track event ID for potential reconnection replay
                lastEventId = String(line.dropFirst(4))
            }
        }
        
        guard let jsonString = data else { return }
        if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
            guard !hasCompletedStream else { return } // Already fired .done
            hasCompletedStream = true
            callback?(.done)
            return
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let eventType = json["type"] as? String else { return }
            
            switch eventType {
            case "skeleton":
                if let blocks = json["blocks"] as? [String] {
                    didReceiveContentEvent = true
                    callback?(.skeleton(blocks: blocks))
                }
                
            case "clarification":
                if let text = json["text"] as? String {
                    didReceiveContentEvent = true
                    callback?(.clarification(text: text))
                }
                
            case "answer":
                Log.ai.info("Lyo2 SSE: processing answer event")
                didReceiveContentEvent = true
                if let blockDict = json["block"] {
                    Log.ai.info("Lyo2 SSE: block dict extracted OK")
                    if let blockData = try? JSONSerialization.data(withJSONObject: blockDict) {
                        Log.ai.info("Lyo2 SSE: re-serialized block (\(blockData.count) bytes)")
                        do {
                            let block = try JSONDecoder().decode(Lyo2UIBlock.self, from: blockData)
                            let textPreview = (block.content["text"]?.value as? String)?.prefix(80) ?? "(no text key)"
                            Log.ai.info("Lyo2 SSE: decoded answer block — type=\(String(describing: block.blockType)), text=\(textPreview)")
                            callback?(.answer(block: block))
                            Log.ai.info("Lyo2 SSE: answer callback fired")
                        } catch {
                            Log.ai.error("Lyo2 Decoding Error (Answer): \(error)")
                            callback?(.error(message: "Decoding failed: \(error.localizedDescription)"))
                        }
                    } else {
                        Log.ai.error("Lyo2 SSE: JSONSerialization.data failed for block dict")
                    }
                } else {
                    Log.ai.warning("Lyo2 SSE: json[\"block\"] is nil! Keys: \(json.keys.sorted())")
                }
                
            case "artifact":
                didReceiveContentEvent = true
                if let blockDict = json["block"],
                   let blockData = try? JSONSerialization.data(withJSONObject: blockDict) {
                    do {
                        let block = try JSONDecoder().decode(Lyo2UIBlock.self, from: blockData)
                        callback?(.artifact(block: block))
                    } catch {
                        Log.ai.error("Lyo2 Decoding Error (Artifact): \(error)")
                        callback?(.error(message: "Artifact decoding failed: \(error.localizedDescription)"))
                    }
                } else {
                    Log.ai.warning("Failed to extract block data from artifact event")
                }
                
            case "actions":
                // v1 backward compat — deployed backend still emits this
                didReceiveContentEvent = true
                if let blocksArray = json["blocks"] as? [[String: Any]] {
                    var blocks: [Lyo2UIBlock] = []
                    for dict in blocksArray {
                        if let d = try? JSONSerialization.data(withJSONObject: dict),
                           let block = try? JSONDecoder().decode(Lyo2UIBlock.self, from: d) {
                            blocks.append(block)
                        }
                    }
                    if !blocks.isEmpty {
                        callback?(.actions(blocks: blocks))
                    }
                }
                
            case "error":
                let msg = json["message"] as? String ?? "Unknown server error"
                callback?(.error(message: msg))
                
            case "open_classroom":
                // v1 backward compat — deployed backend still emits this
                didReceiveContentEvent = true
                if let blockDict = json["block"],
                   let blockData = try? JSONSerialization.data(withJSONObject: blockDict) {
                    do {
                        let block = try JSONDecoder().decode(Lyo2UIBlock.self, from: blockData)
                        Log.ai.info("Lyo2 SSE: open_classroom event received (v1 compat)")
                        callback?(.openClassroom(block: block))
                    } catch {
                        Log.ai.error("Lyo2 Decoding Error (OpenClassroom): \(error)")
                    }
                }
                
            case "a2ui":
                // Stale event type — log and ignore
                Log.ai.info("🎨 Lyo2 SSE: stale event type received — ignoring")

            // ── v2 events (LyoResponse envelope — primary path) ──────

            case "lyo_ui":
                didReceiveContentEvent = true
                if let responseDict = json["response"],
                   let responseData = try? JSONSerialization.data(withJSONObject: responseDict) {
                    do {
                        let response = try JSONDecoder().decode(LyoResponse.self, from: responseData)
                        Log.ai.info("🎨 Lyo2 SSE: lyo_ui v2 event received")
                        callback?(.lyoUI(response: response))
                    } catch {
                        Log.ai.error("Lyo2 Decoding Error (lyo_ui): \(error)")
                    }
                }

            case "lyo_command":
                didReceiveContentEvent = true
                if let responseDict = json["response"],
                   let responseData = try? JSONSerialization.data(withJSONObject: responseDict) {
                    do {
                        let response = try JSONDecoder().decode(LyoResponse.self, from: responseData)
                        Log.ai.info("🎨 Lyo2 SSE: lyo_command v2 event received")
                        callback?(.lyoCommand(response: response))
                    } catch {
                        Log.ai.error("Lyo2 Decoding Error (lyo_command): \(error)")
                    }
                }

            case "lyo_suggestions":
                didReceiveContentEvent = true
                if let responseDict = json["response"],
                   let responseData = try? JSONSerialization.data(withJSONObject: responseDict) {
                    do {
                        let response = try JSONDecoder().decode(LyoResponse.self, from: responseData)
                        Log.ai.info("🎨 Lyo2 SSE: lyo_suggestions v2 event received")
                        callback?(.lyoSuggestions(response: response))
                    } catch {
                        Log.ai.error("Lyo2 Decoding Error (lyo_suggestions): \(error)")
                    }
                }

            case "smart_blocks":
                didReceiveContentEvent = true
                if let blocksArray = json["blocks"],
                   let blocksData = try? JSONSerialization.data(withJSONObject: blocksArray) {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    do {
                        let blocks = try decoder.decode([SmartBlock].self, from: blocksData)
                        Log.ai.info("🧱 Lyo2 SSE: decoded \(blocks.count) SmartBlocks")
                        callback?(.smartBlocks(blocks: blocks))
                    } catch {
                        Log.ai.error("Lyo2 Decoding Error (smart_blocks): \(error)")
                    }
                }
                
            default:
                Log.ai.warning("Lyo2 unknown event type: \(eventType)")
            }
        } catch {
            Log.ai.error("Failed to parse Lyo2 event: \(error)")
        }
    }
}
