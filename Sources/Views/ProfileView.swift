import SwiftUI
import Combine
import os
// Ensure Views/Gamification is imported if needed, or if it's in the same module it's fine.
// Assuming AllAchievementsView is available in the module.

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSettings = false
    @State private var showEditProfile = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeaderView(
                        user: rootViewModel.currentUser,
                        onEditTapped: { showEditProfile = true }
                    )

                    // Stats Grid
                    ProfileStatsView(
                        level: rootViewModel.userLevel,
                        xp: rootViewModel.userXP,
                        coursesCompleted: viewModel.coursesCompleted,
                        streak: viewModel.currentStreak
                    )

                    // 🔥 NEW: Personalized Recap Section
                    if let memory = viewModel.memory {
                        PersonalizedRecapView(memory: memory)
                    }

                    // Self-Evolution Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Self Evolution")
                            .font(.headline)
                        HStack(spacing: 12) {
                            NavigationLink(destination: InsightsDashboardView()) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: "chart.xyaxis.line")
                                        .font(.title2)
                                        .foregroundColor(.purple)
                                    Text("Insights")
                                        .font(.subheadline.bold())
                                    Text("Evolution & risk")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: GoalsView()) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: "target")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("Goals")
                                        .font(.subheadline.bold())
                                    Text("Track progress")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Active Courses Section
                    if !viewModel.activeStacks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Courses")
                                .font(.headline)
                            
                            ForEach(viewModel.activeStacks) { item in
                                HStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "book.fill")
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.title)
                                            .font(.subheadline.bold())
                                        Text(item.subtitle ?? "Course")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // My Discoveries Section
                    if !viewModel.myDiscoveries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("My Discoveries")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "play.rectangle.fill")
                                    .foregroundColor(.purple)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(viewModel.myDiscoveries) { discovery in
                                    DiscoveryCard(discovery: discovery)
                                }
                            }
                        }
                    }

                    // Achievements Section
                    AchievementsSectionView(achievements: viewModel.recentAchievements)

                    // Activity Section
                    ActivitySectionView(activities: viewModel.recentActivity)

                    // Settings & Actions
                    SettingsActionsView(
                        onSettingsTapped: { showSettings = true },
                        onLogoutTapped: {
                            Task {
                                await rootViewModel.logout()
                            }
                        }
                    )
                }
                .padding()
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(rootViewModel)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(rootViewModel)
            }
            .task {
                await viewModel.loadProfileData()
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    let user: User?
    let onEditTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                if let avatarURL = user?.avatarURL {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                Text(String(user?.name.prefix(1) ?? "U").uppercased())
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(String(user?.name.prefix(1) ?? "U").uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                // Edit button
                Button(action: onEditTapped) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color(.systemBackground)))
                }
            }

            // Name and Email
            VStack(spacing: 4) {
                Text(user?.name ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)

                if let email = user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Profile Stats
struct ProfileStatsView: View {
    let level: Int
    let xp: Int
    let coursesCompleted: Int
    let streak: Int

    var body: some View {
        VStack(spacing: 16) {
            // Progress to next level
            VStack(spacing: 8) {
                HStack {
                    Text("Level \(level)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(xp) / \(nextLevelXP) XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: Double(xp) / Double(nextLevelXP))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(icon: "graduationcap.fill", value: "\(coursesCompleted)", label: "Courses", color: .blue)
                StatBox(icon: "flame.fill", value: "\(streak)", label: "Day Streak", color: .orange)
                StatBox(icon: "star.fill", value: "\(level)", label: "Level", color: .yellow)
                StatBox(icon: "bolt.fill", value: "\(xp)", label: "Total XP", color: .purple)
            }
        }
    }

    private var nextLevelXP: Int {
        (level + 1) * 500 // Simple formula, adjust as needed
    }
}

struct StatBox: View {
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
                .font(.title3)
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

// MARK: - Achievements Section
struct AchievementsSectionView: View {
    let achievements: [Achievement]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)

                Spacer()

                NavigationLink("See All") {
                    AllAchievementsView()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            if achievements.isEmpty {
                Text("No achievements yet. Keep learning!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(achievements) { achievement in
                            AchievementBadge(achievement: achievement)
                        }
                    }
                }
            }
        }
    }
}

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.title)
                .foregroundColor(rarityColor)

            Text(achievement.title)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 100)
        .background(rarityColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Activity Section
struct ActivitySectionView: View {
    let activities: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            if activities.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(activities, id: \.self) { activity in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)

                            Text(activity)
                                .font(.subheadline)

                            Spacer()

                            Text("Today")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - Settings & Actions
struct SettingsActionsView: View {
    let onSettingsTapped: () -> Void
    let onLogoutTapped: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onSettingsTapped) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.blue)

                    Text("Settings")
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .foregroundColor(.primary)

            Button(action: onLogoutTapped) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)

                    Text("Sign Out")
                        .fontWeight(.medium)

                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - Personalized Recap View

