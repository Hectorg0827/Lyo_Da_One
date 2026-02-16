//
//  A2ACourseService.swift
//  Lyo
//
//  Service for Google A2A Protocol course generation
//  Handles streaming, polling, and agent discovery
//

import Foundation
import Combine
import os

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
        Log.ai.info("A2ACourseService initialized - Multi-agent pipeline ready")
    }
    
    // MARK: - Agent Discovery
    
    /// Fetch all available A2A agents
    func discoverAgents() async throws -> [A2AAgentCard] {
        Log.ai.debug("Discovering A2A agents...")
        
        let endpoint = Endpoints.A2A.discoverAgents
        
        let response: [A2AAgentCard] = try await NetworkClient.shared.request(endpoint)
        
        await MainActor.run {
            self.agents = response
        }
        
        Log.ai.info("Discovered \(response.count) agents")
        return response
    }
    
    /// Get specific agent card
    func getAgentCard(name: String) async throws -> A2AAgentCard {
        let endpoint = Endpoints.A2A.getAgentCard(name: name)
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    /// Fetch A2A protocol discovery document
    func fetchProtocolDiscovery() async throws -> A2AAgentDiscovery {
        let endpoint = Endpoints.A2A.protocolDiscovery
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Course Generation (Streaming)
    
    // MARK: - Course Generation (Polling Based)
    
    // MARK: - Course Generation (True Streaming)
    
    /// Generate course with real-time SSE updates
    func generateCourseStreaming(
        topic: String,
        qualityTier: CourseQualityTier = .standard,
        userContext: [String: String]? = nil,
        enableVisuals: Bool = true,
        enableVoice: Bool = true,
        onEvent: @escaping (A2AStreamingEvent) -> Void = { _ in }
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
        
        Log.ai.info("Starting A2A course generation (True Stream) for: \(topic)")
        
        streamingTask = Task {
            do {
                let endpoint = Endpoints.A2A.stream(
                    topic: topic,
                    qualityTier: qualityTier.rawValue,
                    userContext: userContext
                )
                
                let (bytes, response) = try await NetworkClient.shared.stream(endpoint)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw LyoError.network(.invalidResponse)
                }
                
                await MainActor.run {
                    self.streamingState = .streaming
                }
                
                // Process lines from stream
                let lines = bytes.lines
                for try await line in lines {
                    guard !Task.isCancelled else { break }
                    
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.hasPrefix("data: ") else { continue }
                    
                    let jsonString = String(trimmed.dropFirst(6))
                    guard let data = jsonString.data(using: .utf8) else { continue }
                    
                    do {
                        let decoder = JSONDecoder.lyoDecoder
                        let event = try decoder.decode(A2AStreamingEvent.self, from: data)
                        
                        await MainActor.run {
                            handleStreamingEvent(event, onEvent: onEvent)
                        }
                        
                        if event.type == .pipelineCompleted {
                            break
                        }
                    } catch {
                        Log.ai.warning("Failed to decode streaming event: \(error)")
                        Log.ai.info("Raw data: \(jsonString)")
                    }
                }
                
                await MainActor.run {
                    self.isGenerating = false
                    self.streamingState = .idle
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

    // MARK: - Streaming Event Parsing (Test/Utility)

    /// Parse SSE lines into streaming events and update service state.
    @MainActor
    func parseStreamingEvents<S: AsyncSequence>(
        _ lines: S,
        onEvent: @escaping (A2AStreamingEvent) -> Void
    ) async throws where S.Element == String {
        for try await line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data: ") else { continue }

            let jsonString = String(trimmed.dropFirst(6))
            guard let data = jsonString.data(using: .utf8) else { continue }

            do {
                let decoder = JSONDecoder.lyoDecoder
                let event = try decoder.decode(A2AStreamingEvent.self, from: data)
                handleStreamingEvent(event, onEvent: onEvent)
            } catch {
                Log.ai.warning("Failed to decode streaming event: \(error)")
                Log.ai.info("Raw data: \(jsonString)")
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
        
        let endpoint = Endpoints.CourseGenerationV2.generate(body: DataWrapper(data: bodyData))
        
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
        
        Log.ai.info("Starting A2A synchronous course generation for: \(topic)")
        
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
                Log.ai.info("A2A course generated successfully")
                
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
        Log.ai.error("Cancelling generation...")
        isGenerating = false
        streamingTask?.cancel()
        pollingTask?.cancel()
        streamingState = .idle
    }
    
    /// Force a stalled job to complete using fallback content
    func forceCompleteJob(jobId: String) async throws -> String {
        Log.ai.info("Force-completing job: \(jobId)")
        
        let endpoint = Endpoints.CourseGenerationV2.forceComplete(jobId: jobId)
        
        let response: [String: String] = try await NetworkClient.shared.request(endpoint)
        
        await MainActor.run {
            self.isGenerating = false
            self.streamingState = .idle
        }
        
        return response["status"] ?? "unknown"
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
                    Log.ai.warning("Polling error: \(error)")
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                }
            }
        }
    }
    
    internal func getPipelineStatus(jobId: String) async throws -> A2AStatusResponse {
        let endpoint = Endpoints.CourseGenerationV2.status(jobId: jobId)
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
            Log.ai.info("Final course fetched: \(course.title)")
        } catch {
            Log.ai.warning("Could not fetch final course: \(error)")
        }
    }
    
    private func fetchFinalCourseResult(jobId: String) async throws -> A2AGeneratedCourse {
        let endpoint = Endpoints.CourseGenerationV2.result(jobId: jobId)
        
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
    
    // MARK: - Event Handling
    
    @MainActor
    private func handleStreamingEvent(_ event: A2AStreamingEvent, onEvent: @escaping (A2AStreamingEvent) -> Void) {
        self.streamingEvents.append(event)
        self.progress = event.progress
        
        if let phase = event.phase {
            self.currentPhase = phase
            
            // Update phases list
            if event.type == .phaseStarted {
                let newPhase = A2APhaseProgress(
                    phase: phase,
                    status: .running,
                    startedAt: event.timestamp,
                    completedAt: nil,
                    durationMs: nil,
                    error: nil
                )
                if !self.phases.contains(where: { $0.phase == phase }) {
                    self.phases.append(newPhase)
                }
            } else if event.type == .phaseCompleted {
                if let index = self.phases.firstIndex(where: { $0.phase == phase }) {
                    let existing = self.phases[index]
                    self.phases[index] = A2APhaseProgress(
                        phase: phase,
                        status: .completed,
                        startedAt: existing.startedAt,
                        completedAt: event.timestamp,
                        durationMs: event.data?.totalDurationMs,
                        error: nil
                    )
                }
            } else if event.type == .phaseFailed {
                if let index = self.phases.firstIndex(where: { $0.phase == phase }) {
                    let existing = self.phases[index]
                    self.phases[index] = A2APhaseProgress(
                        phase: phase,
                        status: .failed,
                        startedAt: existing.startedAt,
                        completedAt: event.timestamp,
                        durationMs: nil,
                        error: event.data?.error ?? event.message
                    )
                }
            }
        }
        
        if event.type == .pipelineCompleted {
            Log.ai.info("✨ Pipeline Completed Successfully: \(event.pipelineId)")
        } else if event.type == .error {
            self.errorMessage = event.message
            self.streamingState = .failed(LyoError.network(.serverError(500)))
        } else if event.type == .contentChunk {
            // Can be used to stream partial text to UI if needed
             Log.ai.debug("📝 Chunk: \(event.chunkContent?.prefix(20) ?? "")")
        } else if event.type == .thinking {
             Log.ai.debug("🤔 Thinking: \(event.thinkingContent?.prefix(50) ?? "")")
        } else if event.type == .artifactCreated {
            Log.ai.info("🎨 Artifact Created: \(event.artifact?.name ?? "Unknown")")
            // Here we could append to a list of artifacts or notify UI
        }
        
        onEvent(event)
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
