//
//  LyoCourseRuntime.swift
//  Lyo
//
//  The Engine that plays LyoCourses.
//  Acts as the "Media Player" for the learning journey.
//

import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
public class LyoCourseRuntime: ObservableObject {
    
    // MARK: - Input
    public let course: LyoCourse
    
    // MARK: - Published State
    @Published public var session: LyoRuntimeSession
    @Published public var progress: LyoRuntimeProgress
    
    // The "Current Frame" for the UI to render
    @Published public var activeModule: LyoModule?
    @Published public var activeLesson: LyoLesson?
    @Published public var activeArtifact: LyoArtifact?
    
    // Playback State
    @Published public var isTransitioning: Bool = false
    @Published public var isCourseComplete: Bool = false
    
    // MARK: - Internal Sequence (The Linear Playlist)
    private struct SequenceItem {
        let module: LyoModule
        let lesson: LyoLesson
        let artifact: LyoArtifact
    }
    
    private var sequence: [SequenceItem] = []
    
    // MARK: - Init
    
    public init(course: LyoCourse) {
        self.course = course
        self.progress = LyoRuntimeProgress(courseId: course.id)
        
        // Build the sequence (Flattening the hierarchy)
        var seq: [SequenceItem] = []
        for mod in course.modules {
            for les in mod.lessons {
                for art in les.artifacts {
                    seq.append(SequenceItem(module: mod, lesson: les, artifact: art))
                }
            }
        }
        self.sequence = seq
        
        // Initialize State (Start at first item)
        if let first = seq.first {
            self.session = LyoRuntimeSession(
                courseId: course.id,
                currentModuleId: first.module.id,
                currentLessonId: first.lesson.id,
                currentArtifactId: first.artifact.id,
                startTime: Date(),
                lastActiveTime: Date()
            )
            self.updateActiveObjects(item: first)
        } else {
            // Empty course edge case
            self.session = LyoRuntimeSession(
                courseId: course.id,
                currentModuleId: "",
                currentLessonId: "",
                currentArtifactId: "",
                startTime: Date(),
                lastActiveTime: Date()
            )
        }
    }
    
    // MARK: - Core Navigation
    
    /// User completed the current artifact. Record result and move next.
    public func completeCurrentArtifact(result: ArtifactResult?) {
        // 1. Save Result
        if let res = result, let currentId = activeArtifact?.id {
             progress.completedArtifacts[currentId] = res
        }
        
        // 2. Logic: Should we adapt? (Phase 4 Hook)
        // checkAdaptationTriggers(result)
        
        // 3. Move Next
        moveToNext()
    }
    
    public func moveToNext() {
        guard let currentIndex = sequence.firstIndex(where: { $0.artifact.id == session.currentArtifactId }) else {
            return
        }
        
        let nextIndex = currentIndex + 1
        
        if nextIndex < sequence.count {
            transitionTo(item: sequence[nextIndex])
        } else {
            finishCourse()
        }
    }
    
    public func moveToPrevious() {
        guard let currentIndex = sequence.firstIndex(where: { $0.artifact.id == session.currentArtifactId }) else {
            return
        }
        
        let prevIndex = currentIndex - 1
        
        if prevIndex >= 0 {
            transitionTo(item: sequence[prevIndex])
        }
    }
    
    // MARK: - Internal Logic
    
    private func transitionTo(item: SequenceItem) {
        withAnimation {
            isTransitioning = true
        }
        
        // Update Session Pointer
        session.currentModuleId = item.module.id
        session.currentLessonId = item.lesson.id
        session.currentArtifactId = item.artifact.id
        session.lastActiveTime = Date()
        
        // Brief delay for transition animation if desired
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateActiveObjects(item: item)
            withAnimation {
                self.isTransitioning = false
            }
        }
        
        playHapticFeedback()
    }
    
    private func updateActiveObjects(item: SequenceItem) {
        self.activeModule = item.module
        self.activeLesson = item.lesson
        self.activeArtifact = item.artifact
    }
    
    private func finishCourse() {
        isCourseComplete = true
        // Trigger completion confettis / summary screen
    }
    
    private func playHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
