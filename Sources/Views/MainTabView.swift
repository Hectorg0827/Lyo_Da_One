import SwiftUI
import os

/// New 5-button navigation with center FAB (Lyo Avatar)
/// Design: Focus | Discover | [Lyo FAB] | Post | Profile
struct MainTabView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @EnvironmentObject var uiState: AppUIState
    @EnvironmentObject var uiStackStore: UIStackStore
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler // NEW
    @StateObject private var stackService = StackService()
    // Unified AI ViewModel
    @StateObject private var aiViewModel = LyoAIViewModel()
    
    @State private var selectedTab: Tab = .focus
    @State private var isStackDrawerOpen = false
    @State private var isStackPanelPresented = false
    
    // Lyo Overlay State
    @State private var isLyoOverlayPresented = false
    @State private var lyoButtonFrame: CGRect = .zero
    
    // Navigation states
    @State private var navigateToCourseId: String? = nil
    @State private var navigateToTutor: (courseId: String, lessonId: String)? = nil
    @State private var isTutorModePresented = false
    @State private var isLiveClassroomPresented = false
    @State private var liveClassroomData: (courseId: String, lessonId: String, courseTitle: String, lessonTitle: String)? = nil
    
    // App Drawer State
    @State private var isAppDrawerOpen = false
    
    // Creation Flow State
    @State private var isCreationSheetPresented = false
    @State private var isCreateHubPresented = false
    @State private var lastCreationOption: CreationOption = .discovery
    @State private var lastCreateMode: CreateMode = .clip
    @State private var isVideoRecorderPresented = false
    @State private var isPostEditorPresented = false
    
    // New Drawer Screens
    @State private var isNotificationsPresented = false
    @State private var isSearchPresented = false
    @State private var recorderMode: CreationOption = .story
    
    // Runtime State (New Architecture)
    @State private var runtimeViewModel: LyoCourseRuntime?

    // Course Start Gate (monetization intercept before classroom)
    @State private var isCourseGatePresented = false
    @State private var pendingClassroomFromGate: (courseId: String, lessonId: String, courseTitle: String, lessonTitle: String)? = nil
    
    // Computed property for App Drawer visibility
    private var shouldShowAppDrawer: Bool {
        // Hide on Profile tab
        if selectedTab == .profile { return false }
        
        // Hide when AI Overlay is open (Lyo Screen)
        if isLyoOverlayPresented { return false }
        
        // Hide when Classroom/Tutor is open
        if isLiveClassroomPresented || isTutorModePresented { return false }
        
        return true
    }
    
    enum Tab {
        case focus
        case clips // Renamed from discover
        case create // New creation tab
        case community // Was post/campus
        case messages
        case profile // Kept for state but not in bottom bar
        
        var toAppTab: AppTab {
            switch self {
            case .focus: return .focus
            case .clips: return .discover
            case .create: return .campus // Temporary mapping
            case .community: return .campus
            case .messages: return .campus // Messages lives in Social/Campus context
            case .profile: return .profile
            }
        }
    }
    
    init() {
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0f172a")
                .ignoresSafeArea()
            
            // Content
            TabView(selection: $selectedTab) {
                FocusView()
                    .tag(Tab.focus)
                
                DiscoverView() // Will rename to ClipsView later
                    .tag(Tab.clips)
                
                // Create Tab - Multi-Mode Creation Interface
                VStack {
                    MultiModeCreationView()

                    // Debug: Add test view link
                    NavigationLink("🧪 Content Feed Test") {
                        ContentFeedTestView()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                }
                .tag(Tab.create)
                
                // Community
                CommunityView()
                    .tag(Tab.community)
                
                // Messages
                ChatView()
                    .tag(Tab.messages)
                
                // Profile - Hidden from tab bar but accessible
                ProfileView()
                    .tag(Tab.profile)
            }
            .environmentObject(stackService)
            .environmentObject(uiStackStore)
            .environmentObject(uiState)
            .toolbar(.hidden, for: .tabBar)
            .onChange(of: selectedTab) { _, newValue in
                uiState.currentTab = newValue.toAppTab
            }
            .onChange(of: uiState.currentTab) { _, newTab in
                // Sync external tab changes (e.g. from Header) to local state
                switch newTab {
                case .focus: selectedTab = .focus
                case .discover: selectedTab = .clips
                case .campus: selectedTab = .community
                case .profile: selectedTab = .profile
                default: break
                }
            }
            
            // Living Hub Navigation
            VStack {
                Spacer()
                
                LivingHubTabBar(
                    selectedTab: $selectedTab,
                    onLyoTap: {
                        HapticManager.shared.medium()
                        withAnimation {
                            isLyoOverlayPresented = true
                        }
                    },
                    lyoButtonFrame: $lyoButtonFrame,
                    isCreationSheetPresented: $isCreationSheetPresented,
                    isCreateActive: isCreationSheetPresented || isCreateHubPresented,
                    onCreateTap: {
                        isCreateHubPresented = true
                    },
                    onCreateLongPress: {
                        isCreateHubPresented = true
                    }
                )
                .offset(y: isLyoOverlayPresented ? 200 : 0) // Slide down when overlay is active
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isLyoOverlayPresented)
            }
            
            // Lyo Overlay (Full Screen)
            if isLyoOverlayPresented {
                LyoOverlayView(
                    isPresented: $isLyoOverlayPresented,
                    startFrame: lyoButtonFrame
                )
                .zIndex(100) // Ensure it's on top
            }
            
            // Stack Drawer Overlay
            StackDrawerView(isPresented: $isStackDrawerOpen)
                .environmentObject(stackService)
            
            // Notification Listeners
            notificationListeners
            
            // App Drawer Overlay (Top Layer)
            if shouldShowAppDrawer {
                AppDrawerOverlay(
                    isPresented: $isAppDrawerOpen,
                    selectedTab: $selectedTab,
                    isNotificationsPresented: $isNotificationsPresented,
                    isSearchPresented: $isSearchPresented
                )
            }
        }
        .onChange(of: deepLinkHandler.pendingAction) { _, action in
            guard let action = action else { return }
            if action == .openDemo {
                Log.ui.info("Launching Demo Runtime...")
                let course = DemoCourseLoader.shared.loadSpanish101()
                let runtime = LyoCourseRuntime(course: course)
                self.runtimeViewModel = runtime
                deepLinkHandler.clearPendingAction()
            } else {
                handleDeepLinkAction(action)
            }
        }
        .environmentObject(aiViewModel) // Inject at root of ZStack
        .detectOffline() // Wire up offline indicator banner
        .onAppear { aiViewModel.uiState = uiState }
        .sheet(isPresented: $uiState.isLioChatPresented) {
            LioChatSheet(isPresented: $uiState.isLioChatPresented)
                .environmentObject(uiState)
                .environmentObject(aiViewModel)
        }
        .sheet(isPresented: $isStackPanelPresented) {
            StackPanelView(
                onClose: { isStackPanelPresented = false },
                onNavigate: { action in handleStackNavigation(action) }
            )
            .environmentObject(uiStackStore)
            .environmentObject(uiState)
        }
        .sheet(isPresented: $isTutorModePresented) {
            if let tutor = navigateToTutor {
                TutorModeView(
                    courseId: tutor.courseId,
                    lessonId: tutor.lessonId,
                    onClose: { isTutorModePresented = false }
                )
                .environmentObject(uiState)
            }
        }
        // ── Monetization gate (shown before classroom for every course start) ──
        .fullScreenCover(isPresented: $isCourseGatePresented) {
            CourseStartGateView(
                courseId: pendingClassroomFromGate?.courseId ?? "pending",
                courseTitle: pendingClassroomFromGate?.courseTitle ?? "Preparing Your Course…"
            ) {
                // Gate completed → dismiss gate then open classroom
                isCourseGatePresented = false
                if let finalData = pendingClassroomFromGate {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        liveClassroomData = finalData
                        withAnimation { isLiveClassroomPresented = true }
                        Log.ui.info("MainTabView: Gate done → LiveClassroomView for \(finalData.courseTitle)")
                    }
                } else {
                    Log.ui.error("MainTabView: Gate done but pendingClassroomFromGate is STILL nil")
                }
            }
            .onAppear {
                if let dg = pendingClassroomFromGate {
                    Log.ui.info("🎬 CourseStartGateView appeared for: \(dg.courseTitle)")
                } else {
                    Log.ui.warning("⚠️ CourseStartGateView fallback — pendingClassroomFromGate was nil")
                }
            }
        }
        .fullScreenCover(isPresented: $isLiveClassroomPresented) {
            if let data = liveClassroomData {
                LiveClassroomView(
                    courseId: data.courseId,
                    lessonId: data.lessonId,
                    courseTitle: data.courseTitle,
                    lessonTitle: data.lessonTitle
                )
                .environmentObject(uiStackStore)
                .environmentObject(uiState)
                .environmentObject(aiViewModel)
            }
        }
        .fullScreenCover(isPresented: $isVideoRecorderPresented) {
            VideoRecorderView(isPresented: $isVideoRecorderPresented, mode: recorderMode)
        }
        .sheet(isPresented: $isPostEditorPresented) {
            PostEditorView(isPresented: $isPostEditorPresented)
        }
        .sheet(isPresented: $isNotificationsPresented) {
            NotificationsView()
        }
        .sheet(isPresented: $isSearchPresented) {
            GlobalSearchView()
        }
        .fullScreenCover(isPresented: $isCreateHubPresented) {
            LyoCreateStudioView()
        }
        // MARK: - New Runtime Integration
        .fullScreenCover(
            isPresented: Binding(
                get: { runtimeViewModel != nil },
                set: { presented in
                    if !presented { runtimeViewModel = nil }
                }
            )
        ) {
            if let vm = runtimeViewModel {
                CourseRuntimeView(runtime: vm)
            }
        }

    }
    
    private func createMode(for option: CreationOption) -> CreateMode {
        switch option {
        case .discovery: return .clip
        case .story: return .story
        case .post: return .post
        case .community: return .event
        }
    }

    private func creationOption(for mode: CreateMode) -> CreationOption {
        switch mode {
        case .clip, .reel: return .discovery
        case .story: return .story
        case .post: return .post
        case .course: return .discovery
        case .event: return .community
        case .live: return .discovery
        }
    }

    // MARK: - Stack Navigation Handler
    
    private func handleStackNavigation(_ action: StackNavigationAction) {
        isStackPanelPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.performStackNavigation(action)
        }
    }
    
    private func performStackNavigation(_ action: StackNavigationAction) {
        switch action {
        case .openCourse(let courseId):
            navigateToCourse(courseId)
        case .openTutor(let courseId, let lessonId):
            navigateToTutor = (courseId, lessonId)
            isTutorModePresented = true
        case .openCollab(let roomId):
            uiState.currentCollabRoomId = roomId
        case .openChat:
            uiState.isLioChatPresented = true
        }
    }
    
    private func navigateToCourse(_ courseId: String) {
        if let courseItem = uiStackStore.items.first(where: { $0.courseId == courseId && $0.type == .course }) {
            let lessonId: String = courseItem.lessonId ?? "lesson-1"
            let courseTitle: String = courseItem.title
            let lessonTitle: String = courseItem.subtitle ?? "Lesson"
            pendingClassroomFromGate = (courseId, lessonId, courseTitle, lessonTitle)
        } else {
            pendingClassroomFromGate = (courseId, "lesson-1", "Shared Course", "Introduction")
        }
        withAnimation { isCourseGatePresented = true }
    }
    
    // MARK: - Deep Link Handler Logic
    
    private func handleDeepLinkAction(_ action: DeepLinkHandler.DeepLinkAction) {
        Log.ui.info("MainTabView: Handling deep link action: \(String(describing: action))")
        
        switch action {
        case .openCourse(let id):
            navigateToCourse(id)
            
        case .openLesson(let courseId, let lessonId):
            pendingClassroomFromGate = (courseId, lessonId, "Shared Course", "Lesson")
            withAnimation { isCourseGatePresented = true }
            
        case .openProfile:
            selectedTab = .profile
            
        case .openChat:
            selectedTab = .messages

        case .openDemo:
            let course = DemoCourseLoader.shared.loadSpanish101()
            let runtime = LyoCourseRuntime(course: course)
            runtimeViewModel = runtime
        }
        
        // Clear after handling
        deepLinkHandler.clearPendingAction()
    }
    
    // MARK: - Notification Handlers
    
    private let tutorModePublisher = NotificationCenter.default.publisher(for: .triggerTutorMode)
    private let liveLessonPublisher = NotificationCenter.default.publisher(for: .triggerLiveLesson)
    private let openClassroomPublisher = NotificationCenter.default.publisher(for: .openClassroom)
    private let dismissOverlayPublisher = NotificationCenter.default.publisher(for: .dismissLyoOverlay)
}

