import SwiftUI

// MARK: - Premium Home View
struct PremiumHomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var uiState: AppUIState
    @State private var showLioChat = false
    @State private var animateWelcome = false
    @State private var streakCount = 7
    @State private var xpToday = 150
    @State private var dailyGoalProgress: Double = 0.65
    
    var body: some View {
        ZStack {
            // Animated gradient background
            PremiumBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Welcome Header
                    welcomeHeader
                        .padding(.top, 20)
                    
                    // Stats Row
                    statsRow
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Continue Learning
                    continueLearningSection
                    
                    // Daily Challenge
                    dailyChallengeCard
                    
                    // Bottom spacing for tab bar
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            
            // Floating Lio button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingLioButton {
                        showLioChat = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showLioChat) {
            LioChatSheet(isPresented: $showLioChat)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateWelcome = true
            }
        }
    }
    
    // MARK: - Welcome Header
    var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(authService.currentUserName.isEmpty ? "Learner" : (authService.currentUserName.components(separatedBy: " ").first ?? "Learner"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Profile Image / Avatar
            Button(action: {
                // Navigate to profile
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    let name = authService.currentUserName.isEmpty ? "U" : authService.currentUserName
                    Text(String(name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var profileAvatar: some View {
        Button {
            uiState.currentTab = .profile
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(userInitials)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .purple.opacity(0.5), radius: 10)
        }
        .scaleEffect(animateWelcome ? 1 : 0.5)
        .opacity(animateWelcome ? 1 : 0)
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            PremiumHomeStatCard(
                icon: "flame.fill",
                value: "\(streakCount)",
                label: "Day Streak",
                color: .orange
            )
            
            PremiumHomeStatCard(
                icon: "star.fill",
                value: "\(xpToday)",
                label: "XP Today",
                color: .yellow
            )
            
            PremiumHomeStatCard(
                icon: "target",
                value: "\(Int(dailyGoalProgress * 100))%",
                label: "Daily Goal",
                color: .green
            )
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    icon: "book.fill",
                    title: "Continue",
                    subtitle: "Resume learning",
                    gradient: [.blue, .cyan]
                ) {
                    uiState.currentTab = .discover
                }
                
                QuickActionCard(
                    icon: "sparkles",
                    title: "Ask Lio",
                    subtitle: "AI tutor",
                    gradient: [.purple, .pink]
                ) {
                    showLioChat = true
                }
                
                QuickActionCard(
                    icon: "person.2.fill",
                    title: "Study Group",
                    subtitle: "Join others",
                    gradient: [.green, .mint]
                ) {
                    uiState.currentTab = .collab
                }
                
                QuickActionCard(
                    icon: "trophy.fill",
                    title: "Challenges",
                    subtitle: "Earn rewards",
                    gradient: [.orange, .yellow]
                ) {
                    uiState.currentTab = .profile
                }
            }
        }
    }
    
    // MARK: - Continue Learning Section
    private var continueLearningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Continue Learning")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    uiState.currentTab = .discover
                }
                .font(.subheadline)
                .foregroundColor(.cyan)
            }
            
            // Course Card
            ContinueLearningCard(
                title: "Advanced Swift Patterns",
                progress: 0.65,
                timeLeft: "15 min left",
                imageName: "swift"
            ) {
                uiState.currentTab = .discover
            }
        }
    }
    
    // MARK: - Daily Challenge
    private var dailyChallengeCard: some View {
        GlassCard(intensity: .medium) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Challenge")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Complete 3 lessons to earn 50 bonus XP")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    ProgressView(value: 0.33)
                        .tint(.orange)
                        .padding(.top, 4)
                }
                
                Spacer()
                
                Text("1/3")
                    .font(.title2.bold())
                    .foregroundColor(.orange)
            }
            .padding(4)
        }
    }
    
    // MARK: - Helpers
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    private var userName: String {
        authService.currentUserName.isEmpty ? "Learner" : (authService.currentUserName.components(separatedBy: " ").first ?? "Learner")
    }
    
    private var userInitials: String {
        let name = authService.currentUserName.isEmpty ? "U" : authService.currentUserName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Stat Card
struct PremiumHomeStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        GlassCard(intensity: .light) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Continue Learning Card
struct ContinueLearningCard: View {
    let title: String
    let progress: Double
    let timeLeft: String
    let imageName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Course thumbnail
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "swift")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(timeLeft)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.cyan)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Floating Lio Button
struct FloatingLioButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "message.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }
}

#Preview {
    PremiumHomeView()
        .environmentObject(AuthService.shared)
        .environmentObject(AppUIState())
        .preferredColorScheme(.dark)
}
