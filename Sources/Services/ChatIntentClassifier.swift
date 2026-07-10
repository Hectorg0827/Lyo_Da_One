//
//  ChatIntentClassifier.swift
//  Lyo
//
//  Fail-proof intent classification - determines if user wants quick answer or full course
//

import Foundation
import SwiftUI

// MARK: - User Intent

enum UserIntent: Equatable {
    case quickExplanation(topic: String)
    case courseCreation(topic: String)
    case courseWizardContinue(action: CourseWizardAction)
    case generalChat(message: String)
    
    var topic: String? {
        switch self {
        case .quickExplanation(let topic), .courseCreation(let topic):
            return topic
        case .courseWizardContinue, .generalChat:
            return nil
        }
    }
}

enum CourseWizardAction: Equatable {
    case confirmTopic
    case selectLevel(String)
    case approveOutline
    case editOutline(String)
    case startCourse
    case cancel
}

// MARK: - Course Wizard State

enum CourseWizardStep: Equatable {
    case inactive
    case confirmingTopic(topic: String)
    case selectingLevel(topic: String)
    case showingOutline(topic: String, level: String, outline: CourseOutline?)
    case generatingCourse(topic: String, level: String)
    case courseReady(courseId: String)
}

struct CourseOutline: Equatable {
    let title: String
    let description: String
    let modules: [String]
    let estimatedDuration: Int
    let level: String
}

// MARK: - Intent Classifier

@MainActor
final class ChatIntentClassifier: ObservableObject {
    static let shared = ChatIntentClassifier()
    
    @Published var wizardStep: CourseWizardStep = .inactive
    @Published var pendingTopic: String?
    
    private init() {}
    
    // MARK: - Course Creation Keywords (Trigger full course flow)
    
    private let courseCreationKeywords: Set<String> = [
        "create a course",
        "make a course",
        "build a course",
        "design a course",
        "generate a course",
        "full course",
        "full corse",           // Common typo
        "complete course",
        "teach me everything",
        "i want to learn",
        "want to learn",        // Without "I"
        "i want to master",
        "want to master",       // Without "I"
        "comprehensive guide",
        "full guide",
        "complete guide",
        "step by step course",
        "structured course",
        "learning path",
        "curriculum",
        "syllabus",
        "class on",
        "class about",
        "make me a course",
        "create me a course",
        "build me a course",
        "do the course",        // Follow-up intent
        "start the course",     // Follow-up intent
        "generate the course",
        "go ahead and create",
        "yes create",
        "yes make"
    ]
    
    private let courseCreationPatterns: [String] = [
        "create .* course",
        "make .* course",
        "build .* course",
        "teach me .* from scratch",
        "learn .* completely",
        "master .*",
        "full .* course",
        "complete .* tutorial",
        "course on .*",
        "course about .*",
        "course for .*",
        "start a course",
        "begin a course",
        "study plan for",
        "learn .* step by step"
    ]
    
    // MARK: - Quick Explanation Keywords (Stay in chat)
    
    private let quickExplanationKeywords: Set<String> = [
        "what is",
        "what are",
        "what's",
        "explain",
        "define",
        "tell me about",
        "describe",
        "how does",
        "how do",
        "why is",
        "why does",
        "quick",
        "briefly",
        "summary",
        "overview",
        "in short",
        "simple explanation",
        "eli5",
        "explain like"
    ]
    
    // MARK: - Classify Intent
    
    func classifyIntent(_ message: String) -> UserIntent {
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If we're in a wizard flow, check for wizard actions first
        if wizardStep != .inactive {
            if let action = parseWizardAction(lowercased) {
                return .courseWizardContinue(action: action)
            }
        }
        
        // Check for explicit course creation intent
        if isCourseCreationIntent(lowercased) {
            let topic = extractTopic(from: lowercased, forCourse: true)
            return .courseCreation(topic: topic)
        }
        
        // Check for quick explanation intent
        if isQuickExplanationIntent(lowercased) {
            let topic = extractTopic(from: lowercased, forCourse: false)
            return .quickExplanation(topic: topic)
        }
        
        // Default: If message is long or complex, likely wants explanation
        // If short and contains learning-related words, might want course
        if containsLearningIntent(lowercased) && !isSimpleQuestion(lowercased) {
            let topic = extractTopic(from: lowercased, forCourse: true)
            return .courseCreation(topic: topic)
        }
        
        // Default to general chat (will be handled as quick explanation)
        return .generalChat(message: message)
    }
    
