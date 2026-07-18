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
    /// Fast path completed — single text response with optional Study Plan + context chips + course payload
    case fastResponse(
        text: String, studyPlan: TestPrepData?, latencyMs: Double, suggestions: [SuggestionChip]?,
        coursePayload: CoursePayload?, conversationId: String?)

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
        .deep: [],
    ]

    private init() {}

    // MARK: - Route Message

    /// Route a message through the appropriate pipeline.
    /// Returns the route result; for streaming, blocks arrive via the callback.
    func route(
        message: String,
        attachmentIds: [String] = [],
        mode: String = "chat",
        forcedIntent: String? = nil,
        conversationHistory: [ConversationMessage] = [],
        conversationId: String? = nil,
        clientMessageId: String? = nil,
        onAgentBlock: ((AgentBlock) -> Void)? = nil,
        onStreamEvent: ((Lyo2StreamEvent) -> Void)? = nil
    ) async -> ChatRouteResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Classify intent on-device (< 1ms)
        let intent = intentClassifier.classify(message)
        lastIntent = intent
        currentTier = intent.tier

        Log.ai.info(
            "🎯 Intent: \(intent.category.rawValue) | Tier: \(intent.tier.label) | Confidence: \(String(format: "%.0f%%", intent.confidence * 100))"
        )

        // 2. Route based on tier
        switch intent.tier {
        case .instant:
            // Chat turns must use the canonical server path even when an
            // acknowledgement could be generated on-device. Otherwise those
            // turns disappear when the user opens another device.
            return await handleFastPath(
                message: message,
                mode: mode,
                intent: intent,
                conversationHistory: conversationHistory,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                onStreamEvent: onStreamEvent,
                startTime: startTime
            )

        case .fast:
            return await handleFastPath(
                message: message,
                mode: mode,
                intent: intent,
                conversationHistory: conversationHistory,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                onStreamEvent: onStreamEvent,
                startTime: startTime
            )

        case .standard, .deep:
            return await handleDeepPath(
                message: message,
                attachmentIds: attachmentIds,
                mode: mode,
                intent: intent,
                forcedIntent: forcedIntent,
                conversationHistory: conversationHistory,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
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
        mode: String,
        intent: ClassifiedIntent,
        conversationHistory: [ConversationMessage],
        conversationId: String?,
        clientMessageId: String?,
        onStreamEvent: ((Lyo2StreamEvent) -> Void)?,
        startTime: CFAbsoluteTime
    ) async -> ChatRouteResult {
        do {
            // Use the standard AI chat endpoint (non-streaming, fast)
            let response = try await sendQuickMessage(
                message: message,
                mode: mode,
                context: intent.category.rawValue,
                conversationHistory: conversationHistory,
                conversationId: conversationId,
                clientMessageId: clientMessageId
            )

            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            recordLatency(latency, for: .fast)

            Log.ai.info("⚡ Fast path response in \(String(format: "%.0f", latency))ms")

            // Extract course payload if backend returned OPEN_CLASSROOM type
            let coursePayload: CoursePayload? = {
                // 1. Check explicit type + payload (payload is OpenClassroomCommand.OpenClassroomPayload)
                if response.type == "OPEN_CLASSROOM", let payload = response.payload {
                    Log.ai.info("🏫 Fast path: OPEN_CLASSROOM type with payload detected")
                    // Map nested OpenClassroomCommand.CoursePayload -> top-level CoursePayload
                    let c = payload.course
                    return CoursePayload(
                        id: nil, title: c.title, topic: c.topic, level: c.level,
                        language: c.language, duration: c.duration, objectives: c.objectives)
                }
                // 2. Try to extract course payload from the response text (heuristic)
                // Rely on explicit payload above
                return nil
            }()

            return .fastResponse(
                text: response.responseText, studyPlan: response.studyPlan, latencyMs: latency,
                suggestions: response.suggestions, coursePayload: coursePayload,
                conversationId: response.conversationId)

        } catch {
            Log.ai.error("⚡ Fast path failed, falling back to deep: \(error.localizedDescription)")
            // Fallback to standard streaming on fast-path failure.
            // CRITICAL: Pass onStreamEvent down so the fallback actually renders!
            return await handleDeepPath(
                message: message,
                mode: mode,
                intent: intent,
                forcedIntent: nil,
                conversationHistory: conversationHistory,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                onStreamEvent: onStreamEvent,
                startTime: startTime
            )
        }
    }

    // MARK: - Deep Path (Multi-Agent Streaming)

    private func handleDeepPath(
        message: String,
        attachmentIds: [String] = [],
        mode: String,
        intent: ClassifiedIntent,
        forcedIntent: String? = nil,
        conversationHistory: [ConversationMessage],
        conversationId: String?,
        clientMessageId: String?,
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
            attachmentIds: attachmentIds,
            forcedIntent: forcedIntent,
            stateSummary: buildStateSummary(mode: mode, intent: intent),
            conversationHistory: memoryWindow,
            conversationId: conversationId,
            clientMessageId: clientMessageId
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
        mode: String,
        context: String,
        conversationHistory: [ConversationMessage],
        conversationId: String?,
        clientMessageId: String?
    ) async throws -> BackendAIChatResponse {
        let request = BackendAIChatRequest(
            message: message,
            conversationHistory: conversationHistory.isEmpty ? nil : conversationHistory,
            context: context,
            modeHint: backendAI.chatModeHint(for: mode),
            conversationId: conversationId,
            clientMessageId: clientMessageId
        )

        let payload = try JSONEncoder().encode(request)
        let endpoint = Endpoints.ChatModule.sendMessage(payload: payload)
        return try await NetworkClient.shared.request(endpoint)
    }

    private func buildStateSummary(mode: String, intent: ClassifiedIntent) -> [String: AnyCodable] {
        var summary: [String: AnyCodable] = [
            "requested_mode": AnyCodable(mode),
            "mode_hint": AnyCodable(backendAI.chatModeHint(for: mode)),
            "speed_tier": AnyCodable(intent.tier.label),
            "intent_category": AnyCodable(intent.category.rawValue),
            "prefer_rich_ui": AnyCodable(true),
            "client_platform": AnyCodable("ios"),
            "client_version": AnyCodable(ClientCapabilities.shared.versionHeader),
            "client_components": AnyCodable(ClientCapabilities.shared.supportedComponents)
        ]

        if let topic = intent.extractedTopic, !topic.isEmpty {
            summary["topic"] = AnyCodable(topic)
        }

        if let emotion = intent.emotionalContext {
            summary["emotional_context"] = AnyCodable(emotion.rawValue)
        }

        return summary
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
