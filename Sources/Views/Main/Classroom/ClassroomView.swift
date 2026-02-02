import SwiftUI

struct ClassroomView: View {
    @StateObject private var viewModel = ClassroomViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var uiStackStore: UIStackStore
    @EnvironmentObject var uiState: AppUIState
    @EnvironmentObject var aiViewModel: LyoAIViewModel
    
    let sessionId: String
    
    // Tutor Mode state
    @State private var isTutorModePresented = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color("LyoBackground")
                    .ignoresSafeArea()
                
                // TTS Voice Bubble Animation
                if viewModel.isNarrating {
                    VStack {
                        HStack {
                            Spacer()
                            TTSVoiceBubbleView()
                                .padding(.top, 60)
                                .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                }
                
                // Main Content
                if let component = viewModel.a2uiComponent {
                     A2UIRenderer(
                        component: component,
                        onAction: { action, _ in
                             // Handle classroom-specific actions from A2UI
                             print("A2UI Action Triggered: \(action.id)")
                             
                             switch action.id {
                             case "next_slide", "next":
                                 withAnimation { viewModel.nextSlide() }
                             case "prev_slide", "previous", "back":
                                 withAnimation { viewModel.previousSlide() }
                             case "exit", "close":
                                 dismiss()
                             case "toggle_tutor":
                                 isTutorModePresented.toggle()
                             case "show_grid":
                                 withAnimation { viewModel.showModuleGrid = true }
                             default:
                                 // Forward other actions to generic handler or log
                                 print("Unhandled A2UI Action: \(action.id)")
                             }
                        }
                     )
                } else if let session = viewModel.session {
                    ModuleCardView(
                        module: session.modules[viewModel.currentModuleIndex],
                        slideIndex: viewModel.currentSlideIndex,
                        settings: viewModel.settings,
                        geometry: geometry
                    )
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                handleSwipe(value: value, geometry: geometry)
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.7)
                            .onEnded { _ in
                                // Trigger tutor mode
                                HapticManager.shared.success()
                                isTutorModePresented = true
                            }
                    )
                    .onTapGesture {
                        viewModel.toggleControls()
                    }
                    
                    // Progress bar at top
                    VStack {
                        ProgressBarView(
                            slideProgress: viewModel.slideProgress,
                            moduleProgress: viewModel.moduleProgress,
                            currentSlide: viewModel.currentSlideIndex + 1,
                            totalSlides: session.modules[viewModel.currentModuleIndex].slides.count
                        )
                        Spacer()
                    }
                    
                    // Controls Overlay (YouTube-style)
                    if viewModel.controlsVisible {
                        ControlsOverlay(viewModel: viewModel)
                            .transition(.opacity)
                    }
                    
                                        // Quick Check Overlay
                    if viewModel.state == .quickCheck {
                        QuickCheckOverlay(viewModel: viewModel)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Reteach Overlay
                    if viewModel.showReteach {
                        ReteachOverlay(viewModel: viewModel)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Module Grid (swipe down to show)
                    if viewModel.showModuleGrid {
                        ModuleGridView(viewModel: viewModel)
                            .transition(.move(edge: .bottom))
                    }
                } else if viewModel.state == .error {
                    // Error state
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text(viewModel.errorMessage ?? "An error occurred")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        HStack(spacing: 16) {
                            Button {
                                Task {
                                    await viewModel.retryLoadSession()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color("LyoAccent"))
                                .cornerRadius(12)
                            }
                            
                            Button {
                                dismiss()
                            } label: {
                                Text("Go Back")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color("LyoSurface"))
                                    .cornerRadius(12)
                            }
                        }
                    }
                } else {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Preparing your lesson...")
                            .font(.system(size: 18))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                }
                
