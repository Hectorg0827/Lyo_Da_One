//
//  TestPrepProposalCardView.swift
//  Lyo
//
//  Approval card for test prep — user must tap "Start My Prep Plan" before execution.
//  Mirrors the structure of CourseProposalCardView.
//

import SwiftUI

struct TestPrepProposalCardView: View {
    let content: TestPrepContent
    let onStartPrep: () -> Void
    let onAdjust: (() -> Void)?

    @State private var isStarting = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            detailsSection
            if isExpanded, let plan = content.studyPlan {
                planPreview(plan)
            }
            ctaSection
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .stroke(accentColor.opacity(0.4), lineWidth: 1)
        )
        .applyMultiLayerShadow()
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: heroGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                    Text("TEST PREP PLAN")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(1.5)
                }

                Text(content.subject)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                badge(
                    icon: "calendar",
                    text: examDateText,
                    color: .orange
                )
                badge(
                    icon: "chart.bar.fill",
                    text: confidenceBadgeText,
                    color: confidenceBadgeColor
                )
                badge(
                    icon: "clock.fill",
                    text: "\(formattedHours)/day",
                    color: accentColor
                )
            }

            if let plan = content.studyPlan {
                HStack {
                    Text("\(plan.schedule.count)-day plan")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Hide preview" : "Preview plan")
                                .font(DesignTokens.Typography.caption)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(accentColor)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - Plan Preview

    private func planPreview(_ plan: StudyPlan) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ForEach(plan.schedule.prefix(2)) { day in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Day \(day.dayNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(accentColor)
                        .frame(width: 40)

                    Text(day.topic)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(day.tasks.reduce(0) { $0 + $1.durationMinutes }) min")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, 6)
                .background(DesignTokens.Colors.surfaceElevated.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            if let plan = content.studyPlan, plan.schedule.count > 2 {
                Text("+ \(plan.schedule.count - 2) more days")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, 4)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Button {
                guard !isStarting else { return }
                isStarting = true
                HapticManager.shared.medium()
                onStartPrep()
            } label: {
                HStack {
                    if isStarting {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    }
                    Text(isStarting ? "Setting up your plan..." : "Start My Prep Plan")
                        .font(DesignTokens.Typography.labelLarge.bold())
                    if !isStarting {
                        Image(systemName: "sparkles")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(
                    isStarting
                        ? AnyShapeStyle(Color.gray)
                        : AnyShapeStyle(LinearGradient(colors: heroGradient, startPoint: .leading, endPoint: .trailing))
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            }
            .disabled(isStarting)

            if let onAdjust {
                Button {
                    onAdjust()
                } label: {
                    Text("Adjust Details")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .padding(.bottom, 4)
    }

    // MARK: - Helpers

    private var cardBackground: some ShapeStyle {
        AnyShapeStyle(DesignTokens.Colors.surface)
    }

    private var accentColor: Color {
        heroGradient.first ?? .blue
    }

    private var heroGradient: [Color] {
        let lower = content.subject.lowercased()
        if lower.contains("math") || lower.contains("calculus") || lower.contains("algebra") {
            return [Color(hex: "1A56DB"), Color(hex: "5850EC")]
        } else if lower.contains("biology") || lower.contains("science") || lower.contains("chemistry") {
            return [Color(hex: "0E9F6E"), Color(hex: "057A55")]
        } else if lower.contains("history") || lower.contains("social") {
            return [Color(hex: "C27803"), Color(hex: "9B1C1C")]
        } else if lower.contains("english") || lower.contains("writing") || lower.contains("lit") {
            return [Color(hex: "7E3AF2"), Color(hex: "5521B5")]
        } else {
            return [Color(hex: "0F172A"), Color(hex: "1E3A5F")]
        }
    }

    /// Cached once instead of reallocating a DateFormatter on every render pass.
    private static let examDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var examDateText: String {
        guard let date = content.testDate else {
            return content.daysUntilTest.map { "\($0) days" } ?? "Scheduled"
        }
        return Self.examDateFormatter.string(from: date)
    }

    private var confidenceBadgeText: String {
        switch content.confidenceLevel {
        case "low": return "Needs work"
        case "high": return "Feeling good"
        default: return "Building up"
        }
    }

    private var confidenceBadgeColor: Color {
        switch content.confidenceLevel {
        case "low": return .red
        case "high": return .green
        default: return .orange
        }
    }

    private var formattedHours: String {
        content.dailyStudyHours == content.dailyStudyHours.rounded()
            ? "\(Int(content.dailyStudyHours))h"
            : String(format: "%.1fh", content.dailyStudyHours)
    }

    private func badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TestPrepProposalCardView(
            content: TestPrepContent(
                subject: "AP Chemistry",
                testType: "final",
                testDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()),
                daysUntilTest: 12,
                dailyStudyHours: 2.0,
                confidenceLevel: "medium",
                studyPlan: StudyPlan(
                    title: "AP Chem Final Prep",
                    description: "12-day intensive plan",
                    schedule: [
                        StudyDay(dayNumber: 1, topic: "Atomic Structure & Periodic Trends", tasks: [
                            StudyTask(title: "Read Chapter 1-2", durationMinutes: 30, type: "read"),
                            StudyTask(title: "Practice problems", durationMinutes: 45, type: "practice")
                        ]),
                        StudyDay(dayNumber: 2, topic: "Chemical Bonding", tasks: [
                            StudyTask(title: "Review bonding types", durationMinutes: 30, type: "read")
                        ])
                    ]
                )
            ),
            onStartPrep: {},
            onAdjust: {}
        )
        .padding()
    }
}
