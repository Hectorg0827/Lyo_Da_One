//
//  A2UIStudyPlanViews.swift
//  Lyo
//
//  Study Plan renderer views for A2UI
//

import SwiftUI

// MARK: - Study Plan Views

struct A2UIStudyPlanOverviewView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(props.title ?? "Study Plan")
                        .font(.title2.bold())
                    if let subtitle = props.subtitle {
                        Text(subtitle)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let progress = normalizedProgress() {
                    CircularProgressView(progress: progress)
                        .frame(width: 50, height: 50)
                }
            }
            
            // Stats
            if let session = props.sessions?.first {
                HStack(spacing: 20) {
                    let focus = session.topic ?? session.title
                    A2UIStatBox(title: "Focus", value: focus, icon: "book.fill")
                    A2UIStatBox(title: "Duration", value: "\(session.duration) min", icon: "clock.fill")
                }
            }
            
            // Milestones
            if let milestones = props.milestones, !milestones.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Milestones")
                        .font(.headline)
                    
                    ForEach(milestones, id: \.id) { milestone in
                        MilestoneRow(milestone: milestone)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func normalizedProgress() -> Double? {
        if let progress = props.progress {
            return progress > 1 ? progress / 100 : progress
        }
        if let total = props.totalCount, let completed = props.completedCount, total > 0 {
            return Double(completed) / Double(total)
        }
        return nil
    }
}

struct A2UIStudySessionView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var timeRemaining: Int = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Timer
            if let session = props.sessions?.first {
                Text(session.topic ?? session.title)
                    .font(.headline)
                
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: CGFloat(timeRemaining) / CGFloat(max(session.duration, 1) * 60))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("remaining")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 180, height: 180)
            }
            
            // Focus Tips
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Controls
            HStack(spacing: 20) {
                Button("Pause") {
                    // Handle pause
                }
                .buttonStyle(.bordered)
                
                Button("End Session") {
                    // Handle end
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            if let session = props.sessions?.first {
                timeRemaining = session.duration * 60
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct A2UIStudyCalendarView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Study Calendar")
                .font(.headline)
            
            // Heatmap grid
            if let heatmap = props.heatmapData {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(heatmap) { cell in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatmapColor(for: cell.value))
                            .frame(height: 30)
                    }
                }
            } else {
                // Placeholder calendar
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(0..<35, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 30)
                    }
                }
            }
            
            // Legend
            HStack {
                Text("Less")
                    .font(.caption)
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(for: intensity))
                        .frame(width: 12, height: 12)
                }
                Text("More")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func heatmapColor(for intensity: Double) -> Color {
        Color.green.opacity(intensity * 0.8 + 0.1)
    }
}

struct A2UIMilestoneTrackerView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(props.title ?? "Milestones")
                .font(.headline)
            
            if let milestones = props.milestones {
                ForEach(milestones, id: \.id) { milestone in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(milestone.isCompleted ? Color.green : Color(.systemGray4), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if milestone.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text(milestone.title)
                                .strikethrough(milestone.isCompleted)
                            if let due = milestone.targetDate {
                                Text("Target: \(due)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
    }
}

struct A2UIStudyStreakView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            // Streak flame
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                Text("🔥")
                    .font(.largeTitle)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(props.streak ?? 0) Day Streak!")
                    .font(.title3.bold())
                Text("Keep it up! Study today to continue.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }
}

struct A2UIFocusModeView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)
            
            Text("Focus Mode")
                .font(.title2.bold())
            
            Text(props.body ?? "Minimize distractions and concentrate on your studies.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Start Focus Session") {
                // Handle start
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
    }
}

struct A2UIStudyGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(props.title ?? "Study")
                .font(.headline)
            if let body = props.body {
                Text(body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

private struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption2.bold())
        }
    }
}

private struct A2UIStatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct MilestoneRow: View {
    let milestone: A2UIMilestone
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(milestone.isCompleted ? .green : .gray)
            
            Text(milestone.title)
                .strikethrough(milestone.isCompleted)
            
            Spacer()
            
            if let reward = milestone.xpReward {
                Text("+\(reward) XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
