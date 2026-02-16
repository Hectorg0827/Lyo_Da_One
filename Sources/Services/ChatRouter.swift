//
//  ChatRouter.swift
//  Lyo
//
//  Two-Speed Response Engine: routes messages through the optimal pipeline
//  based on on-device intent classification.
//
//  Fast Path (< 500ms):
//  - Greetings, acknowledgments, farewells
//  - Simple questions
//  - Single-agent backend endpoint (/api/v1/chat/quick)
//
//  Deep Path (streaming, multi-agent):
//  - Lessons, course creation, complex reasoning
//  - Full Orchestrator via SSE (/api/v1/lyo2/chat/stream)
//  - Returns multipart AgentBlocks
//

import Foundation
import os

// MARK: - Route Result

/// The result of routing a message through the appropriate pipeline
enum ChatRouteResult {
    /// Fast path completed — single text response
    /// Fast path completed — single text response with optional Study Plan
    case fastResponse(text: String, studyPlan: TestPrepData?, latencyMs: Double)
    
    /// Deep path initiated — streaming will deliver AgentBlocks
    case streamingStarted(sessionId: String)
    
    /// Instant/on-device response — no network needed
    case instantResponse(text: String)
    
    /// Error during routing
    case error(String)
}

// MARK: - Chat Router

@MainActor
final class ChatRouter: ObservableObject {
    static let shared = ChatRouter()
    
    // Dependencies
    private let intentClassifier = MessageIntentClassifier.shared
    private let backendAI = BackendAIService.shared
    private let lyo2Chat = Lyo2ChatService.shared
    
    // MARK: - Published State
    
    /// The last classified intent (for debug/analytics)
    @Published private(set) var lastIntent: ClassifiedIntent?
    
    /// Current routing tier being used
    @Published private(set) var currentTier: MessageSpeedTier = .standard
    
    // MARK: - Metrics
    
    /// Running average latency per tier (for adaptive tuning)
    private var tierLatencies: [MessageSpeedTier: [Double]] = [
        .instant: [],
        .fast: [],
        .standard: [],
        .deep: []
    ]
    
    private init() {}
    
    // MARK: - Route Message
    
    /// Route a message through the appropriate pipeline.
    /// Returns the route result; for streaming, blocks arrive via the callback.
    func route(
        message: String,
        conversationHistory: [ConversationMessage] = [],
        onAgentBlock: ((AgentBlock) -> Void)? = nil,
        onStreamEvent: ((Lyo2StreamEvent) -> Void)? = nil
    ) async -> ChatRouteResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Classify intent on-device (< 1ms)
        let intent = intentClassifier.classify(message)
        lastIntent = intent
        currentTier = intent.tier
        
        Log.ai.info("🎯 Intent: \(intent.category.rawValue) | Tier: \(intent.tier.label) | Confidence: \(String(format: "%.0f%%", intent.confidence * 100))")
        
