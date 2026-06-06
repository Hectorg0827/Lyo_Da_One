import SwiftUI

struct MasteryProfileView: View {
    @EnvironmentObject var viewModel: LyoAIViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let profile = viewModel.masteryProfile {
                        // Header Stats
                        HStack(spacing: 20) {
                            MasteryStatCard(title: "Velocity", value: String(format: "%.1fx", profile.learningVelocity), icon: "bolt.fill", color: .orange)
                            MasteryStatCard(title: "Optimal Diff", value: String(format: "%.1f", profile.optimalDifficulty), icon: "target", color: .blue)
                        }
                        .padding(.horizontal)
                        
                        // Skill Mastery List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Skill Mastery")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(profile.skills.sorted(by: { $0.value > $1.value }), id: \.key) { skill, level in
                                SkillRow(name: skill, level: level)
                            }
                        }
                        .padding(.vertical)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Strengths & Weaknesses
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Strengths", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.subheadline.bold())
                                
                                ForEach(profile.strengths, id: \.self) { strength in
                                    Text(strength)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Focus Areas", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.subheadline.bold())
                                
                                ForEach(profile.weaknesses, id: \.self) { weakness in
                                    Text(weakness)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Recommended Focus
                        if !profile.recommendedFocus.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Recommended Next Steps", systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                
                                ForEach(profile.recommendedFocus, id: \.self) { focus in
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(.purple)
                                        Text(focus)
                                            .font(.subheadline)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                    } else {
                        VStack(spacing: 20) {
                            ProgressView()
                            Text("Analyzing your learning patterns...")
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 300)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Mastery Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchMasteryProfile()
                }
            }
        }
    }
}

struct MasteryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct SkillRow: View {
    let name: String
    let level: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(level * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(level), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
    }
}
