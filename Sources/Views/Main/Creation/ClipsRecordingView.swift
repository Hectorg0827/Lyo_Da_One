//
//  ClipsRecordingView.swift
//  Lyo
//
//  The dedicated Clips recording experience — a full-screen educational studio
//  composing the Teleprompter, Chapter Progress Bar, Educational Overlays,
//  and camera preview with backend-connected publishing via ClipService.
//

import SwiftUI
import AVFoundation

// MARK: - Clips Recording View

struct ClipsRecordingView: View {
    @StateObject private var viewModel = ClipsViewModel()
    @ObservedObject var cameraManager: EnhancedCameraManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // MARK: - Camera Preview Layer
            cameraPreviewLayer
            
            // MARK: - Recording Overlays (on top of camera)
            VStack(spacing: 0) {
                // Top area — Teleprompter + close button
                topControls
                
                Spacer()
                
                // Chapter Progress Bar
                ChapterProgressBar(
                    chapters: viewModel.chapters,
                    activeIndex: viewModel.activeChapterIndex,
                    isRecording: viewModel.isRecordingChapter,
                    onSelectChapter: { viewModel.selectChapter(at: $0) },
                    onReRecord: { viewModel.reRecordChapter(at: $0) }
                )
                .padding(.bottom, 8)
                
                // Bottom Controls
                bottomControls
            }
            
            // MARK: - Educational Overlay Tray (slides up from bottom)
            if viewModel.isOverlayTrayVisible {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.toggleOverlayTray() }
                
