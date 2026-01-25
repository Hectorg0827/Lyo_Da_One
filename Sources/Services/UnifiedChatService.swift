//
//  UnifiedChatService.swift
//  Lyo
//
//  SINGLE SOURCE OF TRUTH for all AI chat functionality across the app.
//  This service handles:
//  - Message sending/receiving via BackendAIService
//  - A2UI protocol parsing and rendering
//  - Course creation flow
//  - Conversation persistence
//  - Stack integration
//
//  NOTE: This service uses existing LyoMessage type to maintain compatibility
//  with the existing UI components (LyoMessageBubbleView, etc.)
//

import Foundation
import Combine

// MARK: - Unified Chat Service

@MainActor
final class UnifiedChatService: ObservableObject {
    static let shared = UnifiedChatService()
    
    // Dependencies
    private let repository = LyoRepository.shared
    
    // MARK: - Published State
    
    /// All messages in the current conversation (uses existing LyoMessage type)
    @Published private(set) var messages: [LyoMessage] = []
    
    /// Current conversation ID
    @Published private(set) var currentConversationId: String = UUID().uuidString
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Error message
    @Published var error: String?
    
    /// Pending course to navigate to (set when AI creates a course)
    @Published var pendingCourse: CourseCreationData?
    
    /// Flag to trigger classroom navigation
    @Published var shouldNavigateToClassroom: Bool = false
    
    /// Last AI response source (for debug/analytics)
    @Published private(set) var lastAISource: String = ""
    
    /// Suggestions from last response
    @Published var suggestions: [SuggestionChip] = []
    
    // MARK: - Private Properties
    
    private let backendAI = BackendAIService.shared
    private let lioChatService = LioChatService.shared
    private let stackStore = UIStackStore.shared
    // Use ConversationManager for persistence (already exists in project)
    private var conversationHistory: [ConversationMessage] = []
    
    // MARK: - Initialization
    
    private init() {
        // Load last conversation if available
        Task {
            await loadLastConversation()
        }
    }
    
    // MARK: - Public API
    
    /// Start a completely new chat session
    /// Clears local state and generates a new session ID to ensure isolation
    func startNewChat(withId id: String? = nil) {
        // 1. Generate new session ID
        currentConversationId = id ?? UUID().uuidString
        
        // 2. Clear UI messages
        messages = []
        
        // 3. Clear LLM context
        conversationHistory = []
        
        // 4. Reset other state
        error = nil
        pendingCourse = nil
        shouldNavigateToClassroom = false
        suggestions = []
        
        print("🆕 Started new chat session: \(currentConversationId)")
    }

