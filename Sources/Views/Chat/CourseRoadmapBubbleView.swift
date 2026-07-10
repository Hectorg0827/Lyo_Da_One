//
//  CourseRoadmapBubbleView.swift
//  Lyo
//
//  Created for Dynamic Chat
//

import SwiftUI

struct CourseRoadmapBubbleView: View {
    let title: String
    let modules: [CourseModule]
    let totalModules: Int
    let completedModules: Int
    let onModuleSelect: (CourseModule) -> Void
    
    var progress: Double {
        guard totalModules > 0 else { return 0 }
        return Double(completedModules) / Double(totalModules)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundStyle(.white)
                    Text("COURSE ROADMAP")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(1)
                    Spacer()
                    Text("\(completedModules)/\(totalModules)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            // Modules List
            VStack(spacing: 0) {
                ForEach(modules) { module in
                    Button {
                        if !module.isLocked {
                            onModuleSelect(module)
                        }
                    } label: {
                        CourseModuleRow(module: module)
                    }
                    .buttonStyle(.plain)
                    
                    if module.id != modules.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.1))
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CourseModuleRow: View {
    let module: CourseModule
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                InlineMathText(text: module.title, isSelectable: false)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(module.isLocked ? .secondary : .primary)
                
                if let duration = module.duration {
                    Text(duration)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !module.isLocked && !module.isCompleted {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    var statusIcon: String {
        if module.isCompleted { return "checkmark" }
        if module.isLocked { return "lock.fill" }
        return "play.fill"
    }
    
    var statusColor: Color {
        if module.isCompleted { return .green }
        if module.isLocked { return .secondary }
        return .blue
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CourseRoadmapBubbleView(
            title: "Python for Beginners",
            modules: [
                CourseModule(title: "Introduction to Python", duration: "5 min", isCompleted: true),
                CourseModule(title: "Variables & Data Types", duration: "10 min", isCompleted: false),
                CourseModule(title: "Control Flow: If/Else", duration: "15 min", isLocked: true),
                CourseModule(title: "Loops & Iteration", duration: "12 min", isLocked: true)
            ],
            totalModules: 12,
            completedModules: 1,
            onModuleSelect: { _ in }
        )
        .padding()
    }
}
