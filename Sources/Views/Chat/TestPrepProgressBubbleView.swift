//
//  TestPrepProgressBubbleView.swift
//  Lyo
//
//  Compact progress tracker shown as the 4th delivery phase of test prep.
//

import SwiftUI

struct TestPrepProgressBubbleView: View {
    let content: TestPrepContent
    let onQuickAction: (String) -> Void

    private var daysLeft: Int {
        guard let testDate = content.testDate else {
            return content.daysUntilTest ?? 0
        }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: testDate).day ?? 0)
    }

    private var completedCount: Int { content.completedTaskIds.count }
    private var totalTasks: Int {
        content.studyPlan?.schedule.reduce(0) { $0 + $1.tasks.count } ?? 0
    }
    private var taskProgress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedCount) / Double(totalTasks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            headerRow
            metricsRow
            quickActions
        }
        .padding(DesignTokens.Spacing.md)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(content.subject)
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundStyle(.white)
                Text("Test Prep in Progress")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.purple)
                .font(.title3)
        }
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            metricCard(
                value: "\(daysLeft)",
                label: "days left",
                color: daysLeft <= 2 ? .red : daysLeft <= 5 ? .orange : .purple
            )
            metricCard(
                value: "\(completedCount)/\(totalTasks)",
                label: "tasks done",
                color: .blue
            )
            metricCard(
                value: "\(Int(content.masteryScore * 100))%",
                label: "mastery",
                color: masteryColor
            )
        }
    }

    private func metricCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            actionChip(label: "Quiz Me", icon: "brain", action: "quiz")
            actionChip(label: "Flashcards", icon: "rectangle.on.rectangle.angled", action: "flashcards")
            actionChip(label: "Update Plan", icon: "arrow.triangle.2.circlepath", action: "update")
        }
    }

    private func actionChip(label: String, icon: String, action: String) -> some View {
        Button {
            onQuickAction(action)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }

    private var masteryColor: Color {
        content.masteryScore >= 0.7 ? .green : content.masteryScore >= 0.4 ? .orange : .red
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TestPrepProgressBubbleView(
            content: TestPrepContent(
                subject: "AP Chemistry",
                testType: "final",
                testDate: Calendar.current.date(byAdding: .day, value: 8, to: Date()),
                daysUntilTest: 8,
                dailyStudyHours: 2.0,
                confidenceLevel: "medium",
                masteryScore: 0.35
            ),
            onQuickAction: { _ in }
        )
        .padding()
    }
}
