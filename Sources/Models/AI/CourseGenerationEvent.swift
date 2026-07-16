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
