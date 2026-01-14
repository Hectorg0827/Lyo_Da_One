//
//  VoiceInputService.swift
//  Lyo
//
//  Service for handling voice input (Speech-to-Text)
//

import Foundation
import Speech
import AVFoundation

/// Service for handling voice input (Speech-to-Text)
@MainActor
class VoiceInputService: ObservableObject {
    static let shared = VoiceInputService()
    
    // MARK: - Published State
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var transcript = ""
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: VoiceInputError?
    @Published var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var recordingTimer: Timer?
    private var startTime: Date?
    
    // Configuration
    private let maxRecordingDuration: TimeInterval = 60 // 1 minute max
    
    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        checkPermissions()
    }
    
    // MARK: - Permissions
    
    func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionStatus = status
            }
        }
    }
    
    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            await MainActor.run {
                self.error = .permissionDenied
            }
            return false
        }
        
        // Request microphone permission
        let micStatus: Bool
        #if os(iOS)
        if #available(iOS 17.0, *) {
            micStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            micStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        #else
        micStatus = true // macOS handles permissions differently
        #endif
        
        if !micStatus {
            await MainActor.run {
                self.error = .microphonePermissionDenied
            }
            return false
        }
        
        await MainActor.run {
            self.permissionStatus = speechStatus
        }
        
        return true
    }
    
    // MARK: - Recording Control
    
    func startRecording() async throws {
        guard !isRecording else { return }
        
        // Check permissions
        if permissionStatus != .authorized {
            let granted = await requestPermissions()
            guard granted else { throw VoiceInputError.permissionDenied }
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceInputError.recognizerUnavailable
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceInputError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap for audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level for visualization
            let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    print("❌ Speech recognition error: \(error)")
                    self?.stopRecording()
                }
            }
        }
        
        // Update state
        isRecording = true
        startTime = Date()
        transcript = ""
        error = nil
        
        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.startTime else { return }
                
                self.recordingDuration = Date().timeIntervalSince(startTime)
                
                // Auto-stop at max duration
                if self.recordingDuration >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
        }
        
        // Haptic feedback
        #if os(iOS)
        HapticManager.shared.playRecordingStarted()
        #endif
        
        print("🎤 Voice recording started")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // End recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Reset
        recognitionRequest = nil
        recognitionTask = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Update state
        isRecording = false
        isProcessing = false
        audioLevel = 0
        
        // Deactivate audio session
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        
        // Haptic feedback
        HapticManager.shared.playRecordingStopped()
        #endif
        
        print("🎤 Voice recording stopped. Transcript: \(transcript)")
    }
    
    func cancelRecording() {
        stopRecording()
        transcript = ""
        recordingDuration = 0
    }
    
    // MARK: - Audio Level Calculation
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        let db = 20 * log10(average)
        
        // Normalize to 0-1 range
        let normalized = (db + 50) / 50
        return max(0, min(1, normalized))
    }
}

// MARK: - Errors

enum VoiceInputError: LocalizedError {
    case permissionDenied
    case microphonePermissionDenied
    case recognizerUnavailable
    case requestCreationFailed
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        }
    }
}
