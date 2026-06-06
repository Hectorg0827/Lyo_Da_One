//
//  LyoRuntimeModels.swift
//  Lyo
//
//  Defines the Runtime State for the "AI Learning OS".
//  Tracks strictly where the user is and what they have accomplished.
//

import Foundation

// MARK: - Runtime Session (The Pointer)

public struct LyoRuntimeSession: Codable, Equatable {
    public let courseId: String
    public var currentModuleId: String
    public var currentLessonId: String
    public var currentArtifactId: String
    public var startTime: Date
    public var lastActiveTime: Date
    
    // Using IDs instead of indices for resilience against course structure updates (AI regeneration)
}

// MARK: - Runtime Progress (The Ledger)

public struct LyoRuntimeProgress: Codable {
    public let courseId: String
    
    // Artifact Completion: [ArtifactID: Score/Metadata]
    public var completedArtifacts: [String: ArtifactResult]
    
    // calculated progress
    public var completedArtifactCount: Int { completedArtifacts.count }
    
    public init(courseId: String) {
        self.courseId = courseId
        self.completedArtifacts = [:]
    }
}

public struct ArtifactResult: Codable {
    public let artifactId: String
    public let completedAt: Date
    public let timeSpentSeconds: TimeInterval
    public let score: Double? // 0.0 to 1.0 (nil for non-scored items like Text)
    public let interactionData: [String: String]? // e.g. quiz answers
}

// MARK: - Navigation Events

public enum RuntimeNavigationEvent {
    case next
    case previous
    case jumpTo(moduleId: String, lessonId: String, artifactId: String)
    case completedCourse
}
