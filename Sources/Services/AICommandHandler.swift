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
    
    func handleCommand(_ command: AICommandResponse) -> (displayText: String, wasCommand: Bool) {
        switch command.type {
        case .openClassroom:
            return handleOpenClassroom(command.payload)
            
        case .showQuiz:
            return handleShowQuiz(command.payload)
            
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
        
        // 🔧 FIX: Populate the generated course so LiveClassroomViewModel can find it
        CourseGenerationService.shared.populateGeneratedCourse(from: course)
        
        // Store the course details for navigation
        self.pendingClassroomCourse = course
        self.pendingStackItem = payload?.stackItem
        
        // Trigger local navigation flag
        self.shouldOpenClassroom = true
        
        // Post notification for MainTabView to trigger fullScreenCover
        // Using the central Notification.Name extension if available
        NotificationCenter.default.post(
            name: Notification.Name("openClassroom"),
            object: nil,
            userInfo: [
                "courseId": "GENERATE:\(course.topic)",
                "lessonId": "intro_1",
                "courseTitle": course.title,
                "lessonTitle": "Introduction"
            ]
        )
        
        // Also add to stack if provided
        if let stackItem = payload?.stackItem {
            Task {
                await addToStack(stackItem, course: course)
            }
        }
        
        // Return confirmation message (will be displayed while navigating)
        let confirmationMessage = """
        🎓 Perfect! I'm setting up your **\(course.title)** course now!
        
        **What you'll learn:**
        \(course.objectives.prefix(3).map { "• \($0)" }.joined(separator: "\n"))
        
        Opening the AI Classroom...
        """
        
        return (confirmationMessage, true)
    }
    
    func handleAddToStack(_ payload: AICommandPayload?) -> (displayText: String, wasCommand: Bool) {
        guard let stackItem = payload?.stackItem else {
            return ("I'll add that to your stack!", true)
        }
        
        Task {
            await addToStack(stackItem, course: payload?.course)
        }
        
        return ("✅ Added **\(stackItem.title)** to your Stack!", true)
    }

    func handleShowQuiz(_ payload: AICommandPayload?) -> (displayText: String, wasCommand: Bool) {
        guard let course = payload?.course else {
            // Generic quiz
            NotificationCenter.default.post(
                name: .navigateToQuiz,
                object: nil,
                userInfo: [:]
            )
            return ("🧠 Let's test your knowledge with a quick quiz!", true)
        }

        // Course-specific quiz
        NotificationCenter.default.post(
            name: .navigateToQuiz,
            object: nil,
            userInfo: [
                "courseId": course.topic,
                "courseTitle": course.title
            ]
        )

        let quizMessage = """
        🧠 Great! Let's test your **\(course.title)** knowledge!

        I've prepared some questions to help reinforce what you've learned.

        Opening the quiz...
        """

        return (quizMessage, true)
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
