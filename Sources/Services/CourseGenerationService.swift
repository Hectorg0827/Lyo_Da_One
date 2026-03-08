import Foundation

@MainActor
class CourseGenerationService: ObservableObject {
    static let shared = CourseGenerationService()
    
    @Published var generatedCourse: GeneratedCourse?
    @Published var generationState: GenerationState = .idle {
        didSet {
            switch generationState {
            case .idle: currentStep = "Preparing..."
            case .startingGeneration: currentStep = "Starting course generation..."
            case .engagementBridge: currentStep = "Building your course outline..."
            case .pollingForModules: currentStep = "Generating course content..."
            case .complete: currentStep = "Course ready!"
            case .failed(let msg): currentStep = "Error: \(msg)"
            }
        }
    }
    @Published var progress: Double = 0.0
    
    private var pollingTask: Task<Void, Never>?
    
    enum GenerationState: Equatable {
        case idle
        case startingGeneration       // POST /generate in flight
        case engagementBridge          // Phase B: quiz / voice playing
        case pollingForModules         // Phase C: polling loop active
        case complete
        case failed(String)
    }
    
    // MARK: - Phase A: Instant Payload
    
    /// Kicks off generation. Returns in < 5 seconds with syllabus + preview.
    func startCourseGeneration(topic: String, level: String = "beginner") async {
        generationState = .startingGeneration
        failedModuleFetches.removeAll()
        
        do {
            let response: InstantCourseResponse = try await NetworkClient.shared.request(
                Endpoints.CourseGen.start(topic: topic, level: level)
            )
            
            print("✅ Phase A: Instant payload received — job: \\(response.jobId)")
            
            // Build initial course from instant payload
            let course = buildCourseFromInstant(response)
            self.generatedCourse = course
            self.generationState = .engagementBridge
            
            // Phase C: Begin polling immediately
            startPolling(jobId: response.jobId, courseId: response.instant.courseId)
            
        } catch {
            print("🚨 Phase A FAILED: \\(error)")
            self.generationState = .failed("Could not start course generation: \\(error.localizedDescription)")
        }
    }
    
    // MARK: - Phase C: Polling Loop
    
    private func startPolling(jobId: String, courseId: String) {
        pollingTask?.cancel()
        generationState = .pollingForModules
        
        pollingTask = Task { [weak self] in
            guard let self else { return }
            
            var fastPollCount = 0
            let maxPolls = 120 // 120 × 3 sec = 6 min absolute max
            var pollCount = 0
            
            while !Task.isCancelled && pollCount < maxPolls {
                // Adaptive interval: 2 sec for first 10 polls, then 5 sec
                let interval: UInt64 = fastPollCount < 10 ? 2_000_000_000 : 5_000_000_000
                try? await Task.sleep(nanoseconds: interval)
                fastPollCount += 1
                pollCount += 1
                
                do {
                    let status: CourseStatus = try await NetworkClient.shared.request(
                        Endpoints.CourseGen.status(jobId: jobId)
                    )
                    
                    print("📡 Poll #\\(pollCount): state=\\(status.state) progress=\\(status.progress ?? 0)")
                    self.progress = status.progress ?? 0
                    
                    // Fetch any newly-ready modules
                    for moduleStatus in status.modules where moduleStatus.state == .ready {
                        let _ = await fetchModuleIfNeeded(courseId: courseId, index: moduleStatus.index)
                    }

                    // Retry any previously failed fetches
                    if !self.failedModuleFetches.isEmpty {
                        let retryIndices = self.failedModuleFetches.sorted()
                        for idx in retryIndices {
                            if status.modules.first(where: { $0.index == idx })?.state == .ready {
                                print("🔄 Retrying failed module \(idx)")
                                let _ = await fetchModuleIfNeeded(courseId: courseId, index: idx)
                            }
                        }
                    }

                    // Update states for building/failed modules in local model
                    updateModuleStates(from: status)
                    
                    // Terminal states
                    if status.state == "complete" {
                        print("🎉 All modules ready!")
                        // Hydration pass: re-fetch any modules that failed during polling
                        await hydrateFailedModules(courseId: courseId)
                        // If hydration couldn't recover all modules, fetch full course as safety net
                        if !self.failedModuleFetches.isEmpty {
                            print("🔄 Hydration incomplete — fetching full course truth")
                            await fetchFinalTruth(courseId: courseId)
                        } else {
                            self.generationState = .complete
                        }
                        break
                    } else if status.state == "failed" {
                        print("🚨 Backend generation failed")
                        self.generationState = .failed("Course generation failed on server")
                        break
                    }
                    
                } catch {
                    print("⚠️ Poll error (will retry): \\(error.localizedDescription)")
                    // Don't break — polling is resilient. Next poll will try again.
                }
            }
            
            if pollCount >= maxPolls {
                print("🚨 Polling timed out after \\(maxPolls) attempts")
                // Safety net: fetch whatever the server has
                await fetchFinalTruth(courseId: courseId)
            }
        }
    }
    
