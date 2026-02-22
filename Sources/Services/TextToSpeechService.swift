import Foundation
import AVFoundation
import os

class TextToSpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TextToSpeechService()
    
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking: Bool = false
    var onSpeechFinished: (() -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // Configure audio session for playback and recording (needed for echo cancellation)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetoothHFP, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Log.audio.error("Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Queue Management
    
    private var speechQueue: [String] = []
    
    /// Speak text immediately (clears queue)
    func speak(text: String) {
        stop()
        enqueue(text)
    }
    
    /// Add text to the speech queue
    func enqueue(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        speechQueue.append(text)
        
        // If not currently speaking, start the queue
        if !synthesizer.isSpeaking {
            playNextInQueue()
        }
    }
    
    private func playNextInQueue() {
        guard !speechQueue.isEmpty else { return }
        
        let text = speechQueue.removeFirst()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        speechQueue.removeAll()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            // Check if queue is empty to update state
            if self.speechQueue.isEmpty {
                self.isSpeaking = false
                self.onSpeechFinished?()
            } else {
                // Continue queue
                self.playNextInQueue()
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.speechQueue.removeAll()
        }
    }
}
