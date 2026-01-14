//
//  A2ACourseService.swift
//  Lyo
//
//  Service for Google A2A Protocol course generation
//  Handles streaming, polling, and agent discovery
//

import Foundation

// MARK: - A2A Course Service

@MainActor
final class A2ACourseService: ObservableObject {
    static let shared = A2ACourseService()
    
    // MARK: - Published State
    
    @Published var isGenerating: Bool = false
    @Published var currentPhase: A2APipelinePhase?
    @Published var progress: Int = 0
    @Published var phases: [A2APhaseProgress] = []
    @Published var streamingEvents: [A2AStreamingEvent] = []
    @Published var generatedCourse: A2AGeneratedCourse?
    @Published var errorMessage: String?
    @Published var agents: [A2AAgentCard] = []
    
    // Current pipeline tracking
    @Published var currentPipelineId: String?
    @Published var streamingState: StreamingState = .idle
    
    // MARK: - Private
    
    private var streamingTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private let tokenManager = TokenManager.shared
    
    private init() {
        print("🤖 A2ACourseService initialized - Multi-agent pipeline ready")
    }
    
    // MARK: - Agent Discovery
    
    /// Fetch all available A2A agents
    func discoverAgents() async throws -> [A2AAgentCard] {
        print("🔍 Discovering A2A agents...")
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/agents",
            method: .get,
            requiresAuth: true
        )
        
        let response: [A2AAgentCard] = try await NetworkClient.shared.request(endpoint)
        
        await MainActor.run {
            self.agents = response
        }
        
