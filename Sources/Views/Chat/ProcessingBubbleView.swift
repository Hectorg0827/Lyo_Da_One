//
//  ProcessingBubbleView.swift
//  Lyo
//
//  Created for Dynamic Chat
//

import SwiftUI

struct ProcessingBubbleView: View {
    let step: String
    let progress: Double?
    
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 12) {
            AnimatedReadingMascotView(size: 24)
            
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