    // MARK: - Fetch Individual Module

    /// Track module indices that failed to fetch so we can retry during hydration
    private var failedModuleFetches: Set<Int> = []

    private func fetchModuleIfNeeded(courseId: String, index: Int) async -> Bool {
        // Don't re-fetch if already ready locally WITH lessons
        if let existingModule = generatedCourse?.modules.first(where: { $0.index == index }),
           existingModule.state == .ready, existingModule.lessons?.isEmpty == false {
            return true
        }

        do {
            let fullModule: ProgressiveModule = try await NetworkClient.shared.request(
                Endpoints.CourseGen.module(courseId: courseId, index: index)
            )

            let lessonCount = fullModule.lessons?.count ?? 0
            print("✅ Module \(index) fetched: \(fullModule.title) — \(lessonCount) lessons")

            // Only accept if it actually has lesson content
            guard lessonCount > 0 else {
                print("⚠️ Module \(index) returned 0 lessons — treating as not ready")
                failedModuleFetches.insert(index)
                return false
            }

            failedModuleFetches.remove(index)

            // Swap into local course model
            if let idx = generatedCourse?.modules.firstIndex(where: { $0.index == index }) {
                generatedCourse?.modules[idx] = fullModule
            } else {
                generatedCourse?.modules.append(fullModule)
            }

            return true

        } catch {
            print("🚨 Failed to fetch module \(index): \(error)")
            failedModuleFetches.insert(index)
            return false
        }
    }

    // MARK: - Update Module States from Status

    private func updateModuleStates(from status: CourseStatus) {
        for moduleStatus in status.modules {
            guard let idx = generatedCourse?.modules.firstIndex(where: { $0.index == moduleStatus.index }) else { continue }

            let currentModule = generatedCourse!.modules[idx]

            // NEVER mark a module as .ready locally unless we have actual lesson content.
            // If the backend says "ready" but our fetch failed, keep the local state as .building
            // so the UI shows a loading indicator instead of empty content.
            let effectiveState: ModuleState
            if moduleStatus.state == .ready {
                let hasLessons = currentModule.lessons?.isEmpty == false
                if hasLessons {
                    // Already fetched with content — keep as ready
                    effectiveState = .ready
                } else if failedModuleFetches.contains(moduleStatus.index) {
                    // Fetch failed — keep as building so UI shows progress, not empty "complete"
                    effectiveState = .building
                    print("⚠️ Module \(moduleStatus.index) reported ready by server but fetch failed — keeping as .building")
                } else {
                    // Fetch succeeded and set state already — trust it
                    effectiveState = .ready
                }
            } else {
                effectiveState = moduleStatus.state
            }

            // Only update if local state needs changing
            if currentModule.state != effectiveState || currentModule.state != .ready {
                let updatedTitle: String
                if let statusTitle = moduleStatus.title, !statusTitle.isEmpty,
                   currentModule.title.hasPrefix("Module ") {
                    updatedTitle = statusTitle
                } else {
                    updatedTitle = currentModule.title
                }
                generatedCourse?.modules[idx] = ProgressiveModule(
                    id: currentModule.id,
                    index: currentModule.index,
                    state: effectiveState,
                    title: updatedTitle,
                    lessons: currentModule.lessons,
                    summary: currentModule.summary
                )
            }
        }
    }