extension MainTabView {
    var notificationListeners: some View {
        EmptyView()
            .onReceive(tutorModePublisher) { notification in
                if let userInfo = notification.userInfo {
                    let courseId = userInfo["courseId"] as? String ?? userInfo["topic"] as? String ?? "general"
                    let lessonId = userInfo["lessonId"] as? String ?? "intro"
                    navigateToTutor = (courseId: courseId, lessonId: lessonId)
                    isTutorModePresented = true
                }
            }
            .onReceive(liveLessonPublisher) { notification in
                if let userInfo = notification.userInfo,
                   let lessonId = userInfo["lessonId"] as? String {
                    
                    // Check if we need to generate a course first
                    if lessonId == "intro_1", let topic = userInfo["topic"] as? String {
                        // Pass special "GENERATE:" prefix to signal LiveClassroomViewModel
                        pendingClassroomFromGate = ("GENERATE:\(topic)", lessonId, topic, "Introduction")
                    } else {
                        // Read actual course info from userInfo
                        let courseId = userInfo["courseId"] as? String ?? "GENERATE:\(userInfo["topic"] as? String ?? "Course")"
                        let courseTitle = userInfo["courseTitle"] as? String ?? userInfo["topic"] as? String ?? "Course"
                        let lessonTitle = userInfo["lessonTitle"] as? String ?? "Introduction"
                        pendingClassroomFromGate = (courseId, lessonId, courseTitle, lessonTitle)
                    }
                    withAnimation { isCourseGatePresented = true }
                }
            }
            .onReceive(openClassroomPublisher) { notification in
                Log.ui.info("🎬 MainTabView: Received openClassroom notification — routing through gate")

                // Ensure chat sheet is dismissed first — must be fully gone before
                // fullScreenCover can present reliably on iOS.
                if uiState.isLioChatPresented {
                    Log.ui.info("🎬 Dismissing chat sheet before gate presentation")
                    uiState.isLioChatPresented = false
                }

                // Wait for any chat-sheet / overlay dismiss animation to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    guard let userInfo = notification.userInfo,
                          var courseId = userInfo["courseId"] as? String else {
                        Log.ui.warning("🎬 openClassroom notification missing courseId — aborting gate")
                        return
                    }

                    let lessonId    = userInfo["lessonId"]    as? String ?? "intro_1"
                    let courseTitle = userInfo["courseTitle"] as? String ?? "New Course"
                    let lessonTitle = userInfo["lessonTitle"] as? String ?? "Introduction"
                    let shouldGenerate = userInfo["shouldGenerateCourse"] as? Bool ?? false

                    // Prepend GENERATE: for new AI-originated courses
                    if let topic = userInfo["topic"] as? String,
                       shouldGenerate || courseId.starts(with: "gen_") {
                        courseId = "GENERATE:\(topic)"
                    }

                    // Store the destination; the gate's onProceed will open the classroom
                    self.pendingClassroomFromGate = (courseId, lessonId, courseTitle, lessonTitle)

                    Log.ui.info("🎬 MainTabView: pendingClassroomFromGate set — courseId=\(courseId) title=\(courseTitle)")
                    Log.ui.info("🎬 MainTabView: isCourseGatePresented → true (chat sheet open: \(self.uiState.isLioChatPresented))")

                    DispatchQueue.main.async {
                        withAnimation {
                            self.isCourseGatePresented = true
                        }
                    }
                }
            }
            .onReceive(dismissOverlayPublisher) { _ in
                Log.ui.info("MainTabView: Dismissing Lyo overlay + chat sheet for classroom transition")
                // Also dismiss the Lyo chat sheet — iOS cannot stack a fullScreenCover
                // over an open .sheet, so we must close the chat before presenting the classroom.
                uiState.isLioChatPresented = false
                withAnimation(.easeOut(duration: 0.3)) {
                    isLyoOverlayPresented = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveCourseToLibrary)) { notification in
                if let userInfo = notification.userInfo,
                   let topic = userInfo["topic"] as? String {
                    Log.ui.info("📚 Saving course stack: \(topic)")
                    Task {
                        // Create a stack for this course
                        await stackService.createStackItem(
                            type: .course,
                            refId: UUID().uuidString,
                            tags: ["AI Generated"],
                            contextData: ["title": topic, "topic": topic]
                        )
                        HapticManager.shared.success()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .triggerLioChat)) { _ in
                uiState.isLioChatPresented = true
            }
    }
}

// MARK: - Custom Navigation Bar with Center FAB


struct CustomNavBar: View {
    @Binding var selectedTab: MainTabView.Tab
    let onLyoTap: () -> Void
    @Binding var lyoButtonFrame: CGRect
    @Binding var isCreationSheetPresented: Bool
    let isCreateActive: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Glassmorphism Nav Bar - Full Width
            HStack(spacing: 0) {
                // 1. Focus
                NavButton(
                    icon: "target",
                    isSelected: selectedTab == .focus
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = .focus
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 2. Clips (was Discover)
                NavButton(
                    icon: "play.rectangle.fill", // Video icon for Clips
                    isSelected: selectedTab == .clips
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = .clips
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 3. Center Space (for FAB)
                Color.clear
                    .frame(width: 70)
                
                // 4. Create (+)
                NavButton(
                    icon: "plus.circle.fill",
                    isSelected: selectedTab == .create
                ) {
                    // Present creation sheet instead of switching tab
                    HapticManager.shared.medium()
                    withAnimation {
                        isCreationSheetPresented = true
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 5. Community
                NavButton(
                    icon: "person.3.fill", // Community icon
                    isSelected: selectedTab == .community
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = .community
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 60)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: -5)
            )
            .ignoresSafeArea(edges: .horizontal)
            
            // Center FAB (Lyo Avatar) - Perfectly Aligned
            GeometryReader { geo in
                LyoAvatarButton(onTap: onLyoTap)
                    .onAppear {
                        // Capture the frame in global coordinates
                        DispatchQueue.main.async {
                            lyoButtonFrame = geo.frame(in: .global)
                        }
                    }
            }
            .frame(width: 90, height: 90) // Explicit frame for GeometryReader
            .offset(y: -25) // Float upwards
        }
    }
}

// MARK: - Navigation Button

struct NavButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        isSelected ? 
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6"), Color(hex: "A78BFA")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                
                // Active indicator
                if isSelected {
                    Circle()
                        .fill(Color(hex: "8B5CF6"))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Lyo Avatar FAB

struct LyoAvatarButton: View {
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FF8C00").opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 45
                        )
                    )
                    .frame(width: 90, height: 90)
                    .blur(radius: 10)
                
                // Avatar Circle with Orange Gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FFB74D"),
                                Color(hex: "FF8C00"),
                                Color(hex: "FF6B35")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: Color(hex: "FF8C00").opacity(0.5), radius: 15, x: 0, y: 5)
                
                // Lyo Character Avatar
                Image("LyoAvatar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Legacy Components (for compatibility)

struct FloatingTabIcon: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 56, height: 56)
                }
                
                Circle()
                    .fill(isSelected ? 
                          LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ) :
                          LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MainTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? DesignSystem.Colors.fallbackPrimary : .gray)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? DesignSystem.Colors.fallbackPrimary : .gray)
            }
        }
    }
}

// MARK: - Living Hub Tab Bar
struct LivingHubTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    let onLyoTap: () -> Void
    @Binding var lyoButtonFrame: CGRect
    @Binding var isCreationSheetPresented: Bool
    let isCreateActive: Bool
    let onCreateTap: () -> Void
    let onCreateLongPress: () -> Void
    
    // Progress for the mascot glow (0.0 to 1.0)
    // In a real app, this would come from a ViewModel
    var progress: Double = 0.65 
    var streakActive: Bool = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Liquid Glass Background
            LiquidTabBarShape(curveDepth: 35, curveWidth: 100)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .frame(height: 80)
                .overlay(
                    LiquidTabBarShape(curveDepth: 35, curveWidth: 100)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
            
            // 2. Icons Row
            HStack(spacing: 0) {
                // Left Group
                HStack(spacing: 30) {
                    GhostTabButton(
                        icon: "target",
                        label: "Focus",
                        isSelected: selectedTab == .focus
                    ) { selectedTab = .focus }
                    
                    GhostTabButton(
                        icon: "safari",
                        label: "Discover",
                        isSelected: selectedTab == .clips
                    ) { selectedTab = .clips }
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing, 40) // Space for Mascot
                
                // Right Group
                HStack(spacing: 30) {
                    GhostTabButton(
                        icon: "person.3.fill", // Community icon
                        label: "Community",
                        isSelected: selectedTab == .community
                    ) { selectedTab = .community }
                    
                    CreateTabButton(isActive: isCreateActive, onLongPress: {
                        onCreateLongPress()
                    }) {
                        // Trigger creation flow
                        onCreateTap()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 40) // Space for Mascot
            }
            .frame(height: 80)
            .padding(.bottom, 10) // Adjust for safe area
            
            // 3. The Living Mascot FAB
            GeometryReader { geo in
                LivingMascotFAB(
                    onTap: onLyoTap,
                    progress: progress,
                    streakActive: streakActive
                )
                .position(x: geo.size.width / 2, y: 15) // Positioned in the dip
                .onAppear {
                    DispatchQueue.main.async {
                        lyoButtonFrame = geo.frame(in: .global)
                    }
                }
            }
            .frame(height: 80)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Liquid Tab Bar Shape
struct LiquidTabBarShape: Shape {
    var curveDepth: CGFloat
    var curveWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start top left
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Line to start of curve
        let center = rect.width / 2
        let curveStart = center - (curveWidth / 2)
        let curveEnd = center + (curveWidth / 2)
        
        path.addLine(to: CGPoint(x: curveStart, y: 0))
        
        // The "Dip" Curve
        // Uses two control points for a smooth liquid feel
        path.addCurve(
            to: CGPoint(x: curveEnd, y: 0),
            control1: CGPoint(x: center - (curveWidth / 4), y: curveDepth),
            control2: CGPoint(x: center + (curveWidth / 4), y: curveDepth)
        )
        
        // Continue to top right
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // Bottom right
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        
        // Bottom left
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        
        // Close path
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Ghost Tab Button
struct GhostTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.white)
                    .opacity(isSelected ? 1.0 : 0.5)
                    .shadow(color: isSelected ? .white.opacity(0.5) : .clear, radius: 8)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                // Optional: Tiny dot indicator instead of label or pill
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .shadow(color: .white, radius: 4)
                        .transition(.scale)
                }
            }
            .frame(width: 50, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Create Tab Button
struct CreateTabButton: View {
    let isActive: Bool
    let onLongPress: (() -> Void)?
    let action: () -> Void
    @State private var isPressed = false
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "FDBA74"), // warm orange
                Color(hex: "FB7185"), // coral
                Color(hex: "A855F7")  // violet
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderGradient, lineWidth: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            .padding(1.5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                    .shadow(color: Color(hex: "FB7185").opacity(isActive ? 0.35 : 0.2),
                            radius: isActive ? 16 : 10,
                            x: 0,
                            y: isActive ? 6 : 4)
                
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            }
            .frame(width: 48, height: 48)
            .scaleEffect(isPressed ? 0.95 : (isActive ? 1.05 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.01, maximumDistance: 20, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    onLongPress?()
                }
        )
    }
}

// MARK: - Living Mascot FAB
// MARK: - Living Mascot FAB
struct LivingMascotFAB: View {
    let onTap: () -> Void
    var progress: Double // 0.0 to 1.0
    var streakActive: Bool
    
    @State private var isBreathing = false
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var shockwaveScale: CGFloat = 0.0
    @State private var shockwaveOpacity: Double = 0.0
    
    // Determine glow color based on progress
    var glowColor: Color {
        if streakActive && progress >= 1.0 {
            return Color(hex: "FF8C00") // Gold/Orange for mastery
        } else if progress >= 0.5 {
            return Color(hex: "A78BFA") // Purple for progress
        } else {
            return Color(hex: "60A5FA") // Blue for beginning
        }
    }
    
    var body: some View {
        Button(action: {
            triggerShockwave()
            onTap()
        }) {
            ZStack {
                // 0. Particles (Background)
                MascotParticles(color: glowColor)
                    .frame(width: 120, height: 120)
                
                // 1. Shockwave Ring
                Circle()
                    .stroke(glowColor, lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(shockwaveScale)
                    .opacity(shockwaveOpacity)
                
                // 2. Progressive Glow Field
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowColor.opacity(0.6), glowColor.opacity(0.0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 110, height: 110)
                    .scaleEffect(isBreathing ? 1.15 : 1.0)
                    .opacity(isBreathing ? 0.7 : 0.4)
                
                // 3. Core Glow
                Circle()
                    .fill(glowColor.opacity(0.4))
                    .frame(width: 75, height: 75)
                    .blur(radius: 12)
                    .scaleEffect(isBreathing ? 1.05 : 0.95)
                
                // 4. The Mascot
                Image("LyoAvatar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .shadow(color: glowColor.opacity(0.6), radius: 10, x: 0, y: 5)
                    // 3D Hover Effect
                    .offset(y: isHovering ? -6 : 4)
                    .rotation3DEffect(
                        .degrees(isHovering ? 5 : -5),
                        axis: (x: 10, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(isHovering ? 3 : -3),
                        axis: (x: 0, y: 10, z: 0)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .onAppear {
            // Breathing (Glow)
            withAnimation(
                Animation
                    .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
            
            // Hovering (Movement)
            withAnimation(
                Animation
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                isHovering = true
            }
        }
    }
    
    private func triggerShockwave() {
        shockwaveScale = 1.0
        shockwaveOpacity = 0.8
        
        withAnimation(.easeOut(duration: 0.5)) {
            shockwaveScale = 2.5
            shockwaveOpacity = 0.0
        }
        
        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shockwaveScale = 1.0
        }
    }
}



// MARK: - App Drawer Overlay
struct AppDrawerOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: MainTabView.Tab
    @Binding var isNotificationsPresented: Bool
    @Binding var isSearchPresented: Bool
    
    // Auto-close timer
    @State private var inactivityTimer: Timer?
    @State private var timeRemaining: TimeInterval = 30
    
    // Animation state
    @Namespace private var animation
    @State private var isExpanded = false
    
    // Border Animation
    @State private var borderRotation: Double = 0
    @State private var showBorderBeam: Bool = false
    
    @State private var isStoryViewerPresented = false
    @State private var selectedStoryForViewer: Story? // To pass to viewer if needed, though viewer uses service index potentially
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Did Dimmed Background...
            if isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeDrawer()
                    }
                    .transition(.opacity)
            }
            
            // Drawer Container
            if isExpanded {
                // Expanded State (Full Width Top Drawer)
                VStack(alignment: .leading, spacing: 20) {
                    // Header Row (Button + Progress + Icons)
                    HStack(alignment: .center) {
                        // Close Button (Top Left)
                        AppDrawerButton(isExpanded: true) {
                            closeDrawer()
                        }
                        .matchedGeometryEffect(id: "DrawerButton", in: animation)
                        
                        // Spacer to push icons to right
                        Spacer()
                        
                        // Icons (Top Right)
                        HStack(spacing: 20) {
                            // Profile Button (Moved from bottom bar)
                            Button(action: {
                                selectedTab = .profile
                                closeDrawer()
                            }) {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                            
                            // Message Icon - Opens Lio Chat
                            Button(action: {
                                closeDrawer()
                                // Navigate to messages tab
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    selectedTab = .messages
                                }
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                    
                                    // Badge
                                    Text("2")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 5, y: -5)
                                }
                            }
                            
                            // Bell Icon - Notifications
                            DrawerIconButton(icon: "bell.fill", badge: 5) {
                                isNotificationsPresented = true
                                HapticManager.shared.light()
                            }
                            
                            // Search Icon
                            DrawerIconButton(icon: "magnifyingglass", badge: 0) {
                                isSearchPresented = true
                                HapticManager.shared.light()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10) // Adjust for safe area
                    
                    // Stories Rail
                    StoriesRailView(
                        onStorySelect: { story in
                            // Logic to set index or just open viewer
                            // For simplicity, let's just open viewer. StoryViewer should probably take a starting story ID.
                            // But for now, StoryViewer iterates ALL stories in service.
                            // We should really tell it WHERE to start.
                            // I'll update StoryViewer to handle `startingStoryId` later if strictly needed,
                            // but currently it iterates linearly. We can update index in service or local state.
                            isStoryViewerPresented = true
                            selectedStoryForViewer = story
                        },
                        onAddStory: {
                            // Handle add story
                        }
                    )
                    .padding(.horizontal)
                    
                    // Progress Bar (Permanent - Daily Goal)
                    HStack(spacing: 12) {
                        Text("Daily Progress")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "FF8C00"), Color(hex: "FFD700")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * 0.65, height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text("65%")
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "FFD700"))
                    }
                    .padding(.horizontal)
                    
                    // Stats Chips Row (Scrollable)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            DrawerStatChip(icon: "flame.fill", title: "Streak", value: "7 days", color: .orange)
                            DrawerStatChip(icon: "star.fill", title: "XP Today", value: "150", color: .yellow)
                            DrawerStatChip(icon: "target", title: "Goal", value: "65%", color: .green)
                            DrawerStatChip(icon: "clock.fill", title: "Time", value: "45 min", color: .blue)
                            DrawerStatChip(icon: "book.fill", title: "Lessons", value: "3", color: .purple)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Chat History Section
                    ScrollView { 
                        if #available(iOS 17.0, *) {
                            DrawerChatHistoryView()
                                .padding(.bottom, 40) // Spacing for bottom interaction
                        } else {
                            Text("Chat History requires iOS 17.0 or later")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: UIScreen.main.bounds.width) // Full width
                .frame(height: 320) // Increased height for stats section
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        if showBorderBeam {
                            RoundedRectangle(cornerRadius: 0)
                                .strokeBorder(
                                    AngularGradient(
                                        gradient: Gradient(colors: [.clear, .clear, Color(hex: "FF8C00"), .clear, .clear]),
                                        center: .center,
                                        startAngle: .degrees(borderRotation),
                                        endAngle: .degrees(borderRotation + 360)
                                    ),
                                    lineWidth: 4
                                )
                        }
                    }
                    .ignoresSafeArea()
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                // Collapsed State (Top Right)
                VStack {
                    HStack {
                        Spacer()
                        AppDrawerButton(isExpanded: false) {
                            openDrawer()
                        }
                        .matchedGeometryEffect(id: "DrawerButton", in: animation)
                        .padding(.top, 10)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $isStoryViewerPresented) {
            if let story = selectedStoryForViewer {
                StoryViewer(
                    isPresented: $isStoryViewerPresented,
                    startingStoryId: story.id,
                    onAskLio: { context in
                        // Future: Open Lio Chat with context
                        Log.ui.info("Asked Lio about: \(context)")
                    }
                )
            } else {
                 // Fallback (Should not happen)
                 Text("Error loading story")
                    .onAppear {
                        isStoryViewerPresented = false
                    }
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .resetInactivityTimer)) { _ in
            resetTimer()
        }
    }
    
    private func openDrawer() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isExpanded = true
        }
        startTimer()
        
        // Trigger Border Beam
        showBorderBeam = true
        borderRotation = 0
        withAnimation(.linear(duration: 1.5)) {
            borderRotation = 360
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showBorderBeam = false
        }
    }
    
    private func closeDrawer() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isExpanded = false
        }
        stopTimer()
    }
    
    private func startTimer() {
        stopTimer()
        timeRemaining = 30
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                closeDrawer()
            }
        }
    }
    
    private func stopTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    private func resetTimer() {
        if isExpanded {
            timeRemaining = 30
        }
    }
}

// MARK: - App Drawer Button
struct AppDrawerButton: View {
    let isExpanded: Bool
    let action: () -> Void
    
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsing Glow
                if !isExpanded {
                    Circle()
                        .fill(Color(hex: "FF8C00").opacity(0.4))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.5)
                        .animation(
                            Animation.easeOut(duration: 2.0).repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }
                
                // Button Image
                Image("LyoLogoButton") // Ensure this asset exists
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42) // Increased by 5% (40 * 1.05 = 42)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Drawer Icon Button
struct DrawerIconButton: View {
    let icon: String
    let badge: Int
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
    }
}

// MARK: - Story Circle
struct StoryCircle: View {
    let image: String
    let name: String
    let isLive: Bool
    var isAdd: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: isLive ? [.red, .orange] : [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 56, height: 56)
                
                // Image
                if isAdd {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 50, height: 50)
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: image) // Placeholder
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .padding(3)
                }
                
                // Live Badge
                if isLive {
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                        .offset(y: 25)
                }
            }
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Drawer Stat Chip
struct DrawerStatChip: View {
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
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// End of file

