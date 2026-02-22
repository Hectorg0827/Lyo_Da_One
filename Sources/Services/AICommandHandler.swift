//
//  AICommandHandler.swift
//  Lyo
//
//  Handles structured AI commands and triggers appropriate app actions
//

import Foundation
import SwiftUI
import os

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
    
    /// Returns the CoursePayload for rendering as a proposal card in chat.
    /// The user must tap "Start Learning" on the card before actual generation begins.
    public func handleOpenClassroom(_ payload: AICommandPayload?) -> (displayText: String, wasCommand: Bool) {
        guard let course = payload?.course else {
            Log.ai.warning("OPEN_CLASSROOM command missing course payload")
            return ("I'd love to create a course for you! Could you tell me what topic you'd like to learn?", false)
        }
        
        Log.ai.info("📋 Course proposal prepared (not auto-triggering): \(course.title)")
        
        // Store the course + stack item for later execution (when user taps "Start Learning")
        self.pendingClassroomCourse = course
        self.pendingStackItem = payload?.stackItem
        
        // Return empty string with wasCommand = true
        // The caller (UnifiedChatService) will render a CourseProposalCardView instead
        return ("", true)
    }
    
    /// Actually execute course creation + navigation.
    /// Called ONLY when user taps "Start Learning" on the CourseProposalCardView.
    public func executeOpenClassroom(for course: CoursePayload) {
        Log.ai.info("🚀 User approved course — executing: \(course.title)")
        
        // Populate the generated course so LiveClassroomViewModel can find it
        CourseGenerationService.shared.populateGeneratedCourse(from: course)
        
        // Trigger local navigation flag
        self.shouldOpenClassroom = true
        
        // Resolve the actual courseId
        let resolvedCourseId = CourseGenerationService.shared.generatedCourse?.courseId
            ?? course.id
            ?? "gen_\(UUID().uuidString.prefix(6))"
        
        // 1. Dismiss the Lyo overlay first so fullScreenCover can appear
        NotificationCenter.default.post(
            name: .dismissLyoOverlay,
            object: nil
        )
        
        // 2. Post navigation notification after a brief delay for overlay to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(
                name: Notification.Name("openClassroom"),
                object: nil,
                userInfo: [
                    "courseId": resolvedCourseId,
                    "lessonId": "intro_1",
                    "courseTitle": course.title,
                    "lessonTitle": "Introduction"
                ]
            )
        }
        
        // Add to UIStackStore so the course appears in the Stack
        UIStackStore.shared.upsertCourse(
            courseId: resolvedCourseId,
            title: course.title,
            subtitle: "AI Generated Course",
            progress: 0.0
        )
        
        // Also persist to backend stack if stored
        if let stackItem = pendingStackItem {
            Task {
                await addToStack(stackItem, course: course)
            }
        }
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
            Log.ai.info("Added to Stack: \(item.title)")
            
        } catch {
            Log.ai.warning("Failed to add to stack: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reset State
    
    func clearPendingNavigation() {
        pendingClassroomCourse = nil
        pendingStackItem = nil
        shouldOpenClassroom = false
    }
}
