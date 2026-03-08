import SwiftUI
import AVFoundation
import Photos

// MARK: - Lyo Create Studio - Production Ready

/// The future of learning + social creation
/// TikTok-level UI with AI learning intelligence
struct LyoCreateStudioView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraManager = EnhancedCameraManager()
    @StateObject private var contentStorage = ContentStorageService.shared
    private let haptics = HapticManager.shared

    // MARK: - State
    @State private var selectedMode: CreateMode = .clip
    @State private var showAISuggestions = false
    @State private var showGallery = false
    @State private var selectedTab = 0
    @State private var dragAmount = CGSize.zero
    @State private var showModeDetail = false
    @State private var capturedMedia: CapturedMedia?
    @State private var showWelcomeBanner = true
    @State private var showPublishFlow = false
    @State private var recordingComplete = false
    @State private var showClipsStudio = false
    @State private var showStoriesStudio = false
    @State private var showPostEditor = false
    @State private var showMusicPicker = false
    @State private var showEffectsPicker = false
    @State private var showAIQuizSheet = false
    @State private var showSlidesPicker = false
    @State private var selectedCameraFilter: CameraFilterPreset = .none
    @State private var aiQuizTopic: String = ""

    // MARK: - Animation State
    @State private var recordButtonScale: CGFloat = 1.0
    @State private var recordButtonRotation: Double = 0
    @State private var modeSelectorOpacity: Double = 1.0
    @State private var overlayOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Full Screen Camera Preview
                if selectedMode.requiresCamera {
                    StudioCameraPreviewLayer(
                        session: cameraManager.session,
                        focusPoint: $cameraManager.focusPoint
                    )
                    .ignoresSafeArea(.all)
                    .onTapGesture { location in
                        let point = CGPoint(
                            x: location.x / geometry.size.width,
                            y: location.y / geometry.size.height
                        )
                        cameraManager.setFocus(at: point)
                        haptics.light()
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newZoom = max(1.0, min(cameraManager.zoomFactor * value, 10.0))
                                cameraManager.setZoom(newZoom)
                            }
                    )
                    
                    // Camera filter overlay
                    if selectedCameraFilter != .none {
                        Rectangle()
                            .fill(selectedCameraFilter.color.opacity(0.25))
                            .blendMode(selectedCameraFilter == .noir || selectedCameraFilter == .mono ? .color : .overlay)
                            .ignoresSafeArea(.all)
                            .allowsHitTesting(false)
                        
                        if selectedCameraFilter == .mono {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .blendMode(.saturation)
                                .ignoresSafeArea(.all)
                                .allowsHitTesting(false)
                        }
                    }
                } else {
                    // Non-camera dynamic background
                    selectedMode.gradient
                        .ignoresSafeArea(.all)
                        .transition(.opacity)
                    
                    // Subtle glowing ambient shapes for Course/Event/Post
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: geometry.size.width * 1.5, height: geometry.size.width * 1.5)
                        .blur(radius: 80)
                        .offset(x: UIScreen.main.bounds.width * 0.5, y: -UIScreen.main.bounds.height * 0.2)
                }

                // MARK: - Cinematic Vignette
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.3),
                        Color.clear,
                        Color.clear,
                        Color.black.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all)

                // MARK: - AI Welcome Banner
                if showWelcomeBanner && !cameraManager.isRecording {
                    AISuggestionBanner(
                        suggestion: cameraManager.aiSuggestions.first ?? "Ready to create something amazing?",
                        isVisible: $showWelcomeBanner
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: - Main UI Overlay
                VStack(spacing: 0) {
                    // Top Controls
                    topControlsBar

                    if selectedMode.requiresCamera {
                        Spacer()
                    }

                    ZStack {
                        // Center Content Area (Camera overlays)
                        HStack {
                            // Gallery Quick Access
                            if selectedMode != .course && selectedMode != .event {
                                VStack(spacing: 16) {
                                    galleryThumbnails
                                    Spacer()
                                }
                            }
                            
                            Spacer()
                            
                            // Right Side Tool Panel
                            if selectedMode.requiresCamera {
                                rightSideToolPanel
                            }
                        }
                        .padding(.horizontal, 16)
                        .opacity(cameraManager.isRecording ? 0.3 : 1.0)
                        
                        // Mode Specific Forms for non-camera modes
                        if !selectedMode.requiresCamera {
                            modeSpecificContent
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: cameraManager.isRecording)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedMode)

                    if selectedMode.requiresCamera {
                        Spacer()
                    }

                    // Bottom Controls
                    bottomControlsSection
                }

                // MARK: - AI Suggestions Panel
                if showAISuggestions {
                    AISuggestionsPanel(
                        suggestions: cameraManager.aiSuggestions,
                        isVisible: $showAISuggestions,
                        onSuggestionTap: { suggestion in
                            haptics.medium()
                            // Handle AI suggestion selection
                            showAISuggestions = false
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: - Recording Progress Indicator
                if cameraManager.isRecording {
                    VStack {
                        RecordingProgressBar(
                            progress: cameraManager.recordingProgress,
                            duration: cameraManager.formattedDuration
                        )
                        .padding(.top, geometry.safeAreaInsets.top + 60)

                        Spacer()
                    }
                    .transition(.opacity)
                }

                // MARK: - Focus Animation
                if let focusPoint = cameraManager.focusPoint {
                    FocusAnimationView(point: focusPoint, size: geometry.size)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            cameraManager.checkPermissions()
            setupInitialState()
        }
        .onDisappear {
            // Don't kill the session if a fullScreenCover is being presented —
            // those child views share this cameraManager and need the session alive.
            guard !showClipsStudio, !showStoriesStudio, !showPostEditor else { return }
            cameraManager.cleanup()
        }
        .onChange(of: selectedMode) { _, newMode in
            modeChanged(to: newMode)
        }
        .onChange(of: cameraManager.recordedVideoURL) { _, videoURL in
            if let videoURL = videoURL {
                handleRecordingComplete(videoURL: videoURL)
            }
        }
        .onChange(of: cameraManager.capturedPhoto) { _, photo in
            if let photo = photo {
                handlePhotoCapture(photo: photo)
            }
        }
        .sheet(isPresented: $showModeDetail) {
            CreateModeDetailView(
                mode: selectedMode,
                capturedMedia: capturedMedia,
                cameraManager: cameraManager
            )
        }
        .sheet(isPresented: $showPublishFlow) {
            PublishFlowView(
                mode: selectedMode,
                capturedMedia: capturedMedia,
                contentStorage: contentStorage,
                onComplete: {
                    showPublishFlow = false
                    dismiss()
                }
            )
        }
        .fullScreenCover(isPresented: $showClipsStudio) {
            ClipsRecordingView(cameraManager: cameraManager)
        }
        .fullScreenCover(isPresented: $showStoriesStudio) {
            StoriesRecordingView(cameraManager: cameraManager)
        }
        .fullScreenCover(isPresented: $showPostEditor) {
            PostEditorView(isPresented: $showPostEditor)
        }
        // MARK: - Tool Sheets
        .sheet(isPresented: $showMusicPicker) {
            musicPickerSheet
        }
        .sheet(isPresented: $showEffectsPicker) {
            effectsPickerSheet
        }
        .sheet(isPresented: $showAIQuizSheet) {
            aiQuizSheet
        }
        .sheet(isPresented: $showSlidesPicker) {
            slidesPickerSheet
        }
    }

    // MARK: - Top Controls Bar

    private var topControlsBar: some View {
        HStack {
            // Close Button
            Button {
                haptics.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }

            Spacer()

            // Dynamic Mode Label
            VStack(spacing: 2) {
                Text("Lyo Create Studio")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(selectedMode.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .animation(.easeInOut, value: selectedMode)
            }

            Spacer()

            // AI Assistant Button
            Button {
                haptics.light()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showAISuggestions.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )

                    HStack(spacing: 2) {
                        Text("✨")
                            .font(.system(size: 12))
                        Text("AI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .scaleEffect(showAISuggestions ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showAISuggestions)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Gallery Thumbnails

    private var galleryThumbnails: some View {
        VStack(spacing: 8) {
            ForEach(0..<min(3, cameraManager.recentPhotos.count), id: \.self) { index in
                Button {
                    haptics.light()
                    showGallery = true
                } label: {
                    if index < cameraManager.recentPhotos.count {
                        Image(uiImage: cameraManager.recentPhotos[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Mode Specific Content (For Non-Camera Modes)
    
    @ViewBuilder
    private var modeSpecificContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 12) {
                Label(modeTitle, systemImage: modeIcon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2)
                
                Text(modeSubtitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Tap the button below to get started.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var modeTitle: String {
        switch selectedMode {
        case .post: return "NEW POST"
        case .course: return "AI COURSE BUILDER"
        case .event: return "COMMUNITY EVENT"
        default: return ""
        }
    }
    
    private var modeIcon: String {
        switch selectedMode {
        case .post: return "square.and.pencil"
        case .course: return "sparkles"
        case .event: return "calendar"
        default: return ""
        }
    }
    
    private var modeSubtitle: String {
        switch selectedMode {
        case .post: return "Share what's on your mind with the community."
        case .course: return "What would you like to master today?"
        case .event: return "Organize a meetup or study group."
        default: return ""
        }
    }

    // MARK: - Right Side Tool Panel

    private var rightSideToolPanel: some View {
        VStack(spacing: 16) {
            // Speed Control
            GlassMorphicToolButton(
                icon: cameraManager.speedText,
                isText: true,
                action: {
                    haptics.light()
                    cameraManager.cycleSpeed()
                }
            )

            // Timer
            GlassMorphicToolButton(
                icon: cameraManager.timer > 0 ? "\(cameraManager.timer)" : "timer",
                isText: cameraManager.timer > 0,
                action: {
                    haptics.light()
                    cycleTimer()
                }
            )

            // Sound/Music
            GlassMorphicToolButton(
                icon: "music.note",
                action: {
                    haptics.light()
                    showMusicPicker = true
                }
            )

            // Effects
            GlassMorphicToolButton(
                icon: "camera.filters",
                isActive: selectedCameraFilter != .none,
                action: {
                    haptics.light()
                    showEffectsPicker = true
                }
            )

            // Flash/Torch
            GlassMorphicToolButton(
                icon: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash",
                isActive: cameraManager.isFlashOn,
                action: {
                    haptics.light()
                    cameraManager.toggleFlash()
                }
            )

            // Flip Camera
            GlassMorphicToolButton(
                icon: "arrow.triangle.2.circlepath.camera",
                action: {
                    haptics.medium()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        recordButtonRotation += 180
                    }
                    cameraManager.switchCamera()
                }
            )
            .rotationEffect(.degrees(recordButtonRotation))

            // AI Quiz Addition
            GlassMorphicToolButton(
                icon: "🧠",
                isText: true,
                action: {
                    haptics.medium()
                    showAIQuizSheet = true
                }
            )

            // Add Slides
            GlassMorphicToolButton(
                icon: "📄",
                isText: true,
                action: {
                    haptics.light()
                    showSlidesPicker = true
                }
            )
        }
    }

    // MARK: - Bottom Controls Section

    private var bottomControlsSection: some View {
        VStack(spacing: 20) {
            // Mode Selector
            ModeSelector(
                selectedMode: $selectedMode,
                modes: CreateMode.allCases
            )
            .opacity(modeSelectorOpacity)
            .animation(.easeInOut(duration: 0.3), value: modeSelectorOpacity)

            // Record Button
            RecordButton(
                mode: selectedMode,
                isRecording: cameraManager.isRecording,
                scale: recordButtonScale,
                action: handleRecordButtonTap
            )
            .scaleEffect(recordButtonScale)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: recordButtonScale)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func setupInitialState() {
        // Initialize with a welcoming animation
        withAnimation(.easeOut(duration: 2.0).delay(1.0)) {
            showWelcomeBanner = false
        }
    }

    private func modeChanged(to mode: CreateMode) {
        haptics.selection()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            recordButtonScale = 0.9
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                recordButtonScale = 1.0
            }
        }
    }

    private func handleRecordButtonTap() {
        haptics.heavy()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recordButtonScale = 0.85
        }

        if selectedMode == .clip {
            // Clips get their own dedicated recording studio
            showClipsStudio = true
        } else if selectedMode == .story {
            // Stories use hands-free, interactive studio experience
            showStoriesStudio = true
        } else if selectedMode == .reel {
            if cameraManager.isRecording {
                cameraManager.stopRecording()
                modeSelectorOpacity = 1.0
            } else {
                cameraManager.startRecording()
                modeSelectorOpacity = 0.3
            }
        } else if selectedMode == .post {
            // Posts open the Camera Roll with caption editor
            showPostEditor = true
        } else {
            // For course, live modes - show detail view
            showModeDetail = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                recordButtonScale = 1.0
            }
        }
    }

    private func cycleTimer() {
        let timers = [0, 3, 10]
        guard let currentIndex = timers.firstIndex(of: cameraManager.timer) else { return }
        let nextIndex = (currentIndex + 1) % timers.count
        cameraManager.setTimer(timers[nextIndex])
    }

    // MARK: - Recording Completion Handlers

    private func handleRecordingComplete(videoURL: URL) {
        Log.ui.info("📹 Recording completed: \(videoURL)")

        // Validate the URL is a file URL and exists
        guard videoURL.isFileURL else {
            Log.ui.error("Recorded URL is not a file URL: \(videoURL)")
            HapticManager.shared.error()
            return
        }

        let path = videoURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            Log.ui.error("Recorded file does not exist at path: \(path)")
            HapticManager.shared.error()
            return
        }

        // Keep a strong reference in capturedMedia
        capturedMedia = CapturedMedia(
            videoURL: videoURL,
            mode: selectedMode
        )

        // Optionally save to Photos, but proceed regardless of outcome
        Task { @MainActor in
            // Request add-only permission for saving
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if status == .authorized || status == .limited {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            Log.ui.error("Failed to save video to Photos: \(error.localizedDescription)")
                        } else if success {
                            Log.ui.info("✅ Video saved to Photos")
                        }
                        // Show publish flow regardless
                        showPublishFlow = true
                        recordingComplete = true
                        haptics.success()
                    }
                }
            } else {
                Log.ui.error("Photos permission not granted for saving video")
                // Continue without saving
                showPublishFlow = true
                recordingComplete = true
                haptics.success()
            }
        }
    }

    private func handlePhotoCapture(photo: UIImage) {
        Log.ui.info("📷 Photo captured for \(selectedMode.rawValue)")

        // Create captured media object
        capturedMedia = CapturedMedia(
            image: photo,
            mode: selectedMode
        )

        // For stories, show publish flow immediately
        if selectedMode == .story {
            showPublishFlow = true
        } else {
            showModeDetail = true
        }

        // Haptic feedback for capture
        haptics.success()
    }
}

// MARK: - Captured Media Model

struct CapturedMedia {
    let image: UIImage?
    let videoURL: URL?
    let mode: CreateMode
    let timestamp: Date

    init(image: UIImage? = nil, videoURL: URL? = nil, mode: CreateMode) {
        self.image = image
        self.videoURL = videoURL
        self.mode = mode
        self.timestamp = Date()
    }
}

// MARK: - Camera Filter Preset

enum CameraFilterPreset: String, CaseIterable, Identifiable {
    case none = "None"
    case warmth = "Warmth"
    case coolTone = "Cool"
    case vivid = "Vivid"
    case noir = "Noir"
    case mono = "Mono"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "circle"
        case .warmth: return "sun.max.fill"
        case .coolTone: return "snowflake"
        case .vivid: return "paintpalette.fill"
        case .noir: return "circle.lefthalf.filled"
        case .mono: return "circle.grid.3x3.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .white.opacity(0.3)
        case .warmth: return .orange
        case .coolTone: return .cyan
        case .vivid: return .purple
        case .noir: return .gray
        case .mono: return .white
        }
    }
}

// MARK: - Hub Tool Sheet Views

extension LyoCreateStudioView {
    
    // MARK: - Music Picker Sheet
    
    var musicPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(BackgroundMusicPreset.presets) { preset in
                        Button {
                            haptics.selection()
                            // Music only plays in Clips mode; here we just show the selection
                            showMusicPicker = false
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "6366F1"))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(hex: "6366F1").opacity(0.15))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(preset.genre)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                if preset.fileName == nil {
                                    Text("Off")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                } else {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: "6366F1"))
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                    }
                    
                    Text("Background music is active during Clips recording mode.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(hex: "0F0F1A").ignoresSafeArea())
            .navigationTitle("Background Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showMusicPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Effects Picker Sheet
    
    var effectsPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Camera Filters")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(CameraFilterPreset.allCases) { filter in
                        Button {
                            selectedCameraFilter = filter
                            haptics.selection()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(filter.color.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: filter.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(filter.color)
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedCameraFilter == filter
                                            ? Color(hex: "6366F1")
                                            : Color.clear,
                                            lineWidth: 3
                                        )
                                        .frame(width: 64, height: 64)
                                )
                                
                                Text(filter.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(
                                        selectedCameraFilter == filter
                                        ? .white : .white.opacity(0.6)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                Text("Filters apply to Reel-mode direct recording.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 20)
            }
            .padding(.top, 20)
            .background(Color(hex: "0F0F1A").ignoresSafeArea())
            .navigationTitle("Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { showEffectsPicker = false }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - AI Quiz Sheet
    
    var aiQuizSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "EC4899")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("AI Quiz Generator")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Add an interactive quiz overlay to your recording. AI will generate relevant questions based on your topic.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quiz Topic")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("e.g. Photosynthesis, Algebra...", text: $aiQuizTopic)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .padding(.horizontal, 24)
                
                Button {
                    haptics.medium()
                    // Quiz overlay would be added to the recording
                    showAIQuizSheet = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Generate Quiz")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .disabled(aiQuizTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(aiQuizTopic.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 30)
            .background(Color(hex: "0F0F1A").ignoresSafeArea())
            .navigationTitle("Quiz Overlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAIQuizSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Slides Picker Sheet
    
    var slidesPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "F97316"), Color(hex: "EAB308")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Import Slides")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Import images or PDF pages as slide overlays that display during your recording.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 12) {
                    Button {
                        haptics.light()
                        // Would open photo picker for slide images
                        showSlidesPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 20))
                            Text("Choose from Photos")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    
                    Button {
                        haptics.light()
                        // Would open file picker for PDFs
                        showSlidesPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                            Text("Import PDF")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 30)
            .background(Color(hex: "0F0F1A").ignoresSafeArea())
            .navigationTitle("Slide Overlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSlidesPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    LyoCreateStudioView()
}
