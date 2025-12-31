//
//  CreateHubView.swift
//  Lyo
//
//  Full-screen camera-first creation hub inspired by TikTok/Instagram
//  Supports: Reel, Story, Post, Course, Event/Group creation
//

import SwiftUI
import AVFoundation

struct CreateHubView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CreateViewModel()
    @State private var showModeDetail = false
    
    var body: some View {
        ZStack {
            // Camera Preview or Canvas Background
            if viewModel.selectedMode.requiresCamera {
                CameraPreviewLayer(
                    capturedImage: $viewModel.capturedImage,
                    capturedVideoURL: $viewModel.capturedVideoURL,
                    cameraPosition: $viewModel.cameraPosition,
                    flashMode: $viewModel.flashMode
                )
                .ignoresSafeArea()
            } else {
                // Gradient background for non-camera modes
                LinearGradient(
                    colors: [
                        Color(hex: "0f172a"),
                        viewModel.selectedMode.color.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // UI Overlay
            VStack(spacing: 0) {
                // Top Controls
                topBar
                
                Spacer()
                
                // Mode-specific Content
                if showModeDetail {
                    modeDetailView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Center Action Button (Camera modes)
                    if viewModel.selectedMode.requiresCamera && viewModel.state == .idle {
                        captureButton
                    }
                }
                
                Spacer()
                
                // Bottom Controls
                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                if viewModel.selectedMode.requiresCamera {
                    let hasPermission = await viewModel.checkCameraPermission()
                    if !hasPermission {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showModeDetail) {
            modeDetailSheet
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Close Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Spacer()
            
            // Mode Title
            Text(viewModel.selectedMode.rawValue)
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Spacer()
            
            // Camera Controls (if camera mode)
            if viewModel.selectedMode.requiresCamera {
                HStack(spacing: 16) {
                    // Flash Toggle
                    Button {
                        viewModel.toggleFlash()
                    } label: {
                        Image(systemName: viewModel.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    // Flip Camera
                    Button {
                        viewModel.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            } else {
                // Settings/Options
                Button {
                    // Show options
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // MARK: - Capture Button
    
    private var captureButton: some View {
        Button {
            if viewModel.selectedMode == .reel {
                if viewModel.state == .recording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            } else {
                // Photo capture for story
                // This would trigger actual camera capture
                viewModel.state = .captured
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(viewModel.selectedMode.color, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if viewModel.state == .recording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 40, height: 40)
                } else {
                    Circle()
                        .fill(viewModel.selectedMode.color)
                        .frame(width: 70, height: 70)
                }
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Learn Layers Button (for camera modes)
            if viewModel.selectedMode.requiresCamera && viewModel.state == .captured {
                learnLayersButton
            }
            
            // Mode Picker
            CreateModePicker(
                selectedMode: $viewModel.selectedMode,
                onModeSelected: { mode in
                    withAnimation {
                        viewModel.selectMode(mode)
                    }
                }
            )
            .padding(.horizontal, 20)
            
            // Action Bar (Post/Edit/Next)
            if viewModel.state == .captured || !viewModel.selectedMode.requiresCamera {
                actionBar
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Learn Layers Button
    
    private var learnLayersButton: some View {
        Button {
            // Show learn layers picker
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Add Learn Layer")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(hex: "8B5CF6"))
            )
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: 20) {
            if viewModel.state == .captured {
                // Retake
                Button {
                    viewModel.state = .idle
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Retake")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.ultraThinMaterial))
                }
            }
            
            // Next/Create Button
            Button {
                showModeDetail = true
            } label: {
                HStack {
                    Text(viewModel.selectedMode.requiresCamera ? "Next" : "Create")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(viewModel.selectedMode.color)
                )
            }
        }
    }
    
    // MARK: - Mode Detail View (Inline)
    
    @ViewBuilder
    private var modeDetailView: some View {
        VStack(spacing: 0) {
            // Mode-specific editors
            switch viewModel.selectedMode {
            case .reel, .story:
                MediaEditorView(viewModel: viewModel)
            case .post:
                PostComposeView(viewModel: viewModel)
            case .course:
                CourseGenerationView(viewModel: viewModel)
            case .event:
                EventCreationView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Mode Detail Sheet
    
    @ViewBuilder
    private var modeDetailSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                switch viewModel.selectedMode {
                case .reel, .story:
                    MediaEditorView(viewModel: viewModel)
                case .post:
                    PostComposeView(viewModel: viewModel)
                case .course:
                    CourseGenerationView(viewModel: viewModel)
                case .event:
                    EventCreationView(viewModel: viewModel)
                }
            }
            .navigationTitle(viewModel.selectedMode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showModeDetail = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Publish") {
                        Task {
                            await viewModel.publish()
                            if case .complete = viewModel.state {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.state == .uploading)
                }
            }
        }
    }
}

// MARK: - Camera Preview Layer

struct CameraPreviewLayer: View {
    @Binding var capturedImage: UIImage?
    @Binding var capturedVideoURL: URL?
    @Binding var cameraPosition: AVCaptureDevice.Position
    @Binding var flashMode: AVCaptureDevice.FlashMode
    
    var body: some View {
        ZStack {
            // Show captured media or live preview
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else if let videoURL = capturedVideoURL {
                // Video preview would go here
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        Text("Video Preview")
                            .foregroundColor(.white)
                    )
            } else {
                // Live camera preview
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Camera Preview")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    )
            }
        }
    }
}

// MARK: - Media Editor View

struct MediaEditorView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Caption Input
            TextField("Add a caption...", text: $viewModel.contentText, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal)
            
            // Learn Layers Stack
            if !viewModel.learnLayers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Learn Layers")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(viewModel.learnLayers) { layer in
                        HStack {
                            Image(systemName: layer.type.icon)
                                .foregroundColor(layer.type.color)
                            Text(layer.content)
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                viewModel.removeLearnLayer(layer.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.top, 20)
    }
}

// MARK: - Post Compose View

struct PostComposeView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Text Editor
            TextEditor(text: $viewModel.contentText)
                .frame(height: 200)
                .scrollContentBackground(.hidden)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .foregroundColor(.white)
                .padding(.horizontal)
            
            // Attach Files
            Button {
                // Show file picker
            } label: {
                HStack {
                    Image(systemName: "paperclip")
                    Text("Attach Files")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 20)
    }
}

// MARK: - Course Generation View

struct CourseGenerationView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Topic Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Course Topic")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("e.g., Python Programming", text: $viewModel.courseTopic)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                
                // Level Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Level")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        ForEach(["beginner", "intermediate", "advanced"], id: \.self) { level in
                            Button {
                                viewModel.courseLevel = level
                            } label: {
                                Text(level.capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.courseLevel == level ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                        .fill(viewModel.courseLevel == level ? Color(hex: "10B981") : Color.white.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Outcomes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Learning Outcomes (Optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("AI will generate comprehensive outcomes based on your topic")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Event Creation View

struct EventCreationView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Type Toggle
                HStack(spacing: 20) {
                    Button {
                        viewModel.isGroup = false
                    } label: {
                        VStack {
                            Image(systemName: "calendar")
                                .font(.title2)
                            Text("Event")
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.isGroup ? .white.opacity(0.5) : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.isGroup ? Color.white.opacity(0.1) : Color(hex: "EC4899"))
                        )
                    }
                    
                    Button {
                        viewModel.isGroup = true
                    } label: {
                        VStack {
                            Image(systemName: "person.3.fill")
                                .font(.title2)
                            Text("Group")
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.isGroup ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.isGroup ? Color(hex: "EC4899") : Color.white.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal)
                
                // Title
                TextField("Title", text: $viewModel.eventTitle)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                // Description
                TextEditor(text: $viewModel.eventDescription)
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                // Date Picker
                DatePicker("Date", selection: $viewModel.eventDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                // Location
                TextField("Location (optional)", text: $viewModel.eventLocation)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Preview

#Preview {
    CreateHubView()
}
