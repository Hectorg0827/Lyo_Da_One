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

    // MARK: - Animation State
    @State private var recordButtonScale: CGFloat = 1.0
    @State private var recordButtonRotation: Double = 0
    @State private var modeSelectorOpacity: Double = 1.0
    @State private var overlayOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Full Screen Camera Preview
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

                    Spacer()

                    // Center Content Area
                    HStack {
                        // Gallery Quick Access
                        VStack(spacing: 16) {
                            galleryThumbnails
                            Spacer()
                        }

                        Spacer()

                        // Right Side Tool Panel
                        rightSideToolPanel
                    }
                    .padding(.horizontal, 16)
                    .opacity(cameraManager.isRecording ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: cameraManager.isRecording)

                    Spacer()

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
                    // Handle music selection
                }
            )

            // Effects
            GlassMorphicToolButton(
                icon: "camera.filters",
                action: {
                    haptics.light()
                    // Handle effects
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
                    // Handle AI quiz addition
                }
            )

            // Add Slides
            GlassMorphicToolButton(
                icon: "📄",
                isText: true,
                action: {
                    haptics.light()
                    // Handle slide addition
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

        if selectedMode == .clip || selectedMode == .reel {
            if cameraManager.isRecording {
                cameraManager.stopRecording()
                modeSelectorOpacity = 1.0
            } else {
                cameraManager.startRecording()
                modeSelectorOpacity = 0.3
            }
        } else if selectedMode == .story {
            cameraManager.capturePhoto()
        } else {
            // For course, post, live modes - show detail view
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

        // Create captured media object
        capturedMedia = CapturedMedia(
            videoURL: videoURL,
            mode: selectedMode
        )

        // Show publish flow
        showPublishFlow = true
        recordingComplete = true

        // Haptic feedback for completion
        haptics.success()
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

// MARK: - Preview

#Preview {
    LyoCreateStudioView()
}