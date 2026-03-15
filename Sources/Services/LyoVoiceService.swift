import Foundation
import AVFoundation

/// Dedicated service for Lyo's persona narration
class LyoVoiceService {
    static let shared = LyoVoiceService()
    
    private let tts = TextToSpeechService.shared
    
    private init() {}
    
    /// Speak Lyo's meta-commentary with appropriate emotional tone
    func narrate(_ commentary: String, mood: String? = nil) {
        guard !commentary.isEmpty else { return }
        
        // Map Lyo moods to TTS emotions
        if let mood = mood {
            tts.setEmotion(mood)
        }
        
        tts.speak(text: commentary)
    }
    
    /// Stop all current narration
    func silence() {
        tts.stop()
    }
}