        // 2. Route based on tier
        switch intent.tier {
        case .instant:
            let response = handleInstantResponse(message: message, intent: intent)
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            recordLatency(latency, for: .instant)
            return .instantResponse(text: response)
            
        case .fast:
            return await handleFastPath(
                message: message,
                intent: intent,
                conversationHistory: conversationHistory,
                onStreamEvent: onStreamEvent,
                startTime: startTime
            )
            
        case .standard, .deep:
            return await handleDeepPath(
                message: message,
                intent: intent,
                conversationHistory: conversationHistory,
                onStreamEvent: onStreamEvent,
                startTime: startTime
            )
        }
    }
    
    // MARK: - Instant Handler (On-Device)
    
    private func handleInstantResponse(message: String, intent: ClassifiedIntent) -> String {
        switch intent.category {
        case .navigation:
            // Navigation is handled by the UI layer — just acknowledge
            return "Sure, taking you there!"
        case .uiAction:
            return "Done!"
        default:
            return "Got it!"
        }
    }
    
    // MARK: - Fast Path (Single Agent)
    
    private func handleFastPath(
        message: String,
        intent: ClassifiedIntent,
        conversationHistory: [ConversationMessage],
        onStreamEvent: ((Lyo2StreamEvent) -> Void)?,
        startTime: CFAbsoluteTime
    ) async -> ChatRouteResult {
        do {
            // Use the standard AI chat endpoint (non-streaming, fast)
            let response = try await sendQuickMessage(
                message: message,
                context: intent.category.rawValue,
                conversationHistory: conversationHistory
            )
            
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            recordLatency(latency, for: .fast)
            
            Log.ai.info("⚡ Fast path response in \(String(format: "%.0f", latency))ms")
            return .fastResponse(text: response.responseText, studyPlan: response.studyPlan, latencyMs: latency)
            
        } catch {
            Log.ai.error("⚡ Fast path failed, falling back to deep: \(error.localizedDescription)")
            // Fallback to standard streaming on fast-path failure. 
            // CRITICAL: Pass onStreamEvent down so the fallback actually renders!
            return await handleDeepPath(
                message: message,
                intent: intent,
                conversationHistory: conversationHistory,
                onStreamEvent: onStreamEvent,
                startTime: startTime
            )
        }
    }
    
    // MARK: - Deep Path (Multi-Agent Streaming)
    
    private func handleDeepPath(
        message: String,
        intent: ClassifiedIntent,
        conversationHistory: [ConversationMessage],
        onStreamEvent: ((Lyo2StreamEvent) -> Void)?,
        startTime: CFAbsoluteTime
    ) async -> ChatRouteResult {
        let sessionId = UUID().uuidString
        
        // Build conversation memory window
        let memoryWindow = conversationHistory.suffix(20).map {
            Lyo2ConversationTurn(role: $0.role, content: $0.content)
        }
        
        // Start streaming via Lyo2 pipeline
        // NOTE: The Lyo2StreamingManager now fires callbacks on OperationQueue.main,
        // so this closure runs on the main thread — safe to access @MainActor state directly.
        lyo2Chat.sendMessageStreaming(
            text: message,
            conversationHistory: memoryWindow
        ) { event in
            onStreamEvent?(event)
            
            // Record first-token latency
            if case .answer = event {
                let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                self.recordLatency(latency, for: self.currentTier)
                Log.ai.info("🧠 Deep path first token in \(String(format: "%.0f", latency))ms")
            }
        }
        
        return .streamingStarted(sessionId: sessionId)
    }
    
    // MARK: - Quick Message (Non-Streaming)
    
    /// Send a message via the lightweight non-streaming endpoint
    private func sendQuickMessage(
        message: String,
        context: String,
        conversationHistory: [ConversationMessage]
    ) async throws -> BackendAIChatResponse {
        // Use the existing AI.chat endpoint (non-streaming)
        let response: BackendAIChatResponse = try await NetworkClient.shared.request(
            Endpoints.AI.chat(
                message: message,
                provider: nil,
                context: nil
            )
        )
        
        return response
    }
    
    // MARK: - Latency Tracking
    
    private func recordLatency(_ ms: Double, for tier: MessageSpeedTier) {
        var samples = tierLatencies[tier] ?? []
        samples.append(ms)
        // Keep last 50 samples
        if samples.count > 50 { samples.removeFirst() }
        tierLatencies[tier] = samples
    }
    
    /// Average latency for a given tier
    func averageLatency(for tier: MessageSpeedTier) -> Double {
        let samples = tierLatencies[tier] ?? []
        guard !samples.isEmpty else { return Double(tier.targetLatencyMs) }
        return samples.reduce(0, +) / Double(samples.count)
    }
    
    /// Debug summary of routing metrics
    var metricsReport: String {
        var lines: [String] = ["📊 Chat Router Metrics:"]
        for tier in [MessageSpeedTier.instant, .fast, .standard, .deep] {
            let avg = averageLatency(for: tier)
            let count = tierLatencies[tier]?.count ?? 0
            lines.append("  \(tier.label): avg \(String(format: "%.0f", avg))ms (\(count) samples)")
        }
        return lines.joined(separator: "\n")
    }
}

