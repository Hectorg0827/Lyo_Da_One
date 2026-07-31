import Foundation
import NaturalLanguage
import AVFoundation

/// Picks a TTS voice matching the language the text is actually written in,
/// instead of assuming every utterance is English. Used anywhere the app
/// reads lesson/help content aloud so a Spanish (or any other language)
/// course is narrated in a matching voice rather than an English one.
enum SpeechLanguage {
    static func voice(for text: String, fallback: String = "en-US") -> AVSpeechSynthesisVoice? {
        guard let languageCode = dominantLanguageCode(for: text) else {
            return AVSpeechSynthesisVoice(language: fallback)
        }
        let matched = AVSpeechSynthesisVoice.speechVoices()
            .first { $0.language.lowercased().hasPrefix(languageCode.lowercased()) }
        return matched ?? AVSpeechSynthesisVoice(language: fallback)
    }

    /// Two-letter ISO 639-1 code (e.g. "es") for the dominant language of `text`,
    /// or nil when the text is too short or the detector isn't confident enough
    /// to avoid mis-selecting a voice.
    static func dominantLanguageCode(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage,
              let confidence = recognizer.languageHypotheses(withMaximum: 1)[language],
              confidence > 0.5 else {
            return nil
        }
        return language.rawValue
    }
}
