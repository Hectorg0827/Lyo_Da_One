import Foundation

// MARK: - Legacy Course Generation Models (Backward Compatibility)
//
// These types were previously defined in CourseGenerationService.swift.
// They are still referenced by A2ACourseService, InteractiveCinemaService,
// CourseOrchestrator, CourseGenerationIntermediateView, and LiveClassroomViewModel.
//
// The new progressive system uses GeneratedCourse / CourseModule / CourseLesson
// from ProgressiveCourseModels.swift. These legacy types bridge the old consumers.

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
