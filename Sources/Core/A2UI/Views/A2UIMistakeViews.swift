//
//  A2UIMistakeViews.swift
//  Lyo
//
//  Mistake Tracker renderer views for A2UI
//

import SwiftUI

// MARK: - Mistake Tracker Views

struct A2UIMistakeCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text(props.title ?? "Mistake")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let topic = props.topic {
                            Text(topic)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let count = props.occurrenceCount {
                        Text("×\(count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                Divider()
                
                if let body = props.body {
                    Text(body)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                if let correction = props.correctSolution ?? props.recommendedAction {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Correct approach:")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text(correction)
                            .font(.callout)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button("Practice This") {
                    // Handle practice
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct A2UIMistakePatternView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Mistake Patterns")
                    .font(.headline)
            }
            
            if let related = props.relatedMistakes, !related.isEmpty {
                ForEach(related, id: \.self) { item in
                    PatternRow(pattern: MistakePattern(id: item, name: item, frequency: 0.25, trend: .stable))
                }
            } else if let description = props.patternDescription {
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                // Demo patterns
                PatternRow(pattern: MistakePattern(id: "1", name: "Sign errors", frequency: 0.45, trend: .increasing))
                PatternRow(pattern: MistakePattern(id: "2", name: "Missing steps", frequency: 0.30, trend: .stable))
                PatternRow(pattern: MistakePattern(id: "3", name: "Formula recall", frequency: 0.25, trend: .decreasing))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct A2UIMistakeStatsView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Your Progress")
                .font(.headline)
            
            let total = props.occurrenceCount ?? 0
            let mastery = props.masteryLevel ?? 0
            let resolved = Int(Double(total) * mastery)
            let pending = max(total - resolved, 0)

            HStack(spacing: 24) {
                StatCircle(
                    value: total,
                    label: "Total",
                    color: .red
                )
                
                StatCircle(
                    value: resolved,
                    label: "Resolved",
                    color: .green
                )
                
                StatCircle(
                    value: pending,
                    label: "Pending",
                    color: .orange
                )
            }
            
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("\(Int(mastery * 100))% mastery")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct A2UIMistakeQuizView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var selectedAnswer: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Mistake Review")
                    .font(.headline)
            }
            
            Text(props.question ?? "Based on your past mistakes, answer this:")
                .foregroundColor(.secondary)
            
            if let options = props.options {
                ForEach(options, id: \.id) { option in
                    Button {
                        selectedAnswer = option.id
                    } label: {
                        HStack {
                            Image(systemName: selectedAnswer == option.id ? "circle.fill" : "circle")
                            Text(option.text)
                            Spacer()
                        }
                        .padding()
                        .background(selectedAnswer == option.id ? Color.purple.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

struct A2UIMistakeGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(props.title ?? "Mistake Tracker")
                    .font(.headline)
            }
            
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

// MARK: - Supporting Types

private struct MistakePattern: Identifiable {
    let id: String
    let name: String
    let frequency: Double
    let trend: Trend
    
    enum Trend {
        case increasing, stable, decreasing
    }
}

private struct PatternRow: View {
    let pattern: MistakePattern
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(pattern.name)
                    .font(.subheadline)
                Text("\(Int(pattern.frequency * 100))% of mistakes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: trendIcon)
                .foregroundColor(trendColor)
        }
        .padding(.vertical, 8)
    }
    
    private var trendIcon: String {
        switch pattern.trend {
        case .increasing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .decreasing: return "arrow.down.right"
        }
    }
    
    private var trendColor: Color {
        switch pattern.trend {
        case .increasing: return .red
        case .stable: return .orange
        case .decreasing: return .green
        }
    }
}

private struct StatCircle: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                Text("\(value)")
                    .font(.title2.bold())
                    .foregroundColor(color)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
