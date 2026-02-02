import SwiftUI

struct AllAchievementsView: View {
    @StateObject private var viewModel = AllAchievementsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Stats
                HStack(spacing: 40) {
                    VStack {
                        Text("\(viewModel.unlockedCount)")
                            .font(.title2.bold())
                        Text("Unlocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(viewModel.totalCount)")
                            .font(.title2.bold())
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Achievements Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.achievements) { achievement in
                        AchievementDetailCard(achievement: achievement)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("All Achievements")
        .task {
            await viewModel.loadAchievements()
        }
    }
}

struct AchievementDetailCard: View {
    let achievement: Achievement
    
    var rarityColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rarityColor.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(achievement.isUnlocked ? rarityColor : .gray)
            }
            .grayscale(achievement.isUnlocked ? 0 : 1.0)
            
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                
                Text(achievement.description)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if !achievement.isUnlocked {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("Locked")
                        .font(.caption2.bold())
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            } else {
                 Text("Unlocked")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.isUnlocked ? rarityColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

@MainActor
class AllAchievementsViewModel: ObservableObject {
    @Published var achievements: [Achievement] = []
    
    var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }
    
    var totalCount: Int {
        achievements.count
    }
    
    func loadAchievements() async {
        do {
            // In a real app, we might toggle between 'my achievements' and 'all system achievements'
            // For now, let's assume getAchievements returns all available achievements with their unlock status populated
            // If getMyAchievements only returns unlocked ones, we might need a different endpoint or merge logic.
            // Let's assume for now we want to show what the user has unlocked vs locked.
            
            // Checking LyoRepository for a method to get ALL achievements
            // Based on previous audit, 'getAchievements' exists.
            
            let allAchievements = try await LyoRepository.shared.getAchievements()
            self.achievements = allAchievements
        } catch {
            print("❌ Failed to load all achievements: \(error.localizedDescription)")
            self.achievements = [] 
        }
    }
}
