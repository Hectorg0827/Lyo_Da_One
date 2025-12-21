import SwiftUI
import AVKit

struct DiscoverReelView: View {
    let item: DiscoverItem
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onAskLio: () -> Void
    let onStart: () -> Void
    
    // New interaction callbacks
    var onConvertToCourse: () -> Void = {}
    
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var player: AVPlayer?
    
    // Quiz State
    @State private var showQuiz = false
    @State private var currentQuiz: QuizMoment?
    @State private var videoPausedForQuiz = false
    
    var body: some View {
        ZStack {
            // MARK: - 1. Media Layer
            GeometryReader { proxy in
                if let videoURL = item.videoURL {
                    VideoPlayer(player: player)
                        .disabled(true)
                        .onAppear {
                            setupPlayer(url: videoURL)
                        }
                        .onDisappear {
                            player?.pause()
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else if let thumbnailURL = item.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.black)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                } else {
                    LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .background(Color.black)
                }
            }
            .ignoresSafeArea()
            
            // Gradient Overlay
            VStack {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom).frame(height: 150)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom).frame(height: 300)
            }
            .ignoresSafeArea()
            
            // MARK: - 2. Learning UI Layer
            VStack {
                // Header (Subject, Level, XP)
                ReelHeaderView(item: item)
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Bottom Info (Title, Key Points, Creator)
                    ReelInfoOverlay(item: item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right Action Strip (Lyo Buttons)
                    ReelActionStrip(
                        item: item,
                        isLiked: $isLiked,
                        isSaved: $isSaved,
                        onLike: onLike,
                        onComment: onComment,
                        onShare: onShare,
                        onAskLio: onAskLio,
                        onSave: onSave,
                        onConvertToCourse: onConvertToCourse
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110) // Increased tab bar clearance
            }
            
            // MARK: - 3. Interaction Layer (Quiz)
            if showQuiz, let quiz = currentQuiz {
                QuizOverlayView(quiz: quiz) { success in
                    // Resume video
                    showQuiz = false
                    videoPausedForQuiz = false
                    player?.play()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onTapGesture {
            togglePlayback()
        }
        .onAppear {
            isLiked = item.isLiked
            isSaved = item.isSaved
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            checkQuizTrigger()
        }
    }
    
    // MARK: - Logic
    
    private func setupPlayer(url: URL) {
        player = AVPlayer(url: url)
        player?.play()
        
        // Loop
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
    
    private func togglePlayback() {
        guard !showQuiz else { return }
        if player?.timeControlStatus == .playing {
            player?.pause()
        } else {
            player?.play()
        }
    }
    
    private func checkQuizTrigger() {
        guard let customPlayer = player, customPlayer.timeControlStatus == .playing, !showQuiz else { return }
        
        let currentTime = customPlayer.currentTime().seconds
        
        // Check for quiz moments within 0.5s window
        if let quiz = item.quizMoments.first(where: { abs($0.timestamp - currentTime) < 0.5 }) {
            // Trigger Quiz
            currentQuiz = quiz
            showQuiz = true
            customPlayer.pause()
            videoPausedForQuiz = true
            HapticManager.shared.medium()
        }
    }
}

// MARK: - Preview
struct DiscoverReelView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverReelView(
            item: DiscoverItem(
                type: .videoSnippet,
                title: "Introduction to Swift",
                subtitle: "Learn basic syntax",
                tag: "Swift",
                estimatedMinutes: 2,
                subject: "Coding",
                level: .beginner,
                xpReward: 15,
                keyPoints: ["Variables vs Constants", "Type Inference", "Basic Printing"],
                linkedGoalId: "goal_1",
                quizMoments: [
                    QuizMoment(timestamp: 5, question: "What keyword creates a constant?", options: ["var", "let", "const"], correctIndex: 1, explanation: "In Swift, 'let' defines a constant.")
                ]
            ),
            onLike: {},
            onComment: {},
            onShare: {},
            onSave: {},
            onAskLio: {},
            onStart: {}
        )
    }
}
