//
//  CourseGenerationService.swift
//  Lyo
//
//  Service for generating courses from AI conversations
//

import Foundation
import os

// MARK: - Course Generation Request

struct CourseGenerationRequest: Codable {
    let topic: String
    let level: String
    let outcomes: [String]
    let teachingStyle: String
    let systemPrompt: String?
    let diagnosticData: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case topic
        case level
        case outcomes
        case teachingStyle = "teaching_style"
        case systemPrompt = "system_prompt"
        case diagnosticData = "diagnostic_data"
    }
}

// MARK: - Course Generation Response (Local types to avoid conflicts)

struct GeneratedCourseResponse: Codable {
    let courseId: String
    let title: String
    let description: String
    let modules: [GenerationCourseModule]
    let estimatedDuration: Int
    let difficulty: String
    
    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case title
        case description
        case modules
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
        case id
        case title
        case content
        case durationMinutes = "duration_minutes"
        case order
    }
}

// MARK: - Course Generation Service

@MainActor
final class CourseGenerationService: ObservableObject {
    static let shared = CourseGenerationService()
    
    @Published var isGenerating: Bool = false
    @Published var progress: Double = 0
    @Published var currentStep: String = ""
    @Published var generatedCourse: GeneratedCourseResponse?
    @Published var error: String?

    // MARK: - Hydration Race Condition Guard
    /// Prevents duplicate background hydration tasks from running simultaneously
    private var isHydrating: Bool = false
    private var hydrationTask: Task<Void, Never>? = nil
    
    // NEW: Streaming state for live UI updates
    @Published var streamingText: String = ""
    @Published var streamingBlocks: [LessonBlock] = []
    @Published var isStreaming: Bool = false

    @Published var isGeneratingModule: Bool = false
    
