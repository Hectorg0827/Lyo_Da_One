import SwiftUI

struct ProfileHomeView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @StateObject private var challengesViewModel = ChallengesViewModel()
    @State private var showingSettings = false
    @State private var showingSignOutAlert = false
    
    private var user: User? {
        rootViewModel.currentUser
    }
    
    var body: some View {
        ZStack {
            Color("LyoBackground")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with avatar and stats
                    profileHeader
                    
                    // Quick Stats Cards
                    statsGrid
                    
                    // Achievements Section
                    achievementsSection
                    
                    // Saved Courses Section
                    savedCoursesSection
                    
                    // Settings Section
                    settingsSection
                    
                    // Sign Out Button
                    signOutButton
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
        .task {
            await challengesViewModel.loadChallenges()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await rootViewModel.logout()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color("Primary"), Color("Secondary")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Text(user?.name.prefix(1).uppercased() ?? "U")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Name
            Text(user?.name ?? "User")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            // Email
            Text(user?.email ?? "")
                .font(.system(size: 15))
                .foregroundColor(Color("LyoTextSecondary"))
            
            // Level Badge
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color("LyoAccent"))
                
                Text("Level \(user?.level ?? 1)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color("LyoSurface"))
            )
        }
        .padding(.top, 20)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                icon: "star.fill",
                value: "\(user?.xp ?? 0)",
                label: "Total XP",
                color: Color("LyoAccent")
            )
            
            StatCard(
                icon: "flame.fill",
                value: "\(challengesViewModel.streakData?.currentStreak ?? 0)",
                label: "Day Streak",
                color: .orange
            )
            
            StatCard(
                icon: "trophy.fill",
                value: "\(challengesViewModel.achievements.filter { $0.isUnlocked }.count)",
                label: "Achievements",
                color: Color("Primary")
            )
            
            StatCard(
                icon: "book.fill",
                value: "12",
                label: "Courses",
                color: Color("Secondary")
            )
        }
    }
    
    // MARK: - Achievements Section
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    // Navigate to full achievements view
                } label: {
                    Text("See All")
                        .font(.system(size: 14))
                        .foregroundColor(Color("LyoAccent"))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(challengesViewModel.achievements.prefix(5)) { achievement in
                        AchievementBadgeView(achievement: achievement)
                    }
                }
            }
        }
    }
    
    // MARK: - Saved Courses Section
    
    private var savedCoursesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Saved Courses")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    // Navigate to saved courses
                } label: {
                    Text("See All")
                        .font(.system(size: 14))
                        .foregroundColor(Color("LyoAccent"))
                }
            }
            
            VStack(spacing: 12) {
                SavedCourseRow(
                    title: "Advanced Swift Programming",
                    progress: 0.65,
                    lessons: "13/20 lessons"
                )
                
                SavedCourseRow(
                    title: "iOS App Architecture",
                    progress: 0.30,
                    lessons: "6/20 lessons"
                )
                
                SavedCourseRow(
                    title: "SwiftUI Masterclass",
                    progress: 0.85,
                    lessons: "17/20 lessons"
                )
            }
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "bell.fill",
                title: "Notifications",
                iconColor: .orange
            )
            
            Divider()
                .background(Color("LyoSurface"))
            
            SettingsRow(
                icon: "lock.fill",
                title: "Privacy",
                iconColor: Color("Primary")
            )
            
            Divider()
                .background(Color("LyoSurface"))
            
            SettingsRow(
                icon: "gear",
                title: "Account Settings",
                iconColor: Color("Secondary")
            )
            
            Divider()
                .background(Color("LyoSurface"))
            
            SettingsRow(
                icon: "questionmark.circle.fill",
                title: "Help & Support",
                iconColor: .blue
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoSurface"))
        )
    }
    
    // MARK: - Sign Out Button
    
    private var signOutButton: some View {
        Button {
            showingSignOutAlert = true
        } label: {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .font(.system(size: 18))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("LyoSurface"))
            )
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color("LyoTextSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoSurface"))
        )
    }
}

// MARK: - Saved Course Row Component

struct SavedCourseRow: View {
    let title: String
    let progress: Double
    let lessons: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(lessons)
                        .font(.system(size: 13))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color("Primary"))
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color("LyoBackground"))
                        .frame(height: 6)
                    
                    Rectangle()
                        .fill(Color("Primary"))
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("LyoSurface"))
        )
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    
    var body: some View {
        Button {
            // Handle settings navigation
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color("LyoTextSecondary"))
            }
            .padding()
        }
    }
}
