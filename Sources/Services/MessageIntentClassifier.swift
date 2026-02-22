//
//  MessageIntentClassifier.swift
//  Lyo
//
//  On-device intent classification for the Two-Speed Response Engine.
//  Classifies messages into speed tiers to avoid routing simple greetings
//  through the full 6-agent Orchestrator pipeline (which adds 3-7s latency).
//
//  Speed tiers:
//  - instant  (~1ms)   : Navigation commands, UI actions
//  - fast     (~200ms) : Greetings, simple Q&A, acknowledgments
//  - standard (~800ms) : Quick explanations, frustration handling
//  - deep     (~3000ms): Full lessons, course generation, complex reasoning
//

import Foundation
import os

// MARK: - Message Speed Tier

/// Determines how fast a response should be and which pipeline to use
enum MessageSpeedTier: Comparable {
    case instant        // On-device only, no network
    case fast           // Quick endpoint, single-agent
    case standard       // Standard endpoint, 2-3 agents
    case deep           // Full orchestrator, all agents
    
    /// Human-readable description
    var label: String {
        switch self {
        case .instant:  return "instant"
        case .fast:     return "fast"
        case .standard: return "standard"
        case .deep:     return "deep"
        }
    }
    
    /// Target latency in milliseconds
    var targetLatencyMs: Int {
        switch self {
        case .instant:  return 1
        case .fast:     return 200
        case .standard: return 800
        case .deep:     return 3000
        }
    }
    
    /// Whether this tier should use streaming
    var shouldStream: Bool {
        switch self {
        case .instant, .fast: return false
        case .standard, .deep: return true
        }
    }
}

// MARK: - Classified Intent

/// Result of intent classification with confidence
struct ClassifiedIntent {
    let tier: MessageSpeedTier
    let category: IntentCategory
    let confidence: Double              // 0.0 - 1.0
    let extractedTopic: String?         // Topic extracted from the message (if any)
    let emotionalContext: EmotionalContext?
    
    /// High confidence means we're sure about the classification
    var isHighConfidence: Bool { confidence >= 0.8 }
}

/// Categories of user intent
enum IntentCategory: String {
    // Instant
    case navigation         // "go to settings", "open my courses"
    case uiAction           // "dark mode", "close this"
    
    // Fast
    case greeting           // "hello", "hi", "hey there"
    case farewell           // "bye", "see you", "goodnight"
    case acknowledgment     // "ok", "thanks", "got it"
    case smallTalk          // "how are you", "what's up"
    
    // Standard
    case quickQuestion      // "what is X?", "define Y"
    case frustration        // "I don't understand", "this is confusing"
    case encouragement      // "am I doing well?", "is this right?"
    case clarification      // "what do you mean?", "can you explain?"
    
    // Deep
    case lessonRequest      // "teach me about X", "explain quantum physics"
    case courseCreation      // "create a course on X"
    case deepExplanation    // "why does X work?", "how does X relate to Y?"
    case practiceRequest    // "give me exercises", "quiz me"
    case studyPlan          // "help me study for X", "make a study plan"
}

/// Emotional context detected from the message
enum EmotionalContext: String {
    case neutral
    case curious
    case frustrated
    case excited
    case confused
    case confident
    case anxious
}

// MARK: - Message Intent Classifier

@MainActor
final class MessageIntentClassifier {
    static let shared = MessageIntentClassifier()
    
    private init() {}
    
    // MARK: - Keyword Sets (Pre-compiled for performance)
    
    private let greetingPatterns: Set<String> = [
        "hi", "hello", "hey", "hola", "sup", "yo", "hii", "hiii",
        "good morning", "good afternoon", "good evening", "good night",
        "what's up", "whats up", "howdy", "greetings"
    ]
    
    private let farewellPatterns: Set<String> = [
        "bye", "goodbye", "see you", "later", "goodnight", "cya",
        "gotta go", "talk later", "peace", "adios"
    ]
    
    private let acknowledgmentPatterns: Set<String> = [
        "ok", "okay", "thanks", "thank you", "got it", "understood",
        "makes sense", "cool", "nice", "great", "awesome", "perfect",
        "sure", "yep", "yeah", "yes", "alright", "right", "i see",
        "noted", "thx", "ty"
    ]
    
    private let frustrationIndicators: Set<String> = [
        "don't understand", "dont understand", "confused", "confusing",
        "doesn't make sense", "doesnt make sense", "what?", "huh?",
        "lost", "stuck", "help me", "struggling", "hard", "difficult",
        "i can't", "i cant", "this sucks", "ugh", "frustrated"
    ]
    
    private let courseCreationIndicators: Set<String> = [
        "create a course", "make a course", "build a course",
        "teach me", "create course", "new course", "course on",
        "course about", "full course", "lesson plan"
    ]
    
    private let deepExplanationIndicators: Set<String> = [
        "explain in detail", "deep dive", "elaborate", "tell me everything",
        "comprehensive", "thorough", "step by step", "walk me through",
        "from scratch", "in depth"
    ]
    
    private let practiceIndicators: Set<String> = [
        "quiz me", "test me", "practice", "exercise", "flashcard",
        "drill", "problems", "questions", "challenge me"
    ]
    
