import SwiftUI

struct StoryViewer: View {
    @Binding var isPresented: Bool
    var startingStoryId: String // New: Correct ID to start with
    @StateObject var storyService = StoryService.shared
    @State private var currentStoryIndex: Int = 0
    @State private var currentSlideIndex: Int = 0
    @State private var progress: Double = 0.0
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var isPaused = false
    
    // Actions
    var onAskLio: ((String) -> Void)?
    
    init(isPresented: Binding<Bool>, startingStoryId: String, onAskLio: ((String) -> Void)? = nil) {
        self._isPresented = isPresented
        self.startingStoryId = startingStoryId
        self.onAskLio = onAskLio
        
        // Find index
        if let index = StoryService.shared.stories.firstIndex(where: { $0.id == startingStoryId }) {
            self._currentStoryIndex = State(initialValue: index)
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let story = currentStory {
                if let slide = currentSlide {
                    // Media Layer
                    GeometryReader { geo in
                        renderSlide(slide, in: geo.size)
                            .onTapGesture { location in
                                if location.x < geo.size.width / 2 {
                                    previousSlide()
                                } else {
                                    nextSlide()
                                }
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in isPaused = true }
                                    .onEnded { _ in isPaused = false }
                            )
                    }
                    
                    // UI Layer
                    VStack(spacing: 0) {
                        // Progress Bar
                        HStack(spacing: 4) {
                            ForEach(0..<story.slides.count, id: \.self) { index in
                                ProgressBar(
                                    progress: index < currentSlideIndex ? 1.0 : (index == currentSlideIndex ? progress : 0.0)
                                )
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)
                        
                        // Header
                        HStack {
                            if let avatar = story.userAvatar {
                                Image(systemName: avatar == "sparkles" ? "sparkles" : "person.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .foregroundColor(.white)
                            }
                            Text(story.userName)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            Text(story.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        
                        Spacer()
                        
                        // Footer Actions
                        VStack(spacing: 12) {
                            // Contextual Buttons
                            if let courseId = story.linkedCourseId {
                                Button(action: { 
                                    // Navigate to Course
                                    isPresented = false 
                                    // NotificationCenter trigger for navigation?
                                }) {
                                    HStack {
                                        Image(systemName: "book.fill")
                                        Text("View Course")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                            
                            if let groupId = story.linkedGroupId {
                                Button(action: {
                                    isPresented = false
                                    // Navigate to Community
                                }) {
                                    HStack {
                                        Image(systemName: "person.3.fill")
                                        Text("View Study Group")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                }
                            }
                            
                            if let askLio = onAskLio {
                                Button(action: {
                                    let context = "Regarding story by \(story.userName): \(slide.text ?? "image")"
                                    isPresented = false
                                    askLio(context)
                                }) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text("Ask Lio")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onReceive(timer) { _ in
            guard !isPaused, let slide = currentSlide else { return }
            
            let step = 0.1 / slide.duration
            if progress + step >= 1.0 {
                nextSlide()
            } else {
                progress += step
            }
        }
    }
    
    // MARK: - Logic
    
    private var currentStory: Story? {
        if currentStoryIndex < storyService.stories.count {
            return storyService.stories[currentStoryIndex]
        }
        return nil
    }
    
    private var currentSlide: StorySlide? {
        guard let story = currentStory else { return nil }
        if currentSlideIndex < story.slides.count {
            return story.slides[currentSlideIndex]
        }
        return nil
    }
    
    private func nextSlide() {
        guard let story = currentStory else { return }
        
        if currentSlideIndex < story.slides.count - 1 {
            currentSlideIndex += 1
            progress = 0.0
        } else {
            // Next Story
            if currentStoryIndex < storyService.stories.count - 1 {
                currentStoryIndex += 1
                currentSlideIndex = 0
                progress = 0.0
            } else {
                // End
                isPresented = false
            }
        }
    }
    
    private func previousSlide() {
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
            progress = 0.0
        } else {
            // Previous Story
            if currentStoryIndex > 0 {
                currentStoryIndex -= 1
                currentSlideIndex = 0 // Or last slide? default to first for simplicity
                progress = 0.0
            }
        }
    }
    
    @ViewBuilder
    private func renderSlide(_ slide: StorySlide, in size: CGSize) -> some View {
        switch slide.type {
        case .image:
            if let url = slide.mediaURL, let _ = URL(string: url) {
               // AsyncImage place
               Color.gray.overlay(Text("Image from URL").foregroundColor(.white))
            } else {
                // Mock visual
                ZStack {
                     LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                     VStack {
                         Spacer()
                         if let text = slide.text {
                             Text(text)
                                .font(.title)
                                .bold()
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                         }
                         Spacer()
                     }
                }
            }
        case .text:
            ZStack {
                Color(hex: "1e293b") // Slate dark
                Text(slide.text ?? "")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        case .video:
            Color.black.overlay(Text("Video Placeholder").foregroundColor(.white))
        }
    }
}

struct ProgressBar: View {
    var progress: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.3))
                Capsule().fill(Color.white).frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 3)
    }
}
