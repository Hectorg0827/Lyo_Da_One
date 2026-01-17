//
//  ProcessingBubbleView.swift
//  Lyo
//
//  Created for A2UI Dynamic Chat
//

import SwiftUI

struct ProcessingBubbleView: View {
    let step: String
    let progress: Double?
    
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated Orb / Indicator
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .opacity(animate ? 1.0 : 0.6)
                
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 24, height: 24)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                    animate = true
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .id("step_\(step)") // Force transition on change
                
                if let progress = progress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                        .frame(maxWidth: 120)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
    }
}

#Preview {
    VStack {
        ProcessingBubbleView(step: "Researching topic...", progress: 0.3)
        ProcessingBubbleView(step: "Generating course...", progress: nil)
    }
}
