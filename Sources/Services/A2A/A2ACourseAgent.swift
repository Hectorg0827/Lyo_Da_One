//
//  A2ACourseAgent.swift
//  Lyo
//
//  A2A Protocol wrapper for course generation
//

import Foundation
import os

@MainActor
final class A2ACourseAgent {
    static let shared = A2ACourseAgent()
    
    private let taskManager = A2ATaskManager.shared
    private let agentCardService = AgentCardService.shared
    
    // Default to Lyo's own backend as the course agent
    private var courseAgentURL: String { AppConfig.baseURL }
    
    private init() {}
    
    // MARK: - Generate Course via A2A
    
    /// Generate a course using A2A protocol (enables multi-agent collaboration)
    func generateCourse(
        topic: String,
        level: String = "beginner",
        objectives: [String],
        onProgress: @escaping (String, Double) -> Void,
        onComplete: @escaping (Result<GeneratedCourseResponse, Error>) -> Void
    ) async {
        do {
            // 1. Discover the agent's capabilities
            let agentCard = try await agentCardService.discoverAgent(at: courseAgentURL)
            
            // 2. Verify course_generation skill exists
            guard agentCard.skills.contains(where: { $0.id == "course_generation" }) else {
                throw A2ATaskError.skillNotSupported("course_generation")
            }
            
            onProgress("Connecting to course agent...", 0.1)
            
            // 3. Build the A2A message
            let courseRequest: [String: Any] = [
                "skill": "course_generation",
                "topic": topic,
                "level": level,
                "objectives": objectives
            ]
            
            let message = """
            Generate a learning course with these parameters:
            \(try JSONSerialization.data(withJSONObject: courseRequest).base64EncodedString())
            """
            
            // 4. Stream the task
            try await taskManager.streamTask(
                to: courseAgentURL,
                message: message,
                onUpdate: { response in
                    let progress: Double
                    let status: String
                    
                    switch response.state {
                    case .submitted:
                        progress = 0.2
                        status = "Task submitted..."
                    case .working:
                        progress = 0.5
                        status = "Generating course structure..."
                    case .inputRequired:
                        progress = 0.6
                        status = "Agent needs input..."
                    case .completed:
                        progress = 1.0
                        status = "Course ready!"
                    case .failed:
                        progress = 0
                        status = "Generation failed"
                    default:
                        progress = 0.3
                        status = "Processing..."
                    }
                    
                    onProgress(status, progress)
                },
                onArtifact: { artifact in
                    Log.ai.info("Received artifact: \(artifact.name)")
                },
                onComplete: { task in
                    // Parse the completed task artifacts into a course
                    if task.state == .completed, let artifacts = task.artifacts {
                        do {
                            let course = try self.parseCourseFromArtifacts(artifacts, topic: topic)
                            onComplete(.success(course))
                        } catch {
                            onComplete(.failure(error))
                        }
                    } else {
                        onComplete(.failure(A2ATaskError.taskFailed("Course generation incomplete")))
                    }
                }
            )
            
        } catch {
            onComplete(.failure(error))
        }
    }
    
    // MARK: - Parse Course from A2A Artifacts
    
    private func parseCourseFromArtifacts(_ artifacts: [A2ATaskArtifact], topic: String) throws -> GeneratedCourseResponse {
        // Find the course artifact
        guard let courseArtifact = artifacts.first(where: { $0.name == "course" || $0.name == "generated_course" }) else {
            throw A2ATaskError.invalidResponse
        }
        
        // Extract JSON data from artifact parts
        for part in courseArtifact.parts {
            if part.type == "data", let data = part.data {
                // Convert AnyCodableValue dict to JSON
                let jsonData = try JSONSerialization.data(withJSONObject: AnyCodable.sanitizeForJSON(data.mapValues { $0.value }))
                return try JSONDecoder().decode(GeneratedCourseResponse.self, from: jsonData)
            }
            
            if part.type == "text", let text = part.text {
                // Try parsing as JSON string
                if let jsonData = text.data(using: .utf8) {
                    return try JSONDecoder().decode(GeneratedCourseResponse.self, from: jsonData)
                }
            }
        }
        
        throw A2ATaskError.invalidResponse
    }
    
    // MARK: - Collaborate with External Agent
    
    /// Send a sub-task to an external A2A agent (e.g., quiz generation specialist)
    func collaborateWithAgent(
        agentURL: String,
        skill: String,
        input: String
    ) async throws -> A2ATaskResponse {
        // Discover and verify the external agent
        let agentCard = try await agentCardService.discoverAgent(at: agentURL)
        
        guard agentCard.skills.contains(where: { $0.id == skill }) else {
            throw A2ATaskError.skillNotSupported(skill)
        }
        
        // Send the task
        return try await taskManager.sendTask(
            to: agentURL,
            message: input,
            skill: skill
        )
    }
}
