import Foundation

// MARK: - Legacy Course Types (Compatibility Shim)
//
// This file is included in the Xcode target and must preserve the older
// generated-course DTOs still referenced across the app.

struct GeneratedCourseResponse: Codable {
    let courseId: String
    let title: String
    let description: String
    let modules: [GenerationCourseModule]
    let estimatedDuration: Int
    let difficulty: String

    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case title, description, modules
        case estimatedDuration = "estimated_duration"
        case difficulty
    }
}

struct GenerationCourseModule: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let lessons: [GenerationCourseLesson]
    let order: Int
}

struct GenerationCourseLesson: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let durationMinutes: Int
    let order: Int

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case durationMinutes = "duration_minutes"
        case order
    }
}

struct CourseGenerationRequest: Codable {
    let topic: String
    let level: String?
    let learningOutcomes: [String]?
    let teachingStyle: String?
    let difficulty: String?

    enum CodingKeys: String, CodingKey {
        case topic, level, difficulty
        case learningOutcomes = "learning_outcomes"
        case teachingStyle = "teaching_style"
    }
}

// MARK: - BackendCourseResult (nested inside CourseGenerationService for backward compatibility)

extension CourseGenerationService {
    struct BackendCourseResult: Codable {
        let courseId: String
        let title: String
        let description: String
        let modules: [BackendModule]
        let estimatedDuration: Int
        let difficulty: String
        
        struct BackendModule: Codable {
            let id: String
            let title: String
            let description: String
            let lessons: [BackendLesson]
        }
        
        struct BackendLesson: Codable {
            let id: String
            let title: String
            let content: String
            let durationMinutes: Int
            
            enum CodingKeys: String, CodingKey {
                case id, title, content
                case durationMinutes = "duration_minutes"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case courseId = "course_id"
            case title, description, modules
            case estimatedDuration = "estimated_duration"
            case difficulty
        }
    }
}
