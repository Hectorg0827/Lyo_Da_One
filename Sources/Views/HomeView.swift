import SwiftUI

// MARK: - Home View (Dashboard)
struct HomeView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    WelcomeHeaderView(userName: rootViewModel.userDisplayName)

                    // Quick Stats
                    QuickStatsView(
                        level: rootViewModel.userLevel,
                        xp: rootViewModel.userXP,
                        streak: 0 // TODO: Get from gamification
                    )

                    // Daily Challenge
                    DailyChallengeCard()

                    // Continue Learning
                    ContinueLearningSection()

                    // Recommended Content
                    RecommendedContentSection()

                    // Quick Actions
                    QuickActionsSection()
                }
                .padding()
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Show notifications
                    } label: {
                        Image(systemName: "bell")
                            .overlay(
                                // Notification badge
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                                    .opacity(viewModel.hasNotifications ? 1 : 0)
                            )
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Welcome Header
struct WelcomeHeaderView: View {
    let userName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(userName)
                    .font(.title)
                    .fontWeight(.bold)
            }

            Spacer()

            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(userName.prefix(1)).uppercased())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
        }
    }
}

// MARK: - Quick Stats
struct QuickStatsView: View {
    let level: Int
    let xp: Int
    let streak: Int

    var body: some View {
        HStack(spacing: 16) {
            HomeStatCard(icon: "star.fill", value: "\(level)", label: "Level", color: .blue)
            HomeStatCard(icon: "bolt.fill", value: "\(xp)", label: "XP", color: .orange)
            HomeStatCard(icon: "flame.fill", value: "\(streak)", label: "Streak", color: .red)
        }
    }
}

struct HomeStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Daily Challenge Card
struct DailyChallengeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                Text("Daily Challenge")
                    .font(.headline)

                Spacer()

                Text("2/3")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Complete 3 lessons today")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: 0.66)
                .progressViewStyle(LinearProgressViewStyle(tint: .yellow))

            HStack {
                Text("200 XP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)

                Spacer()

                Text("1 lesson left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - Continue Learning Section
struct ContinueLearningSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Learning")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    HomeContinueLearningCard(
                        title: "Python Basics",
                        progress: 0.75,
                        lesson: "Variables & Types",
                        color: .blue
                    )

                    HomeContinueLearningCard(
                        title: "Web Development",
                        progress: 0.30,
                        lesson: "HTML Structure",
                        color: .orange
                    )

                    HomeContinueLearningCard(
                        title: "Data Science",
                        progress: 0.10,
                        lesson: "Intro to Pandas",
                        color: .green
                    )
                }
            }
        }
    }
}

struct HomeContinueLearningCard: View {
    let title: String
    let progress: Double
    let lesson: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(color)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text(title)
                .font(.headline)

            Text(lesson)
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
        .padding()
        .frame(width: 200)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Recommended Content Section
struct RecommendedContentSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended for You")
                .font(.headline)

            VStack(spacing: 12) {
                RecommendedCard(
                    icon: "brain.head.profile",
                    title: "Advanced Python Quiz",
                    subtitle: "Test your knowledge",
                    color: .blue,
                    destination: QuizView()
                )

                RecommendedCard(
                    icon: "waveform",
                    title: "Listen & Learn",
                    subtitle: "Try text-to-speech",
                    color: .purple,
                    destination: TTSView()
                )

                RecommendedCard(
                    icon: "map",
                    title: "Find Study Groups",
                    subtitle: "Connect with learners nearby",
                    color: .green,
                    destination: CommunityView()
                )
            }
        }
    }
}

struct RecommendedCard<Destination: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(icon: "brain", title: "Take Quiz", color: .blue)
                QuickActionButton(icon: "waveform", title: "Listen", color: .purple)
                QuickActionButton(icon: "map", title: "Find Group", color: .green)
                QuickActionButton(icon: "message", title: "Chat", color: .orange)
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Home View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var hasNotifications = false
    @Published var dailyChallenge: Challenge?
    @Published var continueLearning: [Course] = []
    @Published var recommended: [Any] = []

    func refresh() async {
        // TODO: Load fresh data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(RootViewModel())
    }
}
