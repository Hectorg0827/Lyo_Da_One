//
//  StudyPlanBubbleView.swift
//  Lyo
//
//  Expandable multi-day study plan bubble for the test prep flow.
//

import SwiftUI

struct StudyPlanBubbleView: View {
    let plan: StudyPlan
    let testTitle: String
    let testDate: Date?
    let onConfirmSchedule: (() -> Void)?

    @State private var expandedDays: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            planHeader
            Divider().overlay(Color.white.opacity(0.1))
            daysList
            if let onConfirmSchedule {
                scheduleButton(action: onConfirmSchedule)
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var planHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.purple)
                    Text("STUDY PLAN")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(1.2)
                }
                Text(plan.title)
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundStyle(.white)
                if let desc = plan.description {
                    Text(desc)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(plan.schedule.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.purple)
                Text("days")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - Days List

    private var daysList: some View {
        VStack(spacing: 1) {
            ForEach(plan.schedule) { day in
                dayRow(day)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func dayRow(_ day: StudyDay) -> some View {
        let isOpen = expandedDays.contains(day.id)
        let totalMins = day.tasks.reduce(0) { $0 + $1.durationMinutes }

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if isOpen { expandedDays.remove(day.id) }
                    else { expandedDays.insert(day.id) }
                }
            } label: {
                HStack {
                    Text("Day \(day.dayNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                        .frame(width: 44, alignment: .leading)

                    Text(day.topic)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(totalMins) min")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, 10)
            }

            if isOpen {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(day.tasks) { task in
                        taskRow(task)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().overlay(Color.white.opacity(0.06))
        }
    }

    private func taskRow(_ task: StudyTask) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: taskIcon(for: task.type))
                .font(.caption)
                .foregroundStyle(.purple.opacity(0.8))
                .frame(width: 16)

            Text(task.title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text("\(task.durationMinutes)m")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func taskIcon(for type: String) -> String {
        switch type.lowercased() {
        case "read": return "book.fill"
        case "watch": return "play.circle.fill"
        case "practice": return "pencil"
        default: return "checkmark.circle"
        }
    }

    // MARK: - Schedule Button

    private func scheduleButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text("Add to Calendar")
                    .fontWeight(.semibold)
            }
            .font(DesignTokens.Typography.labelMedium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(Color.purple.opacity(0.2))
            .foregroundStyle(.purple)
        }
        .padding(DesignTokens.Spacing.sm)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StudyPlanBubbleView(
            plan: StudyPlan(
                title: "AP Chemistry Final Prep",
                description: "12-day plan",
                schedule: [
                    StudyDay(dayNumber: 1, topic: "Atomic Structure", tasks: [
                        StudyTask(title: "Read Ch. 1-2", durationMinutes: 30, type: "read"),
                        StudyTask(title: "Practice problems", durationMinutes: 45, type: "practice")
                    ]),
                    StudyDay(dayNumber: 2, topic: "Chemical Bonding", tasks: [
                        StudyTask(title: "Review bonding types", durationMinutes: 30, type: "read"),
                        StudyTask(title: "Watch video lecture", durationMinutes: 20, type: "watch")
                    ])
                ]
            ),
            testTitle: "AP Chemistry Final",
            testDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()),
            onConfirmSchedule: {}
        )
        .padding()
    }
}
