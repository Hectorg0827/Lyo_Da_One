//
//  CourseGenerationService.swift
//  Lyo
//
//  Service for generating courses from AI conversations
//

import Foundation

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
    
    // NEW: Streaming state for live UI updates
    @Published var streamingText: String = ""
    @Published var streamingBlocks: [LessonBlock] = []
    @Published var isStreaming: Bool = false
    
    private var baseURL: String { AppConfig.baseURL }
    
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("last_generated_course.json")
    }
    
    private init() {}
    
    // MARK: - Course Population
    
    /// Populates the generated course locally from a payload (e.g. from chat)
    func populateGeneratedCourse(from payload: CoursePayload) {
        // Create a simple structure if we only have high-level info
        let modules = [
            GenerationCourseModule(
                id: "mod_intro",
                title: "Introduction to \(payload.topic)",
                description: "Overview of \(payload.title)",
                lessons: [
                    GenerationCourseLesson(
                        id: "les_intro",
                        title: "Welcome & Objectives",
                        content: "### Learning Objectives\n\n" + payload.objectives.map { "• \($0)" }.joined(separator: "\n"),
                        durationMinutes: 5,
                        order: 1
                    )
                ],
                order: 1
            )
        ]
        
        let course = GeneratedCourseResponse(
            courseId: payload.id ?? "gen_\(UUID().uuidString.prefix(8))",
            title: payload.title,
            description: payload.topic,
            modules: modules,
            estimatedDuration: 15,
            difficulty: payload.level
        )
        
        self.generatedCourse = course
        
        // STABILITY FIX: Persist immediately
        saveCourseToDisk(course)
        
        print("💾 CourseGenerationService: Populated course locally: \(payload.title)")
    }
    
    // MARK: - Persistence Methods
    
    private func saveCourseToDisk(_ course: GeneratedCourseResponse) {
        Task {
            do {
                let data = try JSONEncoder().encode(course)
                try data.write(to: fileURL)
                print("💾 Course saved to disk for offline recovery.")
            } catch {
                print("⚠️ Failed to save course: \(error)")
            }
        }
    }
    
    func recoverLastCourse() {
        Task {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let data = try Data(contentsOf: fileURL)
                    let course = try JSONDecoder().decode(GeneratedCourseResponse.self, from: data)
                    await MainActor.run {
                        self.generatedCourse = course
                        print("♻️ Recovered last generated course from disk.")
                    }
                }
            } catch {
                print("⚠️ Failed to recover course: \(error)")
            }
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
            
            let moduleText = "Module" + chunk // Restore "Module" prefix for clarity if needed, or just parse
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
        
        print("🛟 CourseGenerationService: Rescued course '\(title)' with \(modules.count) modules")
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
        
        // 🚀 CALLING REAL BACKEND Multi-Agent Pipeline (A2A Orchestrator)
        print("🎯 Calling REAL Backend Multi-Agent Pipeline for: \(topic)")
        
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
            
            // Step 2: Submit course generation job to backend
            let jobResponse = try await BackendAIService.shared.generateCourse(
                topic: topic,
                options: options,
                userContext: [
                    "level": level,
                    "style": teachingStyle,
                    "outcomes": learningOutcomes.joined(separator: ", ")
                ]
            )
            
            print("✅ Job submitted: \(jobResponse.jobId)")
            print("💰 Estimated cost: $\(jobResponse.estimatedCostUsd)")
            
            currentStep = "AI agents working..."
            progress = 0.3
            
            // Step 3: Poll for completion
            let finalCourse = try await pollForCourseCompletion(jobId: jobResponse.jobId)
            
            print("✅ SUCCESS: Backend generated course: \(finalCourse.title)")
            print("📦 Course ID: \(finalCourse.courseId)")
            print("📚 Modules count: \(finalCourse.modules.count)")
            
            currentStep = "Course ready!"
            progress = 1.0
            
            generatedCourse = finalCourse
            
            // 💾 Persist to backend for cross-device access
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
                    }
                )
                try await LyoRepository.shared.saveCourse(data: persistenceData)
            } catch {
                print("⚠️ Failed to persist course to backend: \(error)")
                // Non-blocking error, we still have the local course
            }
            
            return finalCourse
            
        } catch {
            print("❌ Backend generation failed: \(error)")
            print("❌ DEBUG: Full error details: \(String(describing: error))")
            
            // Only use mock if explicitly allowed
            if AppConfig.allowMockFallbacks {
                print("🛠 FALLBACK: Using mock course (LYO_ALLOW_MOCKS=1)")
                let course = generateMockCourse(topic: topic)
                
                currentStep = "Course ready (Offline Mode)!"
                progress = 1.0
                
                generatedCourse = course
                return course
            } else {
                print("❌ PRODUCTION MODE: No mock fallback allowed")
                currentStep = "Failed: \(error.localizedDescription)"
                self.error = error.localizedDescription
                throw error
            }
        }
    }
    
    // MARK: - Poll for Course Completion
    
    private func pollForCourseCompletion(jobId: String) async throws -> GeneratedCourseResponse {
        let maxAttempts = 60  // 5 minutes max (5 second intervals)
        var attempts = 0
        
        while attempts < maxAttempts {
            let status = try await BackendAIService.shared.getCourseGenerationStatus(jobId: jobId)
            
            print("📊 Status: \(status.status) - Progress: \(status.progressPercent)%")
            
            currentStep = status.currentStep ?? "Processing..."
            progress = 0.3 + (Double(status.progressPercent) / 100.0 * 0.6)  // 30% to 90%
            
            switch status.status {
            case "completed":
                print("✅ Course generation completed!")
                currentStep = "Fetching course..."
                progress = 0.95
                return try await fetchGeneratedCourse(jobId: jobId)
                
            case "failed":
                let errorMsg = status.error ?? "Unknown error"
                print("❌ Course generation failed: \(errorMsg)")
                throw CourseGenerationError.serverError
                
            case "processing":
                // Continue polling
                break
                
            default:
                break
            }
            
            attempts += 1
            try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
        }
        
        throw CourseGenerationError.serverError
    }
    
    // MARK: - Fetch Generated Course
    
    private func fetchGeneratedCourse(jobId: String) async throws -> GeneratedCourseResponse {
        // Call backend to get final course structure
        let endpoint = DynamicEndpoint(
            urlString: "/api/v2/courses/\(jobId)/result",
            method: .get,
            requiresAuth: true
        )
        
        let backendCourse: BackendCourseResult = try await NetworkClient.shared.request(endpoint)
        return mapBackendCourseToGenerated(backendCourse)
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
        print("🎓 Starting STREAMING course generation for: \(request.topic)")
        
        let endpoint = Endpoints.AI.generateCourseStream(
            topic: request.topic,
            level: request.level,
            outcomes: request.outcomes,
            teachingStyle: request.teachingStyle
        )
        
        print("📤 Calling streaming backend: \(endpoint.path)")
        
        // Accumulate streamed chunks
        var accumulatedData = Data()
        var lastProgressUpdate = Date()
        let progressUpdateInterval: TimeInterval = 0.5 // Update progress every 0.5 seconds
        
        do {
            let (asyncBytes, response) = try await NetworkClient.shared.stream(endpoint)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw CourseGenerationError.serverError
            }
            
            print("📥 Streaming started - status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Backend error status: \(httpResponse.statusCode)")
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
            
            print("✅ Streaming completed - received \(accumulatedData.count) bytes")
            
            // Log response preview
            if let jsonStr = String(data: accumulatedData, encoding: .utf8) {
                print("📥 Streamed response preview: \(String(jsonStr.prefix(300)))...")
            }
            
            // Parse the accumulated response
            return try parseBackendResponse(data: accumulatedData, topic: request.topic)
            
        } catch let streamError as URLError {
            print("❌ Streaming error: \(streamError.localizedDescription)")
            throw CourseGenerationError.serverError
        } catch {
            print("❌ Unexpected streaming error: \(error)")
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
        
        print("🎓 Starting course generation for: \(request.topic)")
        print("📤 Calling Dual AI Orchestrator: /api/v1/ai/generate")
        
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
        
        // Construct request body for /api/v1/ai/generate
        let requestBody: [String: Any] = [
            "prompt": coursePrompt,
            "task_type": "CONTENT_GENERATION",  // Routes to Gemini for educational content
            "max_tokens": 4000,
            "temperature": 0.7,
            "context": [
                "type": "course_generation",
                "topic": request.topic,
                "level": request.level
            ]
        ]
        
        // Use AnyEncodable wrapper for the body
        let encodableBody = requestBody.mapValues { AnyEncodable(value: $0) }
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/ai/generate",
            method: .post,
            body: encodableBody,
            requiresAuth: true
        )
        
        do {
            let aiResponse: AIResponse = try await NetworkClient.shared.request(endpoint)
            
            let content = aiResponse.content ?? aiResponse.response
            guard let validContent = content else {
                print("❌ Failed to extract content/response from AI JSON")
                throw CourseGenerationError.invalidResponse
            }
            
            print("🤖 AI used: \(aiResponse.primaryAi ?? "unknown")")
            print("📄 Content length: \(validContent.count) characters")
            
            return try parseAIContent(validContent, topic: request.topic)
            
        } catch {
            print("❌ Backend generation failed: \(error)")
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
            print("❌ Failed to convert cleaned JSON to data")
            throw CourseGenerationError.invalidResponse
        }
        
        // Try to decode as GeneratedCourseResponse
        do {
            let course = try JSONDecoder().decode(GeneratedCourseResponse.self, from: courseData)
            print("✅ Backend (Gemini) generated course: \(course.title)")
            return course
        } catch {
            print("⚠️ Direct decode failed, trying to map response...")
            
            // Try to parse as generic JSON and map
            if let courseJson = try? JSONSerialization.jsonObject(with: courseData) as? [String: Any] {
                let course = try mapBackendResponse(courseJson, topic: topic)
                print("✅ Mapped backend course: \(course.title)")
                return course
            }
            
            print("❌ Failed to parse course JSON: \(error)")
            print("❌ Cleaned JSON was: \(cleanJson.prefix(500))...")
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
            print("✅ Backend generated course: \(course.title)")
            return course
        } catch {
            print("⚠️ Direct decode failed, trying to map backend response...")
            
            // Try to parse as generic JSON and map to our structure
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let course = try mapBackendResponse(json, topic: topic)
                print("✅ Mapped backend course: \(course.title)")
                return course
            }
            
            print("❌ Failed to decode backend response: \(error)")
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
        
        print("📤 Sending course generation request to OpenAI...")
        
        let response = try await OpenAIService.shared.sendMessage(
            message: prompt,
            conversationHistory: [],
            systemPrompt: "You are a curriculum designer. You must return only valid JSON with no markdown formatting."
        )
        
        print("📥 OpenAI raw response length: \(response.count) characters")
        print("📥 OpenAI response preview: \(String(response.prefix(200)))...")
        
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
        
        print("🧹 Cleaned JSON length: \(cleanJson.count) characters")
        
        guard let data = cleanJson.data(using: .utf8) else {
            print("❌ Failed to convert cleaned JSON to data")
            throw CourseGenerationError.invalidResponse
        }
        
        do {
            let course = try JSONDecoder().decode(GeneratedCourseResponse.self, from: data)
            print("✅ Successfully decoded course: \(course.title)")
            return course
        } catch let decodingError {
            print("❌ JSON decoding error: \(decodingError)")
            print("❌ Cleaned JSON was: \(cleanJson)")
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
    case serverError
    case invalidResponse
    case noContent
    case authenticationRequired
    case energyRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
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
