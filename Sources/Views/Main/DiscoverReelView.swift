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

    // Lifecycle handles — must be released on disappear to avoid leaks.
    @State private var endObserver: NSObjectProtocol?
    @State private var timeObserver: Any?
    @State private var statusObserver: NSKeyValueObservation?

    // True after the first frame has rendered. Used to fade the poster out.
    @State private var isPlayingFirstFrame: Bool = false

    // True when the video URL fails to load. Surfaces a clear error state to the user.
    @State private var loadFailed: Bool = false

    // Quiz State
    @State private var showQuiz = false
    @State private var currentQuiz: QuizMoment?
    @State private var videoPausedForQuiz = false

    var body: some View {
        ZStack {
            // MARK: - 1. Media Layer
            GeometryReader { proxy in
                ZStack {
                    if let videoURL = item.videoURL {
                        // Poster: shown immediately so swipes feel instant. Fades out
                        // once the player produces its first frame.
                        if let thumb = item.thumbnailURL {
                            AsyncImage(url: thumb) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.black)
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .opacity(isPlayingFirstFrame ? 0 : 1)
                            .animation(.easeOut(duration: 0.25), value: isPlayingFirstFrame)
                        } else {
                            Rectangle().fill(Color.black)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }

                        VideoPlayer(player: player)
                            .disabled(true)
                            .onAppear {
                                // Prioritize lightweight preview for feed scrolling
                                setupPlayer(url: item.previewURL ?? videoURL)
                            }
                            .onDisappear {
                                teardownPlayer()
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()

                        // Surface load failures so the user is never staring at a frozen black frame.
                        if loadFailed {
                            VStack(spacing: 10) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Video unavailable")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Button("Retry") {
                                    loadFailed = false
                                    setupPlayer(url: videoURL)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.white.opacity(0.2))
                                .foregroundStyle(.white)
                            }
                            .padding(20)
                            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Video failed to load. Tap retry.")
                        }
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
    }
    
    // MARK: - Logic
    
    private func setupPlayer(url: URL) {
        // Tear down any prior session before creating a new one (defensive — handles retry).
        teardownPlayer()

        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        newPlayer.play()

        // Loop on end. Capture the token so we can remove the observer on disappear.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }

        // Replace the polling Timer with AVPlayer's own time observer — fires on the
        // playback clock, stops automatically when the player is released, and is
        // removable via removeTimeObserver. Half-second cadence matches the old behavior.
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            checkQuizTrigger(currentTime: time.seconds)
            // First-frame poster fade trigger.
            if !isPlayingFirstFrame, time.seconds > 0 {
                isPlayingFirstFrame = true
            }
        }

        // Surface load failures via KVO on the item's status.
        statusObserver = newPlayer.currentItem?.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                if item.status == .failed {
                    loadFailed = true
                }
            }
        }
    }

    /// Releases every long-lived resource the player owns. Must be called from
    /// `.onDisappear` or before re-creating the player; otherwise observers and
    /// AVPlayer instances accumulate per swipe and the app eventually crashes.
    private func teardownPlayer() {
        if let token = endObserver {
            NotificationCenter.default.removeObserver(token)
            endObserver = nil
        }
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil

        isPlayingFirstFrame = false
    }
    
    private func togglePlayback() {
        guard !showQuiz else { return }
        if player?.timeControlStatus == .playing {
            player?.pause()
        } else {
            player?.play()
        }
    }
    
    private func checkQuizTrigger(currentTime: TimeInterval) {
        guard let customPlayer = player, customPlayer.timeControlStatus == .playing, !showQuiz else { return }

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
