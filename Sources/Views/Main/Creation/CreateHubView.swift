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
    @StateObject private var viewModel: CreateViewModel
    @State private var showModeDetail = false
    let onPublish: ((CreateMode) -> Void)?

    init(initialMode: CreateMode = .reel, onPublish: ((CreateMode) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: CreateViewModel(initialMode: initialMode))
        self.onPublish = onPublish
    }

    
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
                // Gradient background for non-camera modes (TikTok aesthetic)
                LinearGradient(
                    colors: [
                        Color(hex: "0f172a"),
                        viewModel.selectedMode.color.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .background(Color.black)
                .ignoresSafeArea()
            }
            
            // Mode Detail View (Inline) - The "Canvas"
            modeDetailView
                .zIndex(5)
            
            // UI Overlay
            VStack(spacing: 0) {
                // Top Controls
                topBar
                
                // Camera/Gallery Toggle (if applicable)
                if viewModel.selectedMode.requiresCamera && viewModel.state == .idle {
                    toggleContainer
                        .padding(.top, 20)
                }
                
                Spacer()
                
                // Center Action Button (Shutter for Camera modes)
                if viewModel.selectedMode.requiresCamera {
                    if viewModel.state == .idle {
                        captureButton
                            .padding(.bottom, 60)
                    } else if viewModel.state == .captured {
                        shareCapturedMediaButton
                            .padding(.bottom, 60)
                    }
                }
                
                // Bottom Controls Island
                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.state) { oldState, newState in
            if newState == .complete {
                onPublish?(viewModel.selectedMode)
                dismiss()
            }
        }
        // ...
    }
    
    // MARK: - Toggle Container
    
    private var toggleContainer: some View {
        HStack(spacing: 8) {
            toggleButton(label: "📷 Camera", isActive: viewModel.isCameraSource) {
                viewModel.isCameraSource = true
            }
            toggleButton(label: "🖼️ Gallery", isActive: !viewModel.isCameraSource) {
                viewModel.isCameraSource = false
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func toggleButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? Color.white.opacity(0.3) : Color.clear)
                .clipShape(Capsule())
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            
            Spacer()
            
            // Mode Center Info
            VStack(spacing: 2) {
                Text("Create to Learn")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(viewModel.selectedMode.rawValue) Mode")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.white)
            
            Spacer()
            
            // Settings/Camera Flip
            Button {
                if viewModel.selectedMode.requiresCamera {
                    viewModel.toggleCamera()
                }
            } label: {
                Image(systemName: viewModel.selectedMode.requiresCamera ? "arrow.triangle.2.circlepath.camera" : "gearshape")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    
    // MARK: - Share Captured Media
    
    private var shareCapturedMediaButton: some View {
        HStack(spacing: 20) {
            // Retake
            Button {
                viewModel.state = .idle
                viewModel.capturedImage = nil
                viewModel.capturedVideoURL = nil
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Retake")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(.ultraThinMaterial))
            }
            
            // Share
            Button {
                Task { await viewModel.publish() }
            } label: {
                HStack {
                    Text("Share to \(viewModel.selectedMode.rawValue)")
                    Image(systemName: "paperplane.fill")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "42A5F5"), Color(hex: "1976D2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "42A5F5").opacity(0.4), radius: 15)
            }
        }
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
                viewModel.state = .captured
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if viewModel.selectedMode == .reel {
                    // Reel: Solid Red with glow
                    Circle()
                        .fill(Color.red)
                        .frame(width: viewModel.state == .recording ? 40 : 64, height: viewModel.state == .recording ? 40 : 64)
                        .cornerRadius(viewModel.state == .recording ? 8 : 32)
                        .shadow(color: .red.opacity(0.5), radius: 20)
                } else {
                    // Story: Blue Gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "42A5F5"), Color(hex: "1976D2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                }
            }
            .scaleEffect(viewModel.state == .recording ? 1.1 : 1.0)
            .animation(.spring(), value: viewModel.state)
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 0) {
            // Mode Picker Island
            CreateModePicker(
                selectedMode: $viewModel.selectedMode,
                onModeSelected: { mode in
                    withAnimation {
                        viewModel.selectMode(mode)
                    }
                }
            )
        }
    }
    
    // MARK: - Mode Detail View (Inline)
    
    @ViewBuilder
    private var modeDetailView: some View {
        VStack(spacing: 0) {
            switch viewModel.selectedMode {
            case .story:
                StoryModeView(viewModel: viewModel)
            case .reel, .clip:
                ReelModeView(viewModel: viewModel)
            case .post:
                PostModeView(viewModel: viewModel)
            case .course:
                CourseModeView(viewModel: viewModel)
            case .event:
                EventModeView(viewModel: viewModel)
            case .live:
                EventModeView(viewModel: viewModel)
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
                case .reel, .story, .clip:
                    MediaEditorView(viewModel: viewModel)
                case .post:
                    PostComposeView(viewModel: viewModel)
                case .course:
                    CourseGenerationView(viewModel: viewModel)
                case .event:
                    EventCreationView(viewModel: viewModel)
                case .live:
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
                                onPublish?(viewModel.selectedMode)
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
            } else if let _ = capturedVideoURL {
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

// MARK: - Pulsing Animation Modifier
struct CreateHubPulseModifier: ViewModifier {
    @State private var isPulsing = false
    var delay: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.6 : 1.0)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func createHubPulse(delay: Double = 0) -> some View {
        modifier(CreateHubPulseModifier(delay: delay))
    }
}

// MARK: - Story Mode View
struct StoryModeView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        VStack {
            Spacer()
            
            // Filters Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["Warm", "Cool", "B&W", "Vivid"], id: \.self) { filter in
                        Button {
                            // Apply filter
                        } label: {
                            Text(filter)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 120) // Above shutter and picker
        }
    }
}

// MARK: - Reel Mode View
struct ReelModeView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        HStack {
            Spacer()
            
            // Vertical Toolbar
            VStack(spacing: 16) {
                toolbarButton(icon: "1x", action: {})
                toolbarButton(icon: "timer", action: {})
                toolbarButton(icon: "music.note", action: {})
                toolbarButton(icon: "video.fill", action: {})
            }
            .padding(.trailing, 20)
        }
    }
    
    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                
                if icon.contains(".") { // System image
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                } else {
                    Text(icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Post Mode View
struct PostModeView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Thoughts")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $viewModel.contentText)
                        .frame(height: 150)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        formatButton(label: "Bold")
                        formatButton(label: "Link")
                        formatButton(label: "Mention")
                        formatButton(label: "Hashtag")
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemBackground).opacity(0.8))
                        .background(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                Text("\(viewModel.charCount) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(16)
            }
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.15), radius: 30)
            
            Button {
                Task { await viewModel.publish() }
            } label: {
                Text("Publish Post")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "A855F7"), Color(hex: "EC4899")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "A855F7").opacity(0.3), radius: 15)
            }
            .padding(.top, 24)
        }
    }
    
    private func formatButton(label: String) -> some View {
        Button {} label: {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Course Mode View
struct CourseModeView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Course Title")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Enter your course title...", text: $viewModel.courseTopic)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("📚 Course Outline")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button {
                            viewModel.toggleAIOutline()
                        } label: {
                            HStack(spacing: 6) {
                                Text("✨")
                                Text(viewModel.isAIOutlineActive ? "Clear" : "AI Outline")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "06B6D4"), Color(hex: "0891B2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                    
                    VStack(spacing: 12) {
                        if viewModel.generatedModules.isEmpty {
                            Text("Tap \"AI Outline\" to generate modules from your content")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                )
                        } else {
                            ForEach(Array(viewModel.generatedModules.enumerated()), id: \.offset) { index, module in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(hex: "06B6D4"))
                                        .frame(width: 6, height: 6)
                                    
                                    Text(module)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .createHubPulse(delay: Double(index) * 0.2)
                            }
                        }
                    }
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            Button {
                Task { await viewModel.publish() }
            } label: {
                Text("Start Curriculum")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "06B6D4"), Color(hex: "0891B2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "06B6D4").opacity(0.4), radius: 20)
            }
            .padding(.top, 40)
        }
    }
}

// MARK: - Event Mode View
struct EventModeView: View {
    @ObservedObject var viewModel: CreateViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Cover
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "FBBF24"), Color(hex: "F97316")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 160)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    
                    Text("🎉")
                        .font(.system(size: 40))
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    eventField(label: "Event Title", placeholder: "Your amazing event...", text: $viewModel.eventTitle)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📅 Date")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            DatePicker("", selection: $viewModel.eventDate, displayedComponents: .date)
                                .labelsHidden()
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🕐 Time")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            DatePicker("", selection: $viewModel.eventDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    eventField(label: "📍 Location", placeholder: "Event location...", text: $viewModel.eventLocation)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                Button {
                    Task { await viewModel.publish() }
                } label: {
                    Text("Publish Invite")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FBBF24"), Color(hex: "F97316")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "F97316").opacity(0.4), radius: 20)
                }
                .padding(.vertical, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 100)
        }
    }
    
    private func eventField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
