import SwiftUI

struct FocusView: View {
    @EnvironmentObject var stackService: StackService
    @EnvironmentObject var uiState: AppUIState
    
    @State private var animateWelcome = false
    @State private var streakCount = 7
    @State private var xpToday = 150
    @State private var dailyGoalProgress: Double = 0.65
    @State private var isBreathing = false
    @State private var messageText = ""
    @State private var activeCourseIndex = 0
    @State private var focusFeedItems: [FocusFeedItemModel] = FocusFeedItemModel.mock
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                premiumBackground
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        greetingSection
                            .padding(.top, 20)
                        
                        courseStackSection
                            .padding(.top, 4)
                        
                        focusFeedSection
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Lyo App Drawer Button (existing behavior)
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        lioOrb
                            .padding(.trailing, 12)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateWelcome = true
                }
                Task {
                    await stackService.fetchStackItems()
                }
            }
        }
    }

    // MARK: - Premium Background
    private var premiumBackground: some View {
        ZStack {
            // Deep base gradient
            LinearGradient(
                colors: [Color(hex: "050810"), Color(hex: "0A1020"), Color(hex: "0D0F18")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Soft aurora top-right
            RadialGradient(
                colors: [Color(hex: "7C3AED").opacity(0.22), Color.clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            
            // Subtle cyan glow bottom-left
            RadialGradient(
                colors: [Color(hex: "0EA5E9").opacity(0.12), Color.clear],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 360
            )
            
            // Fine grain noise overlay for premium texture
            Rectangle()
                .fill(Color.white.opacity(0.012))
                .background(
                    Canvas { context, size in
                        for _ in 0..<120 {
                            let x = CGFloat.random(in: 0..<size.width)
                            let y = CGFloat.random(in: 0..<size.height)
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                                with: .color(Color.white.opacity(Double.random(in: 0.02...0.045)))
                            )
                        }
                    }
                )
        }
    }

    // MARK: - Course Stack Section
    private var courseStackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            TabView(selection: $activeCourseIndex) {
                ForEach(Array(courseStackCards.enumerated()), id: \.element.id) { index, card in
                    FocusCourseCardView(card: card)
                        .padding(.vertical, 4)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 510) // Increased by ~20% (420 -> 510)
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(courseStackCards.indices, id: \.self) { idx in
                    Circle()
                        .fill(idx == activeCourseIndex ? Color.white : Color.white.opacity(0.25))
                        .frame(width: idx == activeCourseIndex ? 14 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeCourseIndex)
                }
            }
            .padding(.top, -6)
        }
    }

    // MARK: - Feed Section
    private var focusFeedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 10) {
                Text("Today in your world")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                Text("See all")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "A9B7FF"))
            }
            .padding(.horizontal, 2)
            
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(feedRenderItems.indices, id: \.self) { index in
                        FocusFeedCardView(item: feedRenderItems[index])
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        
                        if index == 4 {
                            DiscoverStrip()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Derived Data
    private var courseStackCards: [FocusCourseCardModel] {
        let mapped = stackService.items.prefix(6).enumerated().map { offset, item in
            FocusCourseCardModel(
                id: item.id,
                title: item.title.isEmpty ? "Course Session" : item.title,
                subtitle: item.subtitle ?? "Personalized focus",
                durationText: "~32 min",
                lessonCount: 3,
                challengeCount: 1,
                status: item.status,
                accent: FocusCourseCardModel.palette[offset % FocusCourseCardModel.palette.count],
                description: {
                    if let tags = item.tags, !tags.isEmpty {
                        return "Topics: \(tags.joined(separator: ", "))"
                    } else {
                        return "Explore this personalized learning path designed to boost your skills."
                    }
                }(),
                creator: "Lyo AI",
                likes: Int.random(in: 100...5000),
                dislikes: Int.random(in: 0...50)
            )
        }
        if !mapped.isEmpty { return Array(mapped) }
        return FocusCourseCardModel.suggestedDefaults
    }
    
    private var feedRenderItems: [FocusFeedItemModel] {
        // Repeat items to simulate endless scroll
        var items: [FocusFeedItemModel] = []
        let base = focusFeedItems
        let multiplier = 3
        for i in 0..<multiplier {
            items.append(contentsOf: base.map { $0.withIteration(i) })
        }
        return items
    }
    
    // MARK: - Community Feed Section
    private var communityFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community Feed")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Social Post Cards
                    CommunityPostCard(
                        username: "Alex",
                        action: "finished a lesson",
                        topic: "Swift Basics",
                        time: "2h ago"
                    )
                    
                    CommunityPostCard(
                        username: "Maria",
                        action: "earned 500 XP",
                        topic: "Python Mastery",
                        time: "3h ago"
                    )
                    
                    // Suggested Course
                    SuggestedCourseCard(
                        title: "Advanced SwiftUI",
                        lessons: "12 lessons",
                        duration: "6 hours"
                    )
                    
                    CommunityPostCard(
                        username: "James",
                        action: "completed a challenge",
                        topic: "Data Structures",
                        time: "5h ago"
                    )
                    
                    SuggestedCourseCard(
                        title: "Machine Learning",
                        lessons: "20 lessons",
                        duration: "10 hours"
                    )
                }
            }
        }
    }
    
    // MARK: - Greeting Section
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(greeting)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
            
            Text("Hector")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(hex: "A855F7").opacity(0.25), radius: 12, x: 0, y: 4)
            
            Text("You're one lesson away from an 8-day streak.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .padding(.top, 2)
        }
        .opacity(animateWelcome ? 1 : 0)
        .offset(y: animateWelcome ? 0 : 8)
    }
    
    // MARK: - Stats Chips
    private var statsChipsRow: some View {
        HStack(spacing: 12) {
            StatChip(icon: "flame.fill", title: "Streak", value: "\(streakCount) days", color: .orange)
            StatChip(icon: "star.fill", title: "XP Today", value: "\(xpToday)", color: .yellow)
            StatChip(icon: "target", title: "Goal", value: "\(Int(dailyGoalProgress * 100))%", color: .green)
            Spacer()
        }
        .opacity(animateWelcome ? 1 : 0)
        .offset(y: animateWelcome ? 0 : 10)
    }
    
    // MARK: - Hero Card
    private var continueHeroCard: some View {
        Button {
            // Action to continue course
        } label: {
            GlassCard(intensity: .medium, cornerRadius: 24) {
                HStack(spacing: 16) {
                    // Thumbnail / Icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "swift")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Continue: Swift Basics")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Lesson 2 • 12 min left")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Mini Progress
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                            .overlay(
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.blue)
                                        .frame(width: geo.size.width * 0.4)
                                }
                            )
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                .padding(4)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Your Stacks
    private var todaysFocusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stacks")
                .font(.headline)
                .foregroundColor(.white)
            
            if stackService.items.isEmpty {
                // Suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        SuggestionCard(title: "Improve your focus", duration: "8 min", icon: "brain.head.profile")
                        SuggestionCard(title: "Yesterday's recap", duration: "5 min", icon: "clock.arrow.circlepath")
                    }
                }
            } else {
                // Stack Items
                VStack(spacing: 12) {
                    ForEach(stackService.items.prefix(2)) { item in
                        PremiumStackCard(item: item) // Reusing existing card for now, or could simplify
                    }
                }
            }
        }
    }
    
    // MARK: - Daily Challenge
    private var dailyChallengeCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.9)
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DAILY CHALLENGE")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Complete 3 lessons")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    Text("+50 XP Bonus")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: 0.33)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("1/3")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
            }
            .padding(20)
        }
        .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Lio Orb
    private var lioOrb: some View {
        Button {
            uiState.isLioChatPresented = true
        } label: {
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: "A855F7").opacity(0.6), Color(hex: "6366F1").opacity(0.3), Color(hex: "A855F7").opacity(0.6)],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 68, height: 68)
                    .blur(radius: 2)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "7C3AED"), Color(hex: "6366F1")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: Color(hex: "7C3AED").opacity(0.55), radius: 18, x: 0, y: 6)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .scaleEffect(isBreathing ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isBreathing)
            .onAppear { isBreathing = true }
        }
    }
    
    // MARK: - Bottom Input Bar
    private var bottomInputBar: some View {
        Button {
            uiState.isLioChatPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                
                Text("Ask Lio anything...")
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
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
}

// MARK: - Subviews

struct StatChip: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SuggestionCard: View {
    let title: String
    let duration: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                Text(duration)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .lineLimit(2)
            
            HStack {
                Text("Start")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(16)
        .frame(width: 160)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Focus Course Models & Views

struct FocusCourseCardModel: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let durationText: String
    let lessonCount: Int
    let challengeCount: Int
    let status: StackItemStatus?
    let accent: GradientAccent
    
    // New fields for premium interactive card
    let description: String
    let creator: String
    let likes: Int
    let dislikes: Int
    
    struct GradientAccent: Hashable {
        let start: Color
        let end: Color
        let glow: Color
    }
    
    static let palette: [GradientAccent] = [
        GradientAccent(start: Color(hex: "8B5CF6"), end: Color(hex: "6366F1"), glow: Color(hex: "A855F7")),
        GradientAccent(start: Color(hex: "06B6D4"), end: Color(hex: "3B82F6"), glow: Color(hex: "22D3EE")),
        GradientAccent(start: Color(hex: "F59E0B"), end: Color(hex: "F97316"), glow: Color(hex: "FB923C")),
        GradientAccent(start: Color(hex: "10B981"), end: Color(hex: "06B6D4"), glow: Color(hex: "34D399"))
    ]
    
    static var suggestedDefaults: [FocusCourseCardModel] {
        [
            FocusCourseCardModel(
                id: "suggested_swift",
                title: "Tonight's Swift Power Session",
                subtitle: "3 mini-lessons • 1 challenge",
                durationText: "est. 32 min",
                lessonCount: 3,
                challengeCount: 1,
                status: .active,
                accent: palette[0],
                description: "Master the fundamentals of Swift concurrency and actors in this high-intensity power session designed for senior developers.",
                creator: "Dr. Angela Yu",
                likes: 1240,
                dislikes: 12
            ),
            FocusCourseCardModel(
                id: "suggested_ml",
                title: "Build a Tiny ML Classifier",
                subtitle: "4 sprints • 1 demo",
                durationText: "est. 40 min",
                lessonCount: 4,
                challengeCount: 1,
                status: .active,
                accent: palette[1],
                description: "Create your first machine learning model on iOS using CoreML and CreateML. Perfect for beginners entering the AI space.",
                creator: "Paul Hudson",
                likes: 890,
                dislikes: 4
            )
        ]
    }
}

struct FocusCourseCardView: View {
    let card: FocusCourseCardModel
    
    // Animation States
    @State private var isFlipped = false
    @State private var isPressing = false
    @State private var shakeOffset: CGFloat = 0
    @State private var flipTimer: Timer?
    
    var body: some View {
        ZStack {
            // Front Side
            frontSide
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            // Back Side
            backSide
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4) // Slight padding for the 3D effect clearance
        .scaleEffect(isPressing ? 0.96 : 1.0)
        .offset(x: shakeOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isPressing = pressing
        }) {
            triggerShakeAndFlip()
        }
    }
    
    // MARK: - Interaction Logic
    private func triggerShakeAndFlip() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Shake animation
        withAnimation(.linear(duration: 0.05).repeatCount(4, autoreverses: true)) {
            shakeOffset = 6
        }
        
        // Reset shake and Flip after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) {
                shakeOffset = 0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped = true
            }
            startAutoFlipBackTimer()
        }
    }
    
    private func startAutoFlipBackTimer() {
        flipTimer?.invalidate()
        flipTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { _ in
            withAnimation {
                isFlipped = false
            }
        }
    }
    
    // MARK: - Front Side
    private var frontSide: some View {
        ZStack(alignment: .bottomLeading) {
            // Premium Glassmorphic Background
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            card.accent.start.opacity(0.9),
                            card.accent.end.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    ZStack {
                        // Noise Texture
                        Color.white.opacity(0.03)
                        
                        // Glass Glare
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                        .mask(RoundedRectangle(cornerRadius: 32))
                        
                        // Border Gradient
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 8) // Lifted 2D effect
                .overlay(glassOrb, alignment: .topTrailing) // Moved orb to top for better space usage
            
            VStack(alignment: .leading, spacing: 20) {
                // Header Area
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.status == .active ? "IN PROGRESS" : "START NEW")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(card.title)
                            .font(.system(size: 32, weight: .heavy, design: .rounded)) // Larger Title
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .frame(maxWidth: 240, alignment: .leading) // Constrain width to avoid hitting orb
                    }
                    Spacer()
                    
                    // Menu Button
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                Spacer()
                
                // Progress Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("32%") // Mock progress for premium feel
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * 0.32, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.bottom, 8)
                
                // Action Buttons
                HStack(spacing: 16) {
                    pill(text: "Resume", filled: true, icon: "play.fill")
                    pill(text: "Details", filled: false, icon: "list.bullet")
                }
            }
            .padding(28)
        }
    }
    
    // MARK: - Back Side
    private var backSide: some View {
        ZStack(alignment: .topLeading) {
            // Darker Glass Background for Back
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [card.accent.start.opacity(0.5), card.accent.end.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("About this Course")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.4))
                }
                
                // Description
                Text(card.description)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Meta Info
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CREATOR")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        Text(card.creator)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RATING")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsup.fill")
                                    .foregroundColor(.green.opacity(0.8))
                                Text("\(card.likes)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsdown.fill")
                                    .foregroundColor(.red.opacity(0.8))
                                Text("\(card.dislikes)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Flip Back Button
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isFlipped = false
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Back to Card")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [card.accent.start, card.accent.end],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: card.accent.glow.opacity(0.3), radius: 8, y: 4)
                }
            }
            .padding(28)
        }
    }
    
    private var glassOrb: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [card.accent.glow.opacity(0.6), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .offset(x: 30, y: 30)
                .overlay(
                    Image(systemName: "swift") // Dynamic icon could be passed in model
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white.opacity(0.2))
                )
        }
    }
    
    private func pill(text: String, filled: Bool, icon: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold)) // Slightly larger icon
            }
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .padding(.vertical, 16) // Taller buttons
        .frame(maxWidth: .infinity) // Equal width
        .background(
            Group {
                if filled {
                    LinearGradient(
                        colors: [.white, Color(hex: "F0F9FF")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color.white.opacity(0.12)
                }
            }
        )
        .foregroundColor(filled ? card.accent.start : .white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // More modern shape than Capsule
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(filled ? 0.0 : 0.3), lineWidth: 1)
        )
        .shadow(color: filled ? Color.black.opacity(0.15) : Color.clear, radius: 10, x: 0, y: 5)
    }
}

