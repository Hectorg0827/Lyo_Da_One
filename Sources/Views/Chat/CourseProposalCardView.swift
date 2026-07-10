//
//  CourseProposalCardView.swift
//  Lyo
//
//  Interactive course proposal card that appears in the chat.
//  The user must tap "Start Learning" to begin course generation —
//  prevents unwanted cost from auto-triggered course creation.
//

import SwiftUI

struct CourseProposalCardView: View {
    let payload: CoursePayload
    let onStart: () -> Void
    let onAdjust: (() -> Void)?
    
    @State private var isExpanded = false
    @State private var isGenerating = false
    
    /// Convenience init matching older call sites
    init(coursePayload: CoursePayload, onStartLearning: @escaping () -> Void) {
        self.payload = coursePayload
        self.onStart = onStartLearning
        self.onAdjust = nil
    }
    
    /// Full init with adjust support (EnhancedMessageBubble)
    init(payload: CoursePayload, onStart: @escaping () -> Void, onAdjust: (() -> Void)? = nil) {
        self.payload = payload
        self.onStart = onStart
        self.onAdjust = onAdjust
    }

    private var previewObjectives: [String] {
        Array(payload.objectives.prefix(4))
    }

    private var heroGradient: [Color] {
        let topic = payload.topic.lowercased()
        if topic.contains("math") || topic.contains("physics") {
            return [Color(hex: "06B6D4"), Color(hex: "3B82F6")]
        }
        if topic.contains("design") || topic.contains("art") {
            return [Color(hex: "F472B6"), Color(hex: "8B5CF6")]
        }
        if topic.contains("code") || topic.contains("swift") || topic.contains("ios") {
            return [Color(hex: "6366F1"), Color(hex: "14B8A6")]
        }
        return [Color(hex: "8B5CF6"), Color(hex: "6366F1")]
    }

    private var topicIcon: String {
        let topic = payload.topic.lowercased()
        if topic.contains("math") { return "function" }
        if topic.contains("swift") || topic.contains("ios") || topic.contains("code") {
            return "chevron.left.forwardslash.chevron.right"
        }
        if topic.contains("history") { return "building.columns.fill" }
        if topic.contains("design") || topic.contains("art") { return "paintpalette.fill" }
        if topic.contains("language") || topic.contains("english") || topic.contains("spanish") {
            return "character.book.closed.fill"
        }
        return "sparkles"
    }

    private var lessonEstimateText: String {
        let count = max(previewObjectives.count, payload.objectives.count)
        let estimate = max(3, count * 2)
        return "~\(estimate) guided lessons"
    }

    private var personalizationCopy: String {
        "Built for a \(payload.level.lowercased()) learner with a fast, practical first lesson."
    }

    private var firstModuleTitle: String? {
        previewObjectives.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroCard
            statRow
            
            if let firstModuleTitle {
                firstLessonPreview(title: firstModuleTitle)
            }
            
            // Learning Objectives (expandable)
            if !payload.objectives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("What you'll learn")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(payload.objectives.prefix(6).enumerated()), id: \.offset) { index, objective in
                                HStack(alignment: .top, spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 20, height: 20)
                                        Text("\(index + 1)")
                                            .font(.caption2.bold())
                                            .foregroundColor(Color(hex: "C4B5FD"))
                                    }
                                    .padding(.top, 1)
                                    
                                    Text(objective)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            
            // CTA Buttons
            HStack(spacing: 12) {
                Button(action: {
                    guard !isGenerating else { return }
                    isGenerating = true
                    HapticManager.shared.medium()
                    onStart()
                }) {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Starting...")
                        } else {
                            Image(systemName: "play.fill")
                            Text("Start Course")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: isGenerating
                                ? [Color(hex: "6366F1").opacity(0.6), Color(hex: "8B5CF6").opacity(0.6)]
                                : [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isGenerating)
                
                if let onAdjust {
                    Button(action: {
                        HapticManager.shared.light()
                        onAdjust()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                            Text("Adjust")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "14162B").opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6").opacity(0.45), Color(hex: "6366F1").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .overlay(alignment: .topTrailing) {
            Text("AI Draft")
                .font(.caption2.bold())
                .foregroundColor(Color(hex: "DDD6FE"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .padding(12)
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: heroGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 170)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.02), Color.black.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.topic.uppercased())
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.8))
                        Text(payload.title)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: topicIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                Text(personalizationCopy)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.86))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    heroChip(icon: "chart.bar.fill", text: payload.level)
                    heroChip(icon: "clock.fill", text: payload.duration ?? lessonEstimateText)
                    heroChip(icon: "list.bullet.rectangle.portrait.fill", text: "\(max(1, payload.objectives.count)) outcomes")
                }
            }
            .padding(18)
        }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            featurePill(icon: "bolt.fill", title: "Quick win", detail: "Practical first lesson")
            featurePill(icon: "target", title: "Outcome-led", detail: "Clear milestones")
        }
    }

    private func firstLessonPreview(title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("First module preview")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.62))
                    .textCase(.uppercase)
                Spacer()
                Text("Starts here")
                    .font(.caption2.bold())
                    .foregroundColor(Color(hex: "C4B5FD"))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Text("You’ll begin with the core mental model, a guided walkthrough, and a quick checkpoint before moving deeper.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func heroChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.bold())
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private func featurePill(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color(hex: "C4B5FD"))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
