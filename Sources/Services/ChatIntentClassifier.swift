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
    
    // MARK: - Classify Intent
    
    func classifyIntent(_ message: String) -> UserIntent {
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If we're in a wizard flow, check for wizard actions first
        if wizardStep != .inactive {
            if let action = parseWizardAction(lowercased) {
                return .courseWizardContinue(action: action)
            }
        }
        
        // 🎯 LYO BULLETPROOF FLOW: 
        // We no longer perform local intent detection for course creation.
        // All messages are sent to the backend, and the backend dictates the intent.
        
        // Default to general chat
        return .generalChat(message: message)
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
