//
//  CourseModels.swift
//  Lyo
//
//  Shared course creation and A2UI content models used across the app.
//

import Foundation

// MARK: - Course Creation Data (A2UI Protocol)
/// Data structure for AI-generated course proposals that can be displayed in chat
struct CourseCreationData: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let topic: String
    let level: String
    let modules: [CourseModuleData]
    
    init(id: String = UUID().uuidString, title: String, topic: String, level: String, modules: [CourseModuleData]) {
        self.id = id
        self.title = title
        self.topic = topic
        self.level = level
        self.modules = modules
    }
}

struct CourseModuleData: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let lessons: [CourseLessonData]
    
    init(id: String = UUID().uuidString, title: String, description: String, lessons: [CourseLessonData] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.lessons = lessons
    }
}

struct CourseLessonData: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let duration: String
    
    init(id: String = UUID().uuidString, title: String, duration: String = "10 min") {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

// NOTE: CardAction and TopicOption are defined in MultimodalMessage.swift
// Do not duplicate them here to avoid ambiguous type errors

// MARK: - OPEN_CLASSROOM Command (A2UI Protocol)
/// JSON command structure for triggering classroom navigation from AI responses
struct OpenClassroomCommand: Codable {
    let type: String
    let payload: OpenClassroomPayload
    
    /// Convenience accessor for course data
    var course: CoursePayload { payload.course }
    /// Convenience accessor for stack item data (optional)
    var stackItem: StackItemPayload? { payload.stackItem }
    
    struct OpenClassroomPayload: Codable {
        let stackItem: StackItemPayload?  // Optional - backend may not include it
        let course: CoursePayload
        
        enum CodingKeys: String, CodingKey {
            case stackItem = "stack_item"
            case course
        }
    }
    
    struct StackItemPayload: Codable {
        let category: String
        let title: String
        let subtitle: String
        let status: String
    }
    
    struct CoursePayload: Codable {
        let title: String
        let topic: String
        let level: String
        let language: String?
        let duration: String?
        let objectives: [String]
    }
    
    /// Convert to CourseCreationData for display
    func toCourseCreationData() -> CourseCreationData {
        CourseCreationData(
            title: payload.course.title,
            topic: payload.course.topic,
            level: payload.course.level,
            modules: payload.course.objectives.enumerated().map { index, objective in
                CourseModuleData(
                    id: "mod_\(index + 1)",
                    title: "Module \(index + 1)",
                    description: objective
                )
            }
        )
    }
}
