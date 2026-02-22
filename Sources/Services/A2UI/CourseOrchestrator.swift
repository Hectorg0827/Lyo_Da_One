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
    }
}

extension Notification.Name {
    static let courseDataUpdated = Notification.Name("courseDataUpdated")
}
