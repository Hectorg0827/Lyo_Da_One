//
//  StudyPlanView.swift
//  Lyo
//
//  A premium, dynamic study plan experience that automatically
//  schedules reminders, integrates with the system calendar,
//  and presents a rich interactive checklist for learners.
//

import SwiftUI

struct StudyPlanView: View {
    let plan: StudyPlan
    
    @State private var isAddedToCalendar = false
    @State private var isProcessing = false
    @State private var actionMessage: String?
    @State private var completedTasks: Set<String> = []
    @State private var hasAutoScheduled = false
    @State private var pulseScale: CGFloat = 1.0

    var totalDurationMinutes: Int {
        plan.schedule.reduce(0) { total, day in
            total + day.tasks.reduce(0) { dayTotal, task in dayTotal + task.durationMinutes }
        }
    }

    var progress: Double {
        let allTasks = plan.schedule.flatMap { $0.tasks }
        guard !allTasks.isEmpty else { return 0 }
        let completed = allTasks.filter { completedTasks.contains($0.id) }.count
        return Double(completed) / Double(allTasks.count)
    }
    
    @ViewBuilder
    private func ProgressRing(progress: Double) -> some View {
        let baseCircle = Circle()
            .stroke(Color.white.opacity(0.12), lineWidth: 5)
            .frame(width: 54, height: 54)

        let gradient = LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        let progressCircle = Circle()
            .trim(from: 0.0, to: CGFloat(max(progress, 0.05)))
            .stroke(gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .frame(width: 54, height: 54)
            .rotationEffect(.degrees(-90))

        ZStack {
            baseCircle
            progressCircle
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "C4B5FD"))
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
    }

    @ViewBuilder
    private func TaskRow(task: StudyTask) -> some View {
        let isDone = completedTasks.contains(task.id)
        let iconColor: Color = colorForType(task.type)
        Button(action: {
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if completedTasks.contains(task.id) {
                    completedTasks.remove(task.id)
                } else {
                    completedTasks.insert(task.id)
                }
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isDone ? Color.green : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(isDone ? Color.green : Color.clear))
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Image(systemName: iconForType(task.type))
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDone ? .white.opacity(0.4) : .white.opacity(0.85))
                    .strikethrough(isDone)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text("\(task.durationMinutes)m")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDone ? Color.white.opacity(0.02) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDone ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sleek Premium Header Card
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    // Glassmorphic status ring
                    ProgressRing(progress: progress)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plan.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let desc = plan.description {
                            Text(desc)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                        } else {
                            Text("Your customized preparation schedule")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.08))
                
                // Proactive Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(isAddedToCalendar ? Color.green : Color(hex: "A78BFA"))
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                            ) {
                                pulseScale = 1.4
                            }
                        }
                    
                    Text(isAddedToCalendar ? "⚡ Auto-Scheduled & Synced with Apple Calendar" : "Scheduling study calendar slots...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isAddedToCalendar ? .green.opacity(0.9) : .white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))% Done")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "C4B5FD"))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "181A30").opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            
            // Dynamic Timeline list
            VStack(alignment: .leading, spacing: 18) {
                ForEach(plan.schedule) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        // Day Label & Topic Header
                        HStack(spacing: 8) {
                            Text("DAY \(day.dayNumber)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            
                            Text(day.topic)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        
                        // Tasks for this Day
                        VStack(spacing: 8) {
                            ForEach(day.tasks) { task in
                                TaskRow(task: task)
                            }
                        }
                        .padding(.leading, 6)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(16)
                }
            }
            
            // Manual sync button as secondary fallback
            if !isAddedToCalendar {
                Button(action: forceCalendarSync) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Re-sync Calendar")
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "0C0E1E").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6").opacity(0.35), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            autoTriggerSync()
        }
    }
    
    private func autoTriggerSync() {
        guard !hasAutoScheduled else { return }
        hasAutoScheduled = true
        forceCalendarSync()
    }
    
    private func forceCalendarSync() {
        isProcessing = true
        actionMessage = nil
        
        Task {
            let studyPlan = CalendarStudyPlan(
                id: UUID().uuidString,
                title: plan.title,
                testDate: nil,
                sessions: plan.schedule.enumerated().map { index, day in
                    CalendarStudySession(
                        id: day.id,
                        title: day.tasks.map { $0.title }.joined(separator: ", "),
                        description: "Study \(day.topic): \(day.tasks.map { $0.title }.joined(separator: ", "))",
                        topic: day.topic,
                        durationMinutes: max(day.tasks.reduce(0) { $0 + $1.durationMinutes }, 15),
                        activityType: day.tasks.first?.type ?? "study"
                    )
                }
            )

            let count = await CalendarService.shared.addStudyPlan(studyPlan)
            let sessions = buildStudySessions(from: plan)
            await TestPrepService.shared.scheduleStudyReminders(sessions: sessions)

            await MainActor.run {
                isProcessing = false
                if count > 0 {
                    withAnimation(.spring()) {
                        isAddedToCalendar = true
                    }
                    actionMessage = "Study sessions added to calendar & reminders scheduled."
                } else {
                    actionMessage = "Could not sync calendar automatically. Check permissions."
                }
            }
        }
    }
    
    private func buildStudySessions(from plan: StudyPlan) -> [StudySession] {
        var sessions: [StudySession] = []
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: Date()).addingTimeInterval(86400)

        for (index, day) in plan.schedule.enumerated() {
            let dayDate = calendar.date(byAdding: .day, value: index, to: baseDate) ?? baseDate
            let startTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayDate) ?? dayDate
            let description = day.tasks.map { "• \($0.title)" }.joined(separator: ", ")
            let totalDuration = max(day.tasks.reduce(0) { $0 + $1.durationMinutes }, 15)

            sessions.append(
                StudySession(
                    title: "Study: \(day.topic)",
                    description: description,
                    durationMinutes: totalDuration,
                    date: startTime
                )
            )
        }
        return sessions
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "read": return "book.fill"
        case "practice": return "hammer.fill"
        case "watch": return "play.circle.fill"
        case "quiz": return "checkmark.seal.fill"
        default: return "sparkles"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "read": return Color(hex: "60A5FA")    // Blue
        case "practice": return Color(hex: "F59E0B")// Orange
        case "watch": return Color(hex: "A78BFA")   // Purple
        case "quiz": return Color(hex: "10B981")    // Green
        default: return Color(hex: "818CF8")
        }
    }
}
