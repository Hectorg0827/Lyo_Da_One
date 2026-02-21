//
//  A2ATaskManager.swift
//  Lyo
//
//  Google A2A Protocol - Task Management
//

import Foundation
import os

// MARK: - A2A Task Models (Google A2A Spec)

enum A2ATaskState: String, Codable {
    case submitted
    case working
    case inputRequired = "input-required"
    case completed
    case canceled
    case failed
    case unknown
}

struct A2ATask: Codable, Identifiable {
    let id: String
    let sessionId: String?
    var state: A2ATaskState
    let message: A2AMessage
    var artifacts: [A2ATaskArtifact]?
    var history: [A2AMessage]?
    var metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "sessionId"
        case state
        case message
        case artifacts
        case history
        case metadata
    }
}

struct A2AMessage: Codable {
    let role: String  // "user" or "agent"
    let parts: [A2APart]
}

struct A2APart: Codable {
    let type: String  // "text", "file", "data"
    let text: String?
    let file: A2AFile?
    let data: [String: AnyCodableValue]?
}

struct A2AFile: Codable {
    let name: String
    let mimeType: String
    let bytes: String?  // Base64 encoded
    let uri: String?
}

// Note: This is different from A2AArtifact in A2AModels.swift (used for course generation)
// This version is for the A2A task protocol
struct A2ATaskArtifact: Codable {
    let name: String
    let description: String?
    let parts: [A2APart]
    let index: Int?
    let append: Bool?
    let lastChunk: Bool?
}

// MARK: - A2A Request/Response

struct A2ATaskRequest: Codable {
    let id: String?
    let sessionId: String?
    let message: A2AMessage
    let acceptedOutputModes: [String]?
    let pushNotification: A2APushConfig?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "sessionId"
        case message
        case acceptedOutputModes = "acceptedOutputModes"
        case pushNotification = "pushNotification"
    }
}

struct A2APushConfig: Codable {
    let url: String
    let authentication: A2AAuthentication?
}

struct A2ATaskResponse: Codable {
    let id: String
    let sessionId: String?
    let state: A2ATaskState
    let message: A2AMessage?
    let artifacts: [A2ATaskArtifact]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "sessionId"
        case state
        case message
        case artifacts
    }
}

// MARK: - A2A Task Manager

@MainActor
final class A2ATaskManager: ObservableObject {
    static let shared = A2ATaskManager()
    
    @Published internal(set) var activeTasks: [String: A2ATask] = [:]
    @Published private(set) var isProcessing = false
    
    private var currentSessionId: String?
    
    private init() {
        currentSessionId = UUID().uuidString
    }
    
    // MARK: - Send Task to Agent
    
    /// Send a task to an A2A-compatible agent
    func sendTask(
        to agentURL: String,
        message: String,
        skill: String? = nil,
        acceptedOutputModes: [String] = ["text", "application/json"]
    ) async throws -> A2ATaskResponse {
        isProcessing = true
        defer { isProcessing = false }
        
        let taskId = UUID().uuidString
        let request = A2ATaskRequest(
            id: taskId,
            sessionId: currentSessionId,
            message: A2AMessage(
                role: "user",
                parts: [A2APart(type: "text", text: message, file: nil, data: nil)]
            ),
            acceptedOutputModes: acceptedOutputModes,
            pushNotification: nil
        )
        
        let endpoint = DynamicEndpoint(
            urlString: "\(agentURL)/tasks/send",
            method: .post,
            body: request,
            requiresAuth: true
        )
        
        let response: A2ATaskResponse = try await NetworkClient.shared.request(endpoint)
        
        // Track the task
        let task = A2ATask(
            id: response.id,
            sessionId: response.sessionId,
            state: response.state,
            message: request.message,
            artifacts: response.artifacts,
            history: nil,
            metadata: skill != nil ? ["skill": skill!] : nil
        )
        activeTasks[response.id] = task
        
        Log.ai.info("📤 A2A Task sent: \(response.id) - State: \(String(describing: response.state))")
        
        return response
    }
    
    // MARK: - Stream Task (SSE)
    