// MARK: - Focus Feed Models & Views

struct FocusFeedItemModel: Identifiable, Hashable {
    let id: String
    let author: String
    let title: String
    let timeAgo: String
    let progress: Double
    let badge: String
    let accent: Color
    let thumbnail: String?
    
    func withIteration(_ iteration: Int) -> FocusFeedItemModel {
        // Slightly tweak id and time label to feel endless
        return FocusFeedItemModel(
            id: "\(id)_\(iteration)",
            author: author,
            title: title,
            timeAgo: iteration == 0 ? timeAgo : "\(Int.random(in: 5...40))m ago",
            progress: progress,
            badge: badge,
            accent: accent,
            thumbnail: thumbnail
        )
    }
    
    static let mock: [FocusFeedItemModel] = [
        FocusFeedItemModel(id: "f1", author: "Jade", title: "Shipped the iOS animations challenge", timeAgo: "12m ago", progress: 0.82, badge: "Animations", accent: Color(hex: "7C3AED"), thumbnail: nil),
        FocusFeedItemModel(id: "f2", author: "Mateo", title: "Completed SwiftUI layout sprint", timeAgo: "28m ago", progress: 0.64, badge: "Layouts", accent: Color(hex: "22D3EE"), thumbnail: nil),
        FocusFeedItemModel(id: "f3", author: "Priya", title: "Unlocked AI tutor quiz streak", timeAgo: "1h ago", progress: 0.93, badge: "Streak", accent: Color(hex: "F59E0B"), thumbnail: nil),
        FocusFeedItemModel(id: "f4", author: "Sam", title: "Shared a Swift Concurrency cheat sheet", timeAgo: "2h ago", progress: 0.45, badge: "Share", accent: Color(hex: "10B981"), thumbnail: nil),
        FocusFeedItemModel(id: "f5", author: "Amina", title: "Published a UIKit > SwiftUI port", timeAgo: "3h ago", progress: 0.71, badge: "Porting", accent: Color(hex: "6366F1"), thumbnail: nil)
    ]
}

