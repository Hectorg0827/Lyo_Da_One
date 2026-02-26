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
                
                // Track completion data from streaming events
                var completionCourseId: String?
                var completionPayload: [String: A2AAnyCodableValue]?
                var didComplete = false
                
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
                        
                        // Capture completion data
                        if event.type == .pipelineCompleted || event.type == .completed {
                            completionCourseId = event.data?.courseId ?? event.pipelineId
                            completionPayload = event.payload
                            didComplete = true
                            break
                        }
                    } catch {
                        Log.ai.warning("Failed to decode streaming event: \(error)")
                        Log.ai.info("Raw data: \(jsonString)")
                        
                        // Even if formal decode fails, try to extract progress from raw JSON
                        Task { @MainActor in
                            self.handleRawSSEFallback(jsonString: jsonString, onEvent: onEvent)
                        }
                    }
                }
                
                // ── After stream ends: Fetch the final course ──
                if didComplete || self.currentPipelineId != nil {
                    let jobId = completionCourseId ?? self.currentPipelineId ?? ""
                    Log.ai.info("🎯 Stream completed, fetching course result for: \(jobId)")
                    
                    // Strategy 1: Try to decode course from the payload of the completion event
                    if let payload = completionPayload {
                        do {
                            let payloadData = try JSONEncoder().encode(payload)
                            let course = try JSONDecoder.lyoDecoder.decode(A2AGeneratedCourse.self, from: payloadData)
                            await MainActor.run {
                                self.generatedCourse = course
                                self.streamingState = .completed
                                self.isGenerating = false
                                self.progress = 100
                            }
                            Log.ai.info("✅ Course decoded from stream payload: \(course.title)")
                            return
                        } catch {
                            Log.ai.info("Payload decode failed, will fetch via API: \(error)")
                        }
                        
                        // Strategy 1b: Try decoding A2ACourseResponse which wraps the course
                        do {
                            let payloadData = try JSONEncoder().encode(payload)
                            let courseResponse = try JSONDecoder.lyoDecoder.decode(A2ACourseResponse.self, from: payloadData)
                            if let course = courseResponse.course {
                                await MainActor.run {
                                    self.generatedCourse = course
                                    self.streamingState = .completed
                                    self.isGenerating = false
                                    self.progress = 100
                                }
                                Log.ai.info("✅ Course decoded from A2ACourseResponse payload: \(course.title)")
                                return
                            }
                        } catch {
                            Log.ai.info("A2ACourseResponse payload decode also failed: \(error)")
                        }
                    }
                    
                    // Strategy 2: Fetch via result API endpoint
                    if !jobId.isEmpty && jobId != "unknown" {
                        do {
                            let course = try await fetchFinalCourseResult(jobId: jobId)
                            await MainActor.run {
                                self.generatedCourse = course
                                self.streamingState = .completed
                                self.isGenerating = false
                                self.progress = 100
                            }
                            Log.ai.info("✅ Course fetched via API: \(course.title)")
                            return
                        } catch {
                            Log.ai.warning("⚠️ Failed to fetch course via A2A result: \(error)")
                        }
                        
                        // Strategy 2b: Try CourseGenerationV2 result endpoint (different URL pattern)
                        do {
                            let endpoint = Endpoints.CourseGenerationV2.result(jobId: jobId)
                            let apiResult: APICourseResult = try await NetworkClient.shared.request(endpoint)
                            let course = convertApiResultToCourse(apiResult)
                            await MainActor.run {
                                self.generatedCourse = course
                                self.streamingState = .completed
                                self.isGenerating = false
                                self.progress = 100
                            }
                            Log.ai.info("✅ Course fetched via V2 result: \(course.title)")
                            return
                        } catch {
                            Log.ai.warning("⚠️ Failed to fetch course via V2 result: \(error)")
                        }
                    }
                    
                    // If all else fails, report error
                    await MainActor.run {
                        self.errorMessage = "Course was generated but could not be retrieved."
                        self.streamingState = .failed(A2AError.noCourseGenerated)
                        self.isGenerating = false
                    }
                } else {
                    await MainActor.run {
                        self.isGenerating = false
                        self.streamingState = .idle
                    }
                }
                
            } catch {
                Log.ai.error("❌ SSE streaming failed: \(error). Falling back to polling...")
                
                // ── Fallback: Use submit + poll approach ──
                do {
                    let course = try await self.generateCourse(
                        topic: topic,
                        qualityTier: qualityTier,
                        userContext: userContext,
                        enableVisuals: enableVisuals,
                        enableVoice: enableVoice
                    )
                    await MainActor.run {
                        self.generatedCourse = course
                        self.streamingState = .completed
                        self.isGenerating = false
                        self.progress = 100
                    }
                    Log.ai.info("✅ Course generated via polling fallback: \(course.title)")
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.streamingState = .failed(error)
                        self.isGenerating = false
                    }
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
    
    // MARK: - Raw SSE Fallback
    
    /// When formal decode fails, try to extract useful progress info from raw JSON.
    @MainActor
    private func handleRawSSEFallback(jsonString: String, onEvent: @escaping (A2AStreamingEvent) -> Void) {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return }
        
        // Extract type string
        let typeStr = (json["type"] as? String) ?? (json["event_type"] as? String) ?? ""
        let progressVal = (json["progress"] as? Int) ?? (json["progress_percent"] as? Int) ?? self.progress
        let messageVal = json["message"] as? String
        
        // Update progress even if we can't form a full event
        self.progress = progressVal
        
        // Map backend V2 types to pipeline phases for UI timeline
        switch typeStr {
        case "started", "pipeline_started":
            self.currentPhase = .initialization
        case "agent_working":
            if let agent = (json["data"] as? [String: Any])?["agent"] as? String {
                switch agent {
                case "orchestrator": self.currentPhase = .initialization
                case "curriculum_architect": self.currentPhase = .pedagogy
                case "content_creator": self.currentPhase = .cinematic
                case "assessment_designer": self.currentPhase = .qaCheck
                case "qa_agent": self.currentPhase = .qaCheck
                default: break
                }
            }
        case "lesson_complete", "progress":
            // Keep current phase, just update progress
            break
        case "completed", "pipeline_completed":
            self.currentPhase = .finalization
            self.progress = 100
            // Extract course_id if available
            if let data = json["data"] as? [String: Any], let cid = data["course_id"] as? String {
                self.currentPipelineId = cid
            }
        default:
            break
        }
        
        // Build a synthetic event for the onEvent callback
        let syntheticEvent = A2AStreamingEvent(
            type: A2AEventType(rawValue: typeStr) ?? .unknown,
            pipelineId: self.currentPipelineId ?? "unknown",
            progress: progressVal,
            message: messageVal
        )
        self.streamingEvents.append(syntheticEvent)
        onEvent(syntheticEvent)
        
        Log.ai.debug("📡 Raw SSE fallback: type=\(typeStr) progress=\(progressVal)")
    }
    
    /// Start the generation job on the backend
    private func startJob(
        topic: String,
        qualityTier: CourseQualityTier,
        userContext: [String: String]?,
        enableVisuals: Bool,
        enableVoice: Bool
    ) async throws -> A2ACourseResponse {
        
        let request: [String: Any] = [
            "topic": topic,
            "quality_tier": qualityTier.rawValue,
            "user_context": userContext ?? [:],
            "enable_visuals": enableVisuals,
            "enable_voice": enableVoice,
            "enable_streaming": false
        ]
        
        let endpoint = Endpoints.A2A.generate(topic: topic, options: request)
        
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
            self.currentPipelineId = job.pipelineId
        }
        
        // Poll until complete
        var isDone = false
        var finalCourse: A2AGeneratedCourse?
        
        while !isDone {
            if Task.isCancelled { throw A2AError.pipelineFailed("Cancelled") }
            
            let status = try await getPipelineStatus(jobId: job.pipelineId)
            
            await MainActor.run {
                self.progress = status.progressPercent
                self.mapStatusToPhases(status)
            }
            
            if status.status == "completed" {
                finalCourse = try await fetchFinalCourseResult(jobId: job.pipelineId)
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
        let endpoint = Endpoints.A2A.status(taskId: jobId)
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
        let endpoint = Endpoints.A2A.result(taskId: jobId)
        
        // Note: result might be APICourseResult OR A2ACourseResponse.
        // Assuming backend returns APICourseResult structure for now.
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
        
        switch event.type {
        case .pipelineCompleted, .completed:
            Log.ai.info("✨ Pipeline Completed: \(event.pipelineId)")
            self.currentPhase = .finalization
            self.progress = 100
        case .pipelineStarted, .started:
            Log.ai.info("🚀 Pipeline Started: \(event.pipelineId)")
            self.currentPhase = .initialization
        case .agentWorking:
            Log.ai.debug("🤖 Agent Working: \(event.message ?? "")")
        case .lessonComplete:
            Log.ai.debug("📚 Lesson Complete: \(event.message ?? "")")
        case .progress:
            Log.ai.debug("📊 Progress: \(event.progress)%")
        case .costUpdate:
            Log.ai.debug("💰 Cost Update")
        case .error:
            self.errorMessage = event.message
            self.streamingState = .failed(LyoError.network(.serverError(500)))
        case .contentChunk:
            Log.ai.debug("📝 Chunk: \(event.chunkContent?.prefix(20) ?? "")")
        case .thinking:
            Log.ai.debug("🤔 Thinking: \(event.thinkingContent?.prefix(50) ?? "")")
        case .artifactCreated:
            Log.ai.info("🎨 Artifact Created: \(event.artifact?.name ?? "Unknown")")
        case .unknown:
            Log.ai.debug("❓ Unknown event: \(event.message ?? "")")
        default:
            break
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