    /// Send a message and get AI response with full A2UI support
    /// - Parameters:
    ///   - text: The message text
    ///   - attachments: Optional file attachments
    ///   - context: Optional context (course ID, lesson ID, etc.)
    ///   - mode: Chat mode (study, quiz, etc.)
    func sendMessage(
        _ text: String,
        attachments: [MessageAttachment] = [],
        context: ChatContext? = nil,
        mode: String = "study"
    ) async -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }
        
        // 1. Create and add user message
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: trimmedText,
            isFromUser: true,
            timestamp: Date(),
            attachments: attachments.isEmpty ? nil : attachments,
            actions: nil,
            status: .sent,
            contentTypes: nil,
            responseMode: nil,
            quickExplainer: nil,
            courseProposal: nil
        )
        messages.append(userMessage)
        
        // 2. Update conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: trimmedText))
        
        // 3. Save to persistence
        await saveConversation()
        
        // 4. Add to stack as active chat
        stackStore.upsertChat(
            key: currentConversationId,
            title: extractTitle(from: trimmedText),
            subtitle: "Just now",
            lastMessage: trimmedText
        )
        
        // 5. Get AI response
        isLoading = true
        error = nil
        
        var responseText: String?
        
        do {
            let result = try await backendAI.studySession(
                message: trimmedText,
                resourceId: context?.courseId,
                mode: mode,
                history: conversationHistory
            )
            
            // 6. Parse response for commands and A2UI content
            // We use the raw text and direct A2UI content from the backend
            let (parsedContent, a2uiElements, courseData) = parseResponse(
                text: result.response,
                a2uiContent: result.uiContent,
                recursiveUI: result.uiComponent
            )
            
            // 6a. Handle OPEN_CLASSROOM payload directly from backend
            if result.wasCommand, let openClassroomPayload = result.openClassroomPayload {
                print("🎓 UnifiedChatService: Received OPEN_CLASSROOM from backend!")
                let commandPayload = AICommandPayload(
                    stackItem: nil,
                    course: CoursePayload(
                        id: openClassroomPayload.course.id,
                        title: openClassroomPayload.course.title,
                        topic: openClassroomPayload.course.topic,
                        level: openClassroomPayload.course.level,
                        language: "English",
                        duration: openClassroomPayload.course.duration ?? "~45 min",
                        objectives: openClassroomPayload.course.objectives
                    )
                )
                let _ = AICommandHandler.shared.handleOpenClassroom(commandPayload)
            } else {
                // 6b. Trigger side effects for commands (Stack items, orchestrator)
                // We call this on every response to ensure structured commands are handled
                let _ = AICommandHandler.shared.processResponse(result.response)
            }
            
            responseText = parsedContent
            
            // 7. Create AI message using LyoMessage
            let aiMessage = LyoMessage(
                id: UUID().uuidString,
                sessionId: currentConversationId,
                content: parsedContent,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .sent,
                contentTypes: a2uiElements.isEmpty ? nil : a2uiElements,
                responseMode: nil,
                quickExplainer: nil,
                courseProposal: nil
            )
            
            // 8. If course was created, add to Stack
            if let course = courseData {
                pendingCourse = course
                
                // Add to Local Stack (Immediate UI update)
                stackStore.upsertCourse(
                    courseId: course.id,
                    title: course.title,
                    subtitle: "\(course.level.capitalized) • \(course.modules.count) modules",
                    progress: 0,
                    lessonCount: course.modules.reduce(0) { $0 + $1.lessons.count },
                    completedLessons: 0
                )
                
                // Add to Backend Stack (Persistence)
                Task {
                    let request = CreateStackItemRequest(
                        type: .course,
                        refId: course.id,
                        tags: [course.topic],
                        contextData: ["course_id": course.id]
                    )
                    _ = try? await repository.createStackItem(request: request)
                }
            }
            
            messages.append(aiMessage)
            
            // 9. Update conversation history
            conversationHistory.append(ConversationMessage(role: "assistant", content: parsedContent))
            
            // 10. Save conversation
            await saveConversation()
            
        } catch {
            self.error = error.localizedDescription
            
            // Add error message using LyoMessage
            let errorMessage = LyoMessage(
                id: UUID().uuidString,
                sessionId: currentConversationId,
                content: "Sorry, I encountered an error. Please try again.",
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .failed,
                contentTypes: nil,
                responseMode: nil,
                quickExplainer: nil,
                courseProposal: nil
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
        return responseText
    }

    /// Enhanced sendMessage method that uses the new recursive A2UI backend endpoint
    func sendMessageV2(
        _ text: String,
        attachments: [MessageAttachment] = [],
        context: ChatContext? = nil,
        mode: String = "study"
    ) async -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }

        // 1. Create and add user message
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: trimmedText,
            isFromUser: true,
            timestamp: Date(),
            attachments: attachments.isEmpty ? nil : attachments,
            actions: nil,
            status: .sent,
            contentTypes: nil,
            responseMode: nil,
            quickExplainer: nil,
            courseProposal: nil
        )
        messages.append(userMessage)

        // 2. Update conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: trimmedText))

        // 3. Save to persistence
        await saveConversation()

        // 4. Add to stack as active chat
        stackStore.upsertChat(
            key: currentConversationId,
            title: extractTitle(from: trimmedText),
            subtitle: "Just now",
            lastMessage: trimmedText
        )

        // 5. Get AI response from NEW V2 endpoint
        isLoading = true
        error = nil

        var responseText: String?

        do {
            // Call the new recursive A2UI endpoint
            let result = try await callRecursiveA2UIEndpoint(
                message: trimmedText,
                resourceId: context?.courseId,
                mode: mode,
                history: conversationHistory
            )

            lastAISource = "Backend V2 (Recursive A2UI)"

            // 6. Parse response using new V2 parser
            let (parsedContent, a2uiElements, courseData) = parseResponseV2(
                text: result.response,
                recursiveUI: result.uiLayout
            )

            // 6b. Trigger side effects for commands
            let _ = AICommandHandler.shared.processResponse(result.response)

            responseText = parsedContent

            // 7. Create AI message using LyoMessage
            let aiMessage = LyoMessage(
                id: UUID().uuidString,
                sessionId: currentConversationId,
                content: parsedContent,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .sent,
                contentTypes: a2uiElements.isEmpty ? nil : a2uiElements,
                responseMode: nil,
                quickExplainer: nil,
                courseProposal: nil
            )

            // 8. Handle course creation
            if let course = courseData {
                pendingCourse = course

                // Add to Local Stack (Immediate UI update)
                stackStore.upsertCourse(
                    courseId: course.id,
                    title: course.title,
                    subtitle: "\(course.level.capitalized) • \(course.modules.count) modules",
                    progress: 0,
                    lessonCount: course.modules.reduce(0) { $0 + $1.lessons.count },
                    completedLessons: 0
                )
                
                // Add to Backend Stack (Persistence)
                Task {
                    let request = CreateStackItemRequest(
                        type: .course,
                        refId: course.id,
                        tags: [course.topic],
                        contextData: ["course_id": course.id]
                    )
                    _ = try? await repository.createStackItem(request: request)
                }
            }

            messages.append(aiMessage)

            // 9. Update conversation history
            conversationHistory.append(ConversationMessage(role: "assistant", content: parsedContent))

            // 10. Save conversation
            await saveConversation()

        } catch {
            self.error = error.localizedDescription

            // Add error message using LyoMessage
            let errorMessage = LyoMessage(
                id: UUID().uuidString,
                sessionId: currentConversationId,
                content: "Sorry, I encountered an error. Please try again.",
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .failed,
                contentTypes: nil,
                responseMode: nil,
                quickExplainer: nil,
                courseProposal: nil
            )
            messages.append(errorMessage)
        }

        isLoading = false
        return responseText
    }

    /// Call the new recursive A2UI backend endpoint
    private func callRecursiveA2UIEndpoint(
        message: String,
        resourceId: String?,
        mode: String,
        history: [ConversationMessage]
    ) async throws -> RecursiveChatResponse {
        // Construct request
        let requestBody: [String: Any] = [
            "message": message,
            "conversation_history": history.map { [
                "role": $0.role,
                "content": $0.content
            ]},
            "context": resourceId ?? "",
            "include_chips": 0,
            "include_ctas": 0
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)

        // Make request to v2 endpoint
        let token = await TokenManager.shared.getToken()
        let request = URLRequest.authenticatedRequest(
            url: URL(string: "\(NetworkClient.baseURL)/api/v1/chat/v2")!,
            method: "POST",
            body: requestData,
            token: token
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.networkError("Failed to get response from backend")
        }

        let chatResponse = try JSONDecoder().decode(RecursiveChatResponse.self, from: data)
        return chatResponse
    }
    
    /// Start a new conversation
    func startNewConversation() {
        currentConversationId = UUID().uuidString
        messages.removeAll()
        conversationHistory.removeAll()
        error = nil
    }
    
    /// Fetch and display a proactive greeting from the AI
    func fetchProactiveGreeting() async {
        guard messages.isEmpty else { return }
        
        isLoading = true
        do {
            // Re-use LioGreetingResponse which is visible in the module
            let response: LioGreetingResponse = try await NetworkClient.shared.request(Endpoints.ChatModule.getGreeting)
            
            let greetingMessage = LyoMessage(
                id: UUID().uuidString,
                content: response.greeting,
                isFromUser: false,
                timestamp: Date(),
                attachments: nil,
                actions: nil,
                status: .sent
            )
            
            messages.append(greetingMessage)
            conversationHistory.append(ConversationMessage(role: "assistant", content: response.greeting))
            
        } catch {
            print("⚠️ Failed to fetch proactive greeting: \(error)")
            // Fallback greeting
            let fallback = LyoMessage(
                id: UUID().uuidString,
                content: "Hello! I'm Lyo, your AI learning companion. How can I help you today?",
                isFromUser: false,
                timestamp: Date(),
                status: .sent
            )
            messages.append(fallback)
        }
        isLoading = false
    }
    
    /// Load a specific saved conversation
    func loadConversation(_ conversation: SavedConversation) {
        // 1. Set ID
        currentConversationId = conversation.id
        
        // 2. Set messages
        messages = conversation.messages.map { convertToLyo($0) }
        
        // 3. Rebuild context history for LLM
        // We map LyoMessage back to ConversationMessage format for the AI context
        conversationHistory = conversation.messages.suffix(10).map { msg in
            ConversationMessage(
                role: msg.isFromUser ? "user" : "assistant",
                content: msg.content
            )
        }
        
        // 4. Reset state
        error = nil
        pendingCourse = nil
        shouldNavigateToClassroom = false
        suggestions = []
        
        print("📂 Loaded saved conversation: \(conversation.id) with \(messages.count) messages")
    }
    
    /// Navigate to course that was just created
    func navigateToCourse(_ course: CourseCreationData) {
        pendingCourse = course
        shouldNavigateToClassroom = true
        
        // Post global notification for cinematic flow
        NotificationCenter.default.post(
            name: .openClassroom, 
            object: nil, 
            userInfo: [
                "courseId": "GENERATE:\(course.topic)",
                "courseTitle": course.title,
                "lessonId": "intro_1",
                "lessonTitle": "Introduction"
            ]
        )
    }
    
    /// Explicitly trigger navigation to the current pending course
    func triggerCourseNavigation() {
        guard let course = pendingCourse else { return }
        shouldNavigateToClassroom = true
        
        // Post global notification for cinematic flow
        NotificationCenter.default.post(
            name: .openClassroom, 
            object: nil, 
            userInfo: [
                "courseId": "GENERATE:\(course.topic)",
                "courseTitle": course.title,
                "lessonId": "intro_1",
                "lessonTitle": "Introduction"
            ]
        )
    }
    
    /// Clear navigation flags
    func clearNavigation() {
        shouldNavigateToClassroom = false
    }
    
    // MARK: - Response Parsing

    /// Enhanced method that supports both legacy A2UI and new recursive A2UI
    private func parseResponseV2(
        text: String,
        recursiveUI: DynamicComponent?
    ) -> (String, [MessageContentType], CourseCreationData?) {
        var cleanedText = text
        var elements: [MessageContentType] = []
        var courseData: CourseCreationData?

        // Handle recursive A2UI if present
        if let recursiveComponent = recursiveUI {
            elements.append(.recursiveUI(component: recursiveComponent))
        }

        // Handle AI commands in text
        let commandParsed = AICommandParser.parse(text)

        switch commandParsed {
        case .command(let command):
            if command.type == .openClassroom, let payload = command.payload?.course {
                // Convert to CourseCreationData (same logic as before)
                let modules = payload.objectives.enumerated().map { index, objective in
                    CourseModuleData(
                        id: "mod_\(index + 1)",
                        title: "Module \(index + 1)",
                        description: objective,
                        lessons: [
                            CourseLessonData(id: "les_\(index + 1)_1", title: "Introduction", duration: "10 min"),
                            CourseLessonData(id: "les_\(index + 1)_2", title: "Deep Dive", duration: "15 min"),
                            CourseLessonData(id: "les_\(index + 1)_3", title: "Practice", duration: "10 min")
                        ]
                    )
                }

                courseData = CourseCreationData(
                    id: "course_\(UUID().uuidString.prefix(8))",
                    title: payload.title,
                    topic: payload.topic,
                    level: payload.level,
                    modules: modules
                )

                cleanedText = "I've created a learning path for **\(payload.title)**! 🎓"
            }
        case .chat(let originalText):
            cleanedText = originalText
        }

        return (cleanedText, elements, courseData)
    }

    private func parseResponse(
        text: String,
        a2uiContent: [A2UIContent]?,
        recursiveUI: DynamicComponent? = nil
    ) -> (String, [MessageContentType], CourseCreationData?) {
        var cleanedText = text
        var elements: [MessageContentType] = []
        
        // 0. Handle Recursive A2UI (Standard)
        if let component = recursiveUI {
            elements.append(.recursiveUI(component: component))
        }
        
        var courseData: CourseCreationData?
        
        // 1. Check for JSON commands (OPEN_CLASSROOM, ADD_TO_STACK, etc.)
        // Use the centralized AICommandParser for robust extraction
        let commandParsed = AICommandParser.parse(text)
        
        switch commandParsed {
        case .command(let command):
            if command.type == .openClassroom, let payload = command.payload?.course {
                // Map CoursePayload to CourseCreationData
                let modules = payload.objectives.enumerated().map { index, objective in
                    CourseModuleData(
                        id: "mod_\(index + 1)",
                        title: "Module \(index + 1)",
                        description: objective,
                        lessons: [
                            CourseLessonData(id: "les_\(index + 1)_1", title: "Introduction", duration: "10 min"),
                            CourseLessonData(id: "les_\(index + 1)_2", title: "Deep Dive", duration: "15 min"),
                            CourseLessonData(id: "les_\(index + 1)_1", title: "Practice", duration: "10 min")
                        ]
                    )
                }
                
                courseData = CourseCreationData(
                    id: "course_\(UUID().uuidString.prefix(8))",
                    title: payload.title,
                    topic: payload.topic,
                    level: payload.level,
                    modules: modules
                )
                
                // Add courseRoadmap to elements for UI rendering
                let uiModules = modules.map { mod in
                    CourseModule(
                        id: mod.id,
                        title: mod.title,
                        duration: mod.lessons.first?.duration,
                        isCompleted: false,
                        isLocked: false
                    )
                }
                elements.append(.courseRoadmap(
                    title: payload.title,
                    modules: uiModules,
                    totalModules: uiModules.count,
                    completedModules: 0
                ))
                
                // Set cleaned text to a friendly message
                cleanedText = "I've created a learning path for **\(payload.title)**! 🎓\n\nTap 'Start Learning' below to begin."
            }
        case .chat(let originalText):
            cleanedText = originalText
        }
        
        // 2. Convert backend A2UI content to MessageContentType
        if let content = a2uiContent {
            for item in content {
                switch item.type {
                case .text:
                    // Text type is just the main response - no special handling needed
                    break
                    
                case .processing:
                    // Processing indicator - could show loading state
                    break
                    
                case .topicSelection:
                    if let topics = item.topics {
                        let topicOptions = topics.map { topic in
                            TopicOption(
                                title: topic.title,
                                icon: topic.icon ?? "book.fill",
                                gradientColors: topic.gradientColors
                            )
                        }
                        elements.append(.topicSelection(
                            title: item.title ?? "Choose a Topic",
                            topics: topicOptions
                        ))
                    }
                    
                case .courseRoadmap:
                    if let roadmap = item.courseRoadmap {
                        // Use nested structure from backend
                        let modules = roadmap.modules.map { mod in
                            CourseModuleData(
                                id: UUID().uuidString,
                                title: mod.title,
                                description: mod.description ?? "",
                                lessons: (mod.lessons ?? []).map { les in
                                    CourseLessonData(id: UUID().uuidString, title: les.title, duration: les.duration ?? "10 min")
                                }
                            )
                        }
                        courseData = CourseCreationData(
                            id: "course_\(UUID().uuidString.prefix(8))",
                            title: roadmap.title,
                            topic: roadmap.topic,
                            level: roadmap.level,
                            modules: modules
                        )
                        // Convert CourseModuleData to CourseModule for UI display
                        let uiModules = modules.map { mod in
                            CourseModule(
                                id: mod.id,
                                title: mod.title,
                                duration: mod.lessons.first?.duration,
                                isCompleted: false,
                                isLocked: false
                            )
                        }
                        elements.append(.courseRoadmap(
                            title: roadmap.title,
                            modules: uiModules,
                            totalModules: uiModules.count,
                            completedModules: 0
                        ))
                    } else if let flatModules = item.modules {
                        // Fallback: use flat module format (backwards compatibility)
                        let uiModules = flatModules.map { mod in
                            CourseModule(
                                id: mod.id ?? UUID().uuidString,
                                title: mod.title,
                                duration: mod.duration,
                                isCompleted: mod.isCompleted ?? false,
                                isLocked: mod.isLocked ?? false
                            )
                        }
                        elements.append(.courseRoadmap(
                            title: item.title ?? "Course Roadmap",
                            modules: uiModules,
                            totalModules: item.totalModules ?? uiModules.count,
                            completedModules: item.completedModules ?? 0
                        ))
                    }
                    
                case .flashcards:
                    if let cards = item.cards {
                        // Convert A2UI flashcards to MessageContentType flashcards
                        let flashcardModels = cards.map { card in
                            Flashcard(
                                front: card.front,
                                back: card.back,
                                isMastered: false
                            )
                        }
                        elements.append(.flashcards(
                            title: item.title ?? "Study Flashcards",
                            cards: flashcardModels
                        ))
                    }
                    
                case .quiz:
                    if let quiz = item.quiz {
                        // Add each question as a quiz content type
                        for question in quiz.questions {
                            let correctIndex = question.options.firstIndex(of: question.correctAnswer) ?? 0
                            elements.append(.quiz(
                                question: question.question,
                                options: question.options,
                                correctIndex: correctIndex,
                                explanation: nil
                            ))
                        }
                    }
                    
                case .suggestions:
                    // Smart follow-up suggestions for engagement
                    if let suggestions = item.suggestions, !suggestions.isEmpty {
                        elements.append(.suggestions(
                            title: item.title ?? "What's next?",
                            options: suggestions
                        ))
                    }
                    
                case .unknown:
                    print("⚠️ Unknown A2UI content type received")
                    break
                }
            }
        }
        
        return (cleanedText, elements, courseData)
    }
    
    private func extractOpenClassroomCommand(from text: String) -> OpenClassroomCommand? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract JSON from the response
        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(trimmed[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let command = try? JSONDecoder().decode(OpenClassroomCommand.self, from: data),
              command.type == "OPEN_CLASSROOM" else {
            return nil
        }
        
        return command
    }
    
    // MARK: - Persistence (Simplified - uses UserDefaults for now)
    
    private let conversationStorageKey = "com.lyo.unifiedChat.lastConversation"
    
    private func saveConversation() async {
        // Use ConversationManager as source of truth
        let multimodalMessages = messages.map { convertToMultimodal($0) }
        
        // Generate title if new
        let title = messages.isEmpty ? "New Chat" : SavedConversation.generateTitle(from: multimodalMessages)
        let preview = SavedConversation.getLastMessagePreview(from: multimodalMessages)
        
        let savedConversation = SavedConversation(
            id: currentConversationId,
            title: title,
            lastMessagePreview: preview,
            lastUpdated: Date(),
            messageCount: messages.count,
            messages: multimodalMessages
        )
        
        // Save to Manager
        ConversationManager.shared.saveConversation(savedConversation)
        
        // Also update current pointer
        ConversationManager.shared.loadConversation(savedConversation)
    }
    
    private func loadLastConversation() async {
        // Load from ConversationManager
        if let current = ConversationManager.shared.currentConversation {
            loadConversation(current)
        } else if let recent = ConversationManager.shared.conversations.first {
            loadConversation(recent)
        }
    }
    
    // MARK: - Message Compatibility
    
    private func convertToMultimodal(_ msg: LyoMessage) -> MultimodalMessage {
        return MultimodalMessage(
            id: msg.id,
            sessionId: msg.sessionId,
            role: msg.isFromUser ? .user : .assistant,
            content: msg.content,
            contentTypes: msg.contentTypes ?? [.text], // Preserve A2UI widgets
            timestamp: msg.timestamp,
            isStreaming: false
        )
    }
    
    private func convertToLyo(_ msg: MultimodalMessage) -> LyoMessage {
        var lyoMsg = LyoMessage(
            id: msg.id,
            content: msg.content,
            isFromUser: msg.role == .user,
            timestamp: msg.timestamp,
            status: .sent
        )
        lyoMsg.sessionId = msg.sessionId
        lyoMsg.contentTypes = msg.contentTypes
        return lyoMsg
    }
    
    private func extractTitle(from text: String) -> String {
        let words = text.split(separator: " ").prefix(5)
        return words.joined(separator: " ") + (text.split(separator: " ").count > 5 ? "..." : "")
    }
}

// NOTE: SavedConversation is defined in ConversationManager.swift
// Course models are in Sources/Models/CourseModels.swift
