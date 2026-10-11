import SwiftUI
import AVKit

struct DiscoverReelView: View {
    let item: DiscoverItem
    // Page selection is authoritative; offscreen neighbours preroll silently.
    var isActive: Bool = true
    var shouldLoad: Bool = true
    var playbackAllowed: Bool = true
    @Environment(\.scenePhase) private var scenePhase
    var onFinished: () -> Void = {}
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
    @StateObject private var playback = DiscoverPlayerController()

    // Quiz State
    @State private var showQuiz = false
    @State private var currentQuiz: QuizMoment?
    @State private var videoPausedForQuiz = false
    @State private var completedQuizTimes = Set<TimeInterval>()

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
                            .opacity(playback.isPlayingFirstFrame ? 0 : 1)
                            .animation(.easeOut(duration: 0.25), value: playback.isPlayingFirstFrame)
                        } else {
                            Rectangle().fill(Color.black)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }

                        DiscoverVideoSurface(controller: playback)
                            .allowsHitTesting(false)
                            .onAppear {
                                // Neighbours prepare the canonical source before a swipe.
                                configurePlayback()
                            }
                            .onDisappear {
                                playback.teardown()
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()

                        // Surface load failures so the user is never staring at a frozen black frame.
                        if playback.loadFailed {
                            VStack(spacing: 10) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Video unavailable")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Button("Retry") {
                                    playback.retry(url: videoURL)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.white.opacity(0.2))
                                .foregroundStyle(.white)
                                Button("Next clip", action: onFinished)
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
            .contentShape(Rectangle())
            .onTapGesture { playback.togglePause() }
            .ignoresSafeArea()
            
            // Gradient Overlay
            VStack {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom).frame(height: 150)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom).frame(height: 300)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
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
                .padding(.bottom, 12)

                if item.videoURL != nil, isActive, !playback.loadFailed {
                    playbackControls
                        .padding(.horizontal, 16)
                        .padding(.bottom, 90)
                } else {
                    Spacer().frame(height: 110)
                }
            }
            
            // MARK: - 3. Interaction Layer (Quiz)
            if showQuiz, let quiz = currentQuiz {
                QuizOverlayView(quiz: quiz) { success in
                    // Resume video
                    showQuiz = false
                    videoPausedForQuiz = false
                    completedQuizTimes.insert(quiz.timestamp)
                    configurePlayback()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onAppear {
            isLiked = item.isLiked
            isSaved = item.isSaved
            configurePlayback()
        }
        .onDisappear { playback.teardown() }
        .onChange(of: isActive) { _ in configurePlayback() }
        .onChange(of: shouldLoad) { _ in configurePlayback() }
        .onChange(of: playbackAllowed) { _ in configurePlayback() }
        .onChange(of: scenePhase) { _ in configurePlayback() }
        .onChange(of: showQuiz) { _ in configurePlayback() }
        .onChange(of: playback.completionCount) { _ in
            if isActive && playbackAllowed && scenePhase == .active && !showQuiz { onFinished() }
        }
        .onChange(of: playback.position) { current in checkQuizTrigger(currentTime: current) }
    }

    private var playbackControls: some View {
        VStack(spacing: 4) {
            Slider(value: $playback.position, in: 0...max(playback.duration, 1), onEditingChanged: { editing in
                if editing { playback.beginScrubbing() } else { playback.endScrubbing() }
            })
            .disabled(playback.duration <= 0)
            .tint(.white)
            .accessibilityLabel("Seek video")
            HStack {
                Button { playback.togglePause() } label: {
                    Image(systemName: playback.state.userPaused || playback.ended ? "play.fill" : "pause.fill")
                        .frame(width: 40, height: 32)
                }
                .accessibilityLabel(playback.state.userPaused || playback.ended ? "Play video" : "Pause video")
                Text("\(timeLabel(playback.position)) / \(timeLabel(playback.duration))")
                    .font(.caption.monospacedDigit())
                Spacer()
                Button { playback.toggleMute() } label: {
                    Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 40, height: 32)
                }
                .accessibilityLabel(playback.isMuted ? "Unmute video" : "Mute video")
            }
            .foregroundStyle(.white)
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private func configurePlayback() {
        playback.configure(selected: isActive, foreground: scenePhase == .active && playbackAllowed, quizPaused: showQuiz)
        if shouldLoad, let url = item.videoURL { playback.load(url: url) }
        else { playback.teardown() }
    }

    private func checkQuizTrigger(currentTime: TimeInterval) {
        guard playback.state.shouldPlay, !showQuiz, !playback.ended else { return }
        if let quiz = item.quizMoments.first(where: { !completedQuizTimes.contains($0.timestamp) && abs($0.timestamp - currentTime) < 0.5 }) {
            currentQuiz = quiz
            showQuiz = true
            videoPausedForQuiz = true
            configurePlayback()
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