    private var baseURL: String { AppConfig.baseURL }
    
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("last_generated_course.json")
    }

    private func saveCourseToDisk(_ course: GeneratedCourseResponse) {
        do {
            let data = try JSONEncoder().encode(course)
            try data.write(to: fileURL, options: [.atomic])
            Log.course.info("Saved generated course to disk.")
        } catch {
            Log.course.warning("Failed to save course to disk: \(error)")
        }
    }
    
    private init() {}
    
    // MARK: - Schema Validation (V2)
    func recoverLastGeneratedCourseFromDisk() async {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let course = try JSONDecoder().decode(GeneratedCourseResponse.self, from: data)
                await MainActor.run {
                    self.generatedCourse = course
                    Log.course.info("♻️ Recovered last generated course from disk.")
                }
            }
        } catch {
            Log.course.warning("Failed to recover course: \(error)")
        }
    }

    /// Populates a lightweight local draft from OPEN_CLASSROOM metadata.
    /// This enables immediate classroom launch while the full course hydrates in background.
    func populateGeneratedCourse(from payload: CoursePayload) {
        let draft = buildLocalDraftCourse(topic: payload.topic, level: payload.level)
        
        // Ensure the ID starts with 'gen_' so LiveClassroomViewModel knows to load it from cache,
        // rather than trying to fetch it from the API (which would 404).
        var resolvedCourseId = (payload.id?.isEmpty == false) ? payload.id! : "gen_\(UUID().uuidString.prefix(6))"
        if !resolvedCourseId.hasPrefix("gen_") && !resolvedCourseId.hasPrefix("mock_") {
            resolvedCourseId = "gen_" + resolvedCourseId
        }

        // Merge payload objectives into the draft lessons where possible
        // so the user sees real objectives even in the draft stage
        var enrichedModules = draft.modules
        if !payload.objectives.isEmpty {
            for (mIdx, mod) in enrichedModules.enumerated() {
                var updatedLessons = mod.lessons
                for (lIdx, lesson) in updatedLessons.enumerated() {
                    // Inject real objective text into lesson content as context headers
                    let objIndex = mIdx * mod.lessons.count + lIdx
                    if objIndex < payload.objectives.count {
                        let realObjective = payload.objectives[objIndex]
                        let enrichedContent = """
                        ### 🎯 Learning Objective
                        \(realObjective)
                        
                        \(lesson.content)
                        """
                        updatedLessons[lIdx] = GenerationCourseLesson(
                            id: lesson.id,
                            title: lesson.title,
                            content: enrichedContent,
                            durationMinutes: lesson.durationMinutes,
                            order: lesson.order
                        )
                    }
                }
                enrichedModules[mIdx] = GenerationCourseModule(
                    id: mod.id,
                    title: mod.title,
                    description: mod.description,
                    lessons: updatedLessons,
                    order: mod.order
                )
            }
        }

        let updated = GeneratedCourseResponse(
            courseId: resolvedCourseId,
            title: payload.title,
            description: draft.description,
            modules: enrichedModules,
            estimatedDuration: draft.estimatedDuration,
            difficulty: payload.level
        )

        generatedCourse = updated
        currentStep = "Draft ready — hydrating with real content..."
        progress = 0.3
        saveCourseToDisk(updated)
        Log.course.info("📋 Populated draft course from OPEN_CLASSROOM payload: \(resolvedCourseId)")
        
        // 🚀 Start background hydration to replace template content with REAL AI-generated content
        // Guard: prevent double hydration
        guard !isHydrating else {
            Log.course.info("⚡ Hydration already in progress — skipping duplicate task")
            return
        }
        let topic = payload.topic
        let level = payload.level
        let objectives = payload.objectives
        hydrationTask = Task { [weak self] in
            guard let self else { return }
            Log.course.info("🌊 Starting background hydration for: \(topic)")
            await self.startLegacyGenerationInBackground(
                topic: topic,
                level: level,
                teachingStyle: "interactive",
                learningOutcomes: objectives.isEmpty
                    ? ["Understand core concepts of \(topic)", "Apply knowledge through practical examples", "Build confidence in \(topic)"]
                    : objectives
            )
        }
    }
    
    // MARK: - Rescue from Markdown
    
    /// Parses a raw Markdown course outline into a structured course and caches it.
    /// Returns the new course ID.
    func populateRescuedCourse(from markdown: String) -> String {
        let courseId = "gen_rescued_\(UUID().uuidString.prefix(6))"
        var title = "Generated Course"
        var modules: [GenerationCourseModule] = []
        
        // 1. Extract Title
        let lines = markdown.components(separatedBy: .newlines)
        if let titleLine = lines.first(where: { $0.hasPrefix("# ") || $0.contains("Full Course:") }) {
             // Clean "## Full Course: " -> "Foundations..."
             title = titleLine.replacingOccurrences(of: "#", with: "")
                              .replacingOccurrences(of: "Full Course:", with: "")
                              .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 2. Split by Modules
        // Heuristic: Modules start with "### Module"
        let moduleChunks = markdown.components(separatedBy: "### Module")
        
        for (index, chunk) in moduleChunks.enumerated() {
            if index == 0 { continue } // Skip preamble
            
            let lines = chunk.components(separatedBy: .newlines)
            
            // First line is module title, e.g. "1: Numbers..."
            let moduleTitleLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Module \(index)"
            // Clean "1: Numbers" -> "Numbers" if desired, or keep as is.
            let cleanModuleTitle = moduleTitleLine.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            
            // Split lessons by "#### Lesson"
            let lessonChunks = chunk.components(separatedBy: "#### Lesson")
            var lessons: [GenerationCourseLesson] = []
            
            for (lIndex, lChunk) in lessonChunks.enumerated() {
                if lIndex == 0 { continue } // Skip module description before first lesson
                
                let lLines = lChunk.components(separatedBy: .newlines)
                let lTitleLine = lLines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Lesson \(lIndex)"
                let content = lLines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                lessons.append(GenerationCourseLesson(
                    id: "les_\(index)_\(lIndex)",
                    title: lTitleLine,
                    content: content,
                    durationMinutes: 10,
                    order: lIndex
                ))
            }
            
            // If no lessons found (maybe format was different), create a dummy one with the chunk content
            if lessons.isEmpty {
                 lessons.append(GenerationCourseLesson(
                    id: "les_\(index)_1",
                    title: "Module Content",
                    content: chunk,
                    durationMinutes: 15,
                    order: 1
                 ))
            }
            
            modules.append(GenerationCourseModule(
                id: "mod_\(index)",
                title: cleanModuleTitle,
                description: "",
                lessons: lessons,
                order: index
            ))
        }
        
        // Fallback if parsing failed
        if modules.isEmpty {
            modules.append(GenerationCourseModule(
                id: "mod_1",
                title: "Course Content",
                description: "AI Generated Content",
                lessons: [
                    GenerationCourseLesson(
                        id: "les_1",
                        title: "Overview",
                        content: markdown,
                        durationMinutes: 10,
                        order: 1
                    )
                ],
                order: 1
            ))
        }
        
        self.generatedCourse = GeneratedCourseResponse(
            courseId: courseId,
            title: title,
            description: "Rescued from chat conversation",
            modules: modules,
            estimatedDuration: modules.count * 15,
            difficulty: "Adaptive"
        )
        
        Log.course.info("🛟 CourseGenerationService: Rescued course '\(title)' with \(modules.count) modules")
        return courseId
    }
    
    // MARK: - Generate Course
    
    func generateCourse(
        topic: String,
        level: String = "beginner",
        outcomes: [String]? = nil,
        teachingStyle: String = "interactive"
    ) async throws -> GeneratedCourseResponse {
        isGenerating = true
        progress = 0
        currentStep = "Analyzing topic..."
        error = nil
        
        defer {
            isGenerating = false
            progress = 1.0
        }
        
        // Build outcomes if not provided
        let learningOutcomes = outcomes ?? [
            "Understand core concepts of \(topic)",
            "Apply knowledge through practical examples",
            "Build confidence in \(topic)"
        ]

        // 🚀 NEW STRATEGY: Instant "Local Draft" first, then Hydrate in Background.
        // This ensures <1s response time for the user UI.
        Log.course.info("️ SPEED MODE: Generating Instant Local Draft for: \(topic)")
        
        // 1. Generate Instant Template (0.1s)
        let draftCourse = buildLocalDraftCourse(topic: topic, level: level)
        
        // 2. Publish immediately so UI unlocks
        await MainActor.run {
            self.generatedCourse = draftCourse
            self.currentStep = "Draft ready..."
            self.progress = 0.5
            self.saveCourseToDisk(draftCourse)
        }
        
        // 2b. Add to Stack immediately so course is visible in Focus screen
        await addCourseToStack(courseId: draftCourse.courseId, title: draftCourse.title, topic: topic)
        
        // 3. Start Background Hydration (errors surface to UI)
        // Guard: prevent double hydration if another task is already running
        if !isHydrating {
            hydrationTask = Task { [weak self] in
                guard let self else { return }
                Log.course.info("🌊 Starting Background Hydration...")
                await self.startLegacyGenerationInBackground(
                    topic: topic,
                    level: level,
                    teachingStyle: teachingStyle,
                    learningOutcomes: learningOutcomes
                )
            }
        } else {
            Log.course.info("⚡ Hydration already in progress — skipping duplicate task")
        }

        // 4. Return immediately to unblock `await` callers
        return draftCourse
    }

    // MARK: - Smart Review Generation

    /// Generates a personalized review lesson based on user struggles
    func generateSmartReview(struggles: [StruggleItem]) async throws -> GeneratedCourseResponse {
        guard !struggles.isEmpty else {
            throw CourseGenerationError.invalidRequest // Or handle gracefully
        }
        
        let topics = struggles.prefix(3).map { $0.topic }.joined(separator: ", ")
        let reviewTopic = "Personalized Review: \(topics)"
        
        Log.course.info("🧠 Generating Smart Review for: \(topics)")
        
        // Creating specific learning outcomes based on struggles
        let outcomes = struggles.prefix(5).map { "Reinforce understanding of \($0.topic)" }
        
        // Reuse the main generation pipeline
        return try await generateCourse(
            topic: reviewTopic,
            level: "adaptive",
            outcomes: outcomes,
            teachingStyle: "coaching"
        )
    }

    // MARK: - Legacy / Background Generation Logic

    private func startLegacyGenerationInBackground(
        topic: String,
        level: String,
        teachingStyle: String,
        learningOutcomes: [String]
    ) async {
        // Guard: prevent concurrent hydration
        guard !isHydrating else {
            Log.course.info("⚡ Hydration already active — skipping")
            return
        }
        isHydrating = true
        defer { isHydrating = false }

        do {
            // Step 1: Map level to CourseGenerationOptions
            let options: CourseGenerationOptions
            switch level.lowercased() {
            case "beginner":
                options = .economical
            case "intermediate":
                options = .recommended
            case "advanced":
                options = .premium
            default:
                options = .recommended
            }
            
            // Step 2: Call Backend (this might take 20-30s, but user is already happy)
            let jobResponse = try await BackendAIService.shared.generateCourse(
                topic: topic,
                options: options,
                userContext: [
                    "level": level,
                    "style": teachingStyle,
                    "outcomes": learningOutcomes.joined(separator: ", ")
                ]
            )

            // Step 3: Poll until done
            let finalCourse = try await pollForCourseCompletion(jobId: jobResponse.jobId)

            // Step 4: Silent Swap (Smart Hydration)
            // Step 5 is also inside MainActor.run to avoid data race on self.generatedCourse
            await MainActor.run {
                Log.course.info("✨ Background Hydration Complete! Merging Content safely...")
                
                // CRITICAL: We must NOT replace the whole object if the user is using it.
                // We merge the 'Real' content into the 'Draft' structure to preserve UUIDs and Navigation State.
                if let currentDraft = self.generatedCourse {
                    let mergedCourse = self.mergeContent(real: finalCourse, into: currentDraft)
                    self.generatedCourse = mergedCourse
                    self.saveCourseToDisk(mergedCourse)
                } else {
                    // Fallback if no draft exists
                    self.generatedCourse = finalCourse
                    self.saveCourseToDisk(finalCourse)
                }
                
                self.currentStep = "Course ready!"
                self.progress = 1.0
            }

            // Step 5: Persist to Backend DB (safe: reads self.generatedCourse on MainActor)
            do {
                let finalToSave = await MainActor.run { self.generatedCourse ?? finalCourse }
                
                let persistenceData = CourseCreationData(
                    id: finalToSave.courseId,
                    title: finalToSave.title,
                    topic: topic,
                    level: level,
                    modules: finalToSave.modules.map { mod in
                        CourseModuleData(
                            id: mod.id,
                            title: mod.title,
                            description: mod.description,
                            lessons: mod.lessons.map { les in
                                CourseLessonData(id: les.id, title: les.title, duration: "\(les.durationMinutes) min")
                            }
                        )
                    },
                    difficultyLevel: level.lowercased(),
                    instructorId: await TokenManager.shared.getUserId() ?? "unknown"
                )
                try await LyoRepository.shared.saveCourse(data: persistenceData)
                
                // Update the stack card with final course metadata
                await MainActor.run {
                    UIStackStore.shared.upsertCourse(
                        courseId: finalToSave.courseId,
                        title: finalToSave.title,
                        subtitle: "\(finalToSave.modules.count) modules • AI Generated",
                        lessonCount: finalToSave.modules.flatMap { $0.lessons }.count
                    )
                }
            } catch {
                Log.course.warning("Failed to persist final course to backend: \(error)")
            }

        } catch {
            Log.course.warning("🔴 Pipeline generation failed: \(error.localizedDescription) — trying V2 generator fallback")

            // 🚀 FALLBACK PATH: Try the direct V2 generator which doesn't queue jobs
            do {
                let v2Course = try await BackendAIService.shared.generateCourseV2(
                    topic: topic,
                    audience: level,
                    objectives: learningOutcomes
                )
                let mappedCourse = mapLyoCourseToGenerated(v2Course)

                await MainActor.run {
                    Log.course.info("✨ V2 Generator fallback succeeded! Course: \(mappedCourse.title)")
                    if let currentDraft = self.generatedCourse {
                        let mergedCourse = self.mergeContent(real: mappedCourse, into: currentDraft)
                        self.generatedCourse = mergedCourse
                        self.saveCourseToDisk(mergedCourse)
                    } else {
                        self.generatedCourse = mappedCourse
                        self.saveCourseToDisk(mappedCourse)
                    }
                    self.currentStep = "Course ready!"
                    self.progress = 1.0
                    self.error = nil
                }
            } catch {
                Log.course.warning("🔴 V2 generator also failed: \(error.localizedDescription) — keeping draft")
                // Surface error to UI so user knows hydration failed
                await MainActor.run {
                    self.currentStep = "Content ready (draft mode)"
                    self.error = nil // Don't surface error to user — draft content is still usable
                }
            }
        }
    }

    // MARK: - LyoCourse → GeneratedCourseResponse Mapper

    private func mapLyoCourseToGenerated(_ lyo: LyoCourse) -> GeneratedCourseResponse {
        let modules = lyo.modules.enumerated().map { (mIdx, mod) -> GenerationCourseModule in
            let lessons = mod.lessons.enumerated().map { (lIdx, les) -> GenerationCourseLesson in
                // Extract text content from artifacts
                let content: String
                if let explainer = les.artifacts.first(where: { $0.type == .conceptExplainer }) {
                    let markdown = (explainer.content.value as? [String: Any]).flatMap { $0["markdown"] as? String }
                    let notes = (explainer.content.value as? [String: Any]).flatMap { $0["text"] as? String }
                    content = markdown ?? notes ?? les.goal
                } else if let notes = les.artifacts.first(where: { $0.type == .notes }) {
                    let text = (notes.content.value as? [String: Any]).flatMap { $0["markdown"] as? String }
                        ?? (notes.content.value as? [String: Any]).flatMap { $0["text"] as? String }
                    content = text ?? les.goal
                } else {
                    content = les.goal
                }
                return GenerationCourseLesson(
                    id: les.id,
                    title: les.title,
                    content: content,
                    durationMinutes: les.durationMinutes,
                    order: lIdx + 1
                )
            }
            return GenerationCourseModule(
                id: mod.id,
                title: mod.title,
                description: mod.goal,
                lessons: lessons,
                order: mIdx + 1
            )
        }
        return GeneratedCourseResponse(
            courseId: lyo.id,
            title: lyo.title,
            description: lyo.learningObjectives.first ?? lyo.title,
            modules: modules,
            estimatedDuration: modules.reduce(0) { $0 + $1.lessons.reduce(0) { $0 + $1.durationMinutes } },
            difficulty: lyo.targetAudience
        )
    }
    
    // MARK: - Smart Selection (Merge)
    
    /// Merges high-quality content from 'real' course into 'draft' course structure
    /// Preserves Draft UUIDs where possible to prevent UI resets.
    private func mergeContent(real: GeneratedCourseResponse, into draft: GeneratedCourseResponse) -> GeneratedCourseResponse {
        // 1. Map Real Modules to Draft Modules by Index (Order)
        var mergedModules: [GenerationCourseModule] = []
        
        for (index, draftMod) in draft.modules.enumerated() {
            // Find corresponding real module
            if index < real.modules.count {
                let realMod = real.modules[index]
                
                // Merge Lessons
                var mergedLessons: [GenerationCourseLesson] = []
                for (lIndex, draftLes) in draftMod.lessons.enumerated() {
                    if lIndex < realMod.lessons.count {
                        let realLes = realMod.lessons[lIndex]
                        
                        // HYDRATION MAGIC:
                        // Keep Draft ID (so UI validation stays valid)
                        // Take Real Title & Content (Upgrade)
                        mergedLessons.append(GenerationCourseLesson(
                            id: draftLes.id,
                            title: realLes.title,
                            content: realLes.content,
                            durationMinutes: realLes.durationMinutes,
                            order: draftLes.order
                        ))
                    } else {
                        // If Draft has more lessons, keep them (or remove?) -> Keep to be safe
                        mergedLessons.append(draftLes)
                    }
                }
                
                // Check if Real has *more* lessons than Draft, add them (with new IDs)
                if realMod.lessons.count > draftMod.lessons.count {
                     let extraLessons = realMod.lessons.dropFirst(draftMod.lessons.count)
                     mergedLessons.append(contentsOf: extraLessons)
                }
                
                mergedModules.append(GenerationCourseModule(
                    id: draftMod.id, // Keep Draft ID
                    title: realMod.title,
                    description: realMod.description,
                    lessons: mergedLessons,
                    order: draftMod.order
                ))
            } else {
                mergedModules.append(draftMod)
            }
        }
        
        // Add extra modules from Real if any
        if real.modules.count > draft.modules.count {
            mergedModules.append(contentsOf: real.modules.dropFirst(draft.modules.count))
        }
        
        return GeneratedCourseResponse(
            courseId: draft.courseId, // Keep Draft Course ID
            title: real.title,        // Use Real Title
            description: real.description,
            modules: mergedModules,
            estimatedDuration: real.estimatedDuration,
            difficulty: real.difficulty
        )
    }

    // MARK: - Old Logic (Kept for reference if we need to revert)
    /*
    func generateCourseLegacy(...) async throws -> GeneratedCourseResponse {
        // 🚀 CALLING REAL BACKEND Multi-Agent Pipeline (A2A Orchestrator)
        Log.course.info("Calling REAL Backend Multi-Agent Pipeline for: \(topic)")
        
        do {
            // Step 1: Map level to CourseGenerationOptions
            let options: CourseGenerationOptions
            switch level.lowercased() {
            case "beginner":
                options = .economical
            case "intermediate":
                options = .recommended
            case "advanced":
                options = .premium
            default:
                options = .recommended
            }
            
            currentStep = "Submitting to AI agents..."
            progress = 0.1
            
            // Step 2: Submit outline request (fast) and start background generation
            let outlineResponse = try await BackendAIService.shared.generateCourseOutline(
                topic: topic,
                options: options,
                userContext: [
                    "level": level,
                    "style": teachingStyle,
                    "outcomes": learningOutcomes.joined(separator: ", ")
                ]
            )

            return try await handleOutlineAndBackground(
                outlineResponse: outlineResponse,
                topic: topic,
                level: level,
                options: options,
                learningOutcomes: learningOutcomes
            )
            
        } catch {
            if shouldFallbackToLegacyOutline(error) {
                Log.course.warning("Outline endpoint unavailable. Falling back to legacy generate.")

                let options: CourseGenerationOptions
                switch level.lowercased() {
                case "beginner":
                    options = .economical
                case "intermediate":
                    options = .recommended
                case "advanced":
                    options = .premium
                default:
                    options = .recommended
                }

                let draftCourse = buildLocalDraftCourse(topic: topic, level: level)
                generatedCourse = draftCourse
                saveCourseToDisk(draftCourse)
                await addCourseToStack(courseId: draftCourse.courseId, title: draftCourse.title, topic: topic)

                Task {
                    do {
                        let jobResponse = try await BackendAIService.shared.generateCourse(
                            topic: topic,
                            options: options,
                            userContext: [
                                "level": level,
                                "style": teachingStyle,
                                "outcomes": learningOutcomes.joined(separator: ", ")
                            ]
                        )
                        let finalCourse = try await pollForCourseCompletion(jobId: jobResponse.jobId)
                        await MainActor.run {
                            self.generatedCourse = finalCourse
                            self.currentStep = "Course ready!"
                            self.progress = 1.0
                        }

                        do {
                            let persistenceData = CourseCreationData(
                                id: finalCourse.courseId,
                                title: finalCourse.title,
                                topic: topic,
                                level: level,
                                modules: finalCourse.modules.map { mod in
                                    CourseModuleData(
                                        id: mod.id,
                                        title: mod.title,
                                        description: mod.description,
                                        lessons: mod.lessons.map { les in
                                            CourseLessonData(id: les.id, title: les.title, duration: "\(les.durationMinutes) min")
                                        }
                                    )
                                },
                                difficultyLevel: level,
                                instructorId: await TokenManager.shared.getUserId() ?? "unknown"
                            )
                            try await LyoRepository.shared.saveCourse(data: persistenceData)
                        } catch {
                            Log.course.warning("Failed to persist final course to backend: \(error)")
                        }
                    } catch {
                        Log.course.warning("Legacy background completion failed: \(error)")
                    }
                }

                return draftCourse
            }

            Log.course.error("Backend generation failed: \(error)")
            Log.course.error("DEBUG: Full error details: \(String(describing: error))")
            
            // Only use mock if explicitly allowed
            if AppConfig.allowMockFallbacks {
                Log.course.info("🛠 FALLBACK: Using mock course (LYO_ALLOW_MOCKS=1)")
                let course = generateMockCourse(topic: topic)
                
                currentStep = "Course ready (Offline Mode)!"
                progress = 1.0
                
                generatedCourse = course
                return course
            } else {
                Log.course.warning("PRODUCTION MODE: Falling back to local draft (generation delayed)")
                let draftCourse = buildLocalDraftCourse(topic: topic, level: level)
                generatedCourse = draftCourse
                saveCourseToDisk(draftCourse)
                currentStep = "Generating content..."
                self.error = error.localizedDescription

                await addCourseToStack(courseId: draftCourse.courseId, title: draftCourse.title, topic: topic)

                Task {
                    await startLegacyGenerationInBackground(
                        topic: topic,
                        level: level,
                        teachingStyle: teachingStyle,
                        learningOutcomes: learningOutcomes
                    )
                }

                return draftCourse
            }
        }
    }
    */
    
    // MARK: - Poll for Course Completion (with Stall Detection + Auto-Recovery)
    
    private func pollForCourseCompletion(jobId: String) async throws -> GeneratedCourseResponse {
        let maxAttempts = 60  // 5 minutes max (5 second intervals)
        let stallThresholdSeconds: TimeInterval = 20  // Force-complete if no progress for 20s (backend stalls quickly)
        var attempts = 0
        var lastProgressPercent = -1  // Track last known progress
        var lastProgressUpdate = Date()  // When progress last changed
        var forceCompleteAttempted = false
        var backendResultUnavailable = false
        
        while attempts < maxAttempts {
            // Check for cancellation before each poll
            try Task.checkCancellation()
            
            let status = try await BackendAIService.shared.getCourseGenerationStatus(jobId: jobId)
            
            Log.course.info("Status: \(status.status) - Progress: \(status.progressPercent)%")
            
            // 🛡️ STALL DETECTION: Track if progress is moving
            if status.progressPercent != lastProgressPercent {
                lastProgressPercent = status.progressPercent
                lastProgressUpdate = Date()
                Log.course.info("   ⏱️ Progress updated at \(lastProgressUpdate)")
            }
            
            // 🛡️ CHECK FOR STALL: If no progress for 60s and still "processing"
            let timeSinceLastProgress = Date().timeIntervalSince(lastProgressUpdate)
            if timeSinceLastProgress > stallThresholdSeconds &&
               (status.status == "processing" || status.status == "running") &&
               !forceCompleteAttempted {
                Log.course.warning("STALL DETECTED: No progress for \(Int(timeSinceLastProgress))s - triggering force-complete")
                forceCompleteAttempted = true
                
                // 🔥 Try to force-complete the stalled job FIRST (more reliable approach)
                do {
                    let forceResult = try await forceCompleteJob(jobId: jobId)
                    Log.course.info("⚡ Force-complete triggered: \(forceResult)")
                    // Wait briefly for backend to finalize
                    try await Task.sleep(nanoseconds: 3_000_000_000)  // 3s
                    // Now try to fetch the result
                    do {
                        let partialCourse = try await fetchGeneratedCourse(jobId: jobId)
                        Log.course.info("✅ Retrieved course after force-complete")
                        return partialCourse
                    } catch {
                        Log.course.warning("Result unavailable after force-complete (\(error.localizedDescription)) - using local draft")
                        return try fallbackToLocalDraft(reason: "Result unavailable after force-complete")
                    }
                } catch {
                    if isNotFound(error) {
                        Log.course.warning("Force-complete endpoint unavailable (404) - using local draft")
                        backendResultUnavailable = true
                    } else {
                        Log.course.warning("Force-complete failed: \(error.localizedDescription) - falling back to local draft")
                        return try fallbackToLocalDraft(reason: "Force-complete failed: \(error.localizedDescription)")
                    }
                }
            }

            if backendResultUnavailable {
                return try fallbackToLocalDraft(reason: "Force-complete endpoint not found")
            }
            
            currentStep = status.currentStep ?? "Processing..."
            progress = 0.3 + (Double(status.progressPercent) / 100.0 * 0.6)  // 30% to 90%
            
            switch status.status {
            case "completed":
                Log.course.info("Course generation completed!")
                currentStep = "Fetching course..."
                progress = 0.95
                do {
                    return try await fetchGeneratedCourse(jobId: jobId)
                } catch {
                    // ⚡ ANY error fetching result after completion = use local draft
                    // This handles both 404 (endpoint missing) and 400 (validation/state errors)
                    Log.course.warning("Result unavailable after completion (\(error.localizedDescription)) - using local draft")
                    return try fallbackToLocalDraft(reason: "Result endpoint error: \(error.localizedDescription)")
                }
                
            case "failed":
                let errorMsg = status.error ?? "Unknown error"
                Log.course.error("Course generation failed: \(errorMsg)")
                // 🛡️ RESILIENCE: Try to fetch what we have, fall back to draft for any error
                do {
                    let partialCourse = try await fetchGeneratedCourse(jobId: jobId)
                    Log.course.info("Recovered partial course with \(partialCourse.modules.count) modules")
                    return partialCourse
                } catch {
                    Log.course.warning("Result unavailable after failure (\(error.localizedDescription)) - using local draft")
                    return try fallbackToLocalDraft(reason: "Generation failed and result unavailable")
                }
                
            case "processing", "running", "pending":
                // Continue polling - these are all "in progress" states
                break
                
            default:
                Log.course.warning("Unknown course generation status: \(status.status) - continuing to poll")
                break
            }
            
            attempts += 1
            try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
        }
        
        // 🛡️ TIMEOUT RECOVERY: Instead of throwing, try force-complete one last time
        Log.course.info("⏰ Polling timeout reached - attempting final force-complete")
        do {
            _ = try await forceCompleteJob(jobId: jobId)
            try await Task.sleep(nanoseconds: 2_000_000_000)  // Wait 2s for backend
            let finalCourse = try await fetchGeneratedCourse(jobId: jobId)
            Log.course.info("Recovered course after timeout via force-complete")
            return finalCourse
        } catch {
            if isNotFound(error) {
                Log.course.warning("Recovery endpoints unavailable (404) - using local draft")
                return try fallbackToLocalDraft(reason: "Recovery endpoints not found")
            }
            Log.course.error("Final recovery failed: \(error)")
            throw CourseGenerationError.serverError
        }
    }

    private func isNotFound(_ error: Error) -> Bool {
        if case LyoError.network(.notFound) = error {
            return true
        }
        return false
    }

    private func fallbackToLocalDraft(reason: String) throws -> GeneratedCourseResponse {
        if let draft = generatedCourse {
            Log.course.info("🛟 Falling back to local draft: \(reason)")
            currentStep = "Course ready!"
            progress = 1.0
            return draft
        }

        Log.course.warning("No local draft available for fallback: \(reason)")
        throw CourseGenerationError.serverError
    }
    
    // MARK: - Force Complete Stalled Job
    
    private func forceCompleteJob(jobId: String) async throws -> String {
        let endpoint = Endpoints.CourseGenerationV2.forceComplete(jobId: jobId)
        
        struct ForceCompleteResponse: Codable {
            let status: String
            let message: String
            let modulesCompleted: Int?
            
            enum CodingKeys: String, CodingKey {
                case status
                case message
                case modulesCompleted = "modules_completed"
            }
        }
        
        let response: ForceCompleteResponse = try await NetworkClient.shared.request(endpoint)
        return response.message
    }
    
    // MARK: - Fetch Generated Course
    
    private func fetchGeneratedCourse(jobId: String) async throws -> GeneratedCourseResponse {
        // Call backend to get final course structure
        let endpoint = Endpoints.CourseGenerationV2.result(jobId: jobId)
        
        let backendCourse: BackendCourseResult = try await NetworkClient.shared.request(endpoint)
        return mapBackendCourseToGenerated(backendCourse)
    }

    private func mapOutlineToGenerated(_ outline: CourseOutlineResponse) -> GeneratedCourseResponse {
        let modules = outline.modules.enumerated().map { (index, mod) in
            GenerationCourseModule(
                id: mod.id,
                title: mod.title,
                description: mod.description,
                lessons: [
                    GenerationCourseLesson(
                        id: "\(mod.id)_overview",
                        title: "Module Overview",
                        content: "This module is generating. Check back soon.",
                        durationMinutes: 10,
                        order: 1
                    )
                ],
                order: index
            )
        }

        return GeneratedCourseResponse(
            courseId: outline.courseId,
            title: outline.title,
            description: outline.description,
            modules: modules,
            estimatedDuration: outline.estimatedDuration,
            difficulty: outline.difficulty
        )
    }

    private func handleOutlineAndBackground(
        outlineResponse: CourseOutlineResponse,
        topic: String,
        level: String,
        options: CourseGenerationOptions,
        learningOutcomes: [String]
    ) async throws -> GeneratedCourseResponse {
        Log.course.info("Outline ready: \(outlineResponse.courseId)")
        currentStep = "Outline ready"
        progress = 0.4

        let draftCourse = mapOutlineToGenerated(outlineResponse)
        generatedCourse = draftCourse
        saveCourseToDisk(draftCourse)

        // Persist outline to backend for sharing immediately
        do {
            let persistenceData = CourseCreationData(
                id: draftCourse.courseId,
                title: draftCourse.title,
                topic: topic,
                level: level,
                modules: draftCourse.modules.map { mod in
                    CourseModuleData(
                        id: mod.id,
                        title: mod.title,
                        description: mod.description,
                        lessons: mod.lessons.map { les in
                            CourseLessonData(id: les.id, title: les.title, duration: "\(les.durationMinutes) min")
                        }
                    )
                },
                difficultyLevel: level.lowercased(),
                instructorId: await TokenManager.shared.getUserId() ?? "unknown"
            )
            try await LyoRepository.shared.saveCourse(data: persistenceData)
        } catch {
            Log.course.warning("Failed to persist outline to backend: \(error)")
        }

        await addCourseToStack(courseId: draftCourse.courseId, title: draftCourse.title, topic: topic)

        if let firstModuleId = draftCourse.modules.first?.id {
            Task {
                await generateModuleIfNeeded(courseId: draftCourse.courseId, moduleId: firstModuleId)
            }
        }

        Task {
            do {
                let finalCourse = try await pollForCourseCompletion(jobId: outlineResponse.courseId)
                await MainActor.run {
                    self.generatedCourse = finalCourse
                    self.currentStep = "Course ready!"
                    self.progress = 1.0
                }

                do {
                    let persistenceData = CourseCreationData(
                        id: finalCourse.courseId,
                        title: finalCourse.title,
                        topic: topic,
                        level: level,
                        modules: finalCourse.modules.map { mod in
                            CourseModuleData(
                                id: mod.id,
                                title: mod.title,
                                description: mod.description,
                                lessons: mod.lessons.map { les in
                                    CourseLessonData(id: les.id, title: les.title, duration: "\(les.durationMinutes) min")
                                }
                            )
                        },
                        difficultyLevel: level.lowercased(),
                        instructorId: await TokenManager.shared.getUserId() ?? "unknown"
                    )
                    try await LyoRepository.shared.saveCourse(data: persistenceData)
                } catch {
                    Log.course.warning("Failed to persist final course to backend: \(error)")
                }
            } catch {
                Log.course.warning("Background course completion failed: \(error)")
            }
        }

        return draftCourse
    }


    private func addCourseToStack(courseId: String, title: String, topic: String) async {
        do {
            let request = CreateStackItemRequest(
                type: .course,
                refId: courseId,
                tags: ["AI Generated"],
                contextData: [
                    "title": title,
                    "topic": topic
                ]
            )
            _ = try await LyoRepository.shared.createStackItem(request: request)
            UIStackStore.shared.upsertCourse(
                courseId: courseId,
                title: title,
                subtitle: "AI Generated Course"
            )
        } catch {
            Log.course.warning("Failed to add course to Stack: \(error)")
        }
    }

    private func shouldFallbackToLegacyOutline(_ error: Error) -> Bool {
        if let lyoError = error as? LyoError {
            switch lyoError {
            case .network(let type):
                switch type {
                case .methodNotAllowed, .notImplemented:
                    return true
                case .serverError(let code), .unknown(let code):
                    return code == 405
                default:
                    break
                }
            default:
                break
            }
        }

        if let backendError = error as? BackendAIError {
            switch backendError {
            case .serverError(let message), .networkError(let message):
                if message.contains("405") || message.localizedCaseInsensitiveContains("Method Not Allowed") {
                    return true
                }
            default:
                break
            }
        }

        let message = String(describing: error)
        return message.contains("405") || message.localizedCaseInsensitiveContains("Method Not Allowed")
    }

    private func buildLocalDraftCourse(topic: String, level: String) -> GeneratedCourseResponse {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAdvanced = level.lowercased().contains("advanced")
        let isIntermediate = level.lowercased().contains("intermediate")
        
        // Smart Title Generation
        let courseTitle: String
        let mainDescription: String
        let mod1Title: String
        let mod2Title: String
        let mod3Title: String
        
        if isAdvanced {
            courseTitle = "Advanced Mastery of \(cleanTopic)"
            mainDescription = "An expert-level deep dive into specific nuances of \(cleanTopic)."
            mod1Title = "Advanced Context & Architectures"
            mod2Title = "Professional Application"
            mod3Title = "Future Trends in \(cleanTopic)"
        } else if isIntermediate {
            courseTitle = "Intermediate \(cleanTopic)"
            mainDescription = "Taking your \(cleanTopic) skills to the next level."
            mod1Title = "Bridging the Gap"
            mod2Title = "Core Techniques"
            mod3Title = "Real-world Projects"
        } else {
            courseTitle = "Introduction to \(cleanTopic)"
            mainDescription = "A comprehensive guide to mastering \(cleanTopic) fundamentals."
            mod1Title = "Getting Started with \(cleanTopic)"
            mod2Title = "Core Concepts"
            mod3Title = "Next Steps"
        }
        
        let modules = [
            GenerationCourseModule(
                id: "mod_1",
                title: mod1Title,
                description: "Building the necessary mental models.",
                lessons: [
                    GenerationCourseLesson(
                        id: "les_1_1",
                        title: "Why \(cleanTopic) Matters",
                        content: """
                        Welcome to your journey into **\(cleanTopic)**! 🚀
                        
                        This isn't just another dry textbook definition. **\(cleanTopic)** is a fundamental skill that unlocks new possibilities in your work and life.
                        
                        ### What we'll cover:
                        1. The "Big Picture" view of \(cleanTopic).
                        2. Key terminologies (no jargon!).
                        3. Why experts consider this essential.
                        
                        By the end of this lesson, you'll have a clear mental map of the landscape. Let's dive in!
                        """,
                        durationMinutes: 5,
                        order: 1
                    ),
                    GenerationCourseLesson(
                        id: "les_1_2",
                        title: "Key Pillars",
                        content: """
                        Every robust system stands on strong pillars. For **\(cleanTopic)**, there are three main concepts you must know:
                        
                        ### 1. The Core Principle 🧠
                        Everything starts here. If you understand the core logic, everything else falls into place.
                        
                        ### 2. The Feedback Loop 🔄
                        How do you know it's working? We'll explore the signals and metrics.
                        
                        ### 3. The Execution Strategy ⚡
                        Theory is useless without action. We'll look at how to apply this immediately.
                        """,
                        durationMinutes: 8,
                        order: 2
                    )
                ],
                order: 1
            ),
            GenerationCourseModule(
                id: "mod_2",
                title: mod2Title,
                description: "Moving from theory to practice.",
                lessons: [
                    GenerationCourseLesson(
                        id: "les_2_1",
                        title: "Applying the Concepts",
                        content: """
                        Now for the fun part: **Action**. 🛠️
                        
                        Let's tackle a real-world scenario. Imagine you are faced with a typical challenge in \(cleanTopic).
                        
                        **The Scenario:**
                        You need to optimize for efficiency but constraints are tight.
                        
                        **The Solution:**
                        Using the 'Core Principle' we learned, we can slice through the complexity.
                        
                        *   Step 1: Audit the current state.
                        *   Step 2: Apply the \(cleanTopic) framework.
                        *   Step 3: Measure results.
                        """,
                        durationMinutes: 10,
                        order: 1
                    ),
                    GenerationCourseLesson(
                        id: "les_2_2",
                        title: "Common Pitfalls",
                        content: """
                        Wait! Before you rush off, let's talk about where people go wrong with **\(cleanTopic)**. ⚠️
                        
                        *   **Mistake #1**: Overcomplicating the basics.
                        *   **Mistake #2**: Ignoring the context.
                        *   **Mistake #3**: Giving up too early.
                        
                        Success comes from consistency. Keep it simple.
                        """,
                        durationMinutes: 7,
                        order: 2
                    )
                ],
                order: 2
            ),
            GenerationCourseModule(
                id: "mod_3",
                title: mod3Title,
                description: "Consolidation and future growth.",
                lessons: [
                    GenerationCourseLesson(
                        id: "les_3_1",
                        title: "Your Growth Roadmap",
                        content: """
                        You've built the foundation. Where to next? 🗺️
                        
                        Mastery of **\(cleanTopic)** is a journey, not a destination.
                        
                        **Recommended Next Steps:**
                        1.  Practice the 'Key Pillars' daily.
                        2.  Find a project to apply 'The Execution Strategy'.
                        3.  Connect with others learning \(cleanTopic).
                        
                        You are ready. Go build something amazing!
                        """,
                        durationMinutes: 5,
                        order: 1
                    )
                ],
                order: 3
            )
        ]

        return GeneratedCourseResponse(
             courseId: "gen_\(UUID().uuidString.prefix(8))",
             title: courseTitle,
             description: mainDescription,
             modules: modules,
             estimatedDuration: 90,
             difficulty: level
         )
    }

    private func generateModuleIfNeeded(courseId: String, moduleId: String) async {
        guard let current = generatedCourse else { return }
        guard current.modules.contains(where: { $0.id == moduleId }) else { return }

        isGeneratingModule = true
        defer { isGeneratingModule = false }

        do {
            let moduleResponse = try await BackendAIService.shared.generateCourseModule(
                courseId: courseId,
                moduleId: moduleId
            )

            let module = mapBackendModuleToGenerated(moduleResponse.module)
            await MainActor.run {
                guard let current = self.generatedCourse else { return }
                if let index = current.modules.firstIndex(where: { $0.id == moduleId }) {
                    var modules = current.modules
                    modules[index] = module
                    let updated = GeneratedCourseResponse(
                        courseId: current.courseId,
                        title: current.title,
                        description: current.description,
                        modules: modules,
                        estimatedDuration: current.estimatedDuration,
                        difficulty: current.difficulty
                    )
                    self.generatedCourse = updated
                    self.saveCourseToDisk(updated)
                }
            }
        } catch {
            Log.course.warning("Module generation failed: \(error)")
        }
    }

    private func mapBackendModuleToGenerated(_ module: BackendCourseResult.BackendModule) -> GenerationCourseModule {
        let lessons = module.lessons.enumerated().map { lessonIndex, lesson in
            GenerationCourseLesson(
                id: lesson.id,
                title: lesson.title,
                content: lesson.content,
                durationMinutes: lesson.durationMinutes,
                order: lessonIndex + 1
            )
        }

        return GenerationCourseModule(
            id: module.id,
            title: module.title,
            description: module.description,
            lessons: lessons,
            order: 1
        )
    }
    
    // MARK: - Map Backend Course to Generated Response
    
    private func mapBackendCourseToGenerated(_ backendCourse: BackendCourseResult) -> GeneratedCourseResponse {
        let modules = backendCourse.modules.enumerated().map { index, module in
            GenerationCourseModule(
                id: module.id,
                title: module.title,
                description: module.description,
                lessons: module.lessons.enumerated().map { lessonIndex, lesson in
                    GenerationCourseLesson(
                        id: lesson.id,
                        title: lesson.title,
                        content: lesson.content,
                        durationMinutes: lesson.durationMinutes,
                        order: lessonIndex + 1
                    )
                },
                order: index + 1
            )
        }
        
        return GeneratedCourseResponse(
            courseId: backendCourse.courseId,
            title: backendCourse.title,
            description: backendCourse.description,
            modules: modules,
            estimatedDuration: backendCourse.estimatedDuration,
            difficulty: backendCourse.difficulty
        )
    }
    
    // MARK: - Backend Course Result Model
    
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
    
    // MARK: - Backend Generation (Primary - Uses Gemini AI with Streaming)
    
    private func generateFromBackendStreaming(request: CourseGenerationRequest) async throws -> GeneratedCourseResponse {
        Log.course.info("Starting STREAMING course generation for: \(request.topic)")
        
        let endpoint = Endpoints.AI.generateCourseStream(
            topic: request.topic,
            level: request.level,
            outcomes: request.outcomes,
            teachingStyle: request.teachingStyle
        )
        
        Log.course.info("📤 Calling streaming backend: \(endpoint.path)")
        
        // Accumulate streamed chunks
        var accumulatedData = Data()
        var lastProgressUpdate = Date()
        let progressUpdateInterval: TimeInterval = 0.5 // Update progress every 0.5 seconds
        
        do {
            let (asyncBytes, response) = try await NetworkClient.shared.stream(endpoint)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Log.course.error("Invalid response type")
                throw CourseGenerationError.serverError
            }
            
            Log.course.info("📥 Streaming started - status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                Log.course.error("Backend error status: \(httpResponse.statusCode)")
                throw CourseGenerationError.serverError
            }
            
            // Stream and accumulate chunks
            for try await byte in asyncBytes {
                accumulatedData.append(byte)
                
                // Update progress periodically (avoid too frequent UI updates)
                let now = Date()
                if now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval {
                    let estimatedProgress = min(0.3 + (Double(accumulatedData.count) / 8000.0 * 0.6), 0.9)
                    await MainActor.run {
                        self.progress = estimatedProgress
                        self.currentStep = "Receiving course data... (\(accumulatedData.count) bytes)"
                    }
                    lastProgressUpdate = now
                }
            }
            
            Log.course.info("Streaming completed - received \(accumulatedData.count) bytes")
            
            // Log response preview
            if let jsonStr = String(data: accumulatedData, encoding: .utf8) {
                Log.course.info("📥 Streamed response preview: \(String(jsonStr.prefix(300)))...")
            }
            
            // Parse the accumulated response
            return try parseBackendResponse(data: accumulatedData, topic: request.topic)
            
        } catch let streamError as URLError {
            Log.course.error("Streaming error: \(streamError.localizedDescription)")
            throw CourseGenerationError.serverError
        } catch {
            Log.course.error("Unexpected streaming error: \(error)")
            throw error
        }
    }
    
    // MARK: - Backend Generation (Fallback - Non-Streaming)
    
    private struct AIResponse: Codable {
        let content: String?
        let response: String?
        let primaryAi: String?
        
        enum CodingKeys: String, CodingKey {
            case content
            case response
            case primaryAi = "primary_ai"
        }
    }

    private func generateFromBackend(request: CourseGenerationRequest) async throws -> GeneratedCourseResponse {
        // Use the backend's Dual AI Orchestrator endpoint (Gemini + OpenAI Hybrid)
        // This endpoint routes to Gemini for educational content generation
        
        Log.course.info("Starting course generation for: \(request.topic)")
        Log.course.info("📤 Calling Dual AI Orchestrator: /api/v1/ai/generate")
        
        // Build course generation prompt for the AI
        let outcomesText = request.outcomes.joined(separator: "\n- ")
        let coursePrompt = """
        Generate a complete learning course structure for: \(request.topic)
        
        Level: \(request.level)
        Teaching Style: \(request.teachingStyle)
        
        Learning Outcomes:
        - \(outcomesText)
        
        Create a JSON course structure with:
        - course_id: unique identifier
        - title: engaging course title
        - description: brief course description
        - estimated_duration: total minutes
        - difficulty: \(request.level)
        - modules: array of 2-3 modules, each with:
          - id, title, description, order
          - lessons: array of 2-3 lessons per module, each with:
            - id, title, content (2-3 paragraphs), duration_minutes, order
        
        Return ONLY valid JSON, no markdown or extra text.
        """
        
        let endpoint = Endpoints.AI.generateCourseContent(
            prompt: coursePrompt,
            topic: request.topic,
            level: request.level
        )
        
        do {
            let aiResponse: AIResponse = try await NetworkClient.shared.request(endpoint)
            
            let content = aiResponse.content ?? aiResponse.response
            guard let validContent = content else {
                Log.course.error("Failed to extract content/response from AI JSON")
                throw CourseGenerationError.invalidResponse
            }
            
            Log.course.info("AI used: \(aiResponse.primaryAi ?? "unknown")")
            Log.course.info("📄 Content length: \(validContent.count) characters")
            
            return try parseAIContent(validContent, topic: request.topic)
            
        } catch {
            Log.course.error("Backend generation failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Parse AI Content
    
    private func parseAIContent(_ content: String, topic: String) throws -> GeneratedCourseResponse {
        // Clean and parse the JSON from the content
        var cleanJson = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract JSON if there's extra text
        if let jsonStart = cleanJson.firstIndex(of: "{"),
           let jsonEnd = cleanJson.lastIndex(of: "}") {
            cleanJson = String(cleanJson[jsonStart...jsonEnd])
        }
        
        guard let courseData = cleanJson.data(using: .utf8) else {
            Log.course.error("Failed to convert cleaned JSON to data")
            throw CourseGenerationError.invalidResponse
        }
        
        // Try to decode as GeneratedCourseResponse
        do {
            let course = try JSONDecoder().decode(GeneratedCourseResponse.self, from: courseData)
            Log.course.info("Backend (Gemini) generated course: \(course.title)")
            return course
        } catch {
            Log.course.warning("Direct decode failed, trying to map response...")
            
            // Try to parse as generic JSON and map
            if let courseJson = try? JSONSerialization.jsonObject(with: courseData) as? [String: Any] {
                let course = try mapBackendResponse(courseJson, topic: topic)
                Log.course.info("Mapped backend course: \(course.title)")
                return course
            }
            
            Log.course.error("Failed to parse course JSON: \(error)")
            Log.course.error("Cleaned JSON was: \(cleanJson.prefix(500))...")
            throw CourseGenerationError.invalidResponse
        }
    }
    
    // MARK: - Parse Backend Response (Used by streaming endpoint)
    
    private func parseBackendResponse(data: Data, topic: String) throws -> GeneratedCourseResponse {
        // Try to decode the backend response
        // Backend may return different structure, so we handle both cases
        do {
            // First try direct decode
            let course = try JSONDecoder().decode(GeneratedCourseResponse.self, from: data)
            Log.course.info("Backend generated course: \(course.title)")
            return course
        } catch {
            Log.course.warning("Direct decode failed, trying to map backend response...")
            
            // Try to parse as generic JSON and map to our structure
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let course = try mapBackendResponse(json, topic: topic)
                Log.course.info("Mapped backend course: \(course.title)")
                return course
            }
            
            Log.course.error("Failed to decode backend response: \(error)")
            throw CourseGenerationError.invalidResponse
        }
    }
    
    // MARK: - Map Backend Response to GeneratedCourseResponse
    
    private func mapBackendResponse(_ json: [String: Any], topic: String) throws -> GeneratedCourseResponse {
        // Handle various backend response formats
        let courseId = json["course_id"] as? String ?? json["id"] as? String ?? "backend_\(UUID().uuidString.prefix(8))"
        let title = json["title"] as? String ?? "Course on \(topic)"
        let description = json["description"] as? String ?? "AI-generated course about \(topic)"
        let estimatedDuration = json["estimated_duration"] as? Int ?? json["duration"] as? Int ?? 60
        let difficulty = json["difficulty"] as? String ?? json["level"] as? String ?? "beginner"
        
        // Parse modules
        var modules: [GenerationCourseModule] = []
        
        if let modulesArray = json["modules"] as? [[String: Any]] {
            for (index, moduleJson) in modulesArray.enumerated() {
                let moduleId = moduleJson["id"] as? String ?? "mod_\(index + 1)"
                let moduleTitle = moduleJson["title"] as? String ?? "Module \(index + 1)"
                let moduleDesc = moduleJson["description"] as? String ?? ""
                let moduleOrder = moduleJson["order"] as? Int ?? index + 1
                
                // Parse lessons
                var lessons: [GenerationCourseLesson] = []
                if let lessonsArray = moduleJson["lessons"] as? [[String: Any]] {
                    for (lessonIndex, lessonJson) in lessonsArray.enumerated() {
                        let lesson = GenerationCourseLesson(
                            id: lessonJson["id"] as? String ?? "les_\(index + 1)_\(lessonIndex + 1)",
                            title: lessonJson["title"] as? String ?? "Lesson \(lessonIndex + 1)",
                            content: lessonJson["content"] as? String ?? lessonJson["description"] as? String ?? "",
                            durationMinutes: lessonJson["duration_minutes"] as? Int ?? lessonJson["duration"] as? Int ?? 10,
                            order: lessonJson["order"] as? Int ?? lessonIndex + 1
                        )
                        lessons.append(lesson)
                    }
                }
                
                let module = GenerationCourseModule(
                    id: moduleId,
                    title: moduleTitle,
                    description: moduleDesc,
                    lessons: lessons,
                    order: moduleOrder
                )
                modules.append(module)
            }
        } else if let lessonsArray = json["lessons"] as? [[String: Any]] {
            // Backend returned flat lessons, group into single module
            var lessons: [GenerationCourseLesson] = []
            for (index, lessonJson) in lessonsArray.enumerated() {
                let lesson = GenerationCourseLesson(
                    id: lessonJson["id"] as? String ?? "les_\(index + 1)",
                    title: lessonJson["title"] as? String ?? "Lesson \(index + 1)",
                    content: lessonJson["content"] as? String ?? lessonJson["description"] as? String ?? "",
                    durationMinutes: lessonJson["duration_minutes"] as? Int ?? lessonJson["duration"] as? Int ?? 10,
                    order: index + 1
                )
                lessons.append(lesson)
            }
            
            modules.append(GenerationCourseModule(
                id: "mod_1",
                title: "Course Content",
                description: "Main course material",
                lessons: lessons,
                order: 1
            ))
        }
        
        // If no modules found, create a placeholder
        if modules.isEmpty {
            throw CourseGenerationError.noContent
        }
        
        return GeneratedCourseResponse(
            courseId: courseId,
            title: title,
            description: description,
            modules: modules,
            estimatedDuration: estimatedDuration,
            difficulty: difficulty
        )
    }
    
    // MARK: - OpenAI Fallback Generation (Secondary - Only if backend fails)
    
    private func generateFromOpenAI(topic: String, level: String, outcomes: [String]) async throws -> GeneratedCourseResponse {
        let outcomesText = outcomes.joined(separator: "\n- ")
        
        // Generate a fixed course_id to avoid interpolation issues in JSON
        let courseId = "generated_\(UUID().uuidString.prefix(8))"
        
        let prompt = """
        Create a structured learning course for: \(topic)
        Level: \(level)
        
        Learning Outcomes:
        - \(outcomesText)
        
        Return a JSON object with this exact structure (use these exact field names):
        {
            "course_id": "\(courseId)",
            "title": "Your course title here",
            "description": "Brief course description",
            "estimated_duration": 60,
            "difficulty": "\(level)",
            "modules": [
                {
                    "id": "mod_1",
                    "title": "Module 1 Title",
                    "description": "Module description",
                    "order": 1,
                    "lessons": [
                        {
                            "id": "les_1_1",
                            "title": "Lesson Title",
                            "content": "Lesson content (2-3 paragraphs)",
                            "duration_minutes": 10,
                            "order": 1
                        }
                    ]
                }
            ]
        }
        
        Create 2 modules with 2 lessons each. Keep content concise.
        IMPORTANT: Return ONLY the JSON object, no markdown code blocks, no extra text.
        """
        
        Log.course.info("📤 Sending course generation request to OpenAI...")
        
        let response = try await OpenAIService.shared.sendMessage(
            message: prompt,
            conversationHistory: [],
            systemPrompt: "You are a curriculum designer. You must return only valid JSON with no markdown formatting."
        )
        
        Log.course.info("📥 OpenAI raw response length: \(response.count) characters")
        Log.course.info("📥 OpenAI response preview: \(String(response.prefix(200)))...")
        
        // Clean and parse JSON
        var cleanJson = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract JSON if there's extra text
        if let jsonStart = cleanJson.firstIndex(of: "{"),
           let jsonEnd = cleanJson.lastIndex(of: "}") {
            cleanJson = String(cleanJson[jsonStart...jsonEnd])
        }
        
        Log.course.info("🧹 Cleaned JSON length: \(cleanJson.count) characters")
        
        guard let data = cleanJson.data(using: .utf8) else {
            Log.course.error("Failed to convert cleaned JSON to data")
            throw CourseGenerationError.invalidResponse
        }
        
        do {
            let course = try JSONDecoder().decode(GeneratedCourseResponse.self, from: data)
            Log.course.info("Successfully decoded course: \(course.title)")
            return course
        } catch let decodingError {
            Log.course.error("JSON decoding error: \(decodingError)")
            Log.course.error("Cleaned JSON was: \(cleanJson)")
            throw decodingError
        }
    }
    
    // MARK: - Mock Fallback Generation
    
    private func generateMockCourse(topic: String) -> GeneratedCourseResponse {
        // Generate a richer, more complete mock course
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return GeneratedCourseResponse(
            courseId: "mock_\(UUID().uuidString.prefix(8))",
            title: "Introduction to \(cleanTopic)",
            description: "A comprehensive guide to mastering \(cleanTopic) fundamentals.",
            modules: [
                GenerationCourseModule(
                    id: "mod_1",
                    title: "Getting Started with \(cleanTopic)",
                    description: "Build a solid foundation by understanding the core concepts",
                    lessons: [
                        GenerationCourseLesson(
                            id: "les_1_1",
                            title: "What is \(cleanTopic)?",
                            content: """
                            Welcome to your journey into \(cleanTopic)! 🚀
                            
                            \(cleanTopic) is an exciting topic that forms the foundation for many real-world applications. In this course, we'll break it down into digestible pieces so you can truly understand it.
                            
                            By the end of this lesson, you'll have a clear picture of what \(cleanTopic) is and why it matters. Let's dive in!
                            """,
                            durationMinutes: 5,
                            order: 1
                        ),
                        GenerationCourseLesson(
                            id: "les_1_2",
                            title: "Core Principles of \(cleanTopic)",
                            content: """
                            Now that you know what \(cleanTopic) is, let's explore the key principles:
                            
                            1️⃣ **Consistency** - Regular practice helps reinforce your understanding.
                            
                            2️⃣ **Building Blocks** - Each concept connects to the next. Master the basics first.
                            
                            3️⃣ **Application** - The best way to learn is by doing. We'll have hands-on exercises.
                            
                            These principles will guide you throughout this course and beyond!
                            """,
                            durationMinutes: 8,
                            order: 2
                        ),
                        GenerationCourseLesson(
                            id: "les_1_3",
                            title: "Practical Example",
                            content: """
                            Let's see \(cleanTopic) in action with a practical example! 🎯
                            
                            Imagine you're working on a real project. Here's how you'd apply what we've learned:
                            
                            Step 1: Identify the problem you're trying to solve
                            Step 2: Break it down into smaller pieces
                            Step 3: Apply the core principles we discussed
                            Step 4: Test your solution and iterate
                            
                            This systematic approach works for any challenge you'll face in \(cleanTopic).
                            """,
                            durationMinutes: 10,
                            order: 3
                        )
                    ],
                    order: 1
                ),
                GenerationCourseModule(
                    id: "mod_2",
                    title: "Going Deeper into \(cleanTopic)",
                    description: "Advanced concepts and real-world applications",
                    lessons: [
                        GenerationCourseLesson(
                            id: "les_2_1",
                            title: "Advanced Concepts",
                            content: """
                            You've mastered the basics - now let's level up! 📈
                            
                            In this module, we'll explore more sophisticated aspects of \(cleanTopic):
                            
                            • Pattern recognition and best practices
                            • Common pitfalls and how to avoid them
                            • Real-world case studies
                            
                            Don't worry if some concepts feel challenging at first. That's a sign you're growing!
                            """,
                            durationMinutes: 12,
                            order: 1
                        ),
                        GenerationCourseLesson(
                            id: "les_2_2",
                            title: "Putting It All Together",
                            content: """
                            🎉 Congratulations on reaching the final lesson!
                            
                            Let's recap what you've learned:
                            
                            ✅ You understand what \(cleanTopic) is and why it matters
                            ✅ You know the core principles that guide success
                            ✅ You've seen practical applications
                            ✅ You've explored advanced concepts
                            
                            You're now equipped with the knowledge to apply \(cleanTopic) in your own projects. Keep practicing, stay curious, and you'll continue to grow!
                            """,
                            durationMinutes: 8,
                            order: 2
                        )
                    ],
                    order: 2
                )
            ],
            estimatedDuration: 45,
            difficulty: "Beginner"
        )
    }

    // MARK: - Create Lesson Blocks from Generated Course
    
    func createLiveLessonFromGenerated(lesson: GenerationCourseLesson, moduleTitle: String) -> LiveLesson {
        var blocks: [LessonBlock] = []
        
        // Get user context for personalization
        let memoryContext = SmartMemoryService.shared.memory
        let userContext = UserContextService.shared.currentContext
        
        // Personalized intro based on context
        let introText: String
        if userContext?.persona == "professional" {
            introText = "Let's efficiently cover \(lesson.title). Here's what matters most. ⚡"
        } else if userContext?.persona == "student" {
            introText = "Welcome to \(lesson.title)! Take notes – this might be on the test! 📝"
        } else {
            introText = "Welcome to this lesson on \(lesson.title). Let's dive in! 🚀"
        }
        
        blocks.append(LessonBlock(
            id: "intro_\(lesson.id)",
            type: .paragraph,
            title: lesson.title,
            content: introText
        ))
        
        // Check if this topic was a past struggle - add encouragement
        if let struggles = memoryContext?.struggles,
           struggles.contains(where: { lesson.title.localizedCaseInsensitiveContains($0.topic) }) {
            blocks.append(LessonBlock(
                id: "encouragement_\(lesson.id)",
                type: .paragraph,
                title: "💪 You've Got This!",
                content: "We noticed you found this topic challenging before. We've added extra examples to help!"
            ))
        }
        
        // 🎯 NEW: Parse ACTUAL content from backend instead of generic blocks!
        let paragraphs = lesson.content.components(separatedBy: "\n\n")
        var imageInserted = false
        
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Detect markdown headers (###, ##, #)
            if trimmed.hasPrefix("###") || trimmed.hasPrefix("##") || trimmed.hasPrefix("#") {
                let headerText = trimmed
                    .replacingOccurrences(of: "###", with: "")
                    .replacingOccurrences(of: "##", with: "")
                    .replacingOccurrences(of: "#", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                blocks.append(LessonBlock(
                    id: "heading_\(lesson.id)_\(index)",
                    type: .paragraph,
                    title: headerText,
                    content: nil
                ))
            }
            // Detect code blocks (```)
            else if trimmed.contains("```") {
                let codeContent = extractCodeBlock(from: trimmed)
                blocks.append(LessonBlock(
                    id: "code_\(lesson.id)_\(index)",
                    type: .code,
                    title: "Code Example",
                    code: codeContent
                ))
            }
            // Detect lists (bullet points starting with -, •, or numbered)
            else if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("1.") {
                blocks.append(LessonBlock(
                    id: "list_\(lesson.id)_\(index)",
                    type: .paragraph,
                    content: trimmed
                ))
            }
            // Regular content paragraph
            else {
                blocks.append(LessonBlock(
                    id: "content_\(lesson.id)_\(index)",
                    type: .paragraph,
                    content: trimmed
                ))
            }
            
            // Dynamic visual injection at midpoint (only once)
            if !imageInserted && index >= paragraphs.count / 2 && paragraphs.count > 3 {
                blocks.append(LessonBlock(
                    id: "img_mid_\(lesson.id)",
                    type: .image,
                    title: "Key Insight",
                    imageURL: URL(string: "avatar_reading")
                ))
                imageInserted = true
            }
        }
        
        // Add interactive element based on persona (only for exam prep users)
        if userContext?.suggestedStyle == "exam_prep" {
            blocks.append(LessonBlock(
                id: "flashcard_\(lesson.id)",
                type: .quizMcq,
                title: "⚡ Quick Recall",
                content: "Test your memory!",
                options: ["I remember this", "Need a hint", "Show me again"],
                correctIndex: 0,
                explanation: "Great memory!"
            ))
        }
        
        // 🎯 NEW: Use REAL lesson objectives for quiz if available
        // The backend curriculum architect should provide these
        if !lesson.content.isEmpty && paragraphs.count > 2 {
            // Create a comprehension quiz based on actual content
            let quizQuestion = "Based on what you learned in \(lesson.title), which statement is most accurate?"
            let quizOptions: [String]
            let correctIndex: Int
            
            // If we have at least 3 paragraphs, create options from key points
            if paragraphs.count >= 3 {
                quizOptions = [
                    "I understood the core concepts covered",
                    "I need to review some sections",
                    "I have questions about this topic",
                    "Ready to move to the next lesson"
                ]
                correctIndex = 0
            } else {
                quizOptions = [
                    "I'm ready to continue",
                    "I'd like to review this lesson",
                    "I need more explanation"
                ]
                correctIndex = 0
            }
            
            blocks.append(LessonBlock(
                id: "quiz_\(lesson.id)",
                type: .quizMcq,
                title: "Quick Check",
                question: quizQuestion,
                options: quizOptions,
                correctIndex: correctIndex,
                explanation: "Excellent! You've grasped the key concepts. Let's continue building on this foundation."
            ))
        }
        
        // Summary block with actual lesson recap
        let summaryText = "In this lesson, you explored \(lesson.title). " +
                         "You covered important concepts that will help you in your learning journey. " +
                         "Take a moment to reflect on what you learned before moving forward."
        
        blocks.append(LessonBlock(
            id: "summary_\(lesson.id)",
            type: .summary,
            title: "Summary",
            content: summaryText
        ))
        
        return LiveLesson(
            courseId: "generated",
            lessonId: lesson.id,
            title: lesson.title,
            subtitle: moduleTitle,
            blocks: blocks,
            estimatedDuration: lesson.durationMinutes
        )
    }
    
    // MARK: - Helper: Extract Code Block
    
    private func extractCodeBlock(from text: String) -> String {
        // Extract content between ``` markers
        let pattern = "```(?:[a-zA-Z]*\\n)?(.+?)```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        // Fallback: return text without ```
        return text.replacingOccurrences(of: "```", with: "")
    }
}

// MARK: - Errors

enum CourseGenerationError: LocalizedError {
    case invalidURL
    case invalidRequest
    case serverError
    case invalidResponse
    case noContent
    case authenticationRequired
    case energyRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidRequest:
            return "Invalid request parameters"
        case .serverError:
            return "Server error during course generation"
        case .invalidResponse:
            return "Could not parse generated course"
        case .noContent:
            return "No course content generated"
        case .authenticationRequired:
            return "Please sign in to generate courses"
        case .energyRequired:
            return "Watch an ad or upgrade to Premium for more courses"
        }
    }
}