struct PersonalizedRecapView: View {
    let memory: LearningMemory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Leo's Learning Recap")
                    .font(.headline)
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
            }
            
            if let summary = memory.lastSessionSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.9))
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
            }
            
            if !memory.struggles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AREAS FOR GROWTH")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach(memory.struggles.prefix(2)) { struggle in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(struggle.topic)
                                .font(.caption.bold())
                            Spacer()
                            Text("\(struggle.frequency) struggles")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            
            if !memory.masteredConcepts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MASTERED CONCEPTS")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(memory.masteredConcepts.prefix(3), id: \.self) { concept in
                                Text(concept)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(colors: [.orange.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}

// MARK: - Profile View Model
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var coursesCompleted = 0
    @Published var currentStreak = 0
    @Published var recentAchievements: [Achievement] = []
    @Published var recentActivity: [String] = []
    @Published var xpSummary: XPSummary?
    @Published var userLevel: UserLevel?
    @Published var gamificationStats: GamificationStats?
    @Published var badges: [UserBadge] = []
    @Published var activeStacks: [StackItem] = [] // Added for Profile Stacks
    @Published var myDiscoveries: [Discovery] = [] // Added for Discoveries
    @Published var myRank: LeaderboardRank?
    @Published var memory: LearningMemory? // NEW
    @Published var isLoading = false
    
    private let repository = LyoRepository.shared
    
    func loadProfileData() async {
        isLoading = true
        
        // Load gamification data from backend
        await loadGamificationData()
        
        // Load achievements
        await loadAchievements()
        
        // Load badges
        await loadBadges()
        
        // Load active stacks
        await loadActiveStacks()
        
        // Load discoveries
        loadDiscoveries()
        
        // Load memory for recap
        await loadMemory()
        
        isLoading = false
    }
    
    private func loadDiscoveries() {
        self.myDiscoveries = DiscoveryService.shared.myDiscoveries
    }
    
    private func loadGamificationData() async {
        do {
            // Get XP summary
            self.xpSummary = try await repository.getXPSummary()
            
            // Get user level
            self.userLevel = try await repository.getUserLevel()
            
            // Get gamification stats
            self.gamificationStats = try await repository.getGamificationStats()
            if let stats = gamificationStats {
                self.coursesCompleted = stats.lessonsCompleted
                self.currentStreak = stats.currentStreak
            }
            
            // Get leaderboard rank
            self.myRank = try await repository.getMyLeaderboardRank(type: "xp")
            
            Log.ui.info("Profile gamification data loaded")
        } catch {
            Log.ui.warning("Failed to load gamification data: \(error.localizedDescription)")
            // Use fallback mock data
            coursesCompleted = 5
            currentStreak = 7
        }
    }
    
    private func loadAchievements() async {
        do {
            let achievements = try await repository.getMyAchievements()
            // Get recent unlocked achievements
            self.recentAchievements = achievements
                .filter { $0.isCompleted }
                .compactMap { $0.achievement }
                .prefix(5)
                .map { $0 }
            
            // Build recent activity from achievements
            self.recentActivity = recentAchievements.map { "Earned '\($0.name)' achievement" }
            
            Log.ui.info("Achievements loaded: \(achievements.count)")
        } catch {
            Log.ui.warning("Failed to load achievements: \(error.localizedDescription)")
            recentActivity = [
                "Completed Python Basics",
                "Earned 'Week Warrior' achievement",
                "Joined 'Math Study Group'"
            ]
        }
    }
    
    private func loadBadges() async {
        do {
            self.badges = try await repository.getMyBadges()
            Log.ui.info("Badges loaded: \(self.badges.count)")
        } catch {
            Log.ui.warning("Failed to load badges: \(error.localizedDescription)")
        }
    }
    
    func equipBadge(_ badge: UserBadge) async {
        do {
            let updatedBadge = try await repository.equipBadge(id: badge.id, equipped: !badge.isEquipped)
            if let index = badges.firstIndex(where: { $0.id == badge.id }) {
                badges[index] = updatedBadge
            }
        } catch {
            Log.ui.error("Failed to equip badge: \(error.localizedDescription)")
        }
    }
    
    private func loadActiveStacks() async {
        do {
            // Fetch stacks from repository
            let items = try await repository.getStackItems()
            self.activeStacks = items.filter { $0.type == .course && $0.status == .active }
            Log.ui.info("Profile active stacks loaded: \(self.activeStacks.count)")
        } catch {
            Log.ui.warning("Failed to load active stacks: \(error.localizedDescription)")
        }
    }
    
    private func loadMemory() async {
        await SmartMemoryService.shared.fetchMemory()
        self.memory = SmartMemoryService.shared.memory
    }
}

struct DiscoveryCard: View {
    let discovery: Discovery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(9/16, contentMode: .fit)
                    .cornerRadius(12)
                
                Image(systemName: "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(discovery.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("\(discovery.likes)")
                        .font(.caption2)
                    
                    Spacer()
                    
                    Image(systemName: "eye.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(discovery.views)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(RootViewModel())
    }
}