                // MAIN AI ASSISTANT OVERLAY
                VStack {
                    HStack {
                        Spacer()
                        // Sparkle Button
                        Button(action: {
                            HapticManager.shared.light()
                            // Set context
                            if let session = viewModel.session {
                                let module = session.modules[viewModel.currentModuleIndex]
                                uiState.lioContextHint = "Learning: \(module.title)"
                            } else {
                                uiState.lioContextHint = "In Classroom"
                            }
                            uiState.isLioChatPresented = true
                        }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color(hex: "8B5CF6").opacity(0.5), radius: 8, x: 0, y: 0)
                        }
                        .padding(.top, 24)
                        .padding(.trailing, 24)
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $uiState.isLioChatPresented) {
            LioChatSheet(isPresented: $uiState.isLioChatPresented)
        }
        .sheet(isPresented: $isTutorModePresented) {
            if let session = viewModel.session {
                let currentModule = session.modules[viewModel.currentModuleIndex]
                TutorModeView(
                    courseId: session.lessonId, // Use lessonId as courseId for now
                    lessonId: currentModule.id,
                    onClose: {
                        isTutorModePresented = false
                    },
                    courseTitle: "Lesson: \(session.lessonId)",
                    lessonTitle: currentModule.title
                )
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden) // Hide home indicator
        .onAppear {
            // Lock to landscape orientation
            AppDelegate.orientationLock = .landscape
            
            // Force landscape if not already
            if UIDevice.current.orientation != .landscapeLeft && UIDevice.current.orientation != .landscapeRight {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
        }
        .onDisappear {
            // Restore orientation freedom
            AppDelegate.orientationLock = .all
        }
        .task {
            await viewModel.loadSession(sessionId: sessionId)
            
            // Register course in UI Stack when loaded
            if let session = viewModel.session {
                let firstModuleTitle = session.modules.first?.title ?? "Learning"
                UIStackStore.shared.upsertCourse(
                    courseId: session.lessonId,
                    title: firstModuleTitle,
                    subtitle: "Learning Session",
                    progress: 0.0,
                    lessonCount: session.modules.count,
                    completedLessons: 0
                )
            }
        }
        .onChange(of: viewModel.currentModuleIndex) {
            // Update progress in stack when module changes
            if let session = viewModel.session {
                let progress = Double(viewModel.currentModuleIndex + 1) / Double(session.modules.count)
                UIStackStore.shared.updateCourseProgress(
                    courseId: session.lessonId,
                    progress: progress,
                    completedLessons: viewModel.currentModuleIndex
                )
                
                // Sync State
                A2UIStateObserver.shared.updateState(
                    screenId: "classroom",
                    componentId: session.modules[viewModel.currentModuleIndex].id,
                    metadata: ["progress": String(format: "%.2f", progress)]
                )
            }
        }
    }
    
    private func handleSwipe(value: DragGesture.Value, geometry: GeometryProxy) {
        let horizontalAmount = value.translation.width
        let verticalAmount = value.translation.height
        
        // Vertical swipe down = show module grid
        if abs(verticalAmount) > abs(horizontalAmount) && verticalAmount > 0 {
            withAnimation(.spring(response: 0.4)) {
                viewModel.showModuleGrid = true
            }
        }
        // Horizontal swipes = navigate modules
        else if abs(horizontalAmount) > abs(verticalAmount) {
            if horizontalAmount < 0 {
                // Swipe left = next module
                withAnimation(.spring(response: 0.3)) {
                    viewModel.nextModule()
                }
            } else {
                // Swipe right = previous module
                withAnimation(.spring(response: 0.3)) {
                    viewModel.previousModule()
                }
            }
        }
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let slideProgress: Double
    let moduleProgress: Double
    let currentSlide: Int
    let totalSlides: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Thin progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color("LyoSurface").opacity(0.3))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(Color("LyoAccent"))
                        .frame(width: geometry.size.width * slideProgress, height: 3)
                        .animation(.easeOut(duration: 0.3), value: slideProgress)
                }
            }
            .frame(height: 3)
            
            // Slide indicator
            HStack {
                Spacer()
                Text("Slide \(currentSlide)/\(totalSlides) • ~\(estimatedTimeLeft)m left")
                    .font(.system(size: 12))
                    .foregroundColor(Color("LyoTextSecondary"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color("LyoSurface").opacity(0.8))
                    )
                    .padding(.trailing, 16)
                    .padding(.top, 4)
            }
        }
    }
    
    private var estimatedTimeLeft: Int {
        // Rough estimate: 20 seconds per remaining slide
        (totalSlides - currentSlide) * 20 / 60
    }
}
