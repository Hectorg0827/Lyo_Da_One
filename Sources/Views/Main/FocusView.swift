import SwiftUI
import os

struct FocusView: View {
    @EnvironmentObject var uiStackStore: UIStackStore
    @EnvironmentObject var uiState: AppUIState
    @StateObject private var socialService = CourseSocialService.shared
    
    @StateObject private var feedViewModel = FeedViewModel()
    @State private var animateWelcome = false
    @State private var activeCourseIndex = 0
    @State private var isShowingAllFeed = false

    /// User data from session manager
    private var currentUser: User? { UserSessionManager.shared.currentUser }
    
    var body: some View {
        NavigationStack {
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
                .refreshable {
                    await feedViewModel.loadFeed(refresh: true)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateWelcome = true
                }
                Task {
                    await feedViewModel.loadFeed(refresh: true)
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
            if courseStackCards.isEmpty {
                // Empty state — prompt user to create their first course
                EmptyStateView(
                    iconName: "book.closed.fill",
                    title: "No Courses Yet",
                    message: "You haven't generated or saved any learning paths. Ask Lio AI to create your first course!",
                    actionTitle: "Start with Lio"
                ) {
                    uiState.isLioChatPresented = true
                }
                .padding(.vertical, 60)
            } else {
                TabView(selection: $activeCourseIndex) {
                    ForEach(Array(courseStackCards.enumerated()), id: \.element.id) { index, card in
                        FocusCourseCardView(card: card, socialService: socialService) {
                            // Resume: open classroom for this course
                            NotificationCenter.default.post(
                                name: .openClassroom,
                                object: nil,
                                userInfo: [
                                    "courseId": card.courseId ?? card.id,
                                    "courseTitle": card.title
                                ]
                            )
                        }
                        .padding(.vertical, 4)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 510)
                
                // Page indicators
                if courseStackCards.count > 1 {
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
                
                Button {
                    isShowingAllFeed = true
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "A9B7FF"))
                }
            }
            .padding(.horizontal, 2)
            
            if feedViewModel.isLoading && feedViewModel.posts.isEmpty {
                // Loading skeleton
                ForEach(0..<3, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.04), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            } else {
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
    }

    // MARK: - Derived Data
    private var courseStackCards: [FocusCourseCardModel] {
        let courseItems = uiStackStore.items(ofType: .course)
        guard !courseItems.isEmpty else { return [] }
        
        return courseItems.prefix(6).enumerated().map { offset, item in
            let courseId = item.courseId ?? item.id
            let likes = socialService.getLikeCount(courseId: courseId)
            let rating = socialService.getAverageRating(courseId: courseId)
            let progress = item.progress ?? 0
            let lessons = item.lessonCount ?? 0
            _ = item.completedLessons ?? 0
            let estMinutes = max(lessons * 8, 10) // ~8 min per lesson estimate
            
            return FocusCourseCardModel(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle ?? "Personalized focus",
                durationText: "est. \(estMinutes) min",
                lessonCount: lessons,
                challengeCount: max(lessons / 3, 1),
                progress: progress,
                status: progress >= 1.0 ? .completed : (progress > 0 ? .active : nil),
                accent: FocusCourseCardModel.palette[offset % FocusCourseCardModel.palette.count],
                description: "Explore this personalized learning path designed to boost your skills.",
                creator: "Lyo AI",
                likes: likes,
                dislikes: 0,
                courseId: courseId,
                rating: rating
            )
        }
    }
    
    private var feedRenderItems: [FocusFeedItemModel] {
        if feedViewModel.posts.isEmpty {
            return []
        }
        
        return feedViewModel.posts.enumerated().map { index, post in
            FocusFeedItemModel(
                id: post.id,
                author: post.author.name,
                title: post.content,
                timeAgo: post.createdAt.timeAgoDisplay(),
                progress: nil,
                badge: (post.attachments ?? []).isEmpty ? "Post" : "Media",
                accent: FocusCourseCardModel.palette[index % FocusCourseCardModel.palette.count].start,
                thumbnail: post.attachments?.first
            )
        }
    }
    
    // MARK: - Greeting Section
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(greeting)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
            
            Text(currentUser?.firstName ?? currentUser?.name ?? "Learner")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(hex: "A855F7").opacity(0.25), radius: 12, x: 0, y: 4)
            
            Text(streakMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .padding(.top, 2)
            
            #if DEBUG
            // Dev-only demo button
            Button(action: {
                if let url = URL(string: "lyoapp://demo") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "flask.fill")
                    Text("Launch Spanish 101 Demo")
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(8)
                .background(Color.purple.opacity(0.4))
                .cornerRadius(8)
            }
            #endif
        }
        .opacity(animateWelcome ? 1 : 0)
        .offset(y: animateWelcome ? 0 : 8)
    }
    
    /// Dynamic streak motivation message
    private var streakMessage: String {
        let streak = currentUser?.streak ?? 0
        switch streak {
        case 0:
            return "Start your streak today! 🔥"
        case 1:
            return "1 day streak — keep it going!"
        case 2...6:
            return "\(streak)-day streak! You're building momentum."
        case 7...29:
            return "\(streak)-day streak 🔥 You're on fire!"
        default:
            return "\(streak)-day streak 🌟 Unstoppable!"
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

// MARK: - Focus Course Models & Views

struct FocusCourseCardModel: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let durationText: String
    let lessonCount: Int
    let challengeCount: Int
    let progress: Double
    let status: StackItemStatus?
    let accent: GradientAccent
    
    // New fields for premium interactive card
    let description: String
    let creator: String
    let likes: Int
    let dislikes: Int
    let courseId: String?
    let rating: Double
    
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
}

struct FocusCourseCardView: View {
    let card: FocusCourseCardModel
    @ObservedObject var socialService: CourseSocialService
    var onResume: (() -> Void)? = nil
    
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
                // 🔥 SHARE BUTTON: Overlay for course sharing
                .overlay(alignment: .topLeading) {
                    Button(action: {
                        // Get the root view controller for presenting the share sheet
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            CourseShareService.shared.shareCourse(
                                courseId: card.courseId ?? card.id,
                                title: card.title,
                                description: card.description,
                                from: rootVC
                            )
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(16)
                }
            
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
                        Text("\(Int(card.progress * 100))%")
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
                                .frame(width: geo.size.width * CGFloat(card.progress), height: 6)
                                .animation(.easeInOut(duration: 0.5), value: card.progress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.bottom, 8)
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button {
                        HapticManager.shared.medium()
                        onResume?()
                    } label: {
                        pill(text: "Resume", filled: true, icon: "play.fill")
                    }
                    
                    Button {
                        HapticManager.shared.light()
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isFlipped = true
                        }
                        startAutoFlipBackTimer()
                    } label: {
                        pill(text: "Details", filled: false, icon: "list.bullet")
                    }
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
                    
                    // 🔥 INTERACTIVE LIKE BUTTON
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LIKES")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        Button(action: {
                            let courseId = card.courseId ?? card.id
                            Task {
                                do {
                                    try await socialService.toggleLike(courseId: courseId)
                                    HapticManager.shared.light()
                                } catch {
                                    Log.ui.warning("Failed to toggle like: \(error)")
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                let courseId = card.courseId ?? card.id
                                let isLiked = socialService.hasLiked(courseId: courseId)
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(isLiked ? .red : .white.opacity(0.8))
                                Text("\(socialService.getLikeCount(courseId: courseId))")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // 🔥 INTERACTIVE STAR RATING
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR RATING")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { starIndex in
                                Button(action: {
                                    let courseId = card.courseId ?? card.id
                                    Task {
                                        do {
                                            try await socialService.rateCourse(courseId: courseId, rating: starIndex)
                                            HapticManager.shared.light()
                                        } catch {
                                            Log.ui.warning("Failed to rate course: \(error)")
                                        }
                                    }
                                }) {
                                    let courseId = card.courseId ?? card.id
                                    let userRating = socialService.getUserRating(courseId: courseId) ?? 0
                                    Image(systemName: starIndex <= userRating ? "star.fill" : "star")
                                        .foregroundColor(starIndex <= userRating ? .yellow : .white.opacity(0.4))
                                        .font(.system(size: 20))
                                }
                            }
                        }
                        
                        // Show average rating
                        if card.rating > 0 {
                            Text(String(format: "%.1f average from community", card.rating))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
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
    let progress: Double? // Made optional
    let badge: String
    let accent: Color
    let thumbnail: String?
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
            
            if let _ = item.progress {
                progressBar
            }
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
                Text("\(Int((item.progress ?? 0) * 100))%")
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
                                    .frame(width: geo.size.width * CGFloat(item.progress ?? 0))
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