    private let navigationIndicators: Set<String> = [
        "go to", "open", "show me", "navigate to", "take me to",
        "settings", "profile", "home", "dashboard", "my courses"
    ]
    
    // MARK: - Classify
    
    /// Classify a user message into a speed tier
    /// This runs on-device with no network call — typically < 1ms
    func classify(_ message: String) -> ClassifiedIntent {
        let lowered = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = lowered.split(separator: " ").count
        
        // 1. Navigation (instant)
        if matchesAny(lowered, in: navigationIndicators) {
            return ClassifiedIntent(
                tier: .instant,
                category: .navigation,
                confidence: 0.9,
                extractedTopic: nil,
                emotionalContext: .neutral
            )
        }
        
        // 2. Short messages (< 4 words) — check fast-path patterns
        if wordCount <= 4 {
            // Greeting
            if matchesAny(lowered, in: greetingPatterns) {
                return ClassifiedIntent(
                    tier: .fast,
                    category: .greeting,
                    confidence: 0.95,
                    extractedTopic: nil,
                    emotionalContext: .neutral
                )
            }
            
            // Farewell
            if matchesAny(lowered, in: farewellPatterns) {
                return ClassifiedIntent(
                    tier: .fast,
                    category: .farewell,
                    confidence: 0.95,
                    extractedTopic: nil,
                    emotionalContext: .neutral
                )
            }
            
            // Acknowledgment
            if matchesAny(lowered, in: acknowledgmentPatterns) {
                return ClassifiedIntent(
                    tier: .fast,
                    category: .acknowledgment,
                    confidence: 0.90,
                    extractedTopic: nil,
                    emotionalContext: .neutral
                )
            }
        }
        
        // 3. Frustration detection (standard — needs sentiment agent)
        if matchesAny(lowered, in: frustrationIndicators) {
            return ClassifiedIntent(
                tier: .standard,
                category: .frustration,
                confidence: 0.85,
                extractedTopic: extractTopic(from: lowered),
                emotionalContext: .frustrated
            )
        }
        
        // 4. Course creation (deep)
        if matchesAny(lowered, in: courseCreationIndicators) {
            return ClassifiedIntent(
                tier: .deep,
                category: .courseCreation,
                confidence: 0.90,
                extractedTopic: extractTopic(from: lowered),
                emotionalContext: .curious
            )
        }
        
        // 5. Practice requests (deep)
        if matchesAny(lowered, in: practiceIndicators) {
            return ClassifiedIntent(
                tier: .deep,
                category: .practiceRequest,
                confidence: 0.85,
                extractedTopic: extractTopic(from: lowered),
                emotionalContext: .neutral
            )
        }
        
        // 6. Deep explanation requests
        if matchesAny(lowered, in: deepExplanationIndicators) {
            return ClassifiedIntent(
                tier: .deep,
                category: .deepExplanation,
                confidence: 0.85,
                extractedTopic: extractTopic(from: lowered),
                emotionalContext: .curious
            )
        }
        
        // 7. Question detection — "what is", "how does", "why", etc.
        if isQuestionPattern(lowered) {
            // Short questions → standard, long questions → deep
            let tier: MessageSpeedTier = wordCount <= 8 ? .standard : .deep
            return ClassifiedIntent(
                tier: tier,
                category: wordCount <= 8 ? .quickQuestion : .deepExplanation,
                confidence: 0.75,
                extractedTopic: extractTopic(from: lowered),
                emotionalContext: .curious
            )
        }
        
        // 8. Default: standard for medium messages, deep for long ones
        let defaultTier: MessageSpeedTier = wordCount <= 12 ? .standard : .deep
        return ClassifiedIntent(
            tier: defaultTier,
            category: .quickQuestion,
            confidence: 0.5,
            extractedTopic: extractTopic(from: lowered),
            emotionalContext: .neutral
        )
    }
    
    // MARK: - Pattern Matching Helpers
    
    private func matchesAny(_ text: String, in patterns: Set<String>) -> Bool {
        // Check exact match first
        if patterns.contains(text) { return true }
        
        // Check if text contains any pattern
        for pattern in patterns {
            if text.contains(pattern) { return true }
        }
        return false
    }
    
    private func isQuestionPattern(_ text: String) -> Bool {
        let questionStarters = ["what ", "who ", "where ", "when ", "why ", "how ",
                                "which ", "can you", "could you", "would you",
                                "is it", "are there", "do you", "does "]
        let endsWithQuestion = text.hasSuffix("?")
        let startsWithQuestion = questionStarters.contains { text.hasPrefix($0) }
        return endsWithQuestion || startsWithQuestion
    }
    
    // MARK: - Topic Extraction
    
    /// Basic topic extraction from the message
    /// Strips common prefixes/suffixes to isolate the subject
    private func extractTopic(from text: String) -> String? {
        var cleaned = text
        
        // Remove common prefixes
        let prefixes = [
            "teach me about ", "explain ", "what is ", "what are ",
            "tell me about ", "how does ", "why does ", "can you explain ",
            "help me understand ", "i want to learn about ", "i want to learn ",
            "create a course on ", "create a course about ",
            "quiz me on ", "test me on ", "practice "
        ]
        
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        
        // Remove trailing question mark and punctuation
        cleaned = cleaned.trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
        
        return cleaned.isEmpty ? nil : cleaned
    }
}
