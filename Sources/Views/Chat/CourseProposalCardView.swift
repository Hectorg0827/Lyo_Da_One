//
//  CourseProposalCardView.swift
//  Lyo
//
//  Interactive course proposal card that appears in the chat.
//  The user must tap "Start Learning" to begin course generation —
//  prevents unwanted cost from auto-triggered course creation.
//

import SwiftUI

struct CourseProposalCardView: View {
    let payload: CoursePayload
    let onStart: () -> Void
    let onAdjust: (() -> Void)?
    
    @State private var isExpanded = false
    @State private var isGenerating = false
    
    /// Convenience init matching older call sites
    init(coursePayload: CoursePayload, onStartLearning: @escaping () -> Void) {
        self.payload = coursePayload
        self.onStart = onStartLearning
        self.onAdjust = nil
    }
    
    /// Full init with adjust support (EnhancedMessageBubble)
    init(payload: CoursePayload, onStart: @escaping () -> Void, onAdjust: (() -> Void)? = nil) {
        self.payload = payload
        self.onStart = onStart
        self.onAdjust = onAdjust
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "book.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label(payload.level, systemImage: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let duration = payload.duration {
                            Label(duration, systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if !payload.objectives.isEmpty {
                            Label("\(payload.objectives.count) objectives", systemImage: "list.bullet")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
            }
            
            // Learning Objectives (expandable)
            if !payload.objectives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("What you'll learn")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(payload.objectives.prefix(5).enumerated()), id: \.offset) { _, objective in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "8B5CF6"))
                                        .padding(.top, 2)
                                    
                                    Text(objective)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            
            // CTA Buttons
            HStack(spacing: 12) {
                Button(action: {
                    guard !isGenerating else { return }
                    isGenerating = true
                    HapticManager.shared.medium()
                    onStart()
                }) {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Starting...")
                        } else {
                            Image(systemName: "play.fill")
                            Text("Start Course")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: isGenerating
                                ? [Color(hex: "6366F1").opacity(0.6), Color(hex: "8B5CF6").opacity(0.6)]
                                : [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isGenerating)
                
                if let onAdjust {
                    Button(action: {
                        HapticManager.shared.light()
                        onAdjust()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                            Text("Adjust")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1E1B4B").opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6").opacity(0.4), Color(hex: "6366F1").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
