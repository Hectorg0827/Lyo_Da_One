//
//  A2UILayoutRenderers.swift
//  Lyo
//
//  Layout container renderers for A2UI components
//

import SwiftUI

// MARK: - Layout Renderers

struct A2UIStackRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        let spacing = component.props.spacing ?? 12
        let children = component.children ?? []

        if component.type == .hStack || component.props.axis == "horizontal" {
            HStack(spacing: spacing) {
                ForEach(children) { child in
                    A2UIRenderer(component: child, context: context, onAction: { action, _ in
                        onAction?(action)
                    })
                }
            }
            .padding(paddingFromProps())
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(children) { child in
                    A2UIRenderer(component: child, context: context, onAction: { action, _ in
                        onAction?(action)
                    })
                }
            }
            .padding(paddingFromProps())
        }
    }

    private func paddingFromProps() -> EdgeInsets {
        guard let p = component.props.padding else { return EdgeInsets() }
        return EdgeInsets(
            top: p.top,
            leading: p.leading,
            bottom: p.bottom,
            trailing: p.trailing
        )
    }
}

struct A2UIGridRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        let children = component.children ?? []
        let columns = component.props.columns ?? 2
        let spacing = component.props.spacing ?? 12

        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(children) { child in
                A2UIRenderer(component: child, context: context, onAction: { action, _ in
                    onAction?(action)
                })
            }
        }
        .padding(paddingFromProps())
    }

    private func paddingFromProps() -> EdgeInsets {
        guard let p = component.props.padding else { return EdgeInsets() }
        return EdgeInsets(
            top: p.top,
            leading: p.leading,
            bottom: p.bottom,
            trailing: p.trailing
        )
    }
}

struct A2UICardRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card header
            if let title = component.props.title {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    if let subtitle = component.props.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Card content
            ForEach(component.children ?? []) { child in
                A2UIRenderer(component: child, context: context, onAction: { action, _ in
                    onAction?(action)
                })
            }
        }
        .padding()
        .background(backgroundColorFromProps())
        .cornerRadius(component.props.borderRadius ?? 12)
        .shadow(
            color: Color.black.opacity(0.1),
            radius: component.props.shadowRadius ?? 4,
            x: 0,
            y: 2
        )
        .padding(.horizontal)
    }

    private func backgroundColorFromProps() -> Color {
        if let hex = component.props.backgroundColor {
            return Color(hex: hex)
        }
        return Color(.systemBackground)
    }
}

// MARK: - Study Plan Renderers

struct A2UIStudyPlanOverviewRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(component.props.title ?? "Study Plan")
                        .font(.title2.bold())
                    if let subtitle = component.props.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let progress = component.props.progress {
                    ProgressRing(progress: progress, size: 50)
                }
            }

            // Today's Sessions
            if let sessions = component.props.sessions, !sessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Sessions")
                        .font(.headline)
                    ForEach(sessions.filter { isToday($0.scheduledDate) }) { session in
                        StudySessionCard(session: session)
                    }
                }
            }

            // Upcoming Milestones
            if let milestones = component.props.milestones?.prefix(3) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coming Up")
                        .font(.headline)
                    ForEach(Array(milestones)) { milestone in
                        LayoutMilestoneRow(milestone: milestone)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

struct A2UIStudySessionRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(component.props.title ?? "Study Session")
                    .font(.subheadline.bold())
                if let durationMinutes = component.props.duration {
                    HStack {
                        Image(systemName: "clock")
                        Text("\(durationMinutes) min")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            if component.props.isCompleted == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if let scheduledTime = component.props.startDate {
                Text(scheduledTime, style: .time)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Gamification Renderers

struct A2UIXPBadgeRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.yellow)
            Text("+\(component.props.xp ?? component.props.rewardAmount ?? 50) XP")
                .font(.headline.bold())
                .foregroundColor(.primary)
            if let reason = component.props.text {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

struct A2UILevelProgressRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level \(component.props.level ?? "\(component.props.levelNumber ?? 1)")")
                    .font(.headline.bold())
                Spacer()
                Text("\(component.props.xp ?? 0)/\(component.props.xpToNextLevel ?? 100) XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: component.props.progress ?? 0.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct A2UIAchievementRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundColor(.gold)

            VStack(alignment: .leading, spacing: 4) {
                Text(component.props.title ?? "Achievement Unlocked!")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                Text(component.props.subtitle ?? "Great job!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.gold.opacity(0.1), Color.yellow.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gold.opacity(0.3), lineWidth: 1)
        )
    }
}

struct A2UIProgressRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(component.props.title ?? "Progress")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int((component.props.progress ?? 0) * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: component.props.progress ?? 0.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
    }
}

// MARK: - Supporting Views

struct ProgressRing: View {
    let progress: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.purple, .blue, .purple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
        }
        .frame(width: size, height: size)
    }
}

struct StudySessionCard: View {
    let session: A2UIStudySession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.topic ?? session.title)
                    .font(.subheadline.bold())
                HStack {
                    Image(systemName: "clock")
                    Text("\(session.duration) min")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text(session.scheduledDate, style: .time)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct LayoutMilestoneRow: View {
    let milestone: A2UIMilestone

    var body: some View {
        HStack {
            Circle()
                .fill(typeColor)
                .frame(width: 8, height: 8)

            Text(milestone.title)
                .font(.subheadline)

            Spacer()

            if let targetDate = milestone.targetDate {
                Text(targetDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    var typeColor: Color {
        milestone.isCompleted ? .green : .blue
    }
}

// MARK: - Color Extensions

extension Color {
    static let gold = Color(red: 1.0, green: 0.843, blue: 0.0)
}