    // MARK: - Course Creation Detection
    
    private func isCourseCreationIntent(_ message: String) -> Bool {
        // Check exact phrase matches
        for keyword in courseCreationKeywords {
            if message.contains(keyword) {
                return true
            }
        }
        
        // Check regex patterns
        for pattern in courseCreationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(message.startIndex..., in: message)
                if regex.firstMatch(in: message, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Quick Explanation Detection
    
    private func isQuickExplanationIntent(_ message: String) -> Bool {
        for keyword in quickExplanationKeywords {
            if message.hasPrefix(keyword) || message.contains(" \(keyword) ") {
                return true
            }
        }
        return false
    }
    
    // MARK: - Learning Intent Detection
    
    private func containsLearningIntent(_ message: String) -> Bool {
        let learningWords = ["learn", "study", "understand", "know", "teach", "education", "tutorial"]
        return learningWords.contains { message.contains($0) }
    }
    
    private func isSimpleQuestion(_ message: String) -> Bool {
        // Simple questions are typically short and start with question words
        let questionStarters = ["what", "why", "how", "when", "where", "who", "is", "are", "can", "does", "do"]
        let words = message.split(separator: " ")
        
        return words.count < 10 && questionStarters.contains { message.hasPrefix($0) }
    }
    
    // MARK: - Topic Extraction
    
    private func extractTopic(from message: String, forCourse: Bool) -> String {
        var cleaned = message
        
        // Remove course-related prefixes
        let prefixesToRemove = [
            "create a course on", "create a course about", "create a course for",
            "make a course on", "make a course about", "make a course for",
            "build a course on", "build a course about",
            "teach me everything about", "teach me about", "teach me",
            "i want to learn about", "i want to learn", "i want to master",
            "full course on", "complete course on",
            "what is", "what are", "what's",
            "explain", "define", "tell me about", "describe",
            "how does", "how do", "how to",
            "learn about", "learn"
        ]
        
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        
        // Clean up
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,"))
        
        // Capitalize first letter
        if let first = cleaned.first {
            cleaned = first.uppercased() + cleaned.dropFirst()
        }
        
        return cleaned.isEmpty ? "this topic" : cleaned
    }
    
    // MARK: - Wizard Action Parsing
    
    private func parseWizardAction(_ message: String) -> CourseWizardAction? {
        // Check for confirmation
        if ["yes", "yeah", "yep", "sure", "ok", "okay", "confirm", "correct", "that's right", "sounds good", "perfect", "let's go", "start"].contains(where: { message.contains($0) }) {
            switch wizardStep {
            case .confirmingTopic:
                return .confirmTopic
            case .showingOutline:
                return .startCourse
            default:
                break
            }
        }
        
        // Check for level selection
        if case .selectingLevel = wizardStep {
            if message.contains("beginner") || message.contains("basic") || message.contains("start") {
                return .selectLevel("beginner")
            } else if message.contains("intermediate") || message.contains("medium") {
                return .selectLevel("intermediate")
            } else if message.contains("advanced") || message.contains("expert") {
                return .selectLevel("advanced")
            }
        }
        
        // Check for cancellation
        if ["cancel", "stop", "nevermind", "never mind", "no thanks", "exit", "quit"].contains(where: { message.contains($0) }) {
            return .cancel
        }
        
        // Check for edit requests
        if message.contains("change") || message.contains("edit") || message.contains("modify") || message.contains("different") {
            return .editOutline(message)
        }
        
        return nil
    }
    
    // MARK: - Reset Wizard
    
    func resetWizard() {
        wizardStep = .inactive
        pendingTopic = nil
    }
    
    func startWizard(topic: String) {
        pendingTopic = topic
        wizardStep = .confirmingTopic(topic: topic)
    }
}
