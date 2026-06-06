import SwiftUI

// MARK: - Multi-Mode Creation View
/// High-fidelity creation interface with 5 modes: Story, Reel, Post, Course, Event.
/// Features frosted glass components, dynamic backgrounds, and social-media style interactions.
struct MultiModeCreationView: View {
    @State private var selectedMode: CreationMode = .story
    @State private var inputText = ""
    @State private var courseOutline = ""
    @State private var isGeneratingOutline = false
    @State private var isRecording = false
    @State private var rotationAngle: Double = 0
    @State private var glowOpacity: Double = 0.6
    
    // Animation states
    @State private var contentScale: CGFloat = 0.95
    @State private var contentOpacity: Double = 0
    
    enum CreationMode: String, CaseIterable {
        case story = "Story"
        case reel = "Reel"
        case post = "Post"
        case course = "Course"
        case event = "Event"

        var icon: String {
            switch self {
            case .story: return "camera.fill"
            case .reel: return "video.fill"
            case .post: return "square.and.pencil"
            case .course: return "sparkles"
            case .event: return "calendar"
            }
        }

        var gradient: LinearGradient {
            switch self {
            case .story:
                return LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .reel:
                return LinearGradient(colors: [Color(hex: "4ECDC4"), Color(hex: "44A08D")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .post:
                return LinearGradient(colors: [Color(hex: "45B7D1"), Color(hex: "2980B9")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .course:
                return LinearGradient(colors: [Color(hex: "96CEB4"), Color(hex: "6B8E7A")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .event:
                return LinearGradient(colors: [Color(hex: "FFEAA7"), Color(hex: "F7D794")], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        
        var accentColor: Color {
            switch self {
            case .story: return Color(hex: "FF6B6B")
            case .reel: return Color(hex: "4ECDC4")
            case .post: return Color(hex: "45B7D1")
            case .course: return Color(hex: "96CEB4")
            case .event: return Color(hex: "F7D794")
            }
        }

        var description: String {
            switch self {
            case .story: return "Share a moment"
            case .reel: return "Create a short clip"
            case .post: return "Post an update"
            case .course: return "AI Course Builder"
            case .event: return "Organize a meetup"
            }
        }
    }

    var body: some View {
        ZStack {
            // Dynamic Background
            backgroundView
            
            VStack(spacing: 0) {
                // Frosted Navigation Bar
                topNavigationBar
                
                // Mode Selector
                modeSelectorBar
                    .padding(.top, 12)
                
                // Content Area
                contentContainer
                    .scaleEffect(contentScale)
                    .opacity(contentOpacity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedMode)
                
                Spacer()
                
                // Bottom Action Bar
                bottomActionBar
            }
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentScale = 1.0
                contentOpacity = 1.0
            }
        }
        .onChange(of: selectedMode) { _, _ in
            HapticManager.shared.playLightImpact()
        }
    }

    // MARK: - Components

    private var backgroundView: some View {
        ZStack {
            selectedMode.gradient
                .ignoresSafeArea()
            
            // Animated overlay
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: isRecording ? 100 : -100, y: isRecording ? -200 : 200)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isRecording)
            
            // Noise overlay
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
    }

    private var topNavigationBar: some View {
        HStack {
            Button {
                // Close/Back action
                HapticManager.shared.playMediumImpact()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(selectedMode.rawValue)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(selectedMode.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button {
                // Secondary action (Settings/Drafts)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.3))
    }

    private var modeSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CreationMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: selectedMode == mode ? .bold : .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedMode == mode ? .white : .white.opacity(0.1))
                            .foregroundColor(selectedMode == mode ? .black : .white)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var contentContainer: some View {
        ZStack {
            switch selectedMode {
            case .story:
                storyView
            case .reel:
                reelView
            case .post:
                postView
            case .course:
                courseView
            case .event:
                eventView
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Story View
    private var storyView: some View {
        VStack {
            ZStack {
                // Rounded Camera Preview
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.black.opacity(0.2))
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 64, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.5))
                            Text("TAP TO RECORD")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(2)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .aspectRatio(9/16, contentMode: .fit)
                    .padding(.horizontal, 30)
                
                // Camera Toolbar (Flash, Flip, Timer)
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 20) {
                            toolToggleButton(icon: "bolt.fill")
                            toolToggleButton(icon: "arrow.triangle.2.circlepath")
                            toolToggleButton(icon: "timer")
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .padding(.trailing, 45)
                        .padding(.top, 30)
                    }
                    Spacer()
                }
            }
            
            Spacer()
        }
    }

    private func toolToggleButton(icon: String) -> some View {
        Button {
            HapticManager.shared.playLightImpact()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
        }
    }

    // MARK: - Reel View
    private var reelView: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        VStack {
                            if isRecording {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                    .opacity(glowOpacity)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                                            glowOpacity = 0.2
                                        }
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(20)
                    )
                    .aspectRatio(9/16, contentMode: .fit)
                    .padding(.horizontal, 20)
                
                // Vertical Tools Table
                HStack {
                    Spacer()
                    VStack(spacing: 25) {
                        Image(systemName: "music.note")
                        Image(systemName: "gauge.medium")
                        Image(systemName: "sparkles")
                        Image(systemName: "face.smiling")
                    }
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(30)
                    .padding(.trailing, 35)
                }
            }
            Spacer()
        }
    }

    // MARK: - Post View
    private var postView: some View {
        VStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text("You")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Posting to Feed")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("What's on your mind?")
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 8)
                    }
                    
                    TextEditor(text: $inputText)
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                        .frame(height: 150)
                }
                
                HStack {
                    Button {
                        HapticManager.shared.playLightImpact()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.fill")
                            Text("Media")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Text("\(inputText.count)/280")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(inputText.count > 250 ? .red : .white.opacity(0.5))
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }

    // MARK: - Course View
    private var courseView: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Label("AI COURSE BUILDER", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2)
                
                Text("What would you like to master today?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                TextField("Enter a topic (e.g. Quantum Physics or Baking)", text: $inputText)
                    .padding(20)
                    .background(.white.opacity(0.1))
                    .cornerRadius(18)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
            
            Button {
                generateCourseOutline()
            } label: {
                HStack(spacing: 12) {
                    if isGeneratingOutline {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                    }
                    Text(isGeneratingOutline ? "MANIFESTING KNOWLEDGE..." : "GENERATE AI OUTLINE")
                        .font(.system(size: 14, weight: .black))
                        .tracking(1)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.white.opacity(0.3), radius: 15, x: 0, y: 10)
            }
            .padding(.horizontal, 24)
            .disabled(inputText.isEmpty || isGeneratingOutline)
            
            if !courseOutline.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(courseOutline)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .background(.black.opacity(0.3))
                    .cornerRadius(24)
                }
                .padding(.horizontal, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Spacer()
        }
    }

    // MARK: - Event View
    private var eventView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                eventField(icon: "pencil", placeholder: "Event Title")
                eventField(icon: "calendar", placeholder: "Pick Date & Time")
                eventField(icon: "mappin.and.ellipse", placeholder: "Add Location")
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 120)
                    
                    Text("Describe your meetup...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(16)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }

    private func eventField(icon: String, placeholder: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)
            Text(placeholder)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
        }
        .padding(18)
        .background(.white.opacity(0.1))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Bottom Bar
    private var bottomActionBar: some View {
        VStack(spacing: 20) {
            // Main Action Button
            HStack {
                Button {
                    HapticManager.shared.playHeavyImpact()
                    // Toggle recording or take photo
                    if selectedMode == .reel || selectedMode == .story {
                        isRecording.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 92, height: 92)
                        
                        if isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 30, height: 30)
                                .transition(.scale)
                        } else {
                            Circle()
                                .fill(selectedMode.accentColor)
                                .frame(width: 68, height: 68)
                                .transition(.scale)
                        }
                    }
                }
                .scaleEffect(isRecording ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
            }
            .padding(.bottom, 10)
            
            // Context Bar
            HStack {
                Button {
                    // Gallery
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Gallery")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                Button {
                    // Share
                } label: {
                    HStack {
                        Text(selectedMode == .course ? "BUILD COURSE" : "SHARE")
                            .font(.system(size: 14, weight: .black))
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundColor(.black)
                    .cornerRadius(25)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helper Actions
    private func generateCourseOutline() {
        isGeneratingOutline = true
        HapticManager.shared.playSuccess()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring()) {
                courseOutline = """
                🚀 STARTING: \(inputText.uppercased())
                
                [01] THE FUNDAMENTALS
                Master the core concepts and history of the topic.
                
                [02] PRACTICAL APPLICATION
                Build your first project using real-world scenarios.
                
                [03] ADVANCED STRATEGIES
                Optimizing for performance and scalability.
                
                [04] EXPERT ASSESSMENT
                Final challenge to lock in your mastery.
                """
                isGeneratingOutline = false
            }
        }
    }
}

struct MultiModeCreationView_Previews: PreviewProvider {
    static var previews: some View {
        MultiModeCreationView()
    }
}
