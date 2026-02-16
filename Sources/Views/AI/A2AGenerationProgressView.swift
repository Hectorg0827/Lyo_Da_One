//
//  A2AGenerationProgressView.swift
//  Lyo
//
//  Real-time streaming UI for A2A multi-agent course generation
//  Shows agent handoffs, phase progress, and quality metrics
//

import SwiftUI
import os

// MARK: - A2A Generation Progress View

struct A2AGenerationProgressView: View {
    @StateObject private var service = A2ACourseService.shared
    
    let topic: String
    let qualityTier: CourseQualityTier
    let onComplete: (A2AGeneratedCourse) -> Void
    let onCancel: () -> Void
    
    @State private var expandedPhase: A2APipelinePhase?
    @State private var showDebugEvents: Bool = false
    @State private var pulsateAgent: Bool = false
    
    var body: some View {
        ZStack {
            // Premium background
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current Agent Card
                        currentAgentSection
                        
                        // Phase Progress
                        phasesSection
                        
                        // Live Events
                        if showDebugEvents {
                            eventsSection
                        }
                        
                        // Quality Metrics (when available)
                        if let course = service.generatedCourse {
                            metricsSection(course: course)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                
                // Bottom Action
                bottomAction
            }
        }
        .onAppear {
            startGeneration()
        }
        .onDisappear {
            service.cancelGeneration()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Debug toggle
                Button(action: { showDebugEvents.toggle() }) {
                    Image(systemName: showDebugEvents ? "eye.fill" : "eye.slash.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            VStack(spacing: 8) {
                Text("🤖 Multi-Agent Generation")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                
                Text(topic)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Overall Progress
                ProgressView(value: Double(service.progress) / 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "6366F1")))
                    .frame(maxWidth: 300)
                
                Text("\(service.progress)% Complete")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "0f0f1e")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Current Agent
    
    private var currentAgentSection: some View {
        VStack(spacing: 16) {
            if let phase = service.currentPhase {
                // Active Agent Card
                HStack(spacing: 16) {
                    // Agent Avatar
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [phase.color.opacity(0.5), phase.color.opacity(0.1)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulsateAgent ? 1.1 : 1.0)
                        
                        Image(systemName: phase.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            pulsateAgent = true
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.agentName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(phase.displayName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let lastEvent = service.streamingEvents.last,
                           let msg = lastEvent.message {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    if service.isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: phase.color))
                            .scaleEffect(1.2)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(phase.color.opacity(0.5), lineWidth: 1)
                        )
                )
            } else if !service.isGenerating && service.generatedCourse == nil {
                // Not started yet
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Initializing pipeline...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(32)
            }
        }
    }
    
    // MARK: - Phases Section
    
    private var phasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pipeline Phases")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(A2APipelinePhase.allCases, id: \.self) { phase in
                PhaseRowView(
                    phase: phase,
                    status: statusFor(phase),
                    isCurrent: phase == service.currentPhase,
                    isExpanded: expandedPhase == phase,
                    onTap: {
                        withAnimation {
                            expandedPhase = expandedPhase == phase ? nil : phase
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Events Section (Debug)
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Events")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(service.streamingEvents.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(service.streamingEvents.suffix(20).reversed().enumerated()), id: \.offset) { _, event in
                        EventRowView(event: event)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Metrics Section
    
    private func metricsSection(course: A2AGeneratedCourse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generation Complete! 🎉")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                MetricCard(
                    icon: "book.fill",
                    value: "\(course.modules.count)",
                    label: "Modules"
                )
                
                MetricCard(
                    icon: "doc.text.fill",
                    value: "\(course.modules.flatMap { $0.lessons }.count)",
                    label: "Lessons"
                )
                
                MetricCard(
                    icon: "clock.fill",
                    value: "\(course.estimatedDuration)m",
                    label: "Duration"
                )
            }
            
            // Modules info
            HStack {
                Text("Modules")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(course.modules.count)")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Bottom Action
    
    private var bottomAction: some View {
        VStack(spacing: 16) {
            if let error = service.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let course = service.generatedCourse {
                Button(action: { onComplete(course) }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("View Course")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
            } else if service.isGenerating {
                Button(action: {
                    service.cancelGeneration()
                    onCancel()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Generation")
                    }
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
            } else if service.errorMessage != nil {
                Button(action: { startGeneration() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "6366F1"))
                    .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helpers
    
    private func statusFor(_ phase: A2APipelinePhase) -> A2APhaseStatus {
        if let progress = service.phases.first(where: { $0.phase == phase }) {
            return progress.status
        }
        
        // Infer status based on current phase
        if let currentPhase = service.currentPhase {
            if phase.rawValue < currentPhase.rawValue {
                return .completed
            } else if phase == currentPhase {
                return .running
            }
        }
        
        return .pending
    }
    
    private func startGeneration() {
        service.generateCourseStreaming(
            topic: topic,
            qualityTier: qualityTier,
            userContext: nil,
            enableVisuals: true,
            enableVoice: true
        ) { event in
            // Handle individual events if needed
            Log.ai.info("📨 Event received: \(event.type.rawValue)")
        }
    }
}

// MARK: - Phase Row View

struct PhaseRowView: View {
    let phase: A2APipelinePhase
    let status: A2APhaseStatus
    let isCurrent: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Group {
                        switch status {
                        case .completed:
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        case .running:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: phase.color))
                                .scaleEffect(0.8)
                        case .failed:
                            Image(systemName: "xmark")
                                .foregroundColor(.red)
                        case .skipped:
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.gray)
                        case .pending:
                            Image(systemName: phase.icon)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isCurrent ? .white : .white.opacity(0.7))
                    
                    Text(phase.agentName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? phase.color.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCurrent ? phase.color.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agent: \(phase.agentName)")
                    Text("Phase: \(phase.displayName)")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 8)
            }
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .completed: return .green
        case .running: return phase.color
        case .failed: return .red
        case .skipped: return .gray
        case .pending: return .white.opacity(0.3)
        }
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: A2AStreamingEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(event.type.icon)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.message ?? "")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                if let phase = event.phase {
                    Text(phase.displayName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            Text("\(event.progress)%")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: "6366F1"))
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Phase Extensions

extension A2APipelinePhase {
    var color: Color {
        switch self {
        case .initialization: return Color(hex: "6366F1")
        case .pedagogy: return Color(hex: "8B5CF6")
        case .cinematic: return Color(hex: "EC4899")
        case .qaCheck: return Color(hex: "14B8A6")
        case .visual: return Color(hex: "F59E0B")
        case .voice: return Color(hex: "3B82F6")
        case .assembly: return Color(hex: "10B981")
        case .finalization: return Color(hex: "22C55E")
        }
    }
    
    var agentName: String {
        switch self {
        case .initialization: return "Orchestrator"
        case .pedagogy: return "Pedagogy Agent"
        case .cinematic: return "Cinematic Director"
        case .qaCheck: return "QA Checker"
        case .visual: return "Visual Director"
        case .voice: return "Voice Agent"
        case .assembly: return "Orchestrator"
        case .finalization: return "Orchestrator"
        }
    }
}

extension A2AEventType {
    var icon: String {
        switch self {
        case .pipelineStarted: return "🚀"
        case .phaseStarted: return "▶️"
        case .phaseProgress: return "📊"
        case .phaseCompleted: return "✅"
        case .phaseFailed: return "❌"
        case .agentHandoff: return "🤝"
        case .artifactCreated: return "📦"
        case .pipelineCompleted: return "🎉"
        case .error: return "⚠️"
        case .contentChunk: return "📝"
        case .thinking: return "💭"
        case .agentStarted: return "🏁"
        case .agentCompleted: return "🏆"
        }
    }
}

// MARK: - Preview

#Preview {
    A2AGenerationProgressView(
        topic: "Introduction to Machine Learning",
        qualityTier: .standard,
        onComplete: { _ in },
        onCancel: { }
    )
}
