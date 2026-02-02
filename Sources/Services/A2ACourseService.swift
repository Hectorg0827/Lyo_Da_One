//
//  A2ACourseService.swift
//  Lyo
//
//  Service for Google A2A Protocol course generation
//  Handles streaming, polling, and agent discovery
//

import Foundation
import Combine

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
    
    // MARK: - Course Generation (Polling Based)
    
    /// Start course generation and poll for updates (simulates streaming)
    func generateCourseStreaming(
        topic: String,
        qualityTier: CourseQualityTier = .standard,
        userContext: [String: String]? = nil,
        enableVisuals: Bool = true,
        enableVoice: Bool = true,
        onEvent: @escaping (A2AStreamingEvent) -> Void // Kept for API compatibility, but effectively unused
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
        
        print("🚀 Starting A2A course generation (Polling) for: \(topic)")
        
        Task {
            do {
                let job = try await startJob(
                    topic: topic,
                    qualityTier: qualityTier,
                    userContext: userContext,
                    enableVisuals: enableVisuals,
                    enableVoice: enableVoice
                )
                
                await MainActor.run {
                    self.currentPipelineId = job.jobId
                    self.streamingState = .streaming
                }
                
                // Start polling
                startPolling(jobId: job.jobId) { status in
                    // Map status to events (Optional, if we want to truly mimic SSE)
                    let event = A2AStreamingEvent(
                        type: .phaseProgress,
                        timestamp: Date(),
                        pipelineId: status.jobId,
                        phase: self.currentPhase,
                        progress: status.progressPercent,
                        message: status.currentStep ?? "Processing",
                        data: nil
                    )
                    onEvent(event)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.streamingState = .failed(error)
                    self.isGenerating = false
                }
            }
        }
    }
    
    /// Start the generation job on the backend
    private func startJob(
        topic: String,
        qualityTier: CourseQualityTier,
        userContext: [String: String]?,
        enableVisuals: Bool,
        enableVoice: Bool
    ) async throws -> A2ACourseJobResponse {
        
        let request = A2AGenerateRequest(
            topic: topic,
            qualityTier: qualityTier,
            userContext: userContext,
            enableQualityGates: true,
            enableVisuals: enableVisuals,
            enableVoice: enableVoice,
            enableParallel: true
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/generate",
            method: .post,
            body: DataWrapper(data: bodyData),
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
        

    
    // MARK: - Course Generation (Synchronous)
    
    /// Generate a course synchronously (polls until completion)
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
        
        let job = try await startJob(
            topic: topic,
            qualityTier: qualityTier,
            userContext: userContext,
            enableVisuals: enableVisuals,
            enableVoice: enableVoice
        )
        
        await MainActor.run {
            self.currentPipelineId = job.jobId
        }
        
        // Poll until complete
        var isDone = false
        var finalCourse: A2AGeneratedCourse?
        
        while !isDone {
            if Task.isCancelled { throw A2AError.pipelineFailed("Cancelled") }
            
            let status = try await getPipelineStatus(jobId: job.jobId)
            
            await MainActor.run {
                self.progress = status.progressPercent
                self.mapStatusToPhases(status)
            }
            
            if status.status == "completed" {
                finalCourse = try await fetchFinalCourseResult(jobId: job.jobId)
                await MainActor.run {
                    self.generatedCourse = finalCourse
                    self.streamingState = .completed
                }
                isDone = true
                print("✅ A2A course generated successfully")
                
            } else if status.status == "failed" {
                throw A2AError.pipelineFailed(status.error ?? "Unknown A2A error")
            } else {
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            }
        }
        
        guard let course = finalCourse else {
            throw A2AError.noCourseGenerated
        }
        
        return course
    }
    
    // MARK: - Pipeline Control
    
    /// Cancel the current generation job
    func cancelGeneration() {
        print("🛑 Cancelling generation...")
        isGenerating = false
        streamingTask?.cancel()
        pollingTask?.cancel()
        streamingState = .idle
    }
    
    /// Poll pipeline status
    func startPolling(jobId: String, onUpdate: @escaping (A2AStatusResponse) -> Void) {
        pollingTask?.cancel()
        pollingTask = Task {
            var isFinished = false
            while !isFinished && !Task.isCancelled {
                do {
                    let status = try await getPipelineStatus(jobId: jobId)
                    
                    await MainActor.run {
                        self.progress = status.progressPercent
                        self.mapStatusToPhases(status)
                        onUpdate(status)
                    }
                    
                    if status.status == "completed" {
                        isFinished = true
                        await fetchFinalCourse(jobId: jobId)
                        await MainActor.run {
                            self.streamingState = .completed
                            self.isGenerating = false
                        }
                    } else if status.status == "failed" {
                        isFinished = true
                        await MainActor.run {
                            self.streamingState = .failed(A2AError.pipelineFailed(status.error ?? "Unknown"))
                            self.isGenerating = false
                        }
                    }
                    
                    try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // Poll every 2s
                } catch {
                    print("⚠️ Polling error: \(error)")
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                }
            }
        }
    }
    
    internal func getPipelineStatus(jobId: String) async throws -> A2AStatusResponse {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/\(jobId)/status",
            method: .get,
            requiresAuth: true
        )
        return try await NetworkClient.shared.request(endpoint)
    }
    
    private func mapStatusToPhases(_ status: A2AStatusResponse) {
        // Simple mapping for demo
        // In a real app, 'steps_completed' from backend would map to phases
        if status.currentStep != nil {
            // Update UI if needed
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchFinalCourse(jobId: String) async {
        do {
            let course = try await fetchFinalCourseResult(jobId: jobId)
            
            await MainActor.run {
                self.generatedCourse = course
            }
            print("✅ Final course fetched: \(course.title)")
        } catch {
            print("⚠️ Could not fetch final course: \(error)")
        }
    }
    
    private func fetchFinalCourseResult(jobId: String) async throws -> A2AGeneratedCourse {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/\(jobId)/result",
            method: .get,
            requiresAuth: true
        )
        
        let apiResult: APICourseResult = try await NetworkClient.shared.request(endpoint)
        return convertApiResultToCourse(apiResult)
    }
    
    private func convertApiResultToCourse(_ result: APICourseResult) -> A2AGeneratedCourse {
        let modules = result.modules.enumerated().map { (index, mod) in
            A2ACourseModule(
                id: mod.id,
                title: mod.title,
                description: mod.description,
                lessons: mod.lessons.enumerated().map { (lIndex, lesson) in
                    A2ACourseLesson(
                        id: lesson.id,
                        title: lesson.title,
                        content: lesson.content,
                        durationMinutes: lesson.durationMinutes,
                        order: lIndex,
                        scenes: nil
                    )
                },
                order: index
            )
        }
        
        return A2AGeneratedCourse(
            id: result.courseId,
            title: result.title,
            description: result.description,
            modules: modules,
            learningObjectives: [],
            estimatedDuration: result.estimatedDuration,
            difficulty: result.difficulty,
            visualAssets: nil,
            voiceAssets: nil
        )
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
            GenerationCourseModule(
                id: module.id,
                title: module.title,
                description: module.description,
                lessons: module.lessons.map { lesson in
                    GenerationCourseLesson(
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
    
    // MARK: - Streaming Parser (For Testing)
    
    /// Parse streaming events from an AsyncStream (SSE format)
    func parseStreamingEvents(_ stream: AsyncStream<String>, onEvent: @escaping (A2AStreamingEvent) -> Void) async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        for await line in stream {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data: ") else { continue }
            
            let jsonString = String(trimmed.dropFirst(6))
            guard let data = jsonString.data(using: .utf8) else { continue }
            
            do {
                let event = try decoder.decode(A2AStreamingEvent.self, from: data)
                
                await MainActor.run {
                    self.streamingEvents.append(event)
                    self.progress = event.progress
                    
                    // Simple phase tracking logic
                    if event.type == .phaseStarted, let phaseName = event.phase {
                        let newPhase = A2APhaseProgress(
                            phase: phaseName,
                            status: .running,
                            startedAt: Date(),
                            completedAt: nil,
                            durationMs: nil,
                            error: nil
                        )
                        self.phases.append(newPhase)
                    }
                    
                    onEvent(event)
                }
            } catch {
                print("Failed to decode streaming event: \(error)")
                // Don't throw to consume stream? Or throw? Test expects throws.
                throw error
            }
        }
    }
}

// MARK: - A2A Status Response
struct A2AStatusResponse: Codable {
    let jobId: String
    let status: String
    let progressPercent: Int
    let currentStep: String?
    let error: String?
}
