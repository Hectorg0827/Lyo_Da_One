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
    
    private init() {}
    
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
        
        let request = CourseGenerationRequest(
            topic: topic,
            level: level,
            outcomes: learningOutcomes,
            teachingStyle: teachingStyle,
            systemPrompt: nil,
            diagnosticData: nil
        )
        
        // Use Backend Generation (Gemini via Dual AI Orchestrator)
        currentStep = "Generating course with AI..."
        progress = 0.3
        
        do {
            print("🎯 Attempting Backend course generation for topic: \(topic)")
            
            // Enable streaming for better UX - shows content as it arrives
            let course = try await generateFromBackendStreaming(request: request)
            
            print("✅ SUCCESS: Backend generated course: \(course.title)")
            
            currentStep = "Course ready!"
            progress = 1.0
            
            generatedCourse = course
            return course
            
        } catch let apiError {
            print("⚠️ Backend generation error: \(apiError)")
            
            // Fallback to OpenAI (Direct) if backend fails
            print("🔄 Falling back to OpenAI (Direct)")
            do {
                let course = try await generateFromOpenAI(topic: topic, level: level, outcomes: learningOutcomes)
                print("✅ SUCCESS: OpenAI generated course: \(course.title)")
                
                currentStep = "Course ready!"
                progress = 1.0
                
                generatedCourse = course
                return course
            } catch {
                print("❌ OpenAI fallback failed: \(error)")
                
                // Fallback to mock (Last Resort)
                print("🛠 LAST RESORT: Generating mock course")
                let course = generateMockCourse(topic: topic)
                
                currentStep = "Course ready (Offline Mode)!"
                progress = 1.0
                
                generatedCourse = course
                return course
            }
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
        return GeneratedCourseResponse(
            courseId: "mock_\(UUID().uuidString.prefix(8))",
            title: "Introduction to \(topic)",
            description: "A comprehensive guide to mastering \(topic) fundamentals.",
            modules: [
                GenerationCourseModule(
                    id: "mod_1",
                    title: "Getting Started",
                    description: "Core concepts and setup",
                    lessons: [
                        GenerationCourseLesson(
                            id: "les_1_1",
                            title: "What is \(topic)?",
                            content: "\(topic) is a fascinating subject. In this lesson, we'll explore the basics.\n\nIt is essential for understanding modern systems.",
                            durationMinutes: 5,
                            order: 1
                        ),
                        GenerationCourseLesson(
                            id: "les_1_2",
                            title: "Key Principles",
                            content: "There are three main principles you need to know.\n\n1. Consistency\n2. Practice\n3. Application",
                            durationMinutes: 8,
                            order: 2
                        )
                    ],
                    order: 1
                ),
                GenerationCourseModule(
                    id: "mod_2",
                    title: "Advanced Concepts",
                    description: "Taking it to the next level",
                    lessons: [
                        GenerationCourseLesson(
                            id: "les_2_1",
                            title: "Deep Dive",
                            content: "Now that you know the basics, let's look at advanced topics.",
                            durationMinutes: 12,
                            order: 1
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
            type: .explain,
            title: lesson.title,
            body: introText
        ))
        
        // Check if this topic was a past struggle - add encouragement
        if let struggles = memoryContext?.struggles,
           struggles.contains(where: { lesson.title.localizedCaseInsensitiveContains($0.topic) }) {
            blocks.append(LessonBlock(
                id: "encouragement_\(lesson.id)",
                type: .explain,
                title: "💪 You've Got This!",
                body: "We noticed you found this topic challenging before. We've added extra examples to help!"
            ))
        }
        
        // Cinematic Intro Image
        blocks.append(LessonBlock(
            id: "img_intro_\(lesson.id)",
            type: .image,
            title: "Let's explore \(lesson.title)",
            assetURL: URL(string: "LyoThinking")
        ))
        
        // Split content into paragraphs and create explanation blocks
        let paragraphs = lesson.content.components(separatedBy: "\n\n")
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            blocks.append(LessonBlock(
                id: "exp_\(lesson.id)_\(index)",
                type: .explain,
                title: nil,
                body: trimmed
            ))
            
            // Dynamic visual injection based on content length
            if index == paragraphs.count / 2 && paragraphs.count > 1 {
                blocks.append(LessonBlock(
                    id: "img_mid_\(lesson.id)",
                    type: .image,
                    title: "Key Insight",
                    assetURL: URL(string: "avatar_reading")
                ))
            }
        }
        
        // Add interactive element based on persona
        if userContext?.suggestedStyle == "exam_prep" {
            // Add flashcard-style quick quiz
            blocks.append(LessonBlock(
                id: "flashcard_\(lesson.id)",
                type: .quizMcq,
                title: "⚡ Quick Recall",
                body: "Test your memory!",
                options: ["I remember this", "Need a hint", "Show me again"],
                correctIndex: 0,
                explanation: "Great memory!"
            ))
        }
        
        // Example block
        blocks.append(LessonBlock(
            id: "example_\(lesson.id)",
            type: .example,
            title: "Let's See an Example",
            body: "Here's a practical example to help solidify your understanding of \(lesson.title)."
        ))
        
        // Quiz block
        blocks.append(LessonBlock(
            id: "quiz_\(lesson.id)",
            type: .quizMcq,
            title: "Quick Check",
            body: "Let's make sure you understood the key concepts!",
            options: [
                "I understand the key concepts",
                "I need more examples",
                "I have questions",
                "Ready for next lesson"
            ],
            correctIndex: 0,
            explanation: "Great job! You've completed this lesson."
        ))
        
        // Summary block
        blocks.append(LessonBlock(
            id: "summary_\(lesson.id)",
            type: .summary,
            title: "Summary",
            body: "In this lesson, you learned about \(lesson.title). Keep practicing and you'll master this topic!"
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
