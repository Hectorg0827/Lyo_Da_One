//
//  StoriesRecordingView.swift
//  Lyo
//
//  The dedicated Stories recording experience — a full-screen dynamic studio
//  focusing on "Behind-the-Scenes" (BTS) and "Community Engagement".

import SwiftUI
import AVFoundation

struct StoriesRecordingView: View {
    @StateObject private var viewModel = StoriesViewModel()
    @ObservedObject var cameraManager: EnhancedCameraManager
    @Environment(\.dismiss) private var dismiss
    
    // Timer for hold-to-record
    @State private var recordTimer: Timer?
    @State private var currentRecordingTime: TimeInterval = 0
    let maxRecordingTime: TimeInterval = 15.0 // 15 seconds max for stories
    
    // Haptic
    private let haptics = HapticManager.shared
    
    var body: some View {
        ZStack {
            // MARK: - Camera Preview with Preset Overlays
            cameraPreviewArea
            
            // MARK: - Studio Preset Swipe Layer
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.width < -30 {
                                    // Swipe left (next preset)
                                    viewModel.cyclePreset(forward: true)
                                } else if value.translation.width > 30 {
                                    // Swipe right (prev preset)
                                    viewModel.cyclePreset(forward: false)
                                }
                            }
                    )
            }
            .ignoresSafeArea()
            
            // MARK: - Main UI Overlays
            VStack(spacing: 0) {
                // Top area — Story Segment dashes + close button
                topControls
                
                Spacer()
                
                // Bottom Controls
                bottomControls
            }
            
            // MARK: - Right Sidebar (Stickers)
            HStack {
                Spacer()
                rightSidebarControls
            }
            
            // MARK: - Publish Overlay
            if viewModel.isPublishing || viewModel.isPublishComplete {
                publishOverlay
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        // Cleanup on disappear
        .onDisappear {
            stopRecording()
        }
        // Save video or photo when captured
        .onChange(of: cameraManager.recordedVideoURL) { _, newURL in
            if viewModel.isRecording {
                // If it finished for some other reason
                viewModel.isRecording = false
            }
            // Present publish sheet or publish directly
            if let newURL = newURL {
                Task {
                    await viewModel.publishStory(videoURL: newURL, image: nil)
                }
            }
        }
        .onChange(of: cameraManager.capturedPhoto) { _, newPhoto in
            // Publish photo story
            if let newPhoto = newPhoto {
                Task {
                    await viewModel.publishStory(videoURL: nil, image: newPhoto)
                }
            }
        }
    }
    
    // MARK: - Camera Preview Area
    
    private var cameraPreviewArea: some View {
        ZStack {
            StudioCameraPreviewLayer(
                session: cameraManager.session,
                focusPoint: .constant(cameraManager.focusPoint)
            )
            .ignoresSafeArea()
            
            // Studio Preset Blend Overlay
            if viewModel.currentPreset != .normal {
                Color(viewModel.currentPreset.colorOverlay)
                    .blendMode(viewModel.currentPreset.blendMode)
                    .ignoresSafeArea()
            }
            
            if viewModel.currentPreset == .bwProfessional {
                // Simple B&W overlay simulating desaturation
                Color.black.opacity(0.8)
                    .blendMode(.color)
                    .ignoresSafeArea()
            }
            
            // Preset Label (Fades out)
            VStack {
                Spacer()
                Text(viewModel.currentPreset.rawValue)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5).cornerRadius(8))
                    .padding(.bottom, 150)
                    .opacity(0.8) // Ideally this fades out after a second
                    .animation(.easeInOut(duration: 0.5), value: viewModel.currentPreset)
            }
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        VStack(spacing: 12) {
            Color.clear.frame(height: 54) // Safe area
            
            // Segmented dashes
            HStack(spacing: 4) {
                // Since this is a single story recording view right now, one dash represents current recording
                // Wait, it shows the "queue". Let's mock 3 dashes.
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i == 0 ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 20)
            
            // Header bar
            HStack {
                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                
                Spacer()
                
                // Preset badge (or story badge)
                HStack(spacing: 6) {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 12, weight: .bold))
                    Text(viewModel.currentPreset.rawValue.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.0)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.4)))
                
                Spacer()
                
                // Flip camera
                Button {
                    cameraManager.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Right Sidebar Controls
    
    private var rightSidebarControls: some View {
        VStack(spacing: 20) {
            // Interactive Stickers
            ForEach(StoryStickerType.allCases) { type in
                Button {
                    haptics.selection()
                    // Add sticker logic
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(type.color.opacity(0.8))
                                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                            )
                        
                        Text(type.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.trailing, 16)
        .padding(.top, 100)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(alignment: .center) {
            
            // Left: Hands-Free (or Drafts)
            Button {
                viewModel.isHandsFreeMode.toggle()
                haptics.light()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.isHandsFreeMode ? "hand.raised.slash.fill" : "hand.raised.fill")
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.isHandsFreeMode ? .cyan : .white)
                    
                    Text("Hands-Free")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 80)
            
            Spacer()
            
            // Center: Versatile Shutter Button
            versatileShutterButton
            
            Spacer()
            
            // Right: Sticker Tray or Upload
            Button {
                haptics.light()
                // Show drafts or gallery
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text("Drafts")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 80)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 60)
        .padding(.top, 20)
        .background(
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .top)
        )
    }
    
    // MARK: - Shutter Button
    
    private var versatileShutterButton: some View {
        ZStack {
            // Outer Ring showing progress
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 6)
                .frame(width: 80, height: 80)
            
            if viewModel.isRecording {
                Circle()
                    .trim(from: 0, to: currentRecordingTime / maxRecordingTime)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color(hex: "6366F1"), Color(hex: "EC4899")]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: currentRecordingTime)
            }
            
            // Inner Button
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.white)
                .frame(width: viewModel.isRecording ? 40 : 64, height: viewModel.isRecording ? 40 : 64)
                .animation(.spring(), value: viewModel.isRecording)
            
        }
        // Combined Gesture: Tap for photo, Long Press for video
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    // Start video recording
                    if !viewModel.isRecording {
                        startRecording()
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    // If we were recording video via long press, stop it
                    if viewModel.isRecording && !viewModel.isHandsFreeMode {
                        stopRecording()
                    } else if !viewModel.isRecording {
                        // Short tap -> Photo
                        capturePhoto()
                    }
                }
        )
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        haptics.heavy()
        cameraManager.capturePhoto()
    }
    
    private func startRecording() {
        haptics.heavy()
        viewModel.isRecording = true
        currentRecordingTime = 0
        cameraManager.startRecording()
        
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            currentRecordingTime += 0.1
            
            if currentRecordingTime >= maxRecordingTime {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        guard viewModel.isRecording else { return }
        
        haptics.success()
        viewModel.isRecording = false
        recordTimer?.invalidate()
        recordTimer = nil
        cameraManager.stopRecording()
    }
    
    // MARK: - Publish Overlay
    
    private var publishOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 24) {
                if viewModel.isPublishing {
                    ProgressView(value: viewModel.publishProgress)
                        .tint(Color(hex: "6366F1"))
                        .padding(.horizontal, 40)
                    
                    Text("Sharing to your story...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                } else if viewModel.isPublishComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "66BB6A"), Color(hex: "4CAF50")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Story Shared!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Button {
                        viewModel.reset()
                        dismiss()
                    } label: {
                        Text("Awesome")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color(hex: "6366F1")))
                    }
                    .padding(.top, 20)
                }
                
                if let error = viewModel.publishError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    
                    Button("Try Again") {
                        viewModel.reset()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Capsule().stroke(Color.white, lineWidth: 1))
                }
            }
        }
    }
}

#Preview {
    StoriesRecordingView(cameraManager: EnhancedCameraManager())
}