                VStack {
                    Spacer()
                    EducationalOverlayTray(
                        selectedType: $viewModel.selectedOverlayType,
                        activeOverlays: $viewModel.activeOverlays,
                        selectedMusic: $viewModel.selectedMusic,
                        isDuckingEnabled: $viewModel.isDuckingEnabled,
                        musicVolume: $viewModel.musicVolume,
                        onAddOverlay: {
                            viewModel.addOverlay(at: CGPoint(x: 0.5, y: 0.5))
                        },
                        onDismiss: { viewModel.toggleOverlayTray() }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // MARK: - Publish Success Overlay
            if viewModel.isPublishComplete {
                publishSuccessOverlay
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .sheet(isPresented: $viewModel.showMetadataSheet) {
            metadataSheet
        }
        // Listen for when a recording finishes to save the chapter
        .onChange(of: cameraManager.recordedVideoURL) { _, newURL in
            if let url = newURL, viewModel.isRecordingChapter {
                viewModel.stopRecordingChapter(
                    videoURL: url,
                    duration: cameraManager.recordingDuration
                )
            }
        }
    }
    
    // MARK: - Camera Preview
    
    private var cameraPreviewLayer: some View {
        ZStack {
            // Use the existing StudioCameraPreviewLayer component
            StudioCameraPreviewLayer(
                session: cameraManager.session,
                focusPoint: .constant(cameraManager.focusPoint)
            )
            .ignoresSafeArea()
            
            // Gradient scrim at top & bottom
            VStack {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()
            
            // Active overlay elements (rendered on the camera)
            ForEach(viewModel.activeOverlays) { overlay in
                overlayElement(overlay)
            }
        }
    }
    
    // MARK: - Overlay Element Rendered on Camera
    
    private func overlayElement(_ overlay: EducationalOverlay) -> some View {
        VStack(spacing: 4) {
            Image(systemName: overlay.type.icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(overlay.content)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(overlay.type.color.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: overlay.type.color.opacity(0.4), radius: 10)
        .position(
            x: UIScreen.main.bounds.width * overlay.position.x,
            y: UIScreen.main.bounds.height * overlay.position.y
        )
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        VStack(spacing: 0) {
            // Safe area spacer
            Color.clear.frame(height: 54)
            
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
                
                // Clips identity badge
                HStack(spacing: 6) {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("CLIPS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(1.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
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
                .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 8)
                
                Spacer()
                
                // Timer / duration display
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isRecordingChapter ? .red : .white.opacity(0.5))
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.formattedTotalDuration)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Teleprompter (conditionally shown)
            if viewModel.isTeleprompterVisible {
                TeleprompterOverlayView(
                    scriptText: $viewModel.scriptText,
                    scrollSpeed: $viewModel.scrollSpeed,
                    isPaused: $viewModel.isTeleprompterPaused,
                    opacity: $viewModel.teleprompterOpacity,
                    onDismiss: { viewModel.toggleTeleprompter() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Right-side tool strip (vertical)
            HStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Flip camera
                    toolButton(icon: "arrow.triangle.2.circlepath", label: "Flip") {
                        cameraManager.switchCamera()
                    }
                    
                    // Flash
                    toolButton(icon: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill", label: "Flash", isActive: cameraManager.isFlashOn) {
                        cameraManager.toggleFlash()
                    }
                    
                    // Teleprompter
                    toolButton(icon: "text.justify.left", label: "Script", isActive: viewModel.isTeleprompterVisible) {
                        viewModel.toggleTeleprompter()
                    }
                    
                    // Educational Overlays
                    toolButton(icon: "sparkles.rectangle.stack", label: "Learn", isActive: viewModel.isOverlayTrayVisible) {
                        viewModel.toggleOverlayTray()
                    }
                }
                .padding(.trailing, 16)
            }
            
            // Record + Publish controls
            HStack(alignment: .center, spacing: 32) {
                // Chapter info
                VStack(spacing: 2) {
                    Text(viewModel.activeChapter.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.activeChapter.color)
                    
                    Text("\(viewModel.completedChapterCount)/\(viewModel.chapters.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 60)
                
                // Record button
                recordButton
                
                // Publish button (only when all recorded)
                if viewModel.allChaptersRecorded {
                    publishButton
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Color.clear.frame(width: 60, height: 44)
                }
            }
            .padding(.bottom, 36)
        }
    }
    
    // MARK: - Tool Button
    
    private func toolButton(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isActive ? .cyan : .white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(isActive ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Record Button
    
    private var recordButton: some View {
        Button {
            if viewModel.isRecordingChapter {
                // Stop recording — onChange handler will save the chapter when recordedVideoURL updates
                cameraManager.stopRecording()
            } else {
                viewModel.startRecordingChapter()
                cameraManager.startRecording()
            }
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        viewModel.isRecordingChapter
                        ? Color.red
                        : viewModel.activeChapter.color,
                        lineWidth: 4
                    )
                    .frame(width: 72, height: 72)
                
                // Inner shape
                if viewModel.isRecordingChapter {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(viewModel.activeChapter.color)
                        .frame(width: 58, height: 58)
                }
            }
            .shadow(
                color: viewModel.isRecordingChapter ? .red.opacity(0.5) : viewModel.activeChapter.color.opacity(0.4),
                radius: 12
            )
        }
        .scaleEffect(viewModel.isRecordingChapter ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: viewModel.isRecordingChapter)
    }
    
    // MARK: - Publish Button
    
    private var publishButton: some View {
        Button {
            viewModel.showMetadataSheet = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                
                Text("Publish")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 60)
        }
    }
    
    // MARK: - Metadata Sheet (feeds ClipService → backend)
    
    private var metadataSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Title", systemImage: "pencil.line")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("What are you teaching?", text: $viewModel.clipTitle)
                            .font(.system(size: 16, weight: .medium))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Description", systemImage: "text.alignleft")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Brief description...", text: $viewModel.clipDescription, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(3...6)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    
                    // Subject picker
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Subject", systemImage: "books.vertical")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ClipSubject.allCases) { subject in
                                    Button {
                                        viewModel.clipSubject = subject
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: subject.icon)
                                                .font(.system(size: 12))
                                            Text(subject.rawValue)
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .foregroundColor(
                                            viewModel.clipSubject == subject ? .white : .white.opacity(0.6)
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    viewModel.clipSubject == subject
                                                    ? Color(hex: "6366F1")
                                                    : Color.white.opacity(0.1)
                                                )
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Level picker
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Difficulty", systemImage: "chart.bar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Picker("Level", selection: $viewModel.clipLevel) {
                            ForEach(LearningLevel.allCases, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Course generation toggle
                    Toggle(isOn: $viewModel.enableCourseGeneration) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI Course Generation")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Let AI create a full course from your clip")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .tint(Color(hex: "6366F1"))
                    
                    // Publishing state
                    if viewModel.isPublishing {
                        VStack(spacing: 8) {
                            ProgressView(value: viewModel.publishProgress)
                                .tint(Color(hex: "6366F1"))
                            
                            Text("Publishing your clip...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 8)
                    }
                    
                    if let error = viewModel.publishError {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .background(Color(hex: "0F0F1A").ignoresSafeArea())
            .navigationTitle("Publish Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showMetadataSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        Task {
                            await viewModel.publishClip(cameraManager: cameraManager)
                            if viewModel.isPublishComplete {
                                viewModel.showMetadataSheet = false
                            }
                        }
                    }
                    .disabled(viewModel.clipTitle.isEmpty || viewModel.isPublishing)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(
                        viewModel.clipTitle.isEmpty || viewModel.isPublishing
                        ? .gray
                        : Color(hex: "6366F1")
                    )
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Publish Success Overlay
    
    private var publishSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "66BB6A"), Color(hex: "4CAF50")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Clip Published! 🎉")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Your educational clip is now live and ready for learners.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                if viewModel.enableCourseGeneration {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "FFA726"))
                        Text("AI is generating a course from your clip...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "FFA726"))
                    }
                    .padding(.top, 4)
                }
                
                Button {
                    viewModel.reset()
                    dismiss()
                } label: {
                    Text("Done")
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
                .padding(.horizontal, 40)
                .padding(.top, 12)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Preview

#Preview {
    ClipsRecordingView(
        cameraManager: EnhancedCameraManager()
    )
}
