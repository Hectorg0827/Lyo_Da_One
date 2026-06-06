//
//  CourseGenerationCard.swift
//  Lyo
//
//  Interactive card for course generation in chat
//

import SwiftUI

struct CourseGenerationCard: View {
    let topic: String
    let isGenerating: Bool
    let progress: Double
    let onGenerate: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a Course")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Personalized learning path")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !isGenerating {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Topic Display
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.purple)
                
                Text(topic)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(12)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // Features Preview
            if !isGenerating {
                HStack(spacing: 16) {
                    FeatureChip(icon: "list.bullet", text: "Modules")
                    FeatureChip(icon: "play.circle", text: "Lessons")
                    FeatureChip(icon: "questionmark.circle", text: "Quizzes")
                }
            }
            
            // Progress or Action
            if isGenerating {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .tint(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: onGenerate) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Generate Course")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Material.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var progressText: String {
        switch progress {
        case 0..<0.3:
            return "Analyzing topic..."
        case 0.3..<0.6:
            return "Creating modules..."
        case 0.6..<0.9:
            return "Generating lessons..."
        default:
            return "Almost ready..."
        }
    }
}

// MARK: - Feature Chip

private struct FeatureChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CourseGenerationCard(
            topic: "Swift Programming",
            isGenerating: false,
            progress: 0,
            onGenerate: {},
            onDismiss: {}
        )
        
        CourseGenerationCard(
            topic: "Machine Learning Basics",
            isGenerating: true,
            progress: 0.6,
            onGenerate: {},
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
