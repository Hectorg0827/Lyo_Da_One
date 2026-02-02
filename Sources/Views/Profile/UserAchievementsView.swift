import SwiftUI

struct UserAchievementsView: View {
    @StateObject private var viewModel = UserAchievementsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView("Loading achievements...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.achievements.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "trophy")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)

                            Text("No Achievements Yet")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Keep learning to unlock your first achievement!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(viewModel.achievements) { userAchievement in
                            UserAchievementDetailCard(userAchievement: userAchievement)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("All Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadAllAchievements()
            }
        }
    }
}

struct UserAchievementDetailCard: View {
    let userAchievement: UserAchievement

    var body: some View {
        HStack(spacing: 16) {
            // Achievement Icon
            ZStack {
                Circle()
                    .fill(rarityColor.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: userAchievement.achievement?.icon ?? "star")
                    .font(.title)
                    .foregroundColor(rarityColor)
            }

            // Achievement Info
            VStack(alignment: .leading, spacing: 4) {
                Text(userAchievement.achievement?.title ?? "Unknown Achievement")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(userAchievement.achievement?.description ?? "No description")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    if userAchievement.isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        if let completedAt = userAchievement.completedAt {
                            Text(completedAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label("In Progress", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)

                        if let progress = userAchievement.progress,
                           let target = userAchievement.achievement?.target {
                            Text("\\(progress)/\\(target)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Progress indicator for incomplete achievements
            if !userAchievement.isCompleted,
               let progress = userAchievement.progress,
               let target = userAchievement.achievement?.target,
               target > 0 {
                VStack {
                    Text("\\(Int((Double(progress) / Double(target)) * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)

                    CircularProgressView(
                        progress: Double(progress) / Double(target),
                        lineWidth: 4
                    )
                    .frame(width: 40, height: 40)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .opacity(userAchievement.isCompleted ? 1.0 : 0.7)
    }

    private var rarityColor: Color {
        // Default color since Achievement model doesn't have rarity
        return userAchievement.isCompleted ? .blue : .secondary
    }
}

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
        }
    }
}

@MainActor
class UserAchievementsViewModel: ObservableObject {
    @Published var achievements: [UserAchievement] = []
    @Published var isLoading = false

    private let repository = LyoRepository.shared

    func loadAllAchievements() async {
        isLoading = true

        do {
            achievements = try await repository.getMyAchievements()
            print("✅ Loaded \\(achievements.count) achievements")
        } catch {
            print("❌ Failed to load achievements: \\(error.localizedDescription)")
        }

        isLoading = false
    }
}

struct UserAchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        UserAchievementsView()
    }
}