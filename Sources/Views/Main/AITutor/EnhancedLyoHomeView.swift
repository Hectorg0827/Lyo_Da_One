import SwiftUI
import os

/// Enhanced Lyo Home View with premium animations and Netflix-style discover rail
struct EnhancedLyoHomeView: View {
    @StateObject private var viewModel = LyoAIViewModel()
    @EnvironmentObject var rootViewModel: RootViewModel
    
    // Services
    @StateObject private var smartMemory = SmartMemoryService.shared
    @StateObject private var courseGen = CourseGenerationService.shared
    
    // UI State
    @State private var isHeaderDrawerOpen = false
    @State private var isAvatarFloating = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showBottomNav = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var drawerAutoHideTimer: Timer?
    // Session creation state
    @State private var isCreatingSession = false
    
    // Classroom navigation
    @State private var classroomSession: ClassroomSession?
    
    // Wrapper for using item-based fullScreenCover with a String id
    struct ClassroomSession: Identifiable, Equatable {
        let id: String
    }
    
    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    private var userFirstName: String {
        if let name = rootViewModel.currentUser?.name {
            return name.components(separatedBy: " ").first ?? name
        }
        return "User"
    }
    
    var body: some View {
        ZStack {
            // Mesh gradient background
            DesignTokens.Colors.meshGradient
                .ignoresSafeArea()
            
            // Main content
            ScrollView {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
                .frame(height: 0)
                
                VStack(spacing: 0) {
                    // Chat Canvas (top 65%)
                    chatCanvasSection
                        .frame(minHeight: UIScreen.main.bounds.height * 0.65)
                    
                    // Discover Rail (bottom 35%)
                    discoverRailSection
                        .padding(.top, DesignTokens.Spacing.xl)
                    
                    // Additional vertical sections
                    verticalFeedSections
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                handleScroll(offset: value)
            }
            
            // Fixed header with hidden drawer
            VStack(spacing: 0) {
                enhancedHeader
                
                Spacer()
            }
            .zIndex(100)
            
            // Floating avatar (when detached)
            if isAvatarFloating {
                floatingAvatarBubble
            }
            
            // Bottom navigation (auto-hiding)
            VStack {
                Spacer()
                
                if showBottomNav {
                    bottomNavigation
                        .transition(.move(edge: .bottom))
                }
            }
            .zIndex(99)
            
            // Loading overlay - always visible during session creation
            if isCreatingSession {
                loadingOverlay
                    .zIndex(150)
            }
        }
        // Present ClassroomView as fullScreenCover when classroomSession is set
        .fullScreenCover(item: $classroomSession) { session in
            ClassroomView(sessionId: session.id)
                .zIndex(200)
        }
        .onAppear {
            viewModel.loadInitialSuggestions()
            Task {
                await viewModel.loadCourseCards()
            }
        }
    }
    
    // MARK: - Chat Canvas Section
    
    private var chatCanvasSection: some View {
        VStack(spacing: 20) {
            // Hero greeting (when no messages)
            if viewModel.messages.isEmpty {
                PremiumHeroGreeting(userName: userFirstName)
                    .padding(.top, 100) // Account for header
            } else {
                Spacer().frame(height: 80) // Header spacer when messages exist
            }
            
            // Messages
            ForEach(viewModel.messages) { message in
                LyoMessageBubbleView(
                    message: message,
                    onActionTap: { action in
                        handleAction(action)
                    },
                    onA2UICourseStart: { course in
                        viewModel.onA2UICourseStart(course: course)
                    },
                    onA2UIQuizAnswer: { question, answerIndex in
                        viewModel.onA2UIQuizAnswer(question: question, answerIndex: answerIndex)
                    }
                )
            }
            
            // Suggestion chips (above composer)
            if !viewModel.suggestions.isEmpty && !isAvatarFloating {
                SuggestionChipsBar(
                    suggestions: viewModel.suggestions,
                    onTap: { chip in
                        HapticManager.shared.light()
                        viewModel.executeSuggestion(chip)
                    }
                )
            }
            
            // Composer with attached avatar
            if !isAvatarFloating {
                EnhancedComposerBar(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    showAvatar: true,
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Enhanced Header
    
    private var enhancedHeader: some View {
        VStack(spacing: 0) {
            // Logo container with hidden drawer trigger
            HStack {
                // Logo button (slides on drawer open)
                Button(action: toggleHeaderDrawer) {
                    ZStack {
                        Circle()
                            .fill(Color("LyoSurface"))
                            .frame(width: 44, height: 44)
                        
                        Text("LYO")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color("LyoAccent"))
                    }
                }
                .offset(x: isHeaderDrawerOpen ? (UIScreen.main.bounds.width - 70) : 0)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.24, dampingFraction: 0.8),
                    value: isHeaderDrawerOpen
                )
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(height: 60)
            .glassmorphic(cornerRadius: 0)
            
            // Hidden drawer (slides down)
            if isHeaderDrawerOpen {
                hiddenDrawerContent
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                    )
            }
        }
        .animation(
            reduceMotion
                ? .none
                : .spring(response: 0.22, dampingFraction: 0.85),
            value: isHeaderDrawerOpen
        )
    }
    
    private var hiddenDrawerContent: some View {
        VStack(spacing: 16) {
            // Top row: Messages, Notifications, Search
            HStack(spacing: 20) {
                IconButton(icon: "message", action: {})
                IconButton(icon: "bell", action: {})
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("LyoTextSecondary"))
                    
                    TextField("Search...", text: .constant(""))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("LyoSurface"))
                )
            }
            .padding(.horizontal)
            
            // Instagram-style Stories row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<8) { index in
                        StoryAvatar(
                            name: "User \(index + 1)",
                            hasStory: index < 5
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 90)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .glassmorphic(cornerRadius: 0)
        .applyShadow(DesignTokens.Shadow.md)
    }
    
    // MARK: - Discover Rail
    
    private var discoverRailSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Continue Learning")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    
                    // 🧠 Smart Review Card
                    if let memory = smartMemory.memory, !memory.struggles.isEmpty {
                        SmartReviewCard(
                            struggles: memory.struggles,
                            isGenerating: courseGen.isGenerating,
                            action: {
                                Task {
                                    await startSmartReview(struggles: memory.struggles)
                                }
                            }
                        )
                    }

                    ForEach(viewModel.suggestedCards) { course in
                        PremiumDiscoverCard(
                            title: course.title,
                            subtitle: course.description ?? "",
                            progress: 0.34,
                            imageURL: nil,
                            action: {
                                // Handle course tap
                            }
                        )
                    }
                    
                    // Placeholder cards if no courses
                    if viewModel.suggestedCards.isEmpty {
                        ForEach(0..<5) { _ in
                            PremiumDiscoverCard(
                                title: "Machine Learning",
                                subtitle: "34 min left",
                                progress: 0.45,
                                imageURL: nil,
                                action: {}
                            )
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
    }
    
    // MARK: - Vertical Feed Sections
    
    private var verticalFeedSections: some View {
        VStack(spacing: 32) {
            feedSection(title: "Suggested for You", items: 4)
            feedSection(title: "Popular Now", items: 3)
            feedSection(title: "New Arrivals", items: 5)
        }
        .padding(.top, 32)
    }
    
    private func feedSection(title: String, items: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text(title)
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Spacer()
                
                Button("See All") {
                    HapticManager.shared.light()
                    // Navigate to full section
                }
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.accent)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(0..<items, id: \.self) { _ in
                        PremiumDiscoverCard(
                            title: "Course Title",
                            subtitle: "Description",
                            progress: nil,
                            imageURL: nil,
                            action: {}
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
    }
    
    // MARK: - Floating Avatar
    
    private var floatingAvatarBubble: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: reattachAvatar) {
                    EnhancedAnimatedLyoAvatar(state: .idle, size: 64)
                        .applyShadow(DesignTokens.Shadow.accentGlow)
                }
                .padding(.trailing, DesignTokens.Spacing.lg)
                .padding(.bottom, showBottomNav ? 90 : DesignTokens.Spacing.lg)
            }
        }
        .transition(.scale.combined(with: .opacity))
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7),
            value: isAvatarFloating
        )
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "house.fill", label: "Home", isSelected: false, action: { HapticManager.shared.selection() })
            TabBarButton(icon: "magnifyingglass", label: "Explore", isSelected: false, action: { HapticManager.shared.selection() })
            TabBarButton(icon: "plus.circle.fill", label: "Create", isSelected: false, action: { HapticManager.shared.selection() })
            TabBarButton(icon: "heart.fill", label: "Saved", isSelected: false, action: { HapticManager.shared.selection() })
            TabBarButton(icon: "person.fill", label: "Profile", isSelected: false, action: { HapticManager.shared.selection() })
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .glassmorphic(cornerRadius: 0)
        .applyShadow(DesignTokens.Shadow.lg)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                EnhancedAnimatedLyoAvatar(state: .thinking, size: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.4)
                
                Text("Creating your lesson...")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleHeaderDrawer() {
        withAnimation {
            isHeaderDrawerOpen.toggle()
        }
        
        // Auto-hide timer
        drawerAutoHideTimer?.invalidate()
        if isHeaderDrawerOpen {
            drawerAutoHideTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
                withAnimation {
                    isHeaderDrawerOpen = false
                }
            }
        }
    }
    
    private func handleScroll(offset: CGFloat) {
        let delta = offset - lastScrollOffset
        
        // Avatar detachment on downward scroll
        if delta < -50 && !isAvatarFloating {
            withAnimation {
                isAvatarFloating = true
            }
        }
        
        // Bottom nav auto-hide
        if delta < -20 && showBottomNav {
            withAnimation(.easeOut(duration: 0.12)) {
                showBottomNav = false
            }
        } else if delta > 20 && !showBottomNav {
            withAnimation(.easeIn(duration: 0.14)) {
                showBottomNav = true
            }
        }
        
        lastScrollOffset = offset
    }
    
    private func reattachAvatar() {
        withAnimation {
            isAvatarFloating = false
        }
    }
    
    private func handleAction(_ action: MessageAction) {
        switch action.actionType {
        case .openClassroom:
            if let data = action.data {
                createAndOpenClassroom(lessonData: data)
            }
        case .openDrawer:
            viewModel.isDrawerOpen = true
        case .generateSyllabus:
            // "Refine Course" button tapped — inject a refinement prompt into chat
            if let data = action.data, data["refine"] == "true",
               let title = data["title"], let topic = data["topic"] {
                viewModel.inputText = "I want to refine the course '\(title)' on \(topic). Please offer options to adjust the difficulty level, duration, or focus areas."
                Task { await viewModel.sendMessage() }
            } else {
                Log.ui.info("Action: generateSyllabus")
            }
        case .createCourse, .createCourseA2A, .quizMe, .addToLibrary, .quickExplainer, .makeFlashcards, .extractKeyPoints:
            Log.ui.info("Action: \(action.actionType.rawValue)")
        }
    }
    
    private func createAndOpenClassroom(lessonData: [String: Any]) {
        guard !isCreatingSession else { return }
        
        isCreatingSession = true
        
        Task<Void, Never> {
            do {
                let session = try await LyoRepository.shared.createClassroomSession(
                    lessonId: lessonData["id"] as? String ?? "temp-lesson"
                )
                
                await MainActor.run {
                    self.classroomSession = ClassroomSession(id: session.id)
                    self.isCreatingSession = false
                    
                    // Post global notification for cinematic flow
                    NotificationCenter.default.post(
                        name: .openClassroom,
                        object: nil,
                        userInfo: [
                            "courseId": session.id,
                            "courseTitle": lessonData["title"] as? String ?? "New Lesson",
                            "lessonId": lessonData["id"] as? String ?? "temp-lesson",
                            "lessonTitle": lessonData["title"] as? String ?? "Introduction"
                        ]
                    )
                }
            } catch {
                await MainActor.run {
                    self.isCreatingSession = false
                    viewModel.messages.append(
                        LyoMessage(
                            id: UUID().uuidString,
                            content: "I couldn't create the lesson right now. Please try again.",
                            isFromUser: false,
                            timestamp: Date()
                        )
                    )
                }
            }
        }
    }
    
    // MARK: - Smart Review Action
    
    private func startSmartReview(struggles: [StruggleItem]) async {
        isCreatingSession = true
        do {
            let course = try await courseGen.generateSmartReview(struggles: struggles)
            
            // Navigate to first lesson
            if let firstLesson = course.modules.first?.lessons.first {
                createAndOpenClassroom(lessonData: [
                    "id": firstLesson.id,
                    "title": firstLesson.title
                ])
            }
        } catch {
            Log.ui.error("Failed to generate smart review: \(error)")
            isCreatingSession = false
        }
    }
}

// MARK: - Smart Review Card

struct SmartReviewCard: View {
    let struggles: [StruggleItem]
    let isGenerating: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Gradient
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "4A00E0"), Color(hex: "8E2DE2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 280, height: 160)
                
                // Pattern/Overlay
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 280, height: 160)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                        Spacer()
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("\(struggles.count) Topics")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Daily Smart Review")
                        .font(.title3.bold())
                    
                    Text("Focus on: \(struggles.prefix(2).map(\.topic).joined(separator: ", "))...")
                        .font(.caption)
                        .opacity(0.8)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding()
                .frame(width: 280, height: 160)
            }
            .applyMultiLayerShadow()
        }
        .disabled(isGenerating)
    }
}

// MARK: - Premium Hero Greeting

struct PremiumHeroGreeting: View {
    let userName: String
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Animated avatar with glow
            EnhancedAnimatedLyoAvatar(state: .idle, size: 120)
                .applyShadow(DesignTokens.Shadow.accentGlow)
            
            // Greeting text with premium typography
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Hello, \(userName).")
                    .font(DesignTokens.Typography.displayMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text("What would you like to explore today?")
                    .font(DesignTokens.Typography.bodyLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }
}

// MARK: - Enhanced Animated Lyo Avatar

struct EnhancedAnimatedLyoAvatar: View {
    enum AvatarState {
        case idle, listening, speaking, thinking
    }

    let state: AvatarState
    let size: CGFloat
    
    @State private var breatheScale: CGFloat = 1.0
    @State private var blinkOpacity: Double = 1.0
    @State private var thinkingRotation: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ZStack {
            // Main avatar image
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FCCC66"),
                            Color(hex: "ECA05B"),
                            Color(hex: "CC6F56")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "632E53").opacity(0.4),
                                    Color.clear
                                ],
                                center: .bottom,
                                startRadius: 0,
                                endRadius: size / 2
                            )
                        )
                )
                .scaleEffect(reduceMotion ? 1.0 : breatheScale)
            
            // Eyes
            HStack(spacing: size * 0.2) {
                eye
                eye
            }
            .opacity(blinkOpacity)
            
            // Mouth
            mouth
                .offset(y: size * 0.15)
            
            // Thinking indicator
            if state == .thinking && !reduceMotion {
                thinkingDots
            }
            
            // Listening halo
            if state == .listening && !reduceMotion {
                listeningHalo
            }
        }
        .onAppear {
            if !reduceMotion {
                startAnimations()
            }
        }
    }
    
    private var eye: some View {
        Circle()
            .fill(Color(hex: "39478F"))
            .frame(width: size * 0.15, height: size * 0.15)
            .overlay(
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.06, height: size * 0.06)
                    .offset(x: size * 0.02, y: -size * 0.02)
            )
    }
    
    private var mouth: some View {
        Capsule()
            .fill(Color(hex: "632E53"))
            .frame(width: size * 0.3, height: size * 0.08)
    }
    
    private var thinkingDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color("LyoAccent"))
                    .frame(width: 6, height: 6)
                    .offset(
                        x: cos(thinkingRotation + Double(index) * 2 * .pi / 3) * 8,
                        y: sin(thinkingRotation + Double(index) * 2 * .pi / 3) * 8
                    )
            }
        }
        .offset(y: -size * 0.6)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                thinkingRotation = 2 * .pi
            }
        }
    }
    
    private var listeningHalo: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.accent.opacity(0.6),
                        DesignTokens.Colors.accentSecondary.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
            .frame(width: size * 1.4, height: size * 1.4)
            .opacity(0.6)
    }
    
    private func startAnimations() {
        // Breathe animation
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            breatheScale = 1.02
        }
        
        // Blink animation
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 6...8), repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                blinkOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    blinkOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct IconButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color("LyoSurface"))
                .clipShape(Circle())
        }
    }
}

