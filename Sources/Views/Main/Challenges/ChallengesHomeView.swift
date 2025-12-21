import SwiftUI

struct ChallengesHomeView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject var rootViewModel: RootViewModel
    
    var body: some View {
        ZStack {
            Color("LyoBackground")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Streak Section
                    streakSection
                    
                    // Tab Selector
                    tabSelector
                    
                    // Tab Content
                    tabContent
                }
                .padding(.top)
            }
            .refreshable {
                await viewModel.loadChallenges()
            }
        }
        .task {
            await viewModel.loadChallenges()
            await viewModel.loadGamificationData()
        }
    }
    
    private var streakSection: some View {
        Group {
            if let streakData = viewModel.streakData {
                StreakCalendarView(streakData: streakData)
                    .padding(.horizontal)
            }
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ChallengesViewModel.ChallengeTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal)
    }
    
    private func tabButton(for tab: ChallengesViewModel.ChallengeTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                viewModel.selectedTab = tab
            }
        } label: {
            VStack(spacing: 8) {
                Text(tab.rawValue)
                    .font(.system(size: 15, weight: viewModel.selectedTab == tab ? .bold : .medium))
                    .foregroundColor(viewModel.selectedTab == tab ? .white : Color("LyoTextSecondary"))
                
                Rectangle()
                    .fill(viewModel.selectedTab == tab ? Color("LyoAccent") : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var tabContent: some View {
        Group {
            switch viewModel.selectedTab {
            case .daily:
                dailyTabContent
            case .leaderboard:
                leaderboardTabContent
            case .achievements:
                achievementsTabContent
            case .stats:
                statsTabContent
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    // MARK: - Daily Tab
    private var dailyTabContent: some View {
        VStack(spacing: 16) {
            // Daily Challenges Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Challenges")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Complete challenges to earn XP")
                        .font(.system(size: 14))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
                Spacer()
            }
            
            // Daily Challenges Grid
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.dailyChallenges) { challenge in
                    ChallengeCardView(challenge: challenge) {
                        viewModel.startChallenge(challenge)
                    }
                }
            }
            
            // Weekly Challenge
            if let weeklyChallenge = viewModel.weeklyChallenge {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                        Text("Weekly Challenge")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                        Text("Ends in 5 days")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                    .foregroundColor(.white)
                    
                    ChallengeCardView(challenge: weeklyChallenge) {
                        viewModel.startChallenge(weeklyChallenge)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Stats Tab
    private var statsTabContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Stats")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Track your learning progress")
                        .font(.system(size: 14))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
                Spacer()
            }
            
            // XP Summary Card
            if let xpSummary = viewModel.xpSummary {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("Total XP: \(xpSummary.totalXP)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    ProgressView(value: xpSummary.xpProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color("LyoAccent")))
                    
                    HStack {
                        Text("Level \(xpSummary.currentLevel)")
                            .font(.system(size: 14))
                            .foregroundColor(Color("LyoTextSecondary"))
                        Spacer()
                        Text("\(xpSummary.xpToNextLevel) XP to next level")
                            .font(.system(size: 14))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color("LyoCardBackground"))
                )
            }
            
            // Stats Grid
            if let stats = viewModel.gamificationStats {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCardView(icon: "graduationcap.fill", value: "\(stats.lessonsCompleted)", label: "Lessons", color: .blue)
                    StatCardView(icon: "questionmark.circle.fill", value: "\(stats.quizzesTaken)", label: "Quizzes", color: .purple)
                    StatCardView(icon: "flame.fill", value: "\(stats.currentStreak)", label: "Streak", color: .orange)
                    StatCardView(icon: "trophy.fill", value: "\(stats.achievementsUnlocked)", label: "Achievements", color: .yellow)
                }
            }
            
            // Badges Section
            if !viewModel.myBadges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Badges")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.myBadges) { badge in
                                BadgeView(badge: badge)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Leaderboard Tab
    private var leaderboardTabContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Leaderboard")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("See how you rank against others")
                        .font(.system(size: 14))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
                Spacer()
                
                // Filter button (optional)
                Button {
                    // Show filters
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(Color("LyoAccent"))
                }
            }
            
            // Leaderboard List
            VStack(spacing: 12) {
                ForEach(viewModel.leaderboard) { entry in
                    LeaderboardRowView(
                        entry: entry,
                        isCurrentUser: entry.userId == (rootViewModel.currentUser.map { String($0.id) } ?? "")
                    )
                }
            }
        }
    }
    
    // MARK: - Achievements Tab
    private var achievementsTabContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievements")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    let unlockedCount = viewModel.achievements.filter { $0.isUnlocked }.count
                    Text("\(unlockedCount)/\(viewModel.achievements.count) Unlocked")
                        .font(.system(size: 14))
                        .foregroundColor(Color("LyoAccent"))
                }
                Spacer()
            }
            
            // Achievements Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.achievements) { achievement in
                    AchievementBadgeView(achievement: achievement)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color("LyoTextSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("LyoCardBackground"))
        )
    }
}

struct BadgeView: View {
    let badge: UserBadge
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(rarityGradient)
                    .frame(width: 60, height: 60)
                
                Image(systemName: badge.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            Text(badge.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 80)
    }
    
    private var rarityGradient: LinearGradient {
        switch badge.rarity {
        case .legendary:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .epic:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rare:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .uncommon:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .common:
            return LinearGradient(colors: [.gray, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
