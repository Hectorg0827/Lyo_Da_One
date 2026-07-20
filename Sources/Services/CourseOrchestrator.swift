//
//  CourseOrchestrator.swift
//  Lyo
//
//  Optimistic Course Orchestrator
//

import Foundation
import Combine
import SwiftUI
import os

/// Orchestrates the course creation flow.
/// Ensures 0% failure rate by using caching and template fallbacks.
@MainActor
final class CourseOrchestrator: ObservableObject {
    static let shared = CourseOrchestrator()
    
    @Published var isProcessing = false
    @Published var activeCourseId: String?
    @Published var showClassroom = false // Triggers navigation
    
    private let cinemaService = InteractiveCinemaService.shared
    
    private init() {}
    
    /// The Main Entry Point for Course Creation
    func execute(proposal: CoursePayload) async {
        isProcessing = true
        
        // 1. Immediate UI Feedback
        Log.classroom.info("🎬 Orchestrator: Starting cinematic sequence for '\(proposal.title)'")
        
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

                // Hydrate the UI source-of-truth with real AI content (replaces the stub set in saveToCache).
                // LiveClassroomViewModel observes CourseGenerationService.shared.generatedCourse,
                // so without this swap the classroom keeps rendering the welcome/overview/quiz placeholders.
                let realGenerated = A2ACourseService.shared.convertToLegacyFormat(generatedCourse)
                await MainActor.run {
                    CourseGenerationService.shared.generatedCourse = realGenerated
                }

                // Hot-swap the content
                NotificationCenter.default.post(name: .courseDataUpdated, object: nil, userInfo: ["id": realCourse.id])

                Log.classroom.info("Orchestrator: Real A2A content ready for \(realCourse.title) — \(realGenerated.modules.count) modules hydrated")
                
            } catch {
                Log.classroom.warning("Orchestrator: A2A generation failed: \(error.localizedDescription), falling back to template content.")
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
        let welcome = ProgressiveLesson(
            id: entryLessonId,
            title: "Welcome",
            content: "Welcome! Your personalized course is being prepared. We'll start with a quick orientation.",
            summary: nil,
            miniPractice: nil
        )
        let overview = ProgressiveLesson(
            id: "overview_1",
            title: "Course Overview",
            content: "In this short course you'll learn the fundamentals, complete practice tasks, and try a quick quiz to check progress.",
            summary: nil,
            miniPractice: nil
        )

        // Core content (video + practice)
        let video = ProgressiveLesson(
            id: "video_1",
            title: "Short Explainer Video",
            content: "(Video) Watch this 90-second explainer to get the key ideas.",
            summary: nil,
            miniPractice: nil
        )
        let practice = ProgressiveLesson(
            id: "practice_1",
            title: "Quick Practice",
            content: "Try the interactive exercise: identify the main concept from three examples.",
            summary: nil,
            miniPractice: nil
        )

        // Assessment
        let quiz = ProgressiveLesson(
            id: "quiz_1",
            title: "Quick Quiz",
            content: "A short 3-question quiz to check understanding.",
            summary: nil,
            miniPractice: nil
        )

        let welcomeModule = ProgressiveModule(
            id: "m_welcome",
            index: 1,
            state: .ready,
            title: "Welcome & Orientation",
            lessons: [welcome, overview],
            summary: course.description
        )

        let coreModule = ProgressiveModule(
            id: "m_core",
            index: 2,
            state: .ready,
            title: "Core Concepts",
            lessons: [video, practice],
            summary: "Core learning material"
        )

        let assessmentModule = ProgressiveModule(
            id: "m_assess",
            index: 3,
            state: .ready,
            title: "Assessment",
            lessons: [quiz],
            summary: "Check what you've learned"
        )

        let progressiveModules = [welcomeModule, coreModule, assessmentModule]
        let stubGenerated = GeneratedCourseResponse(
            courseId: course.id,
            title: course.title,
            description: course.description,
            modules: progressiveModules.enumerated().map { moduleIndex, module in
                GenerationCourseModule(
                    id: module.id,
                    title: module.title,
                    description: module.summary ?? module.title,
                    lessons: (module.lessons ?? []).enumerated().map { lessonIndex, lesson in
                        GenerationCourseLesson(
                            id: lesson.id,
                            title: lesson.title ?? "Lesson \(lessonIndex + 1)",
                            content: lesson.content ?? lesson.summary ?? "",
                            durationMinutes: 10,
                            order: lessonIndex
                        )
                    },
                    order: moduleIndex
                )
            },
            estimatedDuration: 30,
            difficulty: "beginner"
        )

        Task { @MainActor in
            CourseGenerationService.shared.generatedCourse = stubGenerated
            Log.classroom.info("CourseOrchestrator: populated richer GeneratedCourse stub for \(course.id) with \(stubGenerated.modules.count) modules")
        }
    }
}

extension Notification.Name {
    static let courseDataUpdated = Notification.Name("courseDataUpdated")
}
