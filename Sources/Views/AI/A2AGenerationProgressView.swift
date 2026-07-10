//
//  A2AGenerationProgressView.swift
//  Lyo
//
//  Real-time streaming UI for A2A multi-agent course generation.
//  Polished Gemini-style dark sheet with animated agent orb,
//  vertical timeline, live event feed, and auto-dismiss on completion.
//

import SwiftUI
import Combine
import os

// MARK: - A2A Generation Progress View

struct A2AGenerationProgressView: View {
    @StateObject private var service = A2ACourseService.shared

    let topic: String
    let qualityTier: CourseQualityTier
    let onComplete: (A2AGeneratedCourse) -> Void
    let onCancel: () -> Void

    // Animation state
    @State private var orbPulse: Bool = false
    @State private var orbRotation: Double = 0
    @State private var showLiveFeed: Bool = false
    @State private var completionScale: CGFloat = 0.6
    @State private var completionOpacity: Double = 0

    // Auto-dismiss once course is ready
    @State private var didAutoDismiss = false
    
    // 🌊 Progressive Streaming State
    @State private var cancellables = Set<AnyCancellable>()
    @State private var hasTriggeredEarlyLaunch = false
    @State private var streamingRuntime: LyoCourseRuntime?

    var body: some View {
        ZStack {
            // Background
            Color(hex: "0a0a14")
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color(hex: "1a1040").opacity(0.6), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Topic + overall progress ring
                        heroSection

                        // Active agent card with live streaming message
                        if service.generatedCourse == nil {
                            activeAgentCard
                        }

                        // Vertical phase timeline
                        phaseTimeline

                        // Live event feed (collapsible)
                        liveFeedSection

                        // Completion card
                        if let course = service.generatedCourse {
                            completionCard(course: course)
                                .scaleEffect(completionScale)
                                .opacity(completionOpacity)
                                .onAppear {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                        completionScale = 1.0
                                        completionOpacity = 1.0
                                    }
                                    // Auto-dismiss after 1.4 s
                                    if !didAutoDismiss {
                                        didAutoDismiss = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                            onComplete(course)
                                        }
                                    }
                                }
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                bottomBar
            }
        }
        .onAppear { startGeneration() }
        .onDisappear { service.cancelGeneration() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Building Course")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Live feed toggle
            Button(action: { withAnimation { showLiveFeed.toggle() } }) {
                Image(systemName: showLiveFeed ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.circle")
                    .font(.system(size: 20))
                    .foregroundColor(showLiveFeed ? Color(hex: "6366F1") : .white.opacity(0.4))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Animated Orb
            ZStack {
                // Outer glow rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            Color(hex: "6366F1").opacity(0.15 - Double(i) * 0.04),
                            lineWidth: 1
                        )
                        .frame(width: CGFloat(90 + i * 22), height: CGFloat(90 + i * 22))
                        .scaleEffect(orbPulse ? 1.06 : 0.97)
                        .animation(
                            .easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(Double(i) * 0.2),
                            value: orbPulse
                        )
                }

                // Core orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "818CF8"), Color(hex: "6366F1"), Color(hex: "4F46E5")],
                            center: .center,
                            startRadius: 0,
                            endRadius: 44
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 20)

                // Rotating arc
                Circle()
                    .trim(from: 0, to: 0.35)
                    .stroke(
                        AngularGradient(colors: [Color.white.opacity(0.6), Color.clear], center: .center),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(orbRotation))

                if service.generatedCourse != nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: service.currentPhase?.icon ?? "cpu")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                orbPulse = true
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    orbRotation = 360
                }
            }

            // Topic
            Text(topic)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Progress bar + percentage
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "A78BFA")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(service.progress) / 100)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: service.progress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(service.currentPhase?.displayName ?? "Initializing…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Text("\(service.progress)%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Color(hex: "A78BFA"))
                }
            }
            .frame(maxWidth: 320)
        }
        .padding(.top, 8)
    }

    // MARK: - Active Agent Card

    private var activeAgentCard: some View {
        Group {
            if let phase = service.currentPhase {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        // Agent icon badge
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(phase.color.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: phase.icon)
                                .font(.system(size: 20))
                                .foregroundColor(phase.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.agentName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Text("Active")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(phase.color.opacity(0.25))
                                .foregroundColor(phase.color)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        // Typing indicator dots
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(phase.color.opacity(0.7))
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(orbPulse ? 1.3 : 0.7)
                                    .animation(
                                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.18),
                                        value: orbPulse
                                    )
                            }
                        }
                    }

                    // Live message from last streaming event
                    if let msg = service.streamingEvents.last(where: { $0.message != nil })?.message {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.easeOut(duration: 0.3), value: msg)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(phase.color.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Phase Timeline

    private var phaseTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pipeline")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.bottom, 10)

            ForEach(Array(A2APipelinePhase.allCases.enumerated()), id: \.element) { idx, phase in
                let status = statusFor(phase)
                let isLast = idx == A2APipelinePhase.allCases.count - 1

                HStack(alignment: .top, spacing: 14) {
                    // Connector column
                    VStack(spacing: 0) {
                        // Status dot
                        ZStack {
                            Circle()
                                .fill(dotBackground(status: status, phase: phase))
                                .frame(width: 28, height: 28)

                            switch status {
                            case .completed:
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            case .running:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: phase.color))
                                    .scaleEffect(0.65)
                            case .failed:
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            default:
                                Image(systemName: phase.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }

                        // Connector line
                        if !isLast {
                            Rectangle()
                                .fill(status == .completed ? Color(hex: "6366F1").opacity(0.5) : Color.white.opacity(0.1))
                                .frame(width: 2, height: 36)
                        }
                    }

                    // Phase label row
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(phase.displayName)
                                .font(.subheadline.weight(status == .running ? .semibold : .regular))
                                .foregroundColor(status == .pending ? .white.opacity(0.35) : .white)

                            if status == .running {
                                Text("Now")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(phase.color.opacity(0.2))
                                    .foregroundColor(phase.color)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(phase.agentName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.top, 4)
                    .padding(.bottom, isLast ? 0 : 24)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func dotBackground(status: A2APhaseStatus, phase: A2APipelinePhase) -> Color {
        switch status {
        case .completed: return Color(hex: "6366F1")
        case .running: return phase.color.opacity(0.3)
        case .failed: return .red.opacity(0.5)
        default: return Color.white.opacity(0.08)
        }
    }

    // MARK: - Live Feed

    private var liveFeedSection: some View {
        Group {
            if showLiveFeed && !service.streamingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Live Feed", systemImage: "dot.radiowaves.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "6366F1"))

                        Spacer()

                        Text("\(service.streamingEvents.count) events")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.3))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(service.streamingEvents.suffix(12).reversed().enumerated()), id: \.offset) { _, event in
                            EventRowView(event: event)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "6366F1").opacity(0.2), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Completion Card

    private func completionCard(course: A2AGeneratedCourse) -> some View {
        VStack(spacing: 20) {
            // Checkmark burst
            ZStack {
                Circle()
                    .fill(Color(hex: "10B981").opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "10B981"))
            }

            Text("Course Ready!")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                MetricCard(icon: "book.closed.fill", value: "\(course.modules.count)", label: "Modules")
                MetricCard(
                    icon: "doc.text.fill",
                    value: "\(course.modules.flatMap { $0.lessons }.count)",
                    label: "Lessons"
                )
                MetricCard(icon: "clock.fill", value: "\(course.estimatedDuration)m", label: "Est. Time")
            }

            Text("Opening your classroom…")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "10B981").opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let error = service.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Group {
                if service.generatedCourse != nil {
                    // Show manual override in case auto-dismiss didn't fire
                    Button(action: { if let c = service.generatedCourse { onComplete(c) } }) {
                        Label("Open Course Now", systemImage: "arrow.right.circle.fill")
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
                    Button(action: { service.cancelGeneration(); onCancel() }) {
                        Label("Cancel", systemImage: "xmark.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(14)
                    }
                } else if service.errorMessage != nil {
                    Button(action: startGeneration) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "6366F1"))
                            .cornerRadius(16)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.clear, Color(hex: "0a0a14").opacity(0.95)],
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
        guard let currentPhase = service.currentPhase else { return .pending }
        if phase.rawValue < currentPhase.rawValue { return .completed }
        if phase == currentPhase { return .running }
        return .pending
    }

    private func startGeneration() {
        // 1. Create a skeleton runtime for progressive injection
        let skeletonCourse = LyoCourse(
            id: "a2a_\(UUIDString.short())",
            title: topic,
            targetAudience: "General",
            learningObjectives: [],
            modules: [],
            generationSource: "ai",
            version: "1.0",
            metadata: nil
        )
        let runtime = LyoCourseRuntime(course: skeletonCourse)
        self.streamingRuntime = runtime
        
        // 2. Subscribe to new modules for "Magical Progressive Launch" 🌊
        service.newModulePublisher
            .receive(on: RunLoop.main)
            .sink { module in
                Log.ai.info("🌊 Module arrived in ProgressView: \(module.title)")
                runtime.appendModule(module)
                
                // If it's the first module, we can trigger the classroom early!
                if !hasTriggeredEarlyLaunch {
                    Log.ai.info("✨ MAGIC: Triggering early classroom launch on first module!")
                    hasTriggeredEarlyLaunch = true
                    
                    // Give it a tiny bit of time to settle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        // We use the full course conversion once it's done, 
                        // but for now we signal we're ready with what we have.
                        let syntheticCourse = A2AGeneratedCourse(
                            id: skeletonCourse.id,
                            title: skeletonCourse.title,
                            description: skeletonCourse.targetAudience,
                            modules: runtime.course.modules.map { $0.toA2AModule() },
                            learningObjectives: [],
                            estimatedDuration: 0,
                            difficulty: "beginner",
                            visualAssets: nil,
                            voiceAssets: nil
                        )
                        onComplete(syntheticCourse)
                    }
                }
            }
            .store(in: &cancellables)

        // 3. Start the actual stream
        service.generateCourseStreaming(
            topic: topic,
            qualityTier: qualityTier,
            userContext: nil,
            enableVisuals: true,
            enableVoice: true
        ) { event in
            Log.ai.info("📨 \(event.type.rawValue): \(event.message ?? "")")
            
            if event.type == .completed || event.type == .pipelineCompleted {
                // Full generation done
                if let course = service.generatedCourse, !hasTriggeredEarlyLaunch {
                    onComplete(course)
                }
            }
        }
    }
}

// MARK: - Extension for mapping
extension LyoModule {
    func toA2AModule() -> A2ACourseModule {
        A2ACourseModule(
            id: self.id,
            title: self.title,
            description: self.title, // Fallback
            lessons: self.lessons.map { lesson in
                A2ACourseLesson(
                    id: lesson.id,
                    title: lesson.title,
                    content: (lesson.artifacts.first?.content.value as? String) ?? "",
                    durationMinutes: 5,
                    order: 0,
                    scenes: nil
                )
            },
            order: 0
        )
    }
}

private enum UUIDString {
    static func short() -> String {
        UUID().uuidString.prefix(8).lowercased()
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: A2AStreamingEvent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(event.type.icon)
                .font(.system(size: 11))

            Text(event.message ?? event.type.rawValue)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(event.progress)%")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 3)
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
                .font(.title3)
                .foregroundColor(Color(hex: "6366F1"))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        case .started: return "🚀"
        case .agentWorking: return "🤖"
        case .lessonComplete: return "📚"
        case .progress: return "📊"
        case .completed: return "🎉"
        case .costUpdate: return "💰"
        case .unknown: return "❓"
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
    .preferredColorScheme(.dark)
}