struct StoryAvatar: View {
    let name: String
    let hasStory: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .strokeBorder(
                    hasStory
                        ? LinearGradient(
                            colors: [Color("LyoAccent"), Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [Color.gray], startPoint: .top, endPoint: .bottom),
                    lineWidth: 2.5
                )
                .background(
                    Circle()
                        .fill(Color("LyoSurface"))
                )
                .frame(width: 64, height: 64)
            
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(Color("LyoTextSecondary"))
                .lineLimit(1)
        }
        .frame(width: 72)
    }
}

// MARK: - Premium Discover Card

struct PremiumDiscoverCard: View {
    let title: String
    let subtitle: String
    let progress: Double?
    let imageURL: URL?
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            withAnimation(DesignTokens.Animation.quick) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignTokens.Animation.springBouncy) {
                    isPressed = false
                }
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // Cover image with gradient overlay
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .fill(DesignTokens.Colors.cardGradient)
                        .frame(width: 280, height: 160)
                    
                    // Glossy overlay
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 280, height: 160)
                    
                    // Progress bar overlay
                    if let progress = progress {
                        VStack {
                            Spacer()
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    Rectangle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 4)
                                    
                                    // Progress fill with gradient
                                    Rectangle()
                                        .fill(DesignTokens.Colors.accentGradient)
                                        .frame(width: geo.size.width * progress, height: 4)
                                }
                            }
                            .frame(height: 4)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.bottom, DesignTokens.Spacing.xs)
                        }
                    }
                }
                .applyMultiLayerShadow()
                
                // Title & subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(subtitle)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 280)
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(DesignTokens.Animation.springBouncy, value: isPressed)
    }
}

// Keep old DiscoverCard for backwards compatibility
struct DiscoverCard: View {
    let title: String
    let subtitle: String
    let progress: Double?
    let imageURL: URL?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover image
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "4A59A4"),
                                Color(hex: "632E53")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 280, height: 160)
                    .overlay(
                        // Progress bar if applicable
                        VStack {
                            Spacer()
                            
                            if let progress = progress {
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(Color("LyoAccent"))
                                        .frame(width: geo.size.width * progress, height: 3)
                                }
                                .frame(height: 3)
                            }
                        }
                    )
                
                // Title & subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color("LyoTextSecondary"))
                        .lineLimit(1)
                }
            }
            .frame(width: 280)
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color("LyoAccent") : Color("LyoTextSecondary"))
                
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Color("LyoAccent") : Color("LyoTextSecondary"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(PremiumTabBarButtonStyle())
    }
}

struct PremiumTabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(DesignTokens.Animation.quick, value: configuration.isPressed)
    }
}

struct EnhancedComposerBar: View {
    @Binding var text: String
    let isLoading: Bool
    let showAvatar: Bool
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var showingOptions = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Avatar (attached to composer)
            if showAvatar {
                EnhancedAnimatedLyoAvatar(state: isFocused ? .listening : .idle, size: 56)
            }
            
            // Input field
            HStack(spacing: 8) {
                // Camera button
                Button(action: {}) {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
                
                // Text input
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Ask anything… or say 'build me a 2-week course'")
                            .font(.system(size: 15))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                    
                    TextField("", text: $text)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .focused($isFocused)
                }
                
                // Gallery button
                Button(action: {}) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .glassmorphic(cornerRadius: DesignTokens.Radius.md)
            
            // Voice / Send button
            if text.isEmpty {
                Button(action: {
                    HapticManager.shared.light()
                }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(DesignTokens.Colors.accentGradient)
                        )
                        .applyShadow(DesignTokens.Shadow.glow)
                }
            } else {
                Button(action: {
                    HapticManager.shared.medium()
                    onSend()
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(DesignTokens.Colors.accentGradient)
                        )
                        .applyShadow(DesignTokens.Shadow.glow)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helper Extensions

// Color extension moved to DesignTokens.swift

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
