//
//  LyoEngagementPrimitives.swift
//  Lyo
//
//  v2 renderers for engagement + system primitives:
//  progress, aiBubble, social, alert, skeleton
//

import SwiftUI

// MARK: - Progress Primitive

/// Renders progress variants: bar, ring, xp, level, streak, badge
struct LyoProgressPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "bar" }

    private var progressValue: Double {
        if let val = component.data?["value"], case .double(let d) = val {
            return d
        }
        if let val = component.data?["value"], case .int(let i) = val {
            return Double(i) / 100.0
        }
        return 0.0
    }

    var body: some View {
        Group {
            switch variant {
            case "ring":
                ringView
            case "xp":
                xpView
            case "level":
                levelView
            case "streak":
                streakView
            case "badge":
                badgeView
            default: // "bar"
                barView
            }
        }
    }

    private var barView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = component.content?.label {
                HStack {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(progressValue * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * max(0, min(1, progressValue)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(progressValue * 100))%")
                    .font(.title3.weight(.bold))
                if let label = component.content?.label {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 80, height: 80)
    }

    private var xpView: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text(component.content?.text ?? "\(Int(progressValue * 1000)) XP")
                .font(.subheadline.weight(.bold))
            Spacer()
            if let subtitle = component.content?.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }

    private var levelView: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(component.content?.text ?? "1")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(component.content?.title ?? "Level")
                    .font(.subheadline.weight(.medium))
                barView
            }
        }
    }

    private var streakView: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(component.content?.title ?? "Streak")
                    .font(.subheadline.weight(.medium))
                Text(component.content?.subtitle ?? "Keep it going!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(component.content?.text ?? "0")
                .font(.title2.weight(.bold))
                .foregroundStyle(.orange)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }

    private var badgeView: some View {
        VStack(spacing: 8) {
            if let icon = component.content?.icon {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.yellow)
            } else {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
            }
            Text(component.content?.title ?? "Badge")
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .frame(width: 80, height: 80)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - AI Bubble Primitive

/// Renders AI assistant variants: thinking, typing, suggestion, explanation, hint, encouragement
struct LyoAIBubblePrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "explanation" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // AI avatar
            aiAvatar

            // Bubble content
            VStack(alignment: .leading, spacing: 6) {
                if variant == "thinking" || variant == "typing" {
                    thinkingIndicator
                } else {
                    if let title = component.content?.title {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                    }
                    if let body = component.content?.body ?? component.content?.text {
                        Text(body)
                            .font(.body)
                    }
                }

                // Children
                if let children = component.children {
                    ForEach(children, id: \.id) { child in
                        LyoPrimitiveRenderer(component: child, context: context)
                    }
                }
            }
            .padding(12)
            .background(bubbleBackground)
            .cornerRadius(16)
        }
        .padding(.trailing, 32)
    }

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: avatarIcon)
                .font(.caption)
                .foregroundStyle(.blue)
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.6)
            }
        }
        .padding(.vertical, 8)
    }

    private var avatarIcon: String {
        switch variant {
        case "thinking":      return "brain"
        case "hint":          return "lightbulb.fill"
        case "encouragement": return "hand.thumbsup.fill"
        case "suggestion":    return "sparkles"
        default:              return "bubble.left.fill"
        }
    }

    private var bubbleBackground: Color {
        switch variant {
        case "hint":          return Color.yellow.opacity(0.1)
        case "encouragement": return Color.green.opacity(0.1)
        case "suggestion":    return Color.purple.opacity(0.1)
        default:              return Color(.systemGray6)
        }
    }
}

// MARK: - Social Primitive

/// Renders social variants: comment, reaction, share, leaderboard, community
struct LyoSocialPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "comment" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch variant {
            case "reaction":
                reactionView
            case "leaderboard":
                leaderboardView
            default: // "comment", "share", "community"
                commentView
            }
        }
    }

    private var commentView: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(component.content?.title ?? "User")
                    .font(.subheadline.weight(.medium))
                Text(component.content?.body ?? component.content?.text ?? "")
                    .font(.body)
            }
        }
    }

    private var reactionView: some View {
        HStack(spacing: 12) {
            ForEach(["👍", "❤️", "🎉", "🤔"], id: \.self) { emoji in
                Button {
                    onAction?(LyoCommand(action: "react", payload: ["emoji": .string(emoji)]))
                } label: {
                    Text(emoji)
                        .font(.title2)
                }
            }
        }
    }

    private var leaderboardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(component.content?.title ?? "Leaderboard")
                .font(.headline)

            if let children = component.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    HStack(spacing: 10) {
                        Text("#\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                        Text(child.content?.title ?? "Player")
                            .font(.subheadline)
                        Spacer()
                        Text(child.content?.text ?? "0")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Alert Primitive

/// Renders alert variants: info, success, warning, error, tip
struct LyoAlertPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "info" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alertIcon)
                .font(.body)
                .foregroundStyle(alertColor)

            VStack(alignment: .leading, spacing: 4) {
                if let title = component.content?.title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                if let body = component.content?.body ?? component.content?.text {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(alertColor.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(alertColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var alertIcon: String {
        switch variant {
        case "success": return "checkmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "error":   return "xmark.circle.fill"
        case "tip":     return "lightbulb.fill"
        default:        return "info.circle.fill"
        }
    }

    private var alertColor: Color {
        switch variant {
        case "success": return .green
        case "warning": return .orange
        case "error":   return .red
        case "tip":     return .yellow
        default:        return .blue
        }
    }
}

// MARK: - Skeleton Primitive

/// Renders loading skeleton variants: text, card, list, full
struct LyoSkeletonPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext

    private var variant: String { component.variant ?? "card" }

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        Group {
            switch variant {
            case "text":
                textSkeleton
            case "list":
                listSkeleton
            case "full":
                fullSkeleton
            default: // "card"
                cardSkeleton
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private var textSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            skeletonBar(width: 200, height: 14)
            skeletonBar(width: .infinity, height: 10)
            skeletonBar(width: 160, height: 10)
        }
    }

    private var cardSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            skeletonBar(width: .infinity, height: 120)
            skeletonBar(width: 180, height: 14)
            skeletonBar(width: 240, height: 10)
            skeletonBar(width: 120, height: 10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var listSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 10) {
                    skeletonBar(width: 40, height: 40)
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 6) {
                        skeletonBar(width: 140, height: 12)
                        skeletonBar(width: 200, height: 10)
                    }
                }
            }
        }
    }

    private var fullSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            skeletonBar(width: .infinity, height: 180)
            textSkeleton
            Divider()
            listSkeleton
        }
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(maxWidth: width == .infinity ? .infinity : width, maxHeight: height)
            .frame(height: height)
            .opacity(0.4 + shimmerPhase * 0.3)
    }
}