struct FocusFeedCardView: View {
    let item: FocusFeedItemModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Avatar with accent ring
                ZStack {
                    Circle()
                        .stroke(item.accent.opacity(0.4), lineWidth: 2)
                        .frame(width: 46, height: 46)
                    Circle()
                        .fill(item.accent.opacity(0.12))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Text(String(item.author.prefix(1)))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(item.accent)
                        )
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.author)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(item.timeAgo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                premiumBadge(text: item.badge, color: item.accent)
            }
            
            Text(item.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .padding(.horizontal, 2)
            
            progressBar
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
        )
    }
    
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(Int(item.progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(height: 6)
                .overlay(
                    Capsule()
                        .fill(item.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(
                            GeometryReader { geo in
                                Capsule()
                                    .fill(item.accent)
                                    .frame(width: geo.size.width * CGFloat(item.progress))
                            }
                        )
                )
        }
    }
    
    private func premiumBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )
            )
            .foregroundColor(color)
    }
}

// MARK: - Discover Strip

struct DiscoverStrip: View {
    private let chips: [(String, String, Color)] = [
        ("person.2.fill", "People", Color(hex: "A855F7")),
        ("sparkles.rectangle.stack", "Content", Color(hex: "22D3EE")),
        ("graduationcap.fill", "Courses", Color(hex: "F59E0B")),
        ("magnifyingglass", "Search", Color(hex: "6366F1"))
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(chips, id: \.0) { chip in
                    HStack(spacing: 8) {
                        Image(systemName: chip.0)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(chip.2)
                        Text(chip.1)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [chip.2.opacity(0.18), chip.2.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(chip.2.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: chip.2.opacity(0.15), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// MARK: - Premium Stack Card
struct PremiumStackCard: View {
    let item: StackItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconForType)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Text(item.type.rawValue.capitalized)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(item.status.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            
            // Tags indicator
            if let tags = item.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .frame(width: 140)
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
    
    private var iconForType: String {
        switch item.type {
        case .course: return "book.fill"
        case .lesson: return "play.circle.fill"
        case .video: return "play.rectangle.fill"
        case .event: return "calendar"
        case .group: return "person.3.fill"
        case .person: return "person.fill"
        case .question: return "questionmark.circle.fill"
        case .session: return "clock.fill"
        case .achievement: return "trophy.fill"
        case .path: return "map.fill"
        }
    }
    
    private var gradientColors: [Color] {
        switch item.type {
        case .course: return [.blue, .purple]
        case .lesson: return [.cyan, .blue]
        case .video: return [.green, .mint]
        case .event: return [.orange, .yellow]
        case .group: return [.pink, .purple]
        case .person: return [.indigo, .purple]
        case .question: return [.yellow, .orange]
        case .session: return [.teal, .cyan]
        case .achievement: return [.yellow, .orange]
        case .path: return [.purple, .pink]
        }
    }
}

// MARK: - Community Feed Cards

struct CommunityPostCard: View {
    let username: String
    let action: String
    let topic: String
    let time: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info
            HStack(spacing: 8) {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(username.prefix(1)))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(username)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            // Action
            Text("\(action)")
                .font(.callout)
                .foregroundColor(.white.opacity(0.8))
            
            // Topic tag
            Text(topic)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.3))
                .clipShape(Capsule())
                .foregroundColor(.white)
        }
        .padding(16)
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SuggestedCourseCard: View {
    let title: String
    let lessons: String
    let duration: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Course icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Text(lessons)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer(minLength: 0)
            
            // Enroll button
            HStack {
                Text("Explore")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.3))
            .clipShape(Capsule())
        }
        .padding(16)
        .frame(width: 180, height: 220)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

