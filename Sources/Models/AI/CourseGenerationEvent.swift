//
//  CourseGenerationEvent.swift
//  Lyo
//
//  Streaming event models for real-time course generation progress
//

import Foundation

// MARK: - Event Type

/// Types of events emitted during course generation streaming
enum CourseGenerationEventType: String, Codable {
    case started
    case agentWorking = "agent_working"
    case lessonComplete = "lesson_complete"
    case progress
    case costUpdate = "cost_update"
    case artifactCreated = "artifact_created" // 🌊 NEW
    case completed
    case error
}

// MARK: - Course Generation Event

/// Event emitted during streaming course generation
struct CourseGenerationEvent: Codable {
    let type: CourseGenerationEventType
    let message: String
    let progress: Int  // 0-100
    let data: CourseGenerationEventData?
    
    enum CodingKeys: String, CodingKey {
        case type
        case message
        case progress
        case data
    }
}

// MARK: - Event Data

/// Additional data attached to streaming events
struct CourseGenerationEventData: Codable {
    let agent: String?
    let step: String?
    let completed: Int?
    let total: Int?
    let courseId: String?
    let cost: Double?
    let error: String?
    let timestamp: String?
    let artifact: LyoArtifact? // 🌊 NEW: Streamed content block
    
    enum CodingKeys: String, CodingKey {
        case agent
        case step
        case completed
        case total
        case courseId = "course_id"
        case cost
        case error
        case timestamp
        case artifact
    }
}

// MARK: - Streaming State

/// State of the streaming connection
enum StreamingState: Equatable {
    case idle
    case connecting
    case streaming
    case completed
    case failed(Error)
    case cancelled
    
    var isActive: Bool {
        switch self {
        case .streaming, .connecting:
            return true
        default:
            return false
        }
    }
    
    // Equatable conformance
    static func == (lhs: StreamingState, rhs: StreamingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.connecting, .connecting):
            return true
        case (.streaming, .streaming):
            return true
        case (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}

// MARK: - Lesson Generation State

/// Per-lesson generation state for progressive UI (shimmer → title → content)
enum LessonGenerationState: Equatable {
    /// Lesson slot reserved but no content yet — show shimmer placeholder
    case pending
    /// Currently being generated — show title + spinner
    case generating(title: String, progress: Int)
    /// Fully generated — show complete content
    case ready
    /// Generation failed — show retry option
    case failed(message: String)
    
    var isPending: Bool {
        if case .pending = self { return true }
        return false
    }
    
    var isGenerating: Bool {
        if case .generating = self { return true }
        return false
    }
    
    static func == (lhs: LessonGenerationState, rhs: LessonGenerationState) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (.generating(let a, let b), .generating(let c, let d)): return a == c && b == d
        case (.ready, .ready): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}
