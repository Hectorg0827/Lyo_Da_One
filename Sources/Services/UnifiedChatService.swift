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
                mode: mode
            )
            
            // 6. Parse response for commands and A2UI content
            let (parsedContent, a2uiElements, courseData) = parseResponse(
                text: result.response,
                a2uiContent: result.uiContent
            )
            
            responseText = parsedContent
            
            // 7. Create AI message using LyoMessage
            let aiMessage = LyoMessage(
                id: UUID().uuidString,
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
                
                // Add to Stack
                stackStore.upsertCourse(
                    courseId: course.id,
                    title: course.title,
                    subtitle: "\(course.level.capitalized) • \(course.modules.count) modules",
                    progress: 0,
                    lessonCount: course.modules.reduce(0) { $0 + $1.lessons.count },
                    completedLessons: 0
                )
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
    
    /// Load a saved conversation
    func loadConversation(id: String) async {
        // TODO: Implement full conversation loading from persistence
        // For now, conversations are managed session-by-session
        print("📂 Load conversation requested: \(id)")
    }
    
    /// Navigate to course that was just created
    func navigateToCourse(_ course: CourseCreationData) {
        pendingCourse = course
        shouldNavigateToClassroom = true
    }
    
    /// Clear navigation flag after navigating
    func clearNavigation() {
        shouldNavigateToClassroom = false
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(
        text: String,
        a2uiContent: [A2UIContent]?
    ) -> (String, [MessageContentType], CourseCreationData?) {
        var cleanedText = text
        var elements: [MessageContentType] = []
        var courseData: CourseCreationData?
        
        // 1. Check for OPEN_CLASSROOM JSON command
        if let command = extractOpenClassroomCommand(from: text) {
            let modules = command.course.objectives.enumerated().map { index, objective in
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
                title: command.course.title,
                topic: command.course.topic,
                level: command.course.level,
                modules: modules
            )
            
            // Add courseRoadmap to elements - convert CourseModuleData to CourseModule for UI
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
                title: command.course.title,
                modules: uiModules,
                totalModules: uiModules.count,
                completedModules: 0
            ))
            
            // Replace JSON with friendly message
            cleanedText = "I've created a learning path for **\(command.course.title)**! 🎓\n\nTap 'Start Learning' below to begin."
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
        // Lightweight persistence to UserDefaults
        // For production, integrate with ConversationManager or a dedicated store
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: conversationStorageKey)
            UserDefaults.standard.set(currentConversationId, forKey: conversationStorageKey + ".id")
        } catch {
            print("⚠️ Failed to save conversation: \(error)")
        }
    }
    
    private func loadLastConversation() async {
        guard let data = UserDefaults.standard.data(forKey: conversationStorageKey),
              let loadedMessages = try? JSONDecoder().decode([LyoMessage].self, from: data) else {
            return
        }
        
        if let savedId = UserDefaults.standard.string(forKey: conversationStorageKey + ".id") {
            currentConversationId = savedId
        }
        messages = loadedMessages
        conversationHistory = loadedMessages.map { msg in
            ConversationMessage(role: msg.isFromUser ? "user" : "assistant", content: msg.content)
        }
    }
    
    private func extractTitle(from text: String) -> String {
        let words = text.split(separator: " ").prefix(5)
        return words.joined(separator: " ") + (text.split(separator: " ").count > 5 ? "..." : "")
    }
}

// NOTE: SavedConversation is defined in ConversationManager.swift
// Course models are in Sources/Models/CourseModels.swift