        print("✅ Discovered \(response.count) agents")
        return response
    }
    
    /// Get specific agent card
    func getAgentCard(name: String) async throws -> A2AAgentCard {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/agents/\(name)",
            method: .get,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    /// Fetch A2A protocol discovery document
    func fetchProtocolDiscovery() async throws -> A2AAgentDiscovery {
        let endpoint = DynamicEndpoint(
            urlString: "/.well-known/agent.json",
            method: .get,
            requiresAuth: false
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Course Generation (Streaming)
    
    /// Generate a course using streaming SSE
    func generateCourseStreaming(
        topic: String,
        qualityTier: CourseQualityTier = .standard,
        userContext: [String: String]? = nil,
        enableVisuals: Bool = true,
        enableVoice: Bool = true,
        onEvent: @escaping (A2AStreamingEvent) -> Void
    ) {
        // Cancel any existing generation
        cancelGeneration()
        
        // Reset state
        isGenerating = true
        currentPhase = .initialization
        progress = 0
        phases = []
        streamingEvents = []
        generatedCourse = nil
        errorMessage = nil
        streamingState = .connecting
        
        print("🚀 Starting A2A streaming course generation for: \(topic)")
        
        streamingTask = Task {
            do {
                try await performStreamingGeneration(
                    topic: topic,
                    qualityTier: qualityTier,
                    userContext: userContext,
                    enableVisuals: enableVisuals,
                    enableVoice: enableVoice,
                    onEvent: onEvent
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.streamingState = .failed(error)
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func performStreamingGeneration(
        topic: String,
        qualityTier: CourseQualityTier,
        userContext: [String: String]?,
        enableVisuals: Bool,
        enableVoice: Bool,
        onEvent: @escaping (A2AStreamingEvent) -> Void
    ) async throws {
        
        // Build request
        let request = A2AGenerateRequest(
            topic: topic,
            qualityTier: qualityTier,
            userContext: userContext,
            enableQualityGates: true,
            enableVisuals: enableVisuals,
            enableVoice: enableVoice,
            enableParallel: true
        )
        
        // Encode request body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        
        // Create endpoint
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/stream-a2a",
            method: .post,
            body: DataWrapper(data: bodyData),
            requiresAuth: true
        )
        
        // Start streaming
        let (bytes, response) = try await NetworkClient.shared.stream(endpoint)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw A2AError.serverError(httpResponse.statusCode)
        }
        
        await MainActor.run {
            self.streamingState = .streaming
        }
        
        // Parse SSE stream
        // Use Type Erasure or Generic to allow testing
        try await parseStreamingEvents(bytes.lines, onEvent: onEvent)
        
        // If streaming completed without explicit completion event, fetch final result
        if await streamingState == .streaming {
            await MainActor.run {
                self.streamingState = .completed
                self.isGenerating = false
            }
        }
        
        // Fetch final course if we have a pipeline ID
        if let pipelineId = await currentPipelineId {
            await fetchFinalCourse(pipelineId: pipelineId)
        }
        
        print("✅ A2A streaming completed")
    }
    
    /// Parse SSE events from a line sequence
    /// Generic to support both URLSession.AsyncBytes.Lines and Test Streams
    func parseStreamingEvents<S: AsyncSequence>(
        _ lines: S,
        onEvent: @escaping (A2AStreamingEvent) -> Void
    ) async throws where S.Element == String {
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        for try await line in lines {
            if Task.isCancelled { break }
            
            // SSE format: "data: {json}"
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString.isEmpty || jsonString.hasPrefix(":") {
                    continue
                }
                
                if let data = jsonString.data(using: .utf8) {
                    do {
                        let event = try decoder.decode(A2AStreamingEvent.self, from: data)
                        
                        print("📥 A2A Event: \(event.type.rawValue) - \(event.message ?? "") (\(event.progress)%)")
                        
                        await MainActor.run {
                            self.streamingEvents.append(event)
                            self.progress = event.progress
                            self.currentPipelineId = event.pipelineId
                            
                            if let phase = event.phase {
                                self.currentPhase = phase
                            }
                            
                            // Handle specific event types
                            switch event.type {
                            case .phaseCompleted:
                                if let phase = event.phase {
                                    self.updatePhaseStatus(phase: phase, status: .completed)
                                }
                                
                            case .phaseStarted:
                                if let phase = event.phase {
                                    self.updatePhaseStatus(phase: phase, status: .running)
                                }
                                
                            case .phaseFailed:
                                if let phase = event.phase {
                                    self.updatePhaseStatus(phase: phase, status: .failed)
                                }
                                
                            case .pipelineCompleted:
                                self.streamingState = .completed
                                self.isGenerating = false
                                
                            case .error:
                                self.errorMessage = event.data?.error ?? event.message
                                self.streamingState = .failed(A2AError.pipelineFailed(event.message ?? "Unknown error"))
                                self.isGenerating = false
                                
                            default:
                                break
                            }
                        }
                        
                        // Call event handler
                        onEvent(event)
                        
                        // Break on terminal events
                        if event.type == .pipelineCompleted || event.type == .error {
                            break
                        }
                        
                    } catch {
                        print("⚠️ Failed to decode A2A event: \(error)")
                        // Don't throw, just skip bad frame
                    }
                }
            }
        }
    }
        

    
    // MARK: - Course Generation (Synchronous)
    
    /// Generate a course synchronously (non-streaming)
    func generateCourse(
        topic: String,
        qualityTier: CourseQualityTier = .standard,
        userContext: [String: String]? = nil,
        enableVisuals: Bool = true,
        enableVoice: Bool = true
    ) async throws -> A2AGeneratedCourse {
        
        isGenerating = true
        currentPhase = .initialization
        progress = 0
        errorMessage = nil
        
        defer {
            Task { @MainActor in
                self.isGenerating = false
            }
        }
        
        print("🚀 Starting A2A synchronous course generation for: \(topic)")
        
        let request = A2AGenerateRequest(
            topic: topic,
            qualityTier: qualityTier,
            userContext: userContext,
            enableQualityGates: true,
            enableVisuals: enableVisuals,
            enableVoice: enableVoice,
            enableParallel: true
        )
        
        // Encode request body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/generate-a2a",
            method: .post,
            body: DataWrapper(data: bodyData),
            requiresAuth: true
        )
        
        let response: A2ACourseResponse = try await NetworkClient.shared.request(endpoint)
        
        if let error = response.error {
            throw A2AError.pipelineFailed(error)
        }
        
        guard let course = response.course else {
            throw A2AError.noCourseGenerated
        }
        
        await MainActor.run {
            self.generatedCourse = course
            self.phases = response.phases
            self.currentPipelineId = response.pipelineId
            self.progress = 100
        }
        
        print("✅ A2A course generated: \(course.title)")
        return course
    }
    
    // MARK: - Pipeline Status
    
    /// Poll for pipeline status
    func getPipelineStatus(pipelineId: String) async throws -> A2APipelineStatus {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/status/\(pipelineId)",
            method: .get,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    /// Start polling for pipeline status
    func startPolling(pipelineId: String, interval: TimeInterval = 2.0, onUpdate: @escaping (A2APipelineStatus) -> Void) {
        stopPolling()
        
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    let status = try await getPipelineStatus(pipelineId: pipelineId)
                    
                    await MainActor.run {
                        self.progress = status.progress
                        self.currentPhase = status.currentPhase
                        self.phases = status.phases
                        
                        if let course = status.course {
                            self.generatedCourse = course
                        }
                    }
                    
                    onUpdate(status)
                    
                    // Stop polling if pipeline is done
                    if status.status == "completed" || status.status == "failed" {
                        await MainActor.run {
                            self.isGenerating = false
                        }
                        break
                    }
                    
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    
                } catch {
                    print("⚠️ Polling error: \(error)")
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    // MARK: - Direct Agent Execution
    
    /// Execute a specific agent directly
    func executeAgent(
        name: String,
        taskId: String,
        prompt: String,
        context: [String: String]? = nil,
        artifacts: [String]? = nil
    ) async throws -> A2ATaskOutput {
        
        let taskInput = A2ATaskInput(
            taskId: taskId,
            prompt: prompt,
            context: context,
            artifacts: artifacts
        )
        
        let request = A2AAgentExecuteRequest(taskInput: taskInput)
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/agents/\(name)/execute",
            method: .post,
            body: DataWrapper(data: bodyData),
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Cancellation
    
    func cancelGeneration() {
        streamingTask?.cancel()
        streamingTask = nil
        stopPolling()
        
        if streamingState.isActive {
            streamingState = .cancelled
        }
        isGenerating = false
    }
    
    // MARK: - Private Helpers
    
    private func updatePhaseStatus(phase: A2APipelinePhase, status: A2APhaseStatus) {
        if let index = phases.firstIndex(where: { $0.phase == phase }) {
            // Update existing
            var updated = phases[index]
            phases[index] = A2APhaseProgress(
                phase: updated.phase,
                status: status,
                startedAt: status == .running ? Date() : updated.startedAt,
                completedAt: status == .completed ? Date() : updated.completedAt,
                durationMs: updated.durationMs,
                error: updated.error
            )
        } else {
            // Add new
            phases.append(A2APhaseProgress(
                phase: phase,
                status: status,
                startedAt: status == .running ? Date() : nil,
                completedAt: status == .completed ? Date() : nil,
                durationMs: nil,
                error: nil
            ))
        }
    }
    
    private func fetchFinalCourse(pipelineId: String) async {
        do {
            let status = try await getPipelineStatus(pipelineId: pipelineId)
            
            if let course = status.course {
                await MainActor.run {
                    self.generatedCourse = course
                    self.phases = status.phases
                }
                print("✅ Final course fetched: \(course.title)")
            }
        } catch {
            print("⚠️ Could not fetch final course: \(error)")
        }
    }
}

// MARK: - A2A Errors

enum A2AError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case pipelineFailed(String)
    case noCourseGenerated
    case agentNotFound(String)
    case streamingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from A2A service"
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .pipelineFailed(let message):
            return "Pipeline failed: \(message)"
        case .noCourseGenerated:
            return "No course was generated"
        case .agentNotFound(let name):
            return "Agent not found: \(name)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        }
    }
}

// MARK: - Helper Extension

extension A2ACourseService {
    /// Convert A2A generated course to the existing GeneratedCourseResponse format
    func convertToLegacyFormat(_ a2aCourse: A2AGeneratedCourse) -> GeneratedCourseResponse {
        let modules = a2aCourse.modules.map { module in
            CourseModule(
                id: module.id,
                title: module.title,
                description: module.description,
                lessons: module.lessons.map { lesson in
                    CourseLesson(
                        id: lesson.id,
                        title: lesson.title,
                        content: lesson.content,
                        durationMinutes: lesson.durationMinutes,
                        order: lesson.order
                    )
                },
                order: module.order
            )
        }
        
        return GeneratedCourseResponse(
            courseId: a2aCourse.id,
            title: a2aCourse.title,
            description: a2aCourse.description,
            modules: modules,
            estimatedDuration: a2aCourse.estimatedDuration,
            difficulty: a2aCourse.difficulty
        )
    }
}
