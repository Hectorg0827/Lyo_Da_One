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

import Combine
import Foundation
import os

// MARK: - Unified Chat Service

@MainActor
final class UnifiedChatService: ObservableObject {
    static let shared = UnifiedChatService()

    // Dependencies
    private let repository = LyoRepository.shared
    private let chatRouter = ChatRouter.shared

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

    /// Cancellable timeout task for the current stream.
    /// Cancelled when real content (answer/done/error) arrives.
    private var streamTimeoutTask: Task<Void, Never>?

    private let backendAI = BackendAIService.shared
    private let lyo2ChatService = Lyo2ChatService.shared
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

        Log.ai.info("🆕 Started new chat session: \(self.currentConversationId)")
    }

    /// Send a message and get AI response using the Lyo 2.0 flow
    func sendMessage(
        _ text: String,
        attachments: [MessageAttachment] = [],
        context: ChatContext? = nil,
        mode: String = "chat"
    ) async -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }

        // Reset stale chips at the beginning of a new user turn.
        // New suggestions (if any) are set from backend response/actions events.
        suggestions = []

        // 1. Add user message to UI state
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: trimmedText,
            isFromUser: true,
            timestamp: Date(),
            attachments: attachments.isEmpty ? nil : attachments
        )
        messages.append(userMessage)

        // 2. Update conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: trimmedText))

        // 3. Save to persistence
        await saveConversation()

        // 4. Update stack
        stackStore.upsertChat(
            key: currentConversationId,
            title: extractTitle(from: trimmedText),
            subtitle: "Just now",
            lastMessage: trimmedText
        )

        isLoading = true
        error = nil

        // 5. Prepare placeholder AI message ID for streaming
        let aiMessageId = UUID().uuidString

        // 6. Route through ChatRouter (Two-Speed Engine)
        let result = await chatRouter.route(
            message: trimmedText,
            mode: mode,
            conversationHistory: conversationHistory,
            onAgentBlock: nil,
            onStreamEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleLyo2Event(event, aiMessageId: aiMessageId)
                }
            }
        )

        // 7. Handle routing result
        switch result {
        case .instantResponse(let text):
            // On-device instant response (greetings, navigation acks)
            let instantMsg = LyoMessage(
                id: aiMessageId,
                sessionId: currentConversationId,
                content: text,
                isFromUser: false,
                timestamp: Date(),
                contentTypes: [.text]
            )
            messages.append(instantMsg)
            conversationHistory.append(ConversationMessage(role: "assistant", content: text))
            isLoading = false
            await saveConversation()
            Log.ai.info("⚡ Instant response served on-device")

        case .fastResponse(let text, let studyPlan, let latencyMs, let chips, let coursePayload, let mappedComponents):
            // Single-agent non-streaming response
            var contentTypes: [MessageContentType] = [.text]
            // Note: studyPlan is TestPrepData, but contentType expects StudyPlan.
            // Bridge the types if a plan is present.
            if let prep = studyPlan {
                let days = prep.sessions.enumerated().map { i, s in
                    StudyDay(
                        id: s.id, dayNumber: i + 1, topic: s.topic,
                        tasks: [
                            StudyTask(
                                title: s.title, durationMinutes: s.durationMinutes,
                                type: s.activityType)
                        ])
                }
                contentTypes.append(
                    .studyPlan(plan: StudyPlan(title: prep.title, description: nil, schedule: days))
                )
            }

            // If backend returned OPEN_CLASSROOM with a CoursePayload, render as proposal card
            // User must tap "Start Class" — no auto-navigation
            if let coursePayload = coursePayload {
                Log.ai.info(
                    "🏫 Fast path: showing course proposal card for '\(coursePayload.title)' — awaiting user action"
                )
                contentTypes = [.courseProposal(payload: coursePayload)]
            } else if let components = mappedComponents, !components.isEmpty {
                // A2UI components decoded from backend ui_component field — use for rich rendering
                // Keep .text first so it still shows the text bubble, then append A2UI widgets
                for component in components {
                    contentTypes.append(.a2ui(component: component))
                }
                Log.ai.info("🎨 Fast path: \(components.count) A2UI component(s) added to chat bubble")
            }

            let fastMsg = LyoMessage(
                id: aiMessageId,
                sessionId: currentConversationId,
                content: text,
                isFromUser: false,
                timestamp: Date(),
                contentTypes: contentTypes,
                shouldAnimate: true
            )
            messages.append(fastMsg)
            conversationHistory.append(ConversationMessage(role: "assistant", content: text))
            isLoading = false
            await saveConversation()
            Log.ai.info("⚡ Fast path response in \(String(format: "%.0f", latencyMs))ms")

            // Update suggestion chips from backend response (context-aware follow-ups)
            if let backendChips = chips, !backendChips.isEmpty {
                if shouldSuppressGenericSuggestions(for: trimmedText, chips: backendChips) {
                    suggestions = []
                    Log.ai.info("💡 Suppressed generic fallback chips for simple prompt")
                } else {
                    suggestions = backendChips
                    Log.ai.info("💡 Updated \(backendChips.count) suggestion chips from backend")
                }
            } else {
                suggestions = []
            }

            // Bridge: Scan for OPEN_CLASSROOM commands in fast responses too
            scanForCommands(in: text, messageId: aiMessageId)

        case .streamingStarted(let sessionId):
            // Deep path — event handling happens via the onStreamEvent callback above
            // The handleLyo2Event closure handles skeleton, answer, artifact, etc.
            Log.ai.info(
                "🧠 Deep path streaming started (session: \(sessionId)) — events handled via callback"
            )

            // Safety timeout: if the deep-path pipeline hasn't delivered content
            // within 90s, clear loading state so the UI isn't stuck forever.
            // The deep path (3-layer multi-agent pipeline) can legitimately take
            // 40-60s, so 90s gives plenty of headroom.
            // This task is CANCELLED by handleLyo2Event when real content arrives.
            streamTimeoutTask?.cancel()
            streamTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 90_000_000_000)  // 90 seconds
                guard !Task.isCancelled else { return }
                guard let self, self.isLoading else { return }
                // Still loading after 90s → stream likely failed silently
                self.isLoading = false
                // Replace the skeleton placeholder (if it exists) instead of
                // appending a duplicate message with the same ID.
                if let idx = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                    let timeoutMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: self.currentConversationId,
                        content: "Response timed out. Please try again.",
                        isFromUser: false,
                        timestamp: self.messages[idx].timestamp,
                        contentTypes: [.text]
                    )
                    self.messages[idx] = timeoutMsg
                } else {
                    let timeoutMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: self.currentConversationId,
                        content: "Response timed out. Please try again.",
                        isFromUser: false,
                        timestamp: Date(),
                        contentTypes: [.text]
                    )
                    self.messages.append(timeoutMsg)
                }
                Log.ai.warning("⏰ Stream timeout — cleared loading state after 90s")
            }

        case .error(let message):
            let errorMsg = LyoMessage(
                id: aiMessageId,
                sessionId: currentConversationId,
                content: message,
                isFromUser: false,
                timestamp: Date(),
                contentTypes: [.text]
            )
            messages.append(errorMsg)
            self.error = message
            isLoading = false
            await saveConversation()
            Log.ai.error("❌ Chat routing error: \(message)")
        }

        return nil  // Result is updated via handleLyo2Event or inline above
    }

    /// Scan response text for embedded AI commands (OPEN_CLASSROOM)
    /// NOTE: Only triggers on explicit OPEN_CLASSROOM markers in the text.
    /// Normal markdown (** bold **, # headings) must NOT trigger this.
    private func scanForCommands(in text: String, messageId: String) {
        let hasPotentialCommand = text.contains("OPEN_CLASSROOM")

        guard hasPotentialCommand else { return }

        let parsed = AICommandParser.parse(text)
        if case .command(let command) = parsed {
            Log.ai.info("🔗 Detected AI command in fast response: \(command.type.rawValue)")

            // For OPEN_CLASSROOM: render a proposal card instead of auto-navigating
            if command.type == .openClassroom, let course = command.payload?.course {
                Log.ai.info("📋 Rendering course proposal card (user must approve)")
                if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                    let proposalMsg = LyoMessage(
                        id: messageId,
                        sessionId: currentConversationId,
                        content: "I found the perfect course for you! 🎓",
                        isFromUser: false,
                        timestamp: messages[idx].timestamp,
                        contentTypes: [.courseProposal(payload: course)]
                    )
                    messages[idx] = proposalMsg
                }
                return
            }

            let result = AICommandHandler.shared.handleCommand(command)
            if result.wasCommand {
                if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                    let friendlyMsg = LyoMessage(
                        id: messageId,
                        sessionId: currentConversationId,
                        content: result.displayText,
                        isFromUser: false,
                        timestamp: messages[idx].timestamp,
                        contentTypes: [.text]
                    )
                    messages[idx] = friendlyMsg
                }
            }
        }
    }

    // MARK: - Streaming Support (Lyo 2.0 Pipeline)

    func sendMessageStreaming(
        _ text: String,
        attachments: [MessageAttachment] = [],
        context: ChatContext? = nil,
        mode: String = "chat",
        speakResponse: Bool = false
    ) async {
        // Re-route through sendMessage which now uses ChatRouter for two-speed routing
        _ = await sendMessage(text, attachments: attachments, context: context, mode: mode)
    }

    // MARK: - Conversation Memory Window

    /// Maximum number of recent messages to include as context for the AI.
    /// Keeps token usage reasonable while preserving conversational continuity.
    private static let maxHistoryTurns = 20

    /// Build a trimmed conversation history window for the AI request.
    /// Keeps only the most recent turns so the LLM stays within token limits.
    private func buildMemoryWindow() -> [Lyo2ConversationTurn] {
        let window = conversationHistory.suffix(Self.maxHistoryTurns)
        return window.map { Lyo2ConversationTurn(role: $0.role, content: $0.content) }
    }

    // MARK: - Lyo 2.0 Streaming Flow

    func sendMessageLyo2(
        text: String,
        attachments: [MessageAttachment] = []
    ) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // 1. Add User Message
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: trimmedText,
            isFromUser: true,
            timestamp: Date(),
            attachments: attachments.isEmpty ? nil : attachments
        )
        messages.append(userMessage)
        conversationHistory.append(ConversationMessage(role: "user", content: trimmedText))
        await saveConversation()

        isLoading = true

        // Lyo 2.0 streaming should work with API key even when no auth token is present.
        // Keep all traffic on Lyo 2.0 to avoid legacy endpoint drift.

        // 2. Prepare Placeholder AI Message ID
        let aiMessageId = UUID().uuidString
        // Do not append empty message yet if using skeletons, or append a "Thinking..." one

        // 3. Build conversation memory window (last N turns for AI context)
        let memoryWindow = buildMemoryWindow()
        Log.ai.info("Sending \(memoryWindow.count) history turns for context")

        // 4. Start Stream
        lyo2ChatService.sendMessageStreaming(
            text: trimmedText,
            conversationHistory: memoryWindow
        ) { [weak self] event in
            guard let self else { return }
            self.handleLyo2Event(event, aiMessageId: aiMessageId)
        }
    }

    private func handleLyo2Event(_ event: Lyo2StreamEvent, aiMessageId: String) {
        Log.ai.info("📲 UnifiedChat: received event: \(String(describing: event).prefix(120))")

        switch event {
        case .skeleton(let blocks):
            Log.ai.info("💀 Skeleton received: \(blocks)")

            // 🧠 Smart Skeleton: Intent-aware hint from block types
            let skeletonHint = inferSkeletonHint(from: blocks)
            Log.ai.info("💀 Skeleton hint: \(skeletonHint)")

            // Create initial placeholder if not exists
            if !messages.contains(where: { $0.id == aiMessageId }) {
                let skeletonMsg = LyoMessage(
                    id: aiMessageId,
                    sessionId: currentConversationId,
                    content: "",  // Content will be filled by 'answer' block
                    isFromUser: false,
                    timestamp: Date(),
                    contentTypes: [.processing(step: skeletonHint, progress: nil)]
                )
                messages.append(skeletonMsg)
            }

        case .answer(let block):
            // ✅ Real content arrived — cancel the safety timeout
            streamTimeoutTask?.cancel()
            streamTimeoutTask = nil

            Log.ai.info("Answer block received — content keys: \(block.content.keys.sorted())")

            // Extract text: backend may send "text" or "markdown" key
            let rawText =
                (block.content["text"]?.value as? String)
                ?? (block.content["markdown"]?.value as? String)
                ?? ""

            // Strip agent markers injected by the backend (e.g. "[tutor]\n", "[quiz]\n")
            let agentTags = ["[tutor]", "[quiz]", "[sentiment]", "[content]", "[metacognition]"]
            var answerText = rawText
            for tag in agentTags {
                if answerText.hasPrefix(tag) {
                    answerText = String(answerText.dropFirst(tag.count))
                    if answerText.hasPrefix("\n") {
                        answerText = String(answerText.dropFirst())
                    }
                    break
                }
            }
            answerText = answerText.trimmingCharacters(in: .whitespacesAndNewlines)

            Log.ai.info("Answer text (\(answerText.count) chars): \(answerText.prefix(100))")

            if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                // Update the skeleton/placeholder message with the real answer
                // 🎬 shouldAnimate = true → triggers typewriter in the message bubble

                // Strip the loading skeleton marker — an answer has arrived.
                // If .processing is left in, the .done handler mistakes this message
                // as "orphaned" and overwrites it with the error fallback.
                var finalTypes = (messages[idx].contentTypes ?? []).filter {
                    if case .processing = $0 { return false }
                    return true
                }

                // --- Generative UI Block parsing ---
                let parsedResponse = AIResponseParser.shared.parse(answerText)
                if let blocks = parsedResponse.uiBlocks, !blocks.isEmpty {
                    finalTypes.append(.generativeUI(blocks: blocks))
                    if let newText = parsedResponse.displayText {
                        answerText = newText
                    }
                }

                if !finalTypes.contains(.text) {
                    finalTypes.append(.text)
                }

                let updatedMessage = LyoMessage(
                    id: aiMessageId,
                    sessionId: messages[idx].sessionId,
                    content: answerText,
                    isFromUser: false,
                    timestamp: messages[idx].timestamp,
                    attachments: messages[idx].attachments,
                    actions: messages[idx].actions,
                    status: messages[idx].status,
                    contentTypes: finalTypes,
                    responseMode: messages[idx].responseMode,
                    quickExplainer: messages[idx].quickExplainer,
                    courseProposal: messages[idx].courseProposal,
                    shouldAnimate: true
                )
                messages[idx] = updatedMessage
                Log.ai.info("Answer message updated at index \(idx) with types: \(finalTypes)")
            } else {
                // No skeleton existed — append as new message

                // --- Generative UI Block parsing ---
                var finalTypes: [MessageContentType] = []
                let parsedResponse = AIResponseParser.shared.parse(answerText)
                if let blocks = parsedResponse.uiBlocks, !blocks.isEmpty {
                    finalTypes.append(.generativeUI(blocks: blocks))
                    if let newText = parsedResponse.displayText {
                        answerText = newText
                    }
                }

                if !finalTypes.contains(.text) {
                    finalTypes.append(.text)
                }

                let answerMsg = LyoMessage(
                    id: aiMessageId,
                    sessionId: currentConversationId,
                    content: answerText,
                    isFromUser: false,
                    timestamp: Date(),
                    contentTypes: finalTypes
                )
                messages.append(answerMsg)
                Log.ai.info("Answer message appended (no skeleton found)")
            }

            conversationHistory.append(ConversationMessage(role: "assistant", content: answerText))
            Task { await saveConversation() }

            // 🔗 Bridge: Scan answer text for explicit OPEN_CLASSROOM commands
            // Only triggers when the answer text literally contains "OPEN_CLASSROOM"
            // Normal markdown with **bold** or # headings must NOT trigger this.
            // For course creation, trust the backend's explicit open_classroom SSE event.
            let hasPotentialCommand = answerText.contains("OPEN_CLASSROOM")

            if hasPotentialCommand {
                let parsed = AICommandParser.parse(answerText)
                if case .command(let command) = parsed {
                    Log.ai.info(
                        "Detected AI command in streaming answer type: \(command.type.rawValue)")

                    // For OPEN_CLASSROOM: render a proposal card instead of auto-navigating
                    if command.type == .openClassroom, let course = command.payload?.course {
                        Log.ai.info(
                            "📋 Rendering course proposal card from stream answer (user must approve)"
                        )
                        if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                            let proposalMsg = LyoMessage(
                                id: aiMessageId,
                                sessionId: currentConversationId,
                                content: "I found the perfect course for you! 🎓",
                                isFromUser: false,
                                timestamp: messages[idx].timestamp,
                                contentTypes: [.courseProposal(payload: course)]
                            )
                            messages[idx] = proposalMsg
                        }
                    } else {
                        let result = AICommandHandler.shared.handleCommand(command)
                        if result.wasCommand {
                            if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                                let friendlyMsg = LyoMessage(
                                    id: aiMessageId,
                                    sessionId: currentConversationId,
                                    content: result.displayText,
                                    isFromUser: false,
                                    timestamp: messages[idx].timestamp,
                                    contentTypes: [.text]
                                )
                                messages[idx] = friendlyMsg
                            }
                        }
                    }
                }
            }

        case .artifact(let block):
            Log.ai.info("Artifact block received: \(String(describing: block.blockType))")

            // 1. Try standard Lyo2UIBlock → MessageContentType mapping
            if let contentType = mapArtifactToContentType(block) {
                // Replace existing answer message to avoid duplicate bubbles
                if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                    let existingTypes = messages[idx].contentTypes ?? []
                    // Merge: keep existing content types and add the artifact
                    var mergedTypes = existingTypes.filter {
                        if case .processing = $0 { return false } else { return true }
                    }
                    mergedTypes.append(contentType)
                    mergedTypes = normalizeContentTypes(mergedTypes)
                    let artifactMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: messages[idx].sessionId,
                        content: messages[idx].content,
                        isFromUser: false,
                        timestamp: messages[idx].timestamp,
                        contentTypes: mergedTypes,
                        isRevealed: false
                    )
                    messages[idx] = artifactMsg

                    // Reveal after a short delay with spring animation
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms buffer
                        self.revealMessage(id: aiMessageId)
                    }
                } else {
                    let artifactMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: currentConversationId,
                        content: "",
                        isFromUser: false,
                        timestamp: Date(),
                        contentTypes: [contentType],
                        isRevealed: false
                    )
                    messages.append(artifactMsg)

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        self.revealMessage(id: aiMessageId)
                    }
                }

                Task { await saveConversation() }
            }

            // 2. Try to decode A2UI component from artifact content
            else if let a2uiComponent = tryDecodeA2UIComponent(from: block) {
                Log.ai.info(
                    "🎨 A2UI component decoded from artifact: \(String(describing: a2uiComponent.type))"
                )
                // Replace existing answer message with A2UI content to avoid duplicate bubbles
                if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                    // Merge types
                    var currentTypes = messages[idx].contentTypes ?? []
                    // Remove processing
                    currentTypes.removeAll {
                        if case .processing = $0 { return true } else { return false }
                    }
                    // Add new component
                    currentTypes.append(.a2ui(component: a2uiComponent))
                    currentTypes = normalizeContentTypes(currentTypes)

                    let a2uiMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: messages[idx].sessionId,
                        content: messages[idx].content,  // Keep existing text
                        isFromUser: false,
                        timestamp: messages[idx].timestamp,
                        contentTypes: currentTypes
                    )
                    messages[idx] = a2uiMsg
                } else {
                    let a2uiMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: currentConversationId,
                        content: "",
                        isFromUser: false,
                        timestamp: Date(),
                        contentTypes: [.a2ui(component: a2uiComponent)]
                    )
                    messages.append(a2uiMsg)
                }
                Task { await saveConversation() }
            }

            // 3. Check if artifact contains OPEN_CLASSROOM payload → render proposal card
            else if let coursePayload = tryDecodeOpenClassroom(from: block) {
                Log.ai.info(
                    "📋 OPEN_CLASSROOM detected in artifact — showing proposal card (user must tap Start Class)"
                )
                // Replace the existing answer message to avoid duplicates
                if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                    // Merge types
                    var currentTypes = messages[idx].contentTypes ?? []
                    currentTypes.removeAll {
                        if case .processing = $0 { return true } else { return false }
                    }
                    currentTypes.append(.courseProposal(payload: coursePayload))
                    currentTypes = normalizeContentTypes(currentTypes)

                    let proposalMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: messages[idx].sessionId,
                        content: messages[idx].content,  // Keep existing text
                        isFromUser: false,
                        timestamp: messages[idx].timestamp,
                        contentTypes: currentTypes
                    )
                    messages[idx] = proposalMsg
                } else {
                    let proposalMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: currentConversationId,
                        content: "",
                        isFromUser: false,
                        timestamp: Date(),
                        contentTypes: [.courseProposal(payload: coursePayload)]
                    )
                    messages.append(proposalMsg)
                }
                Task { await saveConversation() }
            }

        case .clarification(let text):
            Log.ai.info("🤔 Clarification received: \(text.prefix(100))")
            // Replace the skeleton/placeholder with the clarification text
            if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                let clarificationMsg = LyoMessage(
                    id: aiMessageId,
                    sessionId: messages[idx].sessionId,
                    content: text,
                    isFromUser: false,
                    timestamp: messages[idx].timestamp,
                    contentTypes: [.text]
                )
                messages[idx] = clarificationMsg
            } else {
                let clarificationMsg = LyoMessage(
                    id: UUID().uuidString,
                    sessionId: currentConversationId,
                    content: text,
                    isFromUser: false,
                    timestamp: Date(),
                    contentTypes: [.text]
                )
                messages.append(clarificationMsg)
            }
            conversationHistory.append(ConversationMessage(role: "assistant", content: text))
            Task { await saveConversation() }

        case .actions(let blocks):
            Log.ai.info("️ Actions received: \(blocks.count)")
            var newSuggestions: [SuggestionChip] = []

            for block in blocks {
                if block.blockType == .ctaRow {
                    // Backend sends "actions" array of strings for CTA buttons
                    if let actions = block.content["actions"]?.value as? [String] {
                        for label in actions {
                            newSuggestions.append(
                                SuggestionChip(
                                    id: UUID().uuidString,
                                    text: label,
                                    icon: Self.iconForChipLabel(label),
                                    actionType: nil,
                                    context: nil
                                ))
                        }
                    }
                    // Also check legacy "buttons" format
                    if let buttons = block.content["buttons"]?.value as? [[String: Any]] {
                        for btn in buttons {
                            if let label = btn["label"] as? String {
                                newSuggestions.append(
                                    SuggestionChip(
                                        id: UUID().uuidString,
                                        text: label,
                                        icon: Self.iconForChipLabel(label),
                                        actionType: btn["action_type"] as? String,
                                        context: nil
                                    ))
                            }
                        }
                    }
                }
            }

            if !newSuggestions.isEmpty {
                self.suggestions = newSuggestions
                Log.ai.info("Set \(newSuggestions.count) suggestion chips")
            } else {
                self.suggestions = []
            }

        case .error(let message):
            // ✅ Stream error — cancel the safety timeout
            streamTimeoutTask?.cancel()
            streamTimeoutTask = nil

            Log.ai.error("Stream error: \(message)")
            // Replace skeleton with a visible error message so the chat doesn't go blank
            if let idx = messages.firstIndex(where: {
                $0.id == aiMessageId
                    && $0.contentTypes?.contains(where: {
                        if case .processing = $0 { return true } else { return false }
                    }) == true
            }) {
                let errorMsg = LyoMessage(
                    id: aiMessageId,
                    sessionId: messages[idx].sessionId,
                    content: message,
                    isFromUser: false,
                    timestamp: messages[idx].timestamp,
                    contentTypes: [.text]
                )
                messages[idx] = errorMsg
            } else {
                // No skeleton to replace — append error as a new message
                let errorMsg = LyoMessage(
                    id: UUID().uuidString,
                    sessionId: currentConversationId,
                    content: message,
                    isFromUser: false,
                    timestamp: Date(),
                    contentTypes: [.text]
                )
                messages.append(errorMsg)
            }
            self.error = message
            isLoading = false

        case .openClassroom(let block):
            Log.ai.info(
                "📋 OPEN_CLASSROOM stream event — showing proposal card (user must tap Start Class)")
            if let coursePayload = tryDecodeOpenClassroom(from: block) {
                // Show interactive proposal card — user chooses Start Class / Save to Stack / Refine Course
                let proposalContent =
                    "Here's your course proposal! Tap **Start Class** to begin, **Save to Stack** to save for later, or **Refine Course** to adjust. 🎓"
                if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                    let proposalMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: messages[idx].sessionId,
                        content: proposalContent,
                        isFromUser: false,
                        timestamp: messages[idx].timestamp,
                        contentTypes: [.courseProposal(payload: coursePayload)]
                    )
                    messages[idx] = proposalMsg
                } else {
                    let proposalMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: currentConversationId,
                        content: proposalContent,
                        isFromUser: false,
                        timestamp: Date(),
                        contentTypes: [.courseProposal(payload: coursePayload)]
                    )
                    messages.append(proposalMsg)
                }
                Task { await saveConversation() }
            }

        case .a2ui(let block):
            Log.ai.info("🎨 A2UI stream event received!")
            // Decode the A2UI component first — this IS an A2UI event.
            // Only check for classroom intent if the decoded component signals it
            // (open_classroom arrives as a SEPARATE SSE event type handled by .openClassroom above).
            if let a2uiComponent = tryDecodeA2UIComponent(from: block) {
                // Check if this A2UI component carries an open_classroom intent
                if let coursePayload = extractCourseFromComponent(a2uiComponent) {
                    Log.ai.info(
                        "📋 A2UI component has classroom intent — showing proposal card (no auto-navigate)"
                    )
                    if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                        var currentTypes = messages[idx].contentTypes ?? []
                        currentTypes.removeAll {
                            if case .processing = $0 { return true } else { return false }
                        }
                        currentTypes.append(.courseProposal(payload: coursePayload))
                        currentTypes = normalizeContentTypes(currentTypes)

                        let proposalMsg = LyoMessage(
                            id: aiMessageId,
                            sessionId: messages[idx].sessionId,
                            content: messages[idx].content,
                            isFromUser: false,
                            timestamp: messages[idx].timestamp,
                            contentTypes: currentTypes
                        )
                        messages[idx] = proposalMsg
                    } else {
                        let proposalMsg = LyoMessage(
                            id: aiMessageId,
                            sessionId: currentConversationId,
                            content: "",
                            isFromUser: false,
                            timestamp: Date(),
                            contentTypes: [.courseProposal(payload: coursePayload)]
                        )
                        messages.append(proposalMsg)
                    }
                } else {
                    // Regular A2UI component (card, quiz, flashcard, etc.)
                    Log.ai.info("🎨 Rendering A2UI component: type=\(a2uiComponent.type.rawValue)")
                    if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                        var currentTypes = messages[idx].contentTypes ?? []
                        currentTypes.removeAll {
                            if case .processing = $0 { return true } else { return false }
                        }
                        currentTypes.append(.a2ui(component: a2uiComponent))
                        currentTypes = normalizeContentTypes(currentTypes)

                        let a2uiMsg = LyoMessage(
                            id: aiMessageId,
                            sessionId: messages[idx].sessionId,
                            content: messages[idx].content,
                            isFromUser: false,
                            timestamp: messages[idx].timestamp,
                            contentTypes: currentTypes
                        )
                        messages[idx] = a2uiMsg
                    } else {
                        let a2uiMsg = LyoMessage(
                            id: aiMessageId,
                            sessionId: currentConversationId,
                            content: "",
                            isFromUser: false,
                            timestamp: Date(),
                            contentTypes: [.a2ui(component: a2uiComponent)]
                        )
                        messages.append(a2uiMsg)
                    }
                }
                Task { await saveConversation() }
            } else {
                Log.ai.warning("🎨 ⚠️ Could not decode A2UI component from block")
            }

        // ── v2 events (LyoResponse envelope) ──────────────────────

        case .lyoUI(let response):
            Log.ai.info("🎨 v2 lyo_ui event received")
            // Decode the v2 UI component from the LyoResponse
            if let uiComponent = response.ui {
                // Convert LyoUIComponent → A2UIComponent for rendering via existing pipeline
                // The v2 renderer will be triggered by the variant field presence
                let a2uiComponent = lyoUIComponentToA2UI(uiComponent)
                if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                    var currentTypes = messages[idx].contentTypes ?? []
                    currentTypes.removeAll {
                        if case .processing = $0 { return true } else { return false }
                    }
                    currentTypes.append(.a2ui(component: a2uiComponent))
                    currentTypes = normalizeContentTypes(currentTypes)

                    let a2uiMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: messages[idx].sessionId,
                        content: messages[idx].content,
                        isFromUser: false,
                        timestamp: messages[idx].timestamp,
                        contentTypes: currentTypes
                    )
                    messages[idx] = a2uiMsg
                } else {
                    let a2uiMsg = LyoMessage(
                        id: aiMessageId,
                        sessionId: currentConversationId,
                        content: "",
                        isFromUser: false,
                        timestamp: Date(),
                        contentTypes: [.a2ui(component: a2uiComponent)]
                    )
                    messages.append(a2uiMsg)
                }
                Task { await saveConversation() }
            }

        case .lyoCommand(let response):
            Log.ai.info("🎨 v2 lyo_command event received")
            if let command = response.command {
                if command.action == "open_classroom",
                   let payload = command.payload,
                   let payloadData = try? JSONSerialization.data(withJSONObject: payload),
                   let courseDict = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                   let coursePayload = tryDecodeOpenClassroomDict(courseDict) {
                    let proposalContent =
                        "Here's your course proposal! Tap **Start Class** to begin. 🎓"
                    if let idx = messages.firstIndex(where: { $0.id == aiMessageId }) {
                        let proposalMsg = LyoMessage(
                            id: aiMessageId,
                            sessionId: messages[idx].sessionId,
                            content: proposalContent,
                            isFromUser: false,
                            timestamp: messages[idx].timestamp,
                            contentTypes: [.courseProposal(payload: coursePayload)]
                        )
                        messages[idx] = proposalMsg
                    }
                    Task { await saveConversation() }
                }
            }

        case .lyoSuggestions(let response):
            Log.ai.info("🎨 v2 lyo_suggestions event received")
            if let suggestions = response.suggestions {
                var newSuggestions: [SuggestionChip] = []
                for suggestion in suggestions {
                    newSuggestions.append(
                        SuggestionChip(
                            id: UUID().uuidString,
                            text: suggestion.text,
                            icon: Self.iconForChipLabel(suggestion.text),
                            actionType: suggestion.actionId,
                            context: nil
                        )
                    )
                }
                if !newSuggestions.isEmpty {
                    self.suggestions = newSuggestions
                    Log.ai.info("Set \(newSuggestions.count) v2 suggestion chips")
                }
            }

        case .done:
            // ✅ Stream completed — cancel the safety timeout
            streamTimeoutTask?.cancel()
            streamTimeoutTask = nil

            Log.ai.info("🏁 Stream done — cleaning up")
            // If the skeleton placeholder is still present, the backend never sent an answer/clarification.
            // Instead of silently removing it (which causes blank UI), replace with a fallback message.
            if let idx = messages.firstIndex(where: {
                $0.id == aiMessageId
                    && $0.contentTypes?.contains(where: {
                        if case .processing = $0 { return true } else { return false }
                    }) == true
            }) {
                let fallbackMsg = LyoMessage(
                    id: aiMessageId,
                    sessionId: messages[idx].sessionId,
                    content: "I wasn't able to generate a response. Please try again.",
                    isFromUser: false,
                    timestamp: messages[idx].timestamp,
                    contentTypes: [.text]
                )
                messages[idx] = fallbackMsg
                Log.ai.warning(
                    "⚠️ Replaced orphaned skeleton with fallback message (no answer received)")
            }
            // If the orchestrator produced mapped A2UI components for this response,
            // attach them to the final message so the UI renders them inline.
            if let mapped = LyoOrchestrator.shared.lastMappedComponents,
                !mapped.isEmpty,
                let idx = messages.firstIndex(where: { $0.id == aiMessageId })
            {
                var currentTypes = messages[idx].contentTypes ?? []
                // Remove any processing placeholders
                currentTypes.removeAll {
                    if case .processing = $0 { return true } else { return false }
                }
                // Append each mapped component as an A2UI type
                for comp in mapped {
                    currentTypes.append(.a2ui(component: comp))
                }
                currentTypes = normalizeContentTypes(currentTypes)
                let updated = LyoMessage(
                    id: messages[idx].id,
                    sessionId: messages[idx].sessionId,
                    content: messages[idx].content,
                    isFromUser: messages[idx].isFromUser,
                    timestamp: messages[idx].timestamp,
                    contentTypes: currentTypes,
                    isRevealed: messages[idx].isRevealed
                )
                messages[idx] = updated
                Task { await saveConversation() }
            }

            isLoading = false
        }
    }

    private func mapArtifactToContentType(_ block: Lyo2UIBlock) -> MessageContentType? {
        switch block.blockType {
        case .quiz:
            if let question = block.content["question"]?.value as? String,
                let options = block.content["options"]?.value as? [String],
                let correctIndex = block.content["correct_index"]?.value as? Int
            {
                return .quiz(
                    question: question, options: options, correctIndex: correctIndex,
                    explanation: block.content["explanation"]?.value as? String)
            }
            return nil

        case .studyPlan:
            if let title = block.content["title"]?.value as? String,
                let scheduleArray = block.content["schedule"]?.value as? [[String: Any]]
            {

                var studyDays: [StudyDay] = []
                for dayDict in scheduleArray {
                    if let dayNum = dayDict["day"] as? Int ?? dayDict["day_number"] as? Int,
                        let tasksArr = dayDict["tasks"] as? [[String: Any]]
                    {

                        let topic = dayDict["topic"] as? String ?? "Study Day \(dayNum)"
                        var tasks: [StudyTask] = []
                        for t in tasksArr {
                            if let tTitle = t["title"] as? String,
                                let dur = t["duration_minutes"] as? Int ?? t["duration"] as? Int,
                                let type = t["type"] as? String
                            {
                                tasks.append(
                                    StudyTask(
                                        id: UUID().uuidString, title: tTitle, durationMinutes: dur,
                                        type: type)
                                )
                            }
                        }
                        studyDays.append(
                            StudyDay(
                                id: UUID().uuidString, dayNumber: dayNum, topic: topic, tasks: tasks
                            ))
                    }
                }

                if !studyDays.isEmpty {
                    return .studyPlan(
                        plan: StudyPlan(
                            title: title,
                            description: block.content["description"]?.value as? String,
                            schedule: studyDays))
                }
            }
            return nil

        case .flashcards:
            if let title = block.content["title"]?.value as? String,
                let cardsArray = block.content["cards"]?.value as? [[String: Any]]
            {

                let cards = cardsArray.compactMap { dict -> Flashcard? in
                    guard let front = dict["front"] as? String,
                        let back = dict["back"] as? String
                    else { return nil }
                    return Flashcard(front: front, back: back)
                }

                if !cards.isEmpty {
                    return .flashcards(title: title, cards: cards)
                }
            }
            return nil

        case .code:
            if let language = block.content["language"]?.value as? String,
                let code = block.content["code"]?.value as? String
            {
                return .codeSnippet(language: language, code: code)
            }
            return nil

        default:
            return nil
        }
    }

    /// Remove plain `.text` content type whenever rich widgets are present.
    /// This prevents duplicate rendering (text bubble + A2UI/course card) for a single AI turn.
    private func normalizeContentTypes(_ types: [MessageContentType]) -> [MessageContentType] {
        let hasRichContent = types.contains { contentType in
            switch contentType {
            case .a2ui, .courseProposal, .courseRoadmap, .quiz, .flashcards, .studyPlan, .testPrep,
                .recursiveUI, .cinematic, .generativeUI:
                return true
            default:
                return false
            }
        }

        guard hasRichContent else { return types }

        return types.filter { contentType in
            if case .text = contentType { return false }
            return true
        }
    }

    /// Suppress generic fallback chips for simple greeting/ack prompts.
    /// This avoids always-on "Create / Quiz Me / Deep Dive" style overlays after trivial messages.
    private func shouldSuppressGenericSuggestions(for userPrompt: String, chips: [SuggestionChip])
        -> Bool
    {
        let normalizedPrompt =
            userPrompt
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedChipTexts = chips.map {
            $0.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let isSimplePrompt = normalizedPrompt.split(separator: " ").count <= 3
        let simplePrompts: Set<String> = [
            "hi", "hello", "hey", "yo", "ok", "okay", "thanks", "thank you",
        ]
        let isGreetingOrAck = simplePrompts.contains(normalizedPrompt)

        let genericChipKeywords: [String] = ["create", "course", "quiz", "deep dive", "deepdive"]
        let genericCount = normalizedChipTexts.reduce(0) { partial, chipText in
            partial + (genericChipKeywords.contains { chipText.contains($0) } ? 1 : 0)
        }

        return (isSimplePrompt || isGreetingOrAck) && genericCount >= 2
    }

    // MARK: - A2UI / Course Bridge Helpers

    // MARK: - Suggestion Chip Helpers

    /// Maps a suggestion chip label to the appropriate SF Symbol icon
    private static func iconForChipLabel(_ label: String) -> String {
        let lowered = label.lowercased()
        if lowered.contains("course") || lowered.contains("create") { return "plus.circle.fill" }
        if lowered.contains("quiz") { return "questionmark.circle.fill" }
        if lowered.contains("deep dive") || lowered.contains("dive") {
            return "text.magnifyingglass"
        }
        if lowered.contains("flashcard") || lowered.contains("cards") {
            return "rectangle.stack.fill"
        }
        if lowered.contains("tell me more") || lowered.contains("more") {
            return "text.bubble.fill"
        }
        if lowered.contains("review") { return "arrow.counterclockwise.circle.fill" }
        if lowered.contains("plan") || lowered.contains("modify") {
            return "list.bullet.clipboard.fill"
        }
        if lowered.contains("start") { return "play.circle.fill" }
        return "sparkles"
    }

    // MARK: - Lyo Protocol Helpers

    /// Infer a user-facing skeleton hint from the declared block types.
    /// The backend skeleton event contains block type names like "QuizBlock", "FlashcardsBlock", etc.
    private func inferSkeletonHint(from blocks: [String]) -> String {
        let joined = blocks.joined(separator: " ").lowercased()

        if joined.contains("quiz") { return "Building a quiz for you…" }
        if joined.contains("flashcard") { return "Creating flashcards…" }
        if joined.contains("studyplan") { return "Preparing your study plan…" }
        if joined.contains("code") { return "Writing code…" }
        if joined.contains("openclassroom") || joined.contains("course") {
            return "Setting up your classroom…"
        }
        if joined.contains("a2ui") { return "Designing your experience…" }
        if joined.contains("skeleton") { return "Thinking deeply…" }

        // Fallback: if blocks contain only "TutorMessageBlock", it's a simple text answer
        if blocks.count == 1 && joined.contains("tutormessage") { return "Composing a response…" }

        return "Thinking…"
    }

    /// Reveal a hidden artifact message with animation (Buffer-and-Reveal pattern).
    private func revealMessage(id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        var msg = messages[idx]
        msg.isRevealed = true
        messages[idx] = msg
        Log.ai.info("🎬 Revealed artifact message: \(id)")
    }

    /// Recursively convert arbitrary Swift values into JSON-serializable Foundation types.
    /// - Converts dictionaries and arrays recursively.
    /// - Converts enum `A2UIElementType` values to their raw `String` representation.
    /// - Leaves String/NSNumber/NSNull as-is. Falls back to `String(describing:)` for others.
    private func makeJSONSafe(_ value: Any) -> Any {
        // Handle dictionaries
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for (k, v) in dict { out[k] = makeJSONSafe(v) }
            return out
        }
        // Handle arrays
        if let array = value as? [Any] {
            return array.map { makeJSONSafe($0) }
        }
        // Specific handling for A2UIElementType enum → use rawValue
        if let elementType = value as? A2UIElementType {
            return elementType.rawValue
        }
        // Pass through JSON primitives
        if value is String || value is NSNumber || value is NSNull {
            return value
        }
        // Bridge common Swift numeric types to NSNumber
        if let intVal = value as? Int { return NSNumber(value: intVal) }
        if let doubleVal = value as? Double { return NSNumber(value: doubleVal) }
        if let floatVal = value as? Float { return NSNumber(value: floatVal) }
        if let boolVal = value as? Bool { return NSNumber(value: boolVal) }

        // Fallback: stringify unknown types
        return String(describing: value)
    }

    /// Try to decode an A2UIComponent from a Lyo2UIBlock's content dictionary.
    ///
    /// Sanitizes the raw `[String: Any]` dict produced by AnyCodable before calling
    /// JSONSerialization — Swift Void `()` (decoded from JSON null) is not a valid
    /// ObjC-bridgeable type and causes JSONSerialization.data(withJSONObject:) to throw,
    /// which was the primary silent-failure path that fell back to plain text.
    private func tryDecodeA2UIComponent(from block: Lyo2UIBlock) -> A2UIComponent? {
        // Expanded key list — backend may use any of these
        let possibleKeys = [
            "a2ui", "component", "ui", "a2ui_component", "uiComponent", "ui_component", "a2ui_tree",
        ]
        for key in possibleKeys {
            if let rawVal = block.content[key]?.value {
                // Sanitize values (convert enums and non-JSON types to JSON-safe forms)
                let sanitized = makeJSONSafe(rawVal)
                if JSONSerialization.isValidJSONObject(sanitized),
                    let data = try? JSONSerialization.data(withJSONObject: sanitized),
                    let component = try? JSONDecoder().decode(A2UIComponent.self, from: data)
                {
                    Log.ai.info(
                        "🎨 ✅ Decoded A2UIComponent from key '\(key)': type=\(component.type.rawValue)"
                    )
                    return component
                } else {
                    // Log decode error for diagnostics
                    if JSONSerialization.isValidJSONObject(sanitized) {
                        do {
                            let data = try JSONSerialization.data(withJSONObject: sanitized)
                            _ = try JSONDecoder().decode(A2UIComponent.self, from: data)
                        } catch {
                            Log.ai.warning("🎨 ⚠️ Decode failed for key '\(key)': \(error)")
                        }
                    } else {
                        Log.ai.warning(
                            "🎨 ⚠️ Value for key '\(key)' is not a valid JSON object after sanitization"
                        )
                    }
                }
            }
        }

        // Fallback: try decoding the entire content dict directly as an A2UIComponent.
        // The backend sometimes places component fields at the root of "content" without a wrapper key.
        // BUG-B FIX: only require "type" (id is generated by A2UIComponent's custom decoder).
        let rawContentDict = block.content.mapValues { $0.value }
        if rawContentDict["type"] != nil {
            let sanitizedAny = makeJSONSafe(rawContentDict)
            let sanitized = (sanitizedAny as? [String: Any]) ?? rawContentDict
            if JSONSerialization.isValidJSONObject(sanitized),
                let data = try? JSONSerialization.data(withJSONObject: sanitized),
                let component = try? JSONDecoder().decode(A2UIComponent.self, from: data)
            {
                Log.ai.info(
                    "🎨 ✅ Decoded A2UIComponent from root content dict: type=\(component.type.rawValue)"
                )
                return component
            }
        }

        return nil
    }

    /// Try to decode an OPEN_CLASSROOM / CoursePayload from artifact content.
    ///
    /// Supports three detection strategies (checked in order):
    /// 1. Explicit `type: "OPEN_CLASSROOM"` marker in block content (legacy backend format)
    /// 2. A2UI component tree with `intent: "open_classroom"` in root/child props (intent-based routing)
    /// 3. Flat content fields containing `title` + `topic` (heuristic fallback)
    private func tryDecodeOpenClassroom(from block: Lyo2UIBlock) -> CoursePayload? {
        Log.ai.info("🏫 tryDecodeOpenClassroom — block keys: \(block.content.keys.sorted())")

        // ── Strategy 1: Explicit "type": "OPEN_CLASSROOM" marker ──
        if let typeStr = block.content["type"]?.value as? String,
            typeStr == "OPEN_CLASSROOM"
        {
            Log.ai.info("🏫 Found OPEN_CLASSROOM type marker")

            // Try to extract course from nested "course" or "payload" keys
            let courseKeys = ["course", "payload"]
            for key in courseKeys {
                if let courseDict = block.content[key]?.value {
                    Log.ai.info("🏫 Found nested '\(key)' dict, attempting decode")
                    do {
                        let sanitized = AnyCodable.sanitizeForJSON(courseDict)
                        let data = try JSONSerialization.data(withJSONObject: sanitized)
                        let course = try JSONDecoder().decode(CoursePayload.self, from: data)
                        Log.ai.info("🏫 ✅ Decoded CoursePayload from '\(key)': \(course.title)")
                        return course
                    } catch {
                        Log.ai.warning("🏫 Failed to decode CoursePayload from '\(key)': \(error)")
                    }
                }
            }

            // Fallback: Try decoding the entire content dict (minus "type") as CoursePayload
            var contentDict = block.content.compactMapValues { $0.value }
            contentDict.removeValue(forKey: "type")
            if !contentDict.isEmpty {
                Log.ai.info("🏫 Trying to decode full content dict as CoursePayload")
                do {
                    let sanitized = AnyCodable.sanitizeForJSON(contentDict)
                    let data = try JSONSerialization.data(withJSONObject: sanitized)
                    let course = try JSONDecoder().decode(CoursePayload.self, from: data)
                    Log.ai.info("🏫 ✅ Decoded CoursePayload from full content: \(course.title)")
                    return course
                } catch {
                    Log.ai.warning("🏫 Failed to decode full content as CoursePayload: \(error)")
                }
            }
        }

        // ── Strategy 2: A2UI component tree with intent-based routing ──
        // The backend may send: content: { "component": { type: "card", props: { intent: "open_classroom", title: "..." } } }
        let componentKeys = ["component", "a2ui", "ui", "a2ui_component"]
        for key in componentKeys {
            guard let componentDict = block.content[key]?.value else { continue }
            Log.ai.info("🏫 Found '\(key)' in content, attempting A2UI component decode")
            do {
                let sanitized = AnyCodable.sanitizeForJSON(componentDict)
                let data = try JSONSerialization.data(withJSONObject: sanitized)
                let component = try JSONDecoder().decode(A2UIComponent.self, from: data)

                // Check for intent in the component tree (root or first-level children)
                if let course = extractCourseFromComponent(component) {
                    Log.ai.info(
                        "🏫 ✅ Extracted CoursePayload from A2UI component tree: \(course.title)")
                    return course
                }
                Log.ai.info("🏫 A2UI component decoded but no classroom intent/course data found")
            } catch {
                Log.ai.warning("🏫 Failed to decode A2UIComponent from '\(key)': \(error)")
            }
        }

        // ── Strategy 3: Flat content fields (title + topic heuristic) ──
        // BUG-C FIX: Guard this strategy to ONLY fire for blocks that are explicitly
        // identified as classroom-intent. Without this guard, any A2UI card/component
        // that carries a "title" prop at the root of its content dict would be falsely
        // captured here and routed to .courseProposal instead of .a2ui.
        let hasExplicitClassroomIntent: Bool = {
            if block.blockType == .openClassroomBlock { return true }
            if let typeStr = block.content["type"]?.value as? String,
                typeStr.uppercased() == "OPEN_CLASSROOM"
            {
                return true
            }
            if let intent = block.content["intent"]?.value as? String,
                intent.lowercased().contains("classroom")
            {
                return true
            }
            if let action = block.content["action"]?.value as? String,
                action.lowercased() == "open_classroom"
            {
                return true
            }
            return false
        }()

        if hasExplicitClassroomIntent, let title = block.content["title"]?.value as? String {
            let topic = (block.content["topic"]?.value as? String) ?? title
            let objectives =
                (block.content["objectives"]?.value as? [String])
                ?? (block.content["learning_objectives"]?.value as? [String])
                ?? []
            let level =
                (block.content["level"]?.value as? String)
                ?? (block.content["difficulty"]?.value as? String)
                ?? "Beginner"
            let duration =
                (block.content["duration"]?.value as? String)
                ?? (block.content["estimated_duration"]?.value as? String)
            Log.ai.info("🏫 ✅ Built CoursePayload from flat content fields: \(title)")
            return CoursePayload(
                id: block.content["id"]?.value as? String,
                title: title,
                topic: topic,
                level: level,
                language: block.content["language"]?.value as? String,
                duration: duration,
                objectives: objectives
            )
        }

        // ── Final fallback: intent is clear but block has no title/topic fields ──
        // Use the last user message as the course topic so we don't lose the generation intent.
        if hasExplicitClassroomIntent {
            let lastUserText = messages.last(where: { $0.isFromUser })?.content
            if let topic = lastUserText, !topic.isEmpty {
                Log.ai.info("🏫 ✅ Falling back to last user message as course topic: \(topic.prefix(60))")
                return CoursePayload(
                    id: nil,
                    title: topic,
                    topic: topic,
                    level: "Beginner",
                    language: nil,
                    duration: nil,
                    objectives: []
                )
            }
        }

        Log.ai.warning("🏫 ❌ Could not decode any CoursePayload from block")
        return nil
    }

    /// Extract CoursePayload from an A2UIComponent tree.
    /// Walks the root component and its children looking for:
    /// 1. `intent: "open_classroom"` in props → synthesize CoursePayload from props
    /// 2. Props containing `title` + `subtitle` (treated as topic) → heuristic match
    private func extractCourseFromComponent(_ component: A2UIComponent) -> CoursePayload? {
        // Check root component props
        if let course = coursePayloadFromProps(component.props) {
            return course
        }

        // Check first-level children
        if let children = component.children {
            for child in children {
                if let course = coursePayloadFromProps(child.props) {
                    return course
                }
                // Check second-level children (e.g. card > vstack > content)
                if let grandchildren = child.children {
                    for grandchild in grandchildren {
                        if let course = coursePayloadFromProps(grandchild.props) {
                            return course
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Try to build a CoursePayload from A2UI component props.
    /// Returns non-nil if the props contain `intent == "open_classroom"` OR
    /// have enough course-like fields (title + subtitle/hint with course keywords).
    private func coursePayloadFromProps(_ props: A2UIProps) -> CoursePayload? {
        let hasClassroomIntent = props.intent?.lowercased() == "open_classroom"

        // Must have at least a title (either from explicit intent or heuristic)
        // When intent is present but title is missing, try subtitle/hint/label, then last user message.
        let resolvedTitle: String?
        if let explicitTitle = props.title {
            resolvedTitle = explicitTitle
        } else if hasClassroomIntent {
            // 1st fallback: any available descriptive field
            if let fieldFallback = props.subtitle ?? props.hint ?? props.label {
                resolvedTitle = fieldFallback
                Log.ai.info("🏫 open_classroom: no title in props, using field fallback: \(fieldFallback)")
            } else if let lastUserMsg = messages.last(where: { $0.isFromUser })?.content,
                      !lastUserMsg.isEmpty {
                // 2nd fallback: last user message is almost always the requested topic
                resolvedTitle = lastUserMsg
                Log.ai.info("🏫 open_classroom: no title in props, using last user message: \(lastUserMsg.prefix(60))")
            } else {
                resolvedTitle = nil
                Log.ai.warning("🏫 Found open_classroom intent but no title in props and no user messages")
            }
        } else {
            resolvedTitle = nil
        }

        guard let title = resolvedTitle else {
            return nil
        }

        if hasClassroomIntent {
            // Intent-based: trust the backend's signal
            let topic = props.subtitle ?? props.hint ?? title
            let level = props.label ?? "Beginner"
            Log.ai.info("🏫 Intent-based: building CoursePayload from props (intent=open_classroom)")
            return CoursePayload(
                id: nil,
                title: title,
                topic: topic,
                level: level,
                language: nil,
                duration: nil,
                objectives: []
            )
        }

        // Strategy 4: Heuristic fallback (if intent is missing but content strongly suggests a course)
        // Look for keywords in title/subtitle that strongly imply a generated course outline
        let heuristicKeywords = [
            "course outline", "learning path", "curriculum", "modules", "syllabus",
        ]
        let combinedText = (title + " " + (props.subtitle ?? "")).lowercased()

        if heuristicKeywords.contains(where: { combinedText.contains($0) }) {
            Log.ai.info("🏫 Heuristic-based: inferred CoursePayload from props (found keywords)")
            return CoursePayload(
                id: nil,
                title: title,
                topic: props.subtitle ?? title,
                level: props.label ?? "Beginner",
                language: nil,
                duration: nil,
                objectives: []
            )
        }

        // No explicit intent — don't heuristically guess (avoids false positives)
        return nil
    }

    // MARK: - v2 Helpers

    /// Convert a LyoUIComponent (v2) back to an A2UIComponent for rendering.
    /// The variant field on the A2UIComponent enables the v2 renderer path.
    private func lyoUIComponentToA2UI(_ lyoComponent: LyoUIComponent) -> A2UIComponent {
        // Build props from content + style
        var props = A2UIProps()
        if let content = lyoComponent.content {
            props.text = content.text ?? content.body
            props.title = content.title
            props.subtitle = content.subtitle
            props.label = content.label
            props.hint = content.hint
            if let iconName = content.icon {
                props.icon = iconName
            }
            if let imgUrl = content.imageUrl {
                props.imageUrl = imgUrl
            }
        }
        if let style = lyoComponent.style {
            props.foregroundColor = style.foreground
            props.backgroundColor = style.background
            props.spacing = style.spacing
            props.borderRadius = style.radius
            if let alignStr = style.alignment {
                props.alignment = A2UIAlignment(rawValue: alignStr)
            }
            if let fs = style.fontSize {
                props.fontSize = fs
            }
            props.fontWeight = style.fontWeight
        }

        // Map primitive type to A2UIElementType
        let elementType: A2UIElementType
        switch lyoComponent.type {
        case .text: elementType = .text
        case .media: elementType = .image
        case .divider: elementType = .divider
        case .input: elementType = .textInput
        case .button: elementType = .button
        case .container: elementType = .vStack
        case .card: elementType = .card
        case .list: elementType = .lessonList
        case .nav: elementType = .tabs
        case .quiz: elementType = .quizMcq
        case .quizResult: elementType = .gradeDisplay
        case .course: elementType = .course
        case .flashcard: elementType = .flashcard
        case .plan: elementType = .card
        case .tracker: elementType = .progressBar
        case .assignment: elementType = .card
        case .document: elementType = .card
        case .progress: elementType = .progressBar
        case .aiBubble: elementType = .text
        case .social: elementType = .card
        case .alert: elementType = .card
        case .skeleton: elementType = .skeleton
        }

        // Recursively convert children
        var children: [A2UIComponent]? = nil
        if let lyoChildren = lyoComponent.children, !lyoChildren.isEmpty {
            children = lyoChildren.map { lyoUIComponentToA2UI($0) }
        }

        return A2UIComponent(
            id: lyoComponent.id,
            type: elementType,
            props: props,
            children: children,
            variant: lyoComponent.variant
        )
    }

    /// Try to decode a CoursePayload from a raw dictionary (used by v2 lyo_command events).
    private func tryDecodeOpenClassroomDict(_ dict: [String: Any]) -> CoursePayload? {
        // Look for "course" key first
        if let courseDict = dict["course"] as? [String: Any] {
            do {
                let data = try JSONSerialization.data(withJSONObject: courseDict)
                return try JSONDecoder().decode(CoursePayload.self, from: data)
            } catch {
                Log.ai.warning("🏫 v2: Failed to decode CoursePayload from 'course' key: \(error)")
            }
        }
        // Try decoding the full dict
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(CoursePayload.self, from: data)
        } catch {
            Log.ai.warning("🏫 v2: Failed to decode CoursePayload from dict: \(error)")
        }
        return nil
    }

    private func appendToken(to messageId: String, token: String) {
        Log.ai.info("appendToken called - messageId: \(messageId), token: '\(token)'")

        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            Log.ai.warning("appendToken: Message not found for id \(messageId)")
            return
        }

        var message = messages[index]

        // Remove processing state if it exists
        if message.contentTypes?.contains(where: {
            if case .processing = $0 { return true } else { return false }
        }) == true {
            message.contentTypes = nil
        }

        // Append text by creating a NEW message (since content is immutable)
        let updatedContent = message.content + token
        Log.ai.info("Updated content now: '\(updatedContent.prefix(50))...'")

        let newMessage = LyoMessage(
            id: message.id,
            sessionId: message.sessionId,
            content: updatedContent,
            isFromUser: message.isFromUser,
            timestamp: message.timestamp,
            attachments: message.attachments,
            actions: message.actions,
            status: message.status,
            contentTypes: message.contentTypes,
            responseMode: message.responseMode,
            quickExplainer: message.quickExplainer,
            courseProposal: message.courseProposal
        )

        messages[index] = newMessage
        Log.ai.info("Message array updated at index \(index)")
    }

    private func handleStreamingError(_ error: Error) {
        isLoading = false
        self.error = error.localizedDescription

        let errorMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: currentConversationId,
            content: "I encountered an error. Please try again.",
            isFromUser: false,
            timestamp: Date(),
            status: .failed
        )
        messages.append(errorMessage)
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
            let response: LioGreetingResponse = try await NetworkClient.shared.request(
                Endpoints.ChatModule.getGreeting)

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
            conversationHistory.append(
                ConversationMessage(role: "assistant", content: response.greeting))

            // Surface greeting suggestions as quick chips if provided
            if let chips = response.suggestions, !chips.isEmpty {
                suggestions = chips.map { SuggestionChip(id: UUID().uuidString, text: $0) }
            }

        } catch {
            Log.ai.warning("Failed to fetch proactive greeting: \(error)")
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

        Log.ai.info(
            "📂 Loaded saved conversation: \(conversation.id) with \(self.messages.count) messages")
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
                "lessonTitle": "Introduction",
            ]
        )
    }

    /// Explicitly trigger navigation to the current pending course
    func triggerCourseNavigation() {
        guard let course = pendingCourse else { return }
        shouldNavigateToClassroom = true

        // Route through AICommandHandler so course data is properly populated
        // and navigation is centralized (populateGeneratedCourse + notifications)
        let payload = CoursePayload(
            id: course.id,
            title: course.title,
            topic: course.topic,
            level: course.level,
            language: "English",
            duration: "\(course.modules.count) modules",
            objectives: course.modules.map { $0.title }
        )
        AICommandHandler.shared.executeOpenClassroom(for: payload)
    }

    /// Clear navigation flags
    func clearNavigation() {
        shouldNavigateToClassroom = false
    }

    // MARK: - Response Parsing

    // MARK: - Persistence (Simplified - uses UserDefaults for now)

    private let conversationStorageKey = "com.lyo.unifiedChat.lastConversation"

    private func saveConversation() async {
        // Use ConversationManager as source of truth
        let multimodalMessages = messages.map { convertToMultimodal($0) }

        // Generate title if new
        let title =
            messages.isEmpty
            ? "New Chat" : SavedConversation.generateTitle(from: multimodalMessages)
        let preview = SavedConversation.getLastMessagePreview(from: multimodalMessages)

        let savedConversation = SavedConversation(
            id: currentConversationId,
            title: title,
            lastMessagePreview: preview,
            lastUpdated: Date(),
            messageCount: messages.count,
            messages: multimodalMessages
        )

        // Save to Manager (but don't reload - that would replace in-flight messages during streaming)
        ConversationManager.shared.saveConversation(savedConversation)

        // Update the current conversation reference directly without triggering a full reload
        ConversationManager.shared.currentConversation = savedConversation
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
            contentTypes: msg.contentTypes ?? [.text],  // Preserve A2UI widgets
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
