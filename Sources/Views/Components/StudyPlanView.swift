//
//  StudyPlanView.swift
//  Lyo
//
//  Renders a StudyPlan model inside a message bubble.
//

import SwiftUI

struct StudyPlanView: View {
    let plan: StudyPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    if let desc = plan.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            // Schedule
            ForEach(plan.schedule) { day in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Day \(day.dayNumber)")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                        Text("·")
                            .foregroundColor(.white.opacity(0.4))
                        Text(day.topic)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    ForEach(day.tasks) { task in
                        HStack(spacing: 8) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : iconForType(task.type))
                                .font(.caption)
                                .foregroundColor(task.isCompleted ? .green : .white.opacity(0.5))
                            
                            Text(task.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                            
                            Spacer()
                            
                            Text("\(task.durationMinutes)m")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.leading, 12)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "read": return "book"
        case "practice": return "hammer"
        case "watch": return "play.circle"
        default: return "circle"
        }
    }
}
