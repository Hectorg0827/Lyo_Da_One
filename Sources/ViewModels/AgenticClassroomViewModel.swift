//
//  AgenticClassroomViewModel.swift
//  Lyo
//
//  ViewModel for the agentic classroom experience.
//  Consumes both fast-path and deep-path responses from ChatRouter,
//  manages the cinematic rendering of multi-agent blocks,
//  and persists generated content via GeneratedContentStore.
//

import Foundation
import Combine
import SwiftUI
import os

@MainActor
final class AgenticClassroomViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// Current agent blocks being displayed (cinematic reveal order)
    @Published private(set) var visibleBlocks: [AgentBlock] = []
    
    /// The synthesized A2UI component tree for the current response
    @Published private(set) var currentComponent: A2UIComponent?
    
    /// Whether the AI is currently processing
    @Published private(set) var isProcessing: Bool = false
    
    /// Current speed tier being used
    @Published private(set) var currentTier: MessageSpeedTier = .standard
    
    /// Skeleton hint text (shown during processing)
    @Published private(set) var skeletonHint: String = ""
    
    /// Error message (if any)
    @Published var error: String?
    
    /// The conversation messages for display
    @Published private(set) var messages: [LyoMessage] = []
    
    /// Current session ID
    @Published private(set) var sessionId: String = UUID().uuidString
    
    /// Last intent classification (for debug overlay)
    @Published private(set) var lastIntent: ClassifiedIntent?
    
    // MARK: - Dependencies
    
    private let router = ChatRouter.shared
    private let synthesizer = A2UIContentSynthesizer.shared
    private let contentStore = GeneratedContentStore.shared
    private let intentClassifier = MessageIntentClassifier.shared
    
    /// Conversation history for context continuity
    private var conversationHistory: [ConversationMessage] = []
    
    /// Pending blocks waiting for cinematic reveal
    private var pendingBlocks: [AgentBlock] = []
    
    /// Timer for staggered block reveals
    private var revealTimer: Timer?
    
    // MARK: - Init
    
    init(sessionId: String? = nil) {
        self.sessionId = sessionId ?? UUID().uuidString
    }
    
    // MARK: - Send Message
    
    /// Send a message through the two-speed router
    func sendMessage(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // 1. Classify intent (on-device, < 1ms)
        let intent = intentClassifier.classify(trimmedText)
        lastIntent = intent
        currentTier = intent.tier
        
        // 2. Add user message
        let userMessage = LyoMessage(
            id: UUID().uuidString,
            sessionId: sessionId,
            content: trimmedText,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        conversationHistory.append(ConversationMessage(role: "user", content: trimmedText))
        
        // 3. Show processing state
        isProcessing = true
        error = nil
        skeletonHint = skeletonHintForTier(intent.tier)
        
        // 4. Clear previous agent blocks for new response
        visibleBlocks = []
        currentComponent = nil
        
        // 5. Route through the appropriate pipeline
        let aiMessageId = UUID().uuidString
        
        let result = await router.route(
            message: trimmedText,
            conversationHistory: conversationHistory,
            onStreamEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleStreamEvent(event, aiMessageId: aiMessageId)
                }
            }
        )
        
        // 6. Handle route result
        switch result {
        case .instantResponse(let text):
            appendAIMessage(id: aiMessageId, text: text)
            isProcessing = false
            
        case .fastResponse(let text, _, let latencyMs, _, _, _):
            appendAIMessage(id: aiMessageId, text: text)
            isProcessing = false
            Log.ai.info("⚡ Fast response: \(String(format: "%.0f", latencyMs))ms")
            
        case .streamingStarted(let streamSessionId):
            // Streaming events will be handled by handleStreamEvent callback
            Log.ai.info("🧠 Streaming started: \(streamSessionId)")
            
        case .error(let message):
            error = message
            isProcessing = false
            Log.ai.error("❌ Route error: \(message)")
        }
    }
    
    // MARK: - Stream Event Handler
    
    private func handleStreamEvent(_ event: Lyo2StreamEvent, aiMessageId: String) {
        switch event {
        case .skeleton(let blocks):
            skeletonHint = blocks.first ?? "Thinking..."
            
        case .answer(let block):
            let answerText = (block.content["text"]?.value as? String)
                ?? (block.content["markdown"]?.value as? String)
                ?? ""
            
            // Convert to AgentBlocks if the response contains structured sections
            let agentBlocks = parseAgentBlocks(from: answerText)
            
            if !agentBlocks.isEmpty {
                // Multi-agent response — do cinematic reveal
                startCinematicReveal(blocks: agentBlocks)
                
                // Synthesize A2UI component from agent blocks
                currentComponent = synthesizer.synthesizeAgentBlocks(agentBlocks)
                
                // Store for persistence
                contentStore.store(
                    id: aiMessageId,
                    title: "Response",
                    content: answerText,
                    agentBlocks: agentBlocks
                )
            } else {
                // Simple text response
                appendAIMessage(id: aiMessageId, text: answerText, shouldAnimate: true)
            }
            
            conversationHistory.append(ConversationMessage(role: "assistant", content: answerText))
            isProcessing = false
            
        case .artifact(let block):
            // Handle artifacts (quizzes, flashcards, etc.)
            Log.ai.info("🎨 Artifact received: \(String(describing: block.blockType))")
            
        case .clarification(let text):
            appendAIMessage(id: aiMessageId, text: text)
            isProcessing = false
            
        case .error(let message):
            error = message
            isProcessing = false
            
        case .done:
            isProcessing = false
            
        default:
            break
        }
    }
    
    // MARK: - Cinematic Reveal
    
    /// Stagger the reveal of agent blocks with animation delays
    private func startCinematicReveal(blocks: [AgentBlock]) {
        revealTimer?.invalidate()
        pendingBlocks = blocks.sorted { $0.agent.entranceDelay < $1.agent.entranceDelay }
        visibleBlocks = []
        
        revealNextBlock()
    }
    
    private func revealNextBlock() {
        guard !pendingBlocks.isEmpty else { return }
        
        let block = pendingBlocks.removeFirst()
        let delay = block.agent.entranceDelay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.visibleBlocks.append(block)
            }
            self.revealNextBlock()
        }
    }
    
    // MARK: - Message Helpers
    
    private func appendAIMessage(id: String, text: String, shouldAnimate: Bool = false) {
        let msg = LyoMessage(
            id: id,
            sessionId: sessionId,
            content: text,
            isFromUser: false,
            timestamp: Date(),
            shouldAnimate: shouldAnimate
        )
        messages.append(msg)
    }
    
    private func skeletonHintForTier(_ tier: MessageSpeedTier) -> String {
        switch tier {
        case .instant:  return ""
        case .fast:     return "Quick thinking..."
        case .standard: return "Preparing your answer..."
        case .deep:     return "Bringing in the faculty..."
        }
    }
    
    // MARK: - Agent Block Parser
    
    /// Parse a text response into agent blocks based on structural cues.
    /// If the response doesn't have clear multi-agent structure, returns empty array.
    private func parseAgentBlocks(from text: String) -> [AgentBlock] {
        var blocks: [AgentBlock] = []
        let lines = text.components(separatedBy: "\n")
        
        var currentAgent: AgentRole = .tutor
        var currentType: AgentBlockType = .explanation
        var currentContent: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect agent transitions via emoji/marker patterns
            // These markers can be embedded by the backend orchestrator
            if let detected = detectAgentMarker(trimmed) {
                // Flush previous block
                if !currentContent.isEmpty {
                    let content = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        blocks.append(AgentBlock(
                            agent: currentAgent,
                            blockType: currentType,
                            content: content
                        ))
                    }
                    currentContent = []
                }
                currentAgent = detected.agent
                currentType = detected.blockType
                // Don't include the marker line itself in content
                continue
            }
            
            currentContent.append(line)
        }
        
        // Flush remaining content
        if !currentContent.isEmpty {
            let content = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                blocks.append(AgentBlock(
                    agent: currentAgent,
                    blockType: currentType,
                    content: content
                ))
            }
        }
        
        // If we only got one block (no agent transitions detected), return empty
        // to fall back to simple text rendering
        return blocks.count > 1 ? blocks : []
    }
    
    /// Detect agent transition markers in text
    /// The backend can embed these subtly: [tutor], [quiz], etc.
    private func detectAgentMarker(_ line: String) -> (agent: AgentRole, blockType: AgentBlockType)? {
        let lowered = line.lowercased()
        
        // Pattern: [agent:role] or <!-- agent:role -->
        let markerPatterns: [(String, AgentRole, AgentBlockType)] = [
            ("[tutor]", .tutor, .explanation),
            ("[quiz]", .quiz, .checkpoint),
            ("[sentiment]", .sentiment, .encouragement),
            ("[content]", .content, .deepDive),
            ("[metacognition]", .metaCognition, .reflection),
            ("[tip]", .tutor, .quickTip),
            ("[practice]", .quiz, .practicePrompt),
            ("[analogy]", .tutor, .analogy),
            ("[reflect]", .metaCognition, .reflection),
            ("<!-- agent:tutor -->", .tutor, .explanation),
            ("<!-- agent:quiz -->", .quiz, .checkpoint),
            ("<!-- agent:sentiment -->", .sentiment, .encouragement),
            ("<!-- agent:content -->", .content, .deepDive),
            ("<!-- agent:metacognition -->", .metaCognition, .reflection),
        ]
        
        for (pattern, agent, blockType) in markerPatterns {
            if lowered.contains(pattern) {
                return (agent, blockType)
            }
        }
        
        return nil
    }
    
    // MARK: - Session Management
    
    /// Start a new session
    func startNewSession() {
        sessionId = UUID().uuidString
        messages = []
        visibleBlocks = []
        currentComponent = nil
        conversationHistory = []
        error = nil
        isProcessing = false
    }
}
