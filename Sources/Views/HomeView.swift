import SwiftUI
import os

extension Notification.Name {
    static let showNotifications = Notification.Name("showNotifications")
    static let navigateToQuiz = Notification.Name("navigateToQuiz")
}

// MARK: - Home View (Dashboard)
struct HomeView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var notificationService = NotificationService.shared

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
                        streak: viewModel.currentStreak
                    )

                    // Daily Challenge
                    if let challenge = viewModel.dailyChallenge {
                        DailyChallengeCard(challenge: challenge)
                    } else {
                        DailyChallengeCard(challenge: nil)
                    }

                    // Continue Learning
                    ContinueLearningSection(courses: viewModel.continueLearning)

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
                        viewModel.showNotifications()
                    } label: {
                        Image(systemName: "bell")
                            .overlay(
                                // Notification badge
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                                    .opacity(notificationService.unreadCount > 0 ? 1 : 0)
                            )
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
                await notificationService.loadUnreadCount()
            }
            .sheet(isPresented: $notificationService.isShowingNotificationCenter) {
                NotificationCenterView()
            }
            .onAppear {
                Task {
                    await notificationService.loadUnreadCount()
                }
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
    let challenge: Challenge?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                Text("Daily Challenge")
                    .font(.headline)

                Spacer()

                Text(progressText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(challenge?.description ?? "Complete 3 lessons today")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: challenge?.progressPercentage ?? 0.66)
                .progressViewStyle(LinearProgressViewStyle(tint: .yellow))

            HStack {
                Text("\(challenge?.xpReward ?? 200) XP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)

                Spacer()

                Text("\(remainingCount) left")
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

    private var progressText: String {
        let current = Int(challenge?.progress ?? 0)
        let total = challenge?.target ?? 3
        return "\(current)/\(total)"
    }

    private var remainingCount: Int {
        let target = Double(challenge?.target ?? 3)
        let progress = challenge?.progress ?? 0
        return Int(max(0, target - progress))
    }
}

// MARK: - Continue Learning Section
struct ContinueLearningSection: View {
    let courses: [Course]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Learning")
                .font(.headline)

            if courses.isEmpty {
                Text("No active courses. Start learning today!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(courses) { course in
                            HomeContinueLearningCard(
                                title: course.title,
                                progress: course.progressPercentage,
                                lesson: course.currentLesson?.title ?? "Ready to start",
                                color: courseColor(for: course)
                            )
                        }
                    }
                }
            }
        }
    }

    private func courseColor(for course: Course) -> Color {
        let colors: [Color] = [.blue, .orange, .green, .purple, .red, .yellow]
        let index = abs(course.title.hashValue) % colors.count
        return colors[index]
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
    @Published var currentStreak = 0
    @Published var isLoading = false

    func refresh() async {
        await loadDashboardData()
    }

    private func loadDashboardData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadDailyChallenge() }
            group.addTask { await self.loadContinueLearning() }
            group.addTask { await self.loadRecommendedContent() }
            group.addTask { await self.loadCurrentStreak() }
            await group.waitForAll()
        }
    }

    private func loadDailyChallenge() async {
        do {
            dailyChallenge = try await LyoRepository.shared.getDailyChallenge()
        } catch {
            Log.ui.error("Failed to load daily challenge: \(error.localizedDescription)")
        }
    }

    private func loadContinueLearning() async {
        do {
            let courses = try await LyoRepository.shared.getActiveCourses()
            continueLearning = Array(courses.prefix(3))
        } catch {
            Log.ui.error("Failed to load continue learning: \(error.localizedDescription)")
        }
    }

    private func loadRecommendedContent() async {
        do {
            let recommendations = try await LyoRepository.shared.getRecommendations()
            recommended = recommendations
        } catch {
            Log.ui.error("Failed to load recommended content: \(error.localizedDescription)")
        }
    }

    private func loadCurrentStreak() async {
        do {
            let stats = try await LyoRepository.shared.getGamificationStats()
            currentStreak = stats.currentStreak
        } catch {
            Log.ui.error("Failed to load streak: \(error.localizedDescription)")
        }
    }

    func showNotifications() {
        NotificationCenter.default.post(name: .showNotifications, object: nil)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(RootViewModel())
    }
}
