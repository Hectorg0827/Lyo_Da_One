//
//  A2AProgressView.swift
//  Lyo
//
//  Created for A2A Multi-Agent Visualization.
//

import SwiftUI

struct A2AProgressView: View {
    @ObservedObject var courseService = A2ACourseService.shared
    
    // A2A Phases in order
    private let orderedPhases: [A2APipelinePhase] = [
        .pedagogy,
        .cinematic,
        .visual,
        .voice,
        .qaCheck
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Header
            Text("Building Your Course")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if let topic = courseService.generatedCourse?.title {
                Text(topic)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
            }
            
            // Progress Bar
            ProgressView(value: Double(courseService.progress), total: 100)
                .tint(.blue)
                .padding(.horizontal)
            
            // Phase List
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(orderedPhases, id: \.self) { phase in
                        PhaseRow(
                            phase: phase,
                            status: statusFor(phase),
                            isCurrent: courseService.currentPhase == phase
                        )
                    }
                }
                .padding()
            }
            .frame(maxHeight: 300)
            .background(.thinMaterial)
            .cornerRadius(12)
            
            // Status Message
            if let error = courseService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            } else if courseService.isGenerating {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .id("status-\(courseService.currentPhase?.rawValue ?? "nil")") // Force transition
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
    private func statusFor(_ phase: A2APipelinePhase) -> A2APhaseStatus {
        return courseService.phases.first(where: { $0.phase == phase })?.status ?? .pending
    }
    
    private var statusMessage: String {
        guard let phase = courseService.currentPhase else { return "Initializing agents..." }
        
        switch phase {
        case .pedagogy: return "Pedagogy Agent designing structure..."
        case .cinematic: return "Cinematic Agent writing scripts..."
        case .visual: return "Visual Agent generating imagery..."
        case .voice: return "Voice Agent synthesizing audio..."
        case .qaCheck: return "QA Agent verifying content..."
        default: return "Processing..."
        }
    }
}

// MARK: - Subviews

struct PhaseRow: View {
    let phase: A2APipelinePhase
    let status: A2APhaseStatus
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)
                
                if status == .running {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(foregroundColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.displayName)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .semibold : .medium)
                    .foregroundColor(isCurrent ? .primary : .secondary)
                
                if status == .running {
                    Text("Working...")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Status Indicator
            if status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if status == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .opacity(status == .pending ? 0.5 : 1.0)
        .animation(.default, value: status)
    }
    
    var backgroundColor: Color {
        switch status {
        case .running: return .blue
        case .completed: return .green.opacity(0.2)
        case .failed: return .red.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }
    
    var foregroundColor: Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        default: return .gray
        }
    }
    
    var iconName: String {
        phase.icon
    }
}

#Preview {
    A2AProgressView()
}