    /// Send a task and stream the response via SSE
    func streamTask(
        to agentURL: String,
        message: String,
        onUpdate: @escaping (A2ATaskResponse) -> Void,
        onArtifact: @escaping (A2ATaskArtifact) -> Void,
        onComplete: @escaping (A2ATask) -> Void
    ) async throws {
        isProcessing = true
        
        let taskId = UUID().uuidString
        let request = A2ATaskRequest(
            id: taskId,
            sessionId: currentSessionId,
            message: A2AMessage(
                role: "user",
                parts: [A2APart(type: "text", text: message, file: nil, data: nil)]
            ),
            acceptedOutputModes: ["text", "application/json"],
            pushNotification: nil
        )
        
        let endpoint = DynamicEndpoint(
            urlString: "\(agentURL)/tasks/sendSubscribe",
            method: .post,
            body: request,
            requiresAuth: true
        )
        
        var currentTask = A2ATask(
            id: taskId,
            sessionId: currentSessionId,
            state: .submitted,
            message: request.message,
            artifacts: [],
            history: nil,
            metadata: nil
        )
        activeTasks[taskId] = currentTask
        
        do {
            let (bytes, response) = try await NetworkClient.shared.stream(endpoint)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw A2ATaskError.invalidResponse
            }
            
            try await parseTaskStream(
                bytes.lines,
                taskId: taskId,
                onUpdate: onUpdate,
                onArtifact: onArtifact,
                onComplete: onComplete
            )
            
        } catch {
            isProcessing = false
            currentTask.state = .failed
            activeTasks[taskId] = currentTask
            throw error
        }
    }
    
    /// Generic parsing method for both network strings and test streams
    func parseTaskStream<S: AsyncSequence>(
        _ stream: S,
        taskId: String,
        onUpdate: @escaping (A2ATaskResponse) -> Void,
        onArtifact: @escaping (A2ATaskArtifact) -> Void,
        onComplete: @escaping (A2ATask) -> Void
    ) async throws where S.Element == String {
         var currentTask = activeTasks[taskId] ?? A2ATask(id: taskId, sessionId: currentSessionId, state: .submitted, message: A2AMessage(role: "user", parts: []), artifacts: [], history: nil, metadata: nil)

        for try await line in stream {
            guard line.hasPrefix("data: ") else { continue }
            
            let jsonStr = String(line.dropFirst(6))
            guard let jsonData = jsonStr.data(using: .utf8) else { continue }
            
            // Parse SSE event
            if let event = try? JSONDecoder().decode(A2ASSEEvent.self, from: jsonData) {
                switch event.type {
                case "task":
                    if let taskUpdate = event.task {
                        currentTask.state = taskUpdate.state
                        activeTasks[taskId] = currentTask
                        
                        let response = A2ATaskResponse(
                            id: taskId,
                            sessionId: currentSessionId,
                            state: taskUpdate.state,
                            message: taskUpdate.message,
                            artifacts: nil
                        )
                        onUpdate(response)
                    }
                    
                case "artifact":
                    if let artifact = event.artifact {
                        currentTask.artifacts = (currentTask.artifacts ?? []) + [artifact]
                        activeTasks[taskId] = currentTask
                        onArtifact(artifact)
                    }
                    
                default:
                    break
                }
                
                // Check for completion
                if currentTask.state == .completed || currentTask.state == .failed {
                    isProcessing = false
                    onComplete(currentTask)
                    return
                }
            }
        }
    }

    // MARK: - Get Task Status
    
    func getTaskStatus(taskId: String, agentURL: String) async throws -> A2ATask {
        let endpoint = DynamicEndpoint(
            urlString: "\(agentURL)/tasks/\(taskId)",
            method: .get,
            requiresAuth: true
        )
        
        let response: A2ATaskResponse = try await NetworkClient.shared.request(endpoint)
        
        if var task = activeTasks[taskId] {
            task.state = response.state
            task.artifacts = response.artifacts
            activeTasks[taskId] = task
            return task
        }
        
        return A2ATask(
            id: response.id,
            sessionId: response.sessionId,
            state: response.state,
            message: response.message ?? A2AMessage(role: "agent", parts: []),
            artifacts: response.artifacts,
            history: nil,
            metadata: nil
        )
    }
    
    // MARK: - Cancel Task
    
    func cancelTask(taskId: String, agentURL: String) async throws {
        let endpoint = DynamicEndpoint(
            urlString: "\(agentURL)/tasks/\(taskId)/cancel",
            method: .post,
            requiresAuth: true
        )
        
        let _: A2ATaskResponse = try await NetworkClient.shared.request(endpoint)
        
        if var task = activeTasks[taskId] {
            task.state = .canceled
            activeTasks[taskId] = task
        }
        
        Log.ai.info("🚫 A2A Task canceled: \(taskId)")
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        currentSessionId = UUID().uuidString
        activeTasks.removeAll()
        Log.ai.info("New A2A session: \(self.currentSessionId ?? "nil")")
    }
    
    func getCurrentSessionId() -> String? {
        return currentSessionId
    }
}

// MARK: - SSE Event Structure

struct A2ASSEEvent: Codable {
    let type: String  // "task", "artifact"
    let task: A2ATaskUpdate?
    let artifact: A2ATaskArtifact?
}

struct A2ATaskUpdate: Codable {
    let state: A2ATaskState
    let message: A2AMessage?
}

// MARK: - A2A Task Errors
// Note: A2AError is defined in A2ACourseService.swift, so we name this one differently
enum A2ATaskError: LocalizedError {
    case agentNotFound
    case skillNotSupported(String)
    case invalidResponse
    case taskFailed(String)
    case streamingError
    
    var errorDescription: String? {
        switch self {
        case .agentNotFound:
            return "Agent not found or unreachable"
        case .skillNotSupported(let skill):
            return "Agent does not support skill: \(skill)"
        case .invalidResponse:
            return "Invalid response from agent"
        case .taskFailed(let reason):
            return "Task failed: \(reason)"
        case .streamingError:
            return "Streaming connection error"
        }
    }
}

// MARK: - A2AAnyCodableValue for dynamic data

struct A2AAnyCodableValue: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([A2AAnyCodableValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: A2AAnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { A2AAnyCodableValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { A2AAnyCodableValue($0) })
        default:
            try container.encodeNil()
        }
    }
}
