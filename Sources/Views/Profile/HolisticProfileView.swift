import SwiftUI

struct HolisticProfileView: View {
    @StateObject private var softSkillsService = SoftSkillsService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Holistic Profile")
                        .font(.title.bold())
                    Text("More than just grades – your learning DNA")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                if let profile = softSkillsService.profile {
                    // Radar/Spider chart would be ideal here
                    // For now, using skill cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SkillCard(name: "Critical Thinking", skill: profile.criticalThinking, icon: "brain.head.profile")
                        SkillCard(name: "Communication", skill: profile.communication, icon: "bubble.left.and.bubble.right")
                        SkillCard(name: "Grit", skill: profile.grit, icon: "flame")
                        SkillCard(name: "Creativity", skill: profile.creativity, icon: "lightbulb")
                        SkillCard(name: "Collaboration", skill: profile.collaboration, icon: "person.3")
                    }
                    .padding(.horizontal)
                    
                    // Evidence section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Highlights")
                            .font(.headline)
                        
                        ForEach(profile.criticalThinking.evidence.prefix(3), id: \.self) { evidence in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(evidence)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                } else if softSkillsService.isLoading {
                    ProgressView("Analyzing your learning patterns...")
                } else {
                    Text("Complete more lessons to build your profile")
                        .foregroundColor(.secondary)
                }
                // Developer / SaaS Dashboard
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings & API")
                        .font(.headline)
                    
                    NavigationLink(destination: DeveloperDashboardView()) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Developer Dashboard")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
            }
        }
        .task {
            await softSkillsService.fetchProfile()
        }
    }
}

struct SkillCard: View {
    let name: String
    let skill: SkillScore
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(colorForScore(skill.score))
            
            Text(name)
                .font(.caption.bold())
            
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: skill.score / 100)
                    .stroke(colorForScore(skill.score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(skill.score))")
                    .font(.headline)
            }
            .frame(width: 60, height: 60)
            
            // Trend indicator
            HStack(spacing: 4) {
                Image(systemName: trendIcon(skill.trend))
                Text(skill.trend.capitalized)
            }
            .font(.caption2)
            .foregroundColor(trendColor(skill.trend))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }
    
    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return .secondary
        }
    }
}
