import Foundation
@preconcurrency import AVFoundation
import Combine
import os

/// Service for real-time bidirectional audio streaming via WebSockets (True Live Mode)
@MainActor
class AudioStreamManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    static let shared = AudioStreamManager()
    
    // MARK: - Published State
    @Published var isLive = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var userAudioLevel: Float = 0
    @Published var aiAudioLevel: Float = 0
    @Published var isAIThinking = false
    @Published var isAISpeaking = false
    @Published var lastTranscript = ""
    @Published var activeWidget: [String: Any]?
    @Published var error: String?
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    // MARK: - Audio Properties
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let inputBus: AVAudioNodeBus = 0
    
    private let sampleRate: Double = 24000
    private let channels: AVAudioChannelCount = 1
    
    private var inputFormat: AVAudioFormat?
    private var streamFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    
    // MARK: - WebSocket Properties
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var currentSessionId: String?

    /// Create a fresh URLSession for each live connection.
    /// Reusing a session after a connection/init failure can cause
    /// "invalid reuse after initialization failure" crashes.
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    private override init() {
        super.init()
        // Removed persistent URLSession creation per instructions
        // Setup internal format: 24kHz, 16-bit Mono PCM
        self.streamFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, 
                                        sampleRate: sampleRate, 
                                        channels: channels, 
                                        interleaved: false)
    }
    
    // MARK: - Lifecycle Control
    
    @MainActor
    func startLiveMode(sessionId: String) async {
        guard !isLive else { return }
        
        self.error = nil
        self.currentSessionId = sessionId
        
        do {
            try setupAudioSession()
            try setupAudioEngine()

            // Create fresh session per connection (avoids reuse after failure)
            self.session?.invalidateAndCancel()
            self.session = self.makeSession()

            try await connectWebSocket(sessionId: sessionId)
            
            try audioEngine.start()
            isLive = true
            Log.audio.info("🎙️ True Live Mode initiated for session: \(sessionId)")
            
        } catch {
            self.error = "Failed to start Live Mode: \(error.localizedDescription)"
            Log.audio.error("Failed to start Live Mode: \(error)")
            stopLiveMode()
        }
    }
    
    @MainActor
    func stopLiveMode() {
        Log.audio.info("🎙️ Stopping True Live Mode")
        isLive = false
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: inputBus)
        playerNode.stop()
        
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionStatus = .disconnected
        
        session?.invalidateAndCancel()
        session = nil
        
        // Restore session if needed elsewhere
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - WebSocket Logic
    
    private func connectWebSocket(sessionId: String) async throws {
        // Derive WebSocket root from baseURL for consistent routing
        var wsRoot = AppConfig.baseURL
        if wsRoot.hasPrefix("http") {
            wsRoot = wsRoot.replacingOccurrences(of: "https://", with: "wss://")
            wsRoot = wsRoot.replacingOccurrences(of: "http://", with: "ws://")
        }
        
        let wsURLString = "\(wsRoot)/api/v2/chat/\(sessionId)/audio"
        
        guard let url = URL(string: wsURLString) else {
            throw NSError(domain: "AudioStreamManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid WebSocket URL"])
        }
        
        // Add auth token
        var request = URLRequest(url: url)
        if let token = await TokenManager.shared.getToken() {
            // Append token as query param as per WebSocketManager pattern
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "token", value: token)]
            if let authedURL = components?.url {
                request.url = authedURL
            }
        }
        
        connectionStatus = .connecting

        guard let session = session else { throw NSError(domain: "AudioStreamManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "URLSession not initialized"]) }
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        
        receiveAudio()
    }
    
    private func receiveAudio() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.isLive else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .data(let data):
                        self.handleIncomingAudio(data)
                    case .string(let text):
                        self.handleIncomingCommand(text)
                    @unknown default:
                        break
                    }
                    self.receiveAudio() // Loop
                case .failure(let error):
                    Log.audio.error("Audio WebSocket receive error: \(error)")
                    self.handleWebSocketFailure(error)
                }
            }
        }
    }
    
    private func handleIncomingCommand(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String {
                
                DispatchQueue.main.async {
                    switch type {
                    case "interrupt":
                        Log.audio.error("AI Interrupted by Backend")
                        self.stopPlayback()
                    case "transcript":
                        if let text = json["text"] as? String {
                            self.lastTranscript = text
                            // print("🎙️ User: \(text)")
                        }
                    case "ai_transcript":
                        if let text = json["text"] as? String {
                            self.lastTranscript = text
                            // print("🤖 AI: \(text)")
                            self.isAISpeaking = true
                            self.isAIThinking = false
                        }
                    case "ai_complete":
                        self.isAISpeaking = false
                    case "widget":
                        if let component = json["component"] as? String,
                           let data = json["data"] as? [String: Any] {
                            var widgetData = data
                            widgetData["_component"] = component
                            self.activeWidget = widgetData
                            Log.audio.info("🎨 New widget received: \(component)")
                        }
                    default:
                        break
                    }
                }
            }
        } catch {
            Log.audio.error("Failed to parse command: \(text)")
        }
    }
    
    private func stopPlayback() {
        playerNode.stop()
        self.isAISpeaking = false
        self.isAIThinking = false
    }
    
    private func handleIncomingAudio(_ data: Data) {
        guard let format = streamFormat else { return }
        
        let frameCount = UInt32(data.count) / UInt32(MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            if let baseAddress = rawBufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                buffer.int16ChannelData?[0].update(from: baseAddress, count: Int(frameCount))
            }
        }
        
        if isLive {
            // Use empty options for smooth queuing instead of .interrupts
            playerNode.scheduleBuffer(buffer, at: nil, options: [])
            if !playerNode.isPlaying {
                playerNode.play()
            }
            
            // Calculate AI audio level for visualization without capturing `buffer` in a @Sendable closure
            let level = self.calculateLevel(buffer: buffer)
            DispatchQueue.main.async {
                self.aiAudioLevel = level
                if self.aiAudioLevel > 0.05 {
                    self.isAISpeaking = true
                    self.isAIThinking = false
                }
            }
        }
    }
    
    private func handleWebSocketFailure(_ error: Error) {
        DispatchQueue.main.async {
            self.connectionStatus = .error(error.localizedDescription)
            self.stopLiveMode()
            self.session?.invalidateAndCancel()
            self.session = nil
        }
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .playAndRecord with .voiceChat provides best echo cancellation and ducking logic
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
    }
    
    private func setupAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let nativeInputFormat = inputNode.outputFormat(forBus: inputBus)
        self.inputFormat = nativeInputFormat
        
        guard let streamFormat = streamFormat else { return }
        
        // Setup converter from microphone format to our 24kHz stream format
        self.converter = AVAudioConverter(from: nativeInputFormat, to: streamFormat)
        
        // Attach and connect Player Node for AI voice output
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: streamFormat)
        
        // Install Mic Tap
        inputNode.removeTap(onBus: inputBus) // Clear stale
        inputNode.installTap(onBus: inputBus, bufferSize: 1024, format: nativeInputFormat) { [weak self] buffer, _ in
            self?.processAndSendInput(buffer: buffer)
        }
        
        audioEngine.prepare()
    }
    
    private func processAndSendInput(buffer: AVAudioPCMBuffer) {
        guard let converter = converter, let streamFormat = streamFormat else { return }
        
        // Determine capacity for output buffer after resampling
        let ratio = streamFormat.sampleRate / buffer.format.sampleRate
        let targetFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: streamFormat, frameCapacity: targetFrameCapacity) else { return }
        
        var conversionError: NSError?
        let status = converter.convert(to: outBuffer, error: &conversionError) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status == .error || conversionError != nil {
            Log.audio.error("Audio Conversion failed: \(conversionError?.localizedDescription ?? "unknown")")
            return
        }
        
        // Send raw PCM bytes to backend
        let pcmData = Data(buffer: outBuffer)
        if !pcmData.isEmpty {
            webSocket?.send(.data(pcmData)) { error in
                if let error = error {
                    Log.audio.error("WebSocket Send error: \(error)")
                }
            }
        }
        
        // Update user audio level visualization without capturing non-Sendable buffer
        let level = self.calculateLevel(buffer: outBuffer)
        DispatchQueue.main.async {
            self.userAudioLevel = level
        }
    }
    
    // MARK: - Helpers
    
    private func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.int16ChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        if frames == 0 { return 0 }
        
        var rms: Float = 0
        for i in 0..<frames {
            let sample = Float(channelData[i]) / Float(Int16.max)
            rms += sample * sample
        }
        rms = sqrt(rms / Float(frames))
        
        // Basic normalization for UI (0.0 to 1.0)
        // Adjust threshold based on real-world microphone sensitivity
        return min(max(rms * 10, 0), 1)
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Log.audio.info("Audio WebSocket Connected")
        Task { @MainActor in
            self.connectionStatus = .connected
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Log.audio.info("🔌 Audio WebSocket Closed")
        Task { @MainActor in
            self.connectionStatus = .disconnected
            self.isLive = false
        }
    }
}

// MARK: - Extensions

extension Data {
    /// Initializer to extract raw PCM bytes from an AVAudioPCMBuffer
    init(buffer: AVAudioPCMBuffer) {
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let dataSize = frameCount * channelCount * MemoryLayout<Int16>.size
        
        if let channelData = buffer.int16ChannelData {
            self.init(bytes: channelData[0], count: dataSize)
        } else {
            self.init()
        }
    }
}

