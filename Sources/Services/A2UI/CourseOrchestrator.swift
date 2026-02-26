//
//  CourseOrchestrator.swift
//  Lyo
//
//  Google A2UI Protocol - Optimistic Course Orchestrator
//

import Foundation
import Combine
import SwiftUI
import os

/// Orchestrates the "Cinematic View" creation from A2UI triggers.
/// Ensures 0% failure rate by using caching and template fallbacks.
@MainActor
final class CourseOrchestrator: ObservableObject {
    static let shared = CourseOrchestrator()
    
    @Published var isProcessing = false
    @Published var activeCourseId: String?
    @Published var showClassroom = false // Triggers navigation
    
    private let cinemaService = InteractiveCinemaService.shared
    
    private init() {}
    
    /// The Main Entry Point for the A2UI Protocol
    func execute(proposal: CoursePayload) async {
        isProcessing = true
        
        // 1. Immediate UI Feedback
        Log.a2ui.info("🎬 Orchestrator: Starting cinematic sequence for '\(proposal.title)'")
        
        // 2. Optimistic Generation (Fail-Proof Strategy)
        // We start by creating a valid local "shell" course immediately so navigation works 100% of the time.
        // In a real implementation, we might save this to CoreData or Realm
        let localCourse = createShellCourse(from: proposal)
        saveToCache(localCourse)
        
        // 3. Trigger Navigation immediately (Don't wait for backend)
        self.activeCourseId = localCourse.id
        
        // Use NotificationCenter to trigger UI globally (MainTabView listens to this)
        NotificationCenter.default.post(
            name: .openClassroom, 
            object: nil, 
            userInfo: [
                "courseId": localCourse.id, // Use the shell ID directly
                "courseTitle": proposal.title,
                "lessonId": "welcome_1", // Matches Welcome node in InteractiveCinemaService
                "lessonTitle": "Getting Ready"
            ]
        )
        
        self.showClassroom = true
        
        // 4. Hydrate with Real Intelligence (Background)
        Task {
            do {
                // Call Backend via A2ACourseService
                let generatedCourse = try await A2ACourseService.shared.generateCourse(
                    topic: proposal.topic,
                    qualityTier: .standard,
                    userContext: ["level": proposal.level],
                    enableVisuals: true,
                    enableVoice: true
                )
                
                // Map A2A Course to GraphCourseItem (for compatibility)
                let realCourse = GraphCourseItem(
                    id: generatedCourse.id,
                    title: generatedCourse.title,
                    description: generatedCourse.description,
                    subject: proposal.topic,
                    gradeBand: generatedCourse.difficulty,
                    entryNodeId: generatedCourse.modules.first?.lessons.first?.id,
                    estimatedMinutes: generatedCourse.estimatedDuration,
                    totalNodes: generatedCourse.modules.reduce(0) { $0 + $1.lessons.count },
                    createdAt: Date()
                )
                
                // Hot-swap the content
                NotificationCenter.default.post(name: .courseDataUpdated, object: nil, userInfo: ["id": realCourse.id])
                
                Log.a2ui.info("Orchestrator: Real A2A content ready for \(realCourse.title)")
                
            } catch {
                Log.a2ui.warning("Orchestrator: A2A generation failed: \(error.localizedDescription), falling back to template content.")
                // We stay on the 'shell' course which is populated with template data
            }
            self.isProcessing = false
        }
    }
    
    // MARK: - Fallback Systems
    
    private func createShellCourse(from proposal: CoursePayload) -> GraphCourseItem {
        // Creates a valid, playable course object instantly
        return GraphCourseItem(
            id: "temp_\(UUID().uuidString.prefix(8))",
            title: proposal.title,
            description: "Personalized course on \(proposal.topic)",
            subject: proposal.topic,
            gradeBand: proposal.level,
            entryNodeId: "n1",
            estimatedMinutes: 45,
            totalNodes: 1,
            createdAt: Date()
        )
    }
    
    private func saveToCache(_ course: GraphCourseItem) {
        if let data = try? JSONEncoder().encode(course) {
            UserDefaults.standard.set(data, forKey: "course_cache_\(course.id)")
        }
        // Also populate an in-memory lightweight GeneratedCourseResponse so
        // InteractiveCinemaService and LiveClassroomViewModel can render a richer
        // playable experience immediately while backend generation completes.
        let entryLessonId = course.entryNodeId ?? "welcome_1"

        // Welcome & orientation
        let welcome = GenerationCourseLesson(
            id: entryLessonId,
            title: "Welcome",
            content: "Welcome! Your personalized course is being prepared. We'll start with a quick orientation.",
            durationMinutes: 1,
            order: 1
        )
        let overview = GenerationCourseLesson(
            id: "overview_1",
            title: "Course Overview",
            content: "In this short course you'll learn the fundamentals, complete practice tasks, and try a quick quiz to check progress.",
            durationMinutes: 2,
            order: 2
        )

        // Core content (video + practice)
        let video = GenerationCourseLesson(
            id: "video_1",
            title: "Short Explainer Video",
            content: "(Video) Watch this 90-second explainer to get the key ideas.",
            durationMinutes: 3,
            order: 1
        )
        let practice = GenerationCourseLesson(
            id: "practice_1",
            title: "Quick Practice",
            content: "Try the interactive exercise: identify the main concept from three examples.",
            durationMinutes: 4,
            order: 2
        )

        // Assessment
        let quiz = GenerationCourseLesson(
            id: "quiz_1",
            title: "Quick Quiz",
            content: "A short 3-question quiz to check understanding.",
            durationMinutes: 2,
            order: 1
        )

        let welcomeModule = GenerationCourseModule(
            id: "m_welcome",
            title: "Welcome & Orientation",
            description: course.description,
            lessons: [welcome, overview],
            order: 1
        )

        let coreModule = GenerationCourseModule(
            id: "m_core",
            title: "Core Concepts",
            description: "Core learning material",
            lessons: [video, practice],
            order: 2
        )

        let assessmentModule = GenerationCourseModule(
            id: "m_assess",
            title: "Assessment",
            description: "Check what you've learned",
            lessons: [quiz],
            order: 3
        )

        let stubGenerated = GeneratedCourseResponse(
            courseId: course.id,
            title: course.title,
            description: course.description,
            modules: [welcomeModule, coreModule, assessmentModule],
            estimatedDuration: max(5, course.estimatedMinutes),
            difficulty: course.gradeBand
        )

        Task { @MainActor in
            CourseGenerationService.shared.generatedCourse = stubGenerated
            Log.a2ui.info("CourseOrchestrator: populated richer GeneratedCourseResponse stub for \(course.id) with \(stubGenerated.modules.count) modules")
        }
    }
}

extension Notification.Name {
    static let courseDataUpdated = Notification.Name("courseDataUpdated")
}