    // MARK: - Hydration Pass

    /// Re-fetch any modules that failed during polling. Called when generation completes.
    private func hydrateFailedModules(courseId: String) async {
        guard !failedModuleFetches.isEmpty else { return }

        let toRetry = failedModuleFetches.sorted()
        print("💧 Hydration pass: retrying \(toRetry.count) failed module fetches")

        for index in toRetry {
            // Give each retry 2 attempts with a small delay
            for attempt in 1...2 {
                let success = await fetchModuleIfNeeded(courseId: courseId, index: index)
                if success {
                    print("💧 Hydration: Module \(index) recovered on attempt \(attempt)")
                    break
                }
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // If we recovered any modules, trigger a final rebuild
        if failedModuleFetches.isEmpty {
            print("💧 Hydration complete — all modules recovered")
        } else {
            print("⚠️ Hydration finished with \(failedModuleFetches.count) still missing")
        }
    }

    // MARK: - Safety Net: Final Truth

    /// Called on timeout, app relaunch, or background return
    func fetchFinalTruth(courseId: String) async {
        do {
            let fullCourse: GeneratedCourse = try await NetworkClient.shared.request(
                Endpoints.CourseGen.fullCourse(courseId: courseId)
            )
            print("🔄 Final truth fetched: \(fullCourse.modules.count) modules")
            self.generatedCourse = fullCourse
            self.failedModuleFetches.removeAll()
            self.generationState = .complete
        } catch {
            print("🚨 Final truth fetch failed: \(error)")
            self.generationState = .failed("Could not retrieve course")
        }
    }
    
    // MARK: - Build Course from Instant Payload
    
    private func buildCourseFromInstant(_ response: InstantCourseResponse) -> GeneratedCourse {
        let instant = response.instant
        
        // Build module placeholders from syllabus
        var modules: [ProgressiveModule] = instant.syllabus.enumerated().map { idx, title in
            ProgressiveModule(
                id: UUID().uuidString,
                index: idx + 1,
                state: .locked,
                title: title
            )
        }
        
        // Enrich Module 1 with preview data
        if let preview = instant.modulePreview, let firstIdx = modules.firstIndex(where: { $0.index == preview.moduleIndex }) {
            var previewLesson: [ProgressiveLesson] = []
            if let lp = preview.lessonPreview {
                previewLesson.append(ProgressiveLesson(
                    id: UUID().uuidString,
                    title: lp.title,
                    content: nil,
                    summary: lp.summary,
                    miniPractice: lp.miniPractice
                ))
            }
            modules[firstIdx] = ProgressiveModule(
                id: modules[firstIdx].id,
                index: preview.moduleIndex,
                state: .building,
                title: preview.moduleTitle,
                lessons: previewLesson,
                summary: preview.lessonPreview?.summary
            )
        }
        
        return GeneratedCourse(
            id: instant.courseId,
            jobId: response.jobId,
            title: instant.title,
            objective: instant.objective,
            syllabus: instant.syllabus,
            modules: modules,
            schemaVersion: response.schemaVersion
        )
    }
    
    // MARK: - Cleanup
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    func reset() {
        stopPolling()
        generatedCourse = nil
        generationState = .idle
        progress = 0.0
    }
    
    // MARK: - Compatibility Helpers
    
    /// Legacy convenience — human-readable step description
    @Published var currentStep: String = "Preparing..."
    
    /// Legacy convenience — true while any generation is in progress
    var isGenerating: Bool {
        switch generationState {
        case .startingGeneration, .engagementBridge, .pollingForModules:
            return true
        default:
            return false
        }
    }
    
    /// Smart Review: generates a quick review course from struggle items
    func generateSmartReview(struggles: [StruggleItem]) async throws -> GeneratedCourseResponse {
        let topic = struggles.map(\.topic).joined(separator: ", ")
        await startCourseGeneration(topic: "Review: \(topic)", level: "adaptive")
        
        // Return a lightweight GeneratedCourseResponse for callers that expect the old API
        let modules = struggles.enumerated().map { idx, item in
            GenerationCourseModule(
                id: UUID().uuidString,
                title: item.topic,
                description: "Review of \(item.topic)",
                lessons: [
                    GenerationCourseLesson(
                        id: UUID().uuidString,
                        title: "Review: \(item.topic)",
                        content: "",
                        durationMinutes: 5,
                        order: 1
                    )
                ],
                order: idx + 1
            )
        }
        
        return GeneratedCourseResponse(
            courseId: generatedCourse?.id ?? UUID().uuidString,
            title: "Smart Review",
            description: "Targeted review of areas that need practice",
            modules: modules,
            estimatedDuration: struggles.count * 5,
            difficulty: "adaptive"
        )
    }
    
    // MARK: - Legacy Compatibility: generateCourse
    
    /// Wraps the new progressive generation into the old blocking API signature.
    /// Used by InteractiveCinemaService and other legacy callers.
    func generateCourse(
        topic: String,
        level: String = "beginner",
        outcomes: [String] = [],
        teachingStyle: String = "interactive"
    ) async throws -> GeneratedCourseResponse {
        await startCourseGeneration(topic: topic, level: level)
        
        // Wait for generation to progress past instant payload (max 60 seconds)
        var attempts = 0
        while generationState != .complete && attempts < 60 {
            if case .failed(let msg) = generationState {
                throw CourseGenerationError.generationFailed(msg)
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
        }
        
        guard let course = generatedCourse else {
            throw CourseGenerationError.noContent
        }
        
        return convertToLegacyResponse(course, level: level)
    }
    
    /// Convert a GeneratedCourse to the legacy GeneratedCourseResponse type
    private func convertToLegacyResponse(_ course: GeneratedCourse, level: String = "beginner") -> GeneratedCourseResponse {
        GeneratedCourseResponse(
            courseId: course.id,
            title: course.title,
            description: course.objective ?? "",
            modules: course.modules.enumerated().map { idx, module in
                GenerationCourseModule(
                    id: module.id,
                    title: module.title,
                    description: module.summary ?? "",
                    lessons: (module.lessons ?? []).enumerated().map { lIdx, lesson in
                        GenerationCourseLesson(
                            id: lesson.id,
                            title: lesson.title ?? "Lesson \(lIdx + 1)",
                            content: lesson.content ?? lesson.summary ?? "",
                            durationMinutes: 5,
                            order: lIdx + 1
                        )
                    },
                    order: idx + 1
                )
            },
            estimatedDuration: course.modules.count * 15,
            difficulty: level
        )
    }
    
    // MARK: - Legacy Compatibility: createLiveLessonFromGenerated
    
    /// Converts a ProgressiveLesson into a LiveLesson for the classroom ViewModel.
    func createLiveLessonFromGenerated(lesson: ProgressiveLesson, moduleTitle: String) -> LiveLesson {
        var blocks: [LessonBlock] = []
        
        blocks.append(LessonBlock(
            id: "intro_\(lesson.id)",
            type: .paragraph,
            title: lesson.title ?? "Lesson",
            content: lesson.content ?? lesson.summary ?? ""
        ))
        
        if let practice = lesson.miniPractice, !practice.isEmpty {
            for (i, question) in practice.enumerated() {
                blocks.append(LessonBlock(
                    id: "practice_\(lesson.id)_\(i)",
                    type: .paragraph,
                    title: "Practice \(i + 1)",
                    content: question
                ))
            }
        }
        
        blocks.append(LessonBlock(
            id: "summary_\(lesson.id)",
            type: .summary,
            title: "✅ Lesson Complete",
            content: lesson.summary ?? "You've finished this lesson in \(moduleTitle)."
        ))
        
        return LiveLesson(
            courseId: generatedCourse?.id ?? "unknown",
            lessonId: lesson.id,
            title: lesson.title ?? "Lesson",
            subtitle: moduleTitle,
            blocks: blocks
        )
    }
}
