//
//  AICommandHandler.swift
//  Lyo
//
//  Handles structured AI commands and triggers appropriate app actions
//

import Foundation
import SwiftUI

// MARK: - AI Command Handler
/// Handles structured AI commands and triggers appropriate app actions

@MainActor
class AICommandHandler: ObservableObject {
    static let shared = AICommandHandler()
    
    // MARK: - Published State for Navigation
    @Published var pendingClassroomCourse: CoursePayload?
    @Published var pendingStackItem: StackItemPayload?
    @Published var shouldOpenClassroom: Bool = false
    
    /// Shared AppUIState to coordinate navigation
    var uiState: AppUIState?
    
    private init() {}
    
    // MARK: - Process AI Response
    
    /// Process an AI response and return displayable text (or trigger navigation)
    /// Returns: Text to display in chat (empty if command was handled)
    func processResponse(_ responseText: String) -> (displayText: String, wasCommand: Bool) {
        let parsed = AICommandParser.parse(responseText)
        
        switch parsed {
        case .chat(let text):
            return (text, false)
            
        case .command(let command):
            return handleCommand(command)
        }
    }
    
    // MARK: - Handle Commands
    
    private func handleCommand(_ command: AICommandResponse) -> (displayText: String, wasCommand: Bool) {
        switch command.type {
        case .openClassroom:
            return handleOpenClassroom(command.payload)
            
        case .showQuiz:
            // TODO: Handle quiz command
            return ("Let's start a quiz!", true)
            
        case .addToStack:
            return handleAddToStack(command.payload)
            
        case .normalChat:
            // Shouldn't happen, but handle gracefully
            return ("", false)
        }
    }
    
    public func handleOpenClassroom(_ payload: AICommandPayload?) -> (displayText: String, wasCommand: Bool) {
        guard let course = payload?.course else {
            print("⚠️ OPEN_CLASSROOM command missing course payload")
            return ("I'd love to create a course for you! Could you tell me what topic you'd like to learn?", false)
        }
        
        print("🎓 Opening AI Classroom for: \(course.title)")
        
        // 1. Set navigation state
        self.pendingClassroomCourse = course
        
        // 2. Use the CourseOrchestrator for robust, optimistic creation
        Task {
            await CourseOrchestrator.shared.execute(proposal: course)
        }
        
        // 3. Trigger navigation
        self.shouldOpenClassroom = true
        
        // 4. Also add to stack if provided
        if let stackItem = payload?.stackItem {
            Task {
                await addToStack(stackItem, course: course)
            }
        }
        
        // Return confirmation message
        let confirmationMessage = """
        🎓 Fantastic! I'm weaving together your **\(course.title)** course right now.
        
        **Curriculum:**
        \(course.objectives.prefix(3).map { "• \($0)" }.joined(separator: "\n"))
        
        Opening the classroom...
        """
        
        return (confirmationMessage, true)
    }
    
    private func handleAddToStack(_ payload: AICommandPayload?) -> (displayText: String, wasCommand: Bool) {
        guard let stackItem = payload?.stackItem else {
            return ("I'll add that to your stack!", true)
        }
        
        Task {
            await addToStack(stackItem, course: payload?.course)
        }
        
        return ("✅ Added **\(stackItem.title)** to your Stack!", true)
    }
    
    // MARK: - Stack Integration
    
    private func addToStack(_ item: StackItemPayload, course: CoursePayload?) async {
        do {
            // Map the payload category to a StackItemType
            let itemType: StackItemType
            switch item.category.lowercased() {
            case "course": itemType = .course
            case "lesson": itemType = .lesson
            case "event": itemType = .event
            default: itemType = .course
            }
            
            // Build context data from course info if available
            var contextData: [String: String] = [
                "title": item.title,
                "subtitle": item.subtitle,
                "status": item.status
            ]
            
            if let due = item.due {
                contextData["due"] = due
            }
            
            if let courseInfo = course {
                contextData["topic"] = courseInfo.topic
                contextData["level"] = courseInfo.level
                contextData["duration"] = courseInfo.duration
            }
            
            let request = CreateStackItemRequest(
                type: itemType,
                refId: item.title, // Using title as refId for now
                tags: course.map { [$0.topic, $0.level] } ?? [],
                contextData: contextData
            )
            
            let _ = try await LyoRepository.shared.createStackItem(request: request)
            print("✅ Added to Stack: \(item.title)")
            
        } catch {
            print("⚠️ Failed to add to stack: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reset State
    
    func clearPendingNavigation() {
        pendingClassroomCourse = nil
        pendingStackItem = nil
        shouldOpenClassroom = false
    }
}

