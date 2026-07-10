//
//  StoriesRecordingView.swift
//  Lyo
//
//  Full-screen Stories recording studio with multi-segment recording,
//  interactive stickers, preset filters, pinch-to-zoom, and tap-to-focus.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct StoriesRecordingView: View {
    @StateObject private var viewModel = StoriesViewModel()
    @ObservedObject var cameraManager: EnhancedCameraManager
    @Environment(\.dismiss) private var dismiss
    
    // Recording timer
    @State private var recordTimer: Timer?
    @State private var currentRecordingTime: TimeInterval = 0
    
    // Zoom
    @State private var currentZoomScale: CGFloat = 1.0
    @State private var showZoomBadge: Bool = false
    
    // Photo picker for drafts/uploads
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // Sticker editing
    @State private var editingSticker: StorySticker?
    @State private var stickerEditText: String = ""
    @State private var pollOptionTexts: [String] = ["", "", ""]
    
    // Haptic
    private let haptics = HapticManager.shared
    
    var body: some View {
        ZStack {
            // MARK: - Camera Preview with Preset Overlays
            cameraPreviewArea
            
            // MARK: - Swipe to change preset
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.width < -30 {
                                    viewModel.cyclePreset(forward: true)
                                } else if value.translation.width > 30 {
                                    viewModel.cyclePreset(forward: false)
                                }
                            }
                    )
            }
            .ignoresSafeArea()
            .allowsHitTesting(!viewModel.isRecording) // Don't interfere during recording
            
            // MARK: - Main UI Overlays
            VStack(spacing: 0) {
                topControls
                Spacer()
                bottomControls
            }
            
            // MARK: - Right Sidebar (Stickers)
            HStack {
                Spacer()
                rightSidebarControls
            }
            
            // MARK: - Zoom Badge
            if showZoomBadge {
                VStack {
                    Spacer()
                    Text(String(format: "%.1f×", cameraManager.zoomFactor))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.ultraThinMaterial))
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
            
            // MARK: - Publish Overlay
            if viewModel.isPublishing || viewModel.isPublishComplete {
                publishOverlay
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onAppear {
            cameraManager.ensureSessionRunning()
        }
        .onDisappear {
            stopRecording()
            viewModel.reset()
        }
        // Save video when recording finishes
        .onChange(of: cameraManager.recordedVideoURL) { _, newURL in
            if let url = newURL {
                viewModel.addVideoSegment(url: url, duration: currentRecordingTime)
                if viewModel.isRecording {
                    viewModel.isRecording = false
                }
            }
        }
        // Save photo when captured
        .onChange(of: cameraManager.capturedPhoto) { _, newPhoto in
            if let photo = newPhoto {
                viewModel.addPhotoSegment(image: photo)
            }
        }
        // Sticker editing sheet
        .sheet(item: $editingSticker) { sticker in
            stickerEditSheet(for: sticker)
        }
        // Photo picker for drafts
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadPickedMedia(newItem)
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
            // Pinch-to-zoom
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newZoom = max(1.0, min(currentZoomScale * value, 10.0))
                        cameraManager.setZoom(newZoom)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showZoomBadge = true
                        }
                    }
                    .onEnded { _ in
                        currentZoomScale = cameraManager.zoomFactor
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showZoomBadge = false
                            }
                        }
                    }
            )
            // Tap-to-focus
            .onTapGesture { location in
                let screenSize = UIScreen.main.bounds.size
                let point = CGPoint(
                    x: location.x / screenSize.width,
                    y: location.y / screenSize.height
                )
                cameraManager.setFocus(at: point)
                haptics.light()
            }
            
            // Preset color overlay
            if viewModel.currentPreset != .normal {
                Color(viewModel.currentPreset.colorOverlay)
                    .blendMode(viewModel.currentPreset.blendMode)
                    .ignoresSafeArea()
            }
            
            if viewModel.currentPreset == .bwProfessional {
                Color.black.opacity(0.8)
                    .blendMode(.color)
                    .ignoresSafeArea()
            }
            
            // Gradient scrims
            VStack {
                LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 180)
            }
            .ignoresSafeArea()
            
            // Preset label (fades)
            if !viewModel.isRecording {
                VStack {
                    Spacer()
                    Text(viewModel.currentPreset.rawValue)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4).cornerRadius(8))
                        .padding(.bottom, 180)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.currentPreset)
                }
            }
            
            // Active stickers — draggable
            ForEach(viewModel.activeStickers) { sticker in
                draggableStickerElement(sticker)
            }
        }
    }
    
    // MARK: - Draggable Sticker
    
    private func draggableStickerElement(_ sticker: StorySticker) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        return VStack(spacing: 6) {
            Image(systemName: sticker.type.icon)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(sticker.content)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sticker.type.color.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
        )
        .shadow(color: sticker.type.color.opacity(0.5), radius: 12)
        .position(
            x: screenWidth * sticker.position.x,
            y: screenHeight * sticker.position.y
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newX = max(0.05, min(0.95, value.location.x / screenWidth))
                    let newY = max(0.05, min(0.95, value.location.y / screenHeight))
                    viewModel.updateStickerPosition(sticker.id, to: CGPoint(x: newX, y: newY))
                }
        )
        // Tap to edit content
        .onTapGesture {
            stickerEditText = sticker.content
            editingSticker = sticker
            haptics.light()
        }
        // Long press to delete
        .onLongPressGesture {
            haptics.medium()
            viewModel.removeSticker(sticker.id)
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        VStack(spacing: 12) {
            Color.clear.frame(height: 54) // Safe area
            
            // Dynamic segment dashes
            HStack(spacing: 4) {
                if viewModel.hasSegments || viewModel.isRecording {
                    // Show real segment progress
                    ForEach(0..<viewModel.maxSegments, id: \.self) { i in
                        Capsule()
                            .fill(segmentColor(for: i))
                            .frame(height: 3)
                    }
                } else {
                    // Empty state — show placeholder dashes
                    ForEach(0..<viewModel.maxSegments, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 3)
                    }
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
                
                // Story badge with segment count
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
                
                // Right side: flash + flip
                HStack(spacing: 12) {
                    // Flash toggle
                    Button {
                        cameraManager.toggleFlash()
                        haptics.light()
                    } label: {
                        Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    // Flip camera
                    Button {
                        cameraManager.switchCamera()
                        haptics.medium()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Recording timer
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    
                    Text(String(format: "%.1fs", currentRecordingTime))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(.ultraThinMaterial))
            }
        }
    }
    
    /// Color for each segment dash.
    private func segmentColor(for index: Int) -> Color {
        if index < viewModel.recordedSnippetsCount {
            return .white  // Recorded
        } else if index == viewModel.recordedSnippetsCount && viewModel.isRecording {
            return .red     // Currently recording
        } else {
            return .white.opacity(0.2)  // Pending
        }
    }
    
    // MARK: - Right Sidebar Controls
    
    private var rightSidebarControls: some View {
        VStack(spacing: 16) {
            // Interactive Stickers — now functional
            ForEach(StoryStickerType.allCases) { type in
                Button {
                    haptics.selection()
                    viewModel.addSticker(type: type)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
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
        .padding(.top, 180)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Undo segment button (if segments exist)
            if viewModel.hasSegments && !viewModel.isRecording {
                Button {
                    viewModel.deleteLastSegment()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .bold))
                        Text("Undo")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                }
            }
            
            HStack(alignment: .center) {
                // Left: Hands-Free
                Button {
                    viewModel.isHandsFreeMode.toggle()
                    haptics.light()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.isHandsFreeMode ? "hand.raised.slash.fill" : "hand.raised.fill")
                            .font(.system(size: 22))
                            .foregroundColor(viewModel.isHandsFreeMode ? .cyan : .white)
                        
                        Text("Hands-Free")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80)
                
                Spacer()
                
                // Center: Shutter Button
                versatileShutterButton
                
                Spacer()
                
                // Right: Drafts / Gallery upload
                Button {
                    haptics.light()
                    showPhotoPicker = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                        
                        Text("Upload")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80)
            }
            .padding(.horizontal, 30)
            
            // Publish button (when segments exist)
            if viewModel.hasSegments && !viewModel.isRecording {
                Button {
                    Task {
                        await viewModel.publishStory(videoURL: nil, image: nil)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Share Story")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "EC4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .padding(.horizontal, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 50)
        .padding(.top, 16)
        .background(
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .top)
        )
    }
    
    // MARK: - Shutter Button
    
    private var versatileShutterButton: some View {
        ZStack {
            // Outer ring with progress
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 6)
                .frame(width: 80, height: 80)
            
            if viewModel.isRecording {
                Circle()
                    .trim(from: 0, to: currentRecordingTime / viewModel.maxSegmentDuration)
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
            
            // Inner button
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.white)
                .frame(
                    width: viewModel.isRecording ? 40 : 64,
                    height: viewModel.isRecording ? 40 : 64
                )
                .animation(.spring(), value: viewModel.isRecording)
            
            // Segment count badge
            if viewModel.hasSegments && !viewModel.isRecording {
                VStack {
                    Spacer()
                    Text("\(viewModel.recordedSnippetsCount)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color(hex: "6366F1")))
                        .offset(x: 30, y: -5)
                }
                .frame(width: 80, height: 80)
            }
        }
        // Long press → video
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    if !viewModel.isRecording && viewModel.canRecordMore {
                        startRecording()
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if viewModel.isRecording && !viewModel.isHandsFreeMode {
                        stopRecording()
                    } else if !viewModel.isRecording {
                        // Short tap → photo
                        capturePhoto()
                    }
                }
        )
        .opacity(viewModel.canRecordMore || viewModel.isRecording ? 1.0 : 0.4)
        .disabled(!viewModel.canRecordMore && !viewModel.isRecording)
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        guard viewModel.canRecordMore else { return }
        haptics.heavy()
        cameraManager.capturePhoto()
    }
    
    private func startRecording() {
        haptics.heavy()
        viewModel.isRecording = true
        currentRecordingTime = 0
        cameraManager.startRecording()
        
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor in
                currentRecordingTime += 0.1
                if currentRecordingTime >= viewModel.maxSegmentDuration {
                    stopRecording()
                }
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
    
    // MARK: - Load Picked Media
    
    private func loadPickedMedia(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        // Try loading as image first
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run {
                viewModel.addPhotoSegment(image: image)
            }
        }
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
                    
                    Text(publishStatusText)
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
                    
                    Text("Story Shared! 🎉")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if viewModel.recordedSnippetsCount > 1 {
                        Text("\(viewModel.recordedSnippetsCount) segments merged and published")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Button {
                        viewModel.reset()
                        dismiss()
                    } label: {
                        Text("Awesome")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "6366F1"), Color(hex: "EC4899")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .padding(.top, 20)
                }
                
                if let error = viewModel.publishError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    
                    Button("Try Again") {
                        viewModel.publishError = nil
                        viewModel.isPublishing = false
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
    
    private var publishStatusText: String {
        if viewModel.publishProgress < 0.3 {
            return "Merging segments..."
        } else if viewModel.publishProgress < 0.6 {
            return "Uploading your story..."
        } else {
            return "Almost there..."
        }
    }
}

#Preview {
    StoriesRecordingView(cameraManager: EnhancedCameraManager())
}

// MARK: - Sticker Edit Sheet

extension StoriesRecordingView {
    
    func stickerEditSheet(for sticker: StorySticker) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Sticker type header
                HStack(spacing: 12) {
                    Image(systemName: sticker.type.icon)
                        .font(.system(size: 28))
                        .foregroundColor(sticker.type.color)
                    
                    Text("Edit \(sticker.type.rawValue)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // Type-specific content
                switch sticker.type {
                case .qa:
                    qaEditContent
                case .poll:
                    pollEditContent
                case .countdown:
                    countdownEditContent
                }
                
                Spacer()
                
                // Apply button
                Button {
                    applyStickerEdit(sticker)
                } label: {
                    Text("Apply")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(sticker.type.color)
                        )
                }
                .padding(.horizontal, 24)
                
                // Delete sticker
                Button {
                    viewModel.removeSticker(sticker.id)
                    editingSticker = nil
                } label: {
                    Text("Remove Sticker")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 30)
            .background(Color(hex: "0F0F1A").ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingSticker = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // Q&A: question text
    private var qaEditContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Question")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("Ask your audience something...", text: $stickerEditText)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
            
            Text("Viewers can tap to answer during playback.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 24)
    }
    
    // Poll: multiple options
    private var pollEditContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Poll Question")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("What should I teach next?", text: $stickerEditText)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
            
            Text("Options")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            ForEach(0..<3, id: \.self) { i in
                TextField("Option \(i + 1)", text: $pollOptionTexts[i])
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
        .padding(.horizontal, 24)
    }
    
    // Countdown: time display
    private var countdownEditContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Countdown Label")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("e.g. Exam in..., Quiz starts in...", text: $stickerEditText)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
            
            Text("Countdown timer will overlay on the story.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 24)
    }
    
    private func applyStickerEdit(_ sticker: StorySticker) {
        if let index = viewModel.activeStickers.firstIndex(where: { $0.id == sticker.id }) {
            let displayText: String
            switch sticker.type {
            case .qa:
                displayText = stickerEditText.isEmpty ? "Q&A" : stickerEditText
            case .poll:
                let question = stickerEditText.isEmpty ? "Poll" : stickerEditText
                let filledOptions = pollOptionTexts.filter { !$0.isEmpty }
                displayText = filledOptions.isEmpty ? question : "\(question)\n" + filledOptions.joined(separator: " | ")
            case .countdown:
                displayText = stickerEditText.isEmpty ? "Countdown" : stickerEditText
            }
            viewModel.activeStickers[index].content = displayText
        }
        editingSticker = nil
        haptics.success()
    }
}
