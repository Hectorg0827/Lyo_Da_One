import SwiftUI

// MARK: - Live Classroom View

struct LiveClassroomView: View {
    let courseId: String
    let lessonId: String
    let courseTitle: String
    let lessonTitle: String
    
    @StateObject private var viewModel = LiveClassroomViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var uiStackStore: UIStackStore
    @EnvironmentObject var uiState: AppUIState
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Immersive Magical Background
            MagicalBackgroundView(baseColor: viewModel.currentThemeColor)
                .ignoresSafeArea()
            
            // Celebration Layer
            if viewModel.lioState == .celebrating {
                Group {
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 400))
                        .blur(radius: 40)
                    
                    MagicEffectView(type: .confetti)
                }
                .transition(.opacity)
                .ignoresSafeArea()
            }
            
            // Completion View Overlay
            if viewModel.isLessonComplete {
                LessonCompletionView(
                    courseTitle: courseTitle,
                    lessonTitle: viewModel.lesson?.title ?? lessonTitle,
                    xpGained: viewModel.xpGained,
                    onDismiss: {
                        dismiss()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(20)
            }
            
            VStack(spacing: 0) {
                // Top Floating Header
                topOverlay
                    .zIndex(10)
                
                // Stage Area
                stageArea
                    .frame(maxHeight: .infinity)
                
                // Bottom Floating Lio Bar
                lioLiveBar
                    .padding(.bottom, 20)
                    .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .task {
            await viewModel.loadLesson(courseId: courseId, lessonId: lessonId)
        }
        .sheet(isPresented: $viewModel.showTranscriptSheet) {
            TranscriptSheet(transcript: viewModel.transcript)
        }
        .sheet(isPresented: $viewModel.showAskQuestionSheet) {
            AskQuestionSheet(
                question: $viewModel.userQuestion,
                isProcessing: viewModel.isProcessingQuestion
            ) { question in
                Task {
                    await viewModel.askQuestion(question)
                }
            }
        }
        .sheet(isPresented: $viewModel.showEnergySheet) {
            EnergyPaymentSheet()
                .environmentObject(MonetizationService.shared)
        }
        .sheet(isPresented: $uiState.isLioChatPresented) {
            LioChatSheet(isPresented: $uiState.isLioChatPresented)
        }
        .onAppear {
            // Register in stack
            uiStackStore.upsertCourse(
                courseId: courseId,
                title: courseTitle,
                subtitle: lessonTitle
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ClassroomShareSheet(activityItems: ["Check out this course on Lyo!", url])
            }
        }
    }
    
    // MARK: - Top Overlay
    
    private var topOverlay: some View {
        HStack(alignment: .center) {
            // Back button
            Button(action: {
                HapticManager.shared.light()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Material.thinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            Spacer()
            
            // Title & Progress
            VStack(spacing: 4) {
                Text(viewModel.lesson?.title ?? courseTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let lesson = viewModel.lesson {
                    HStack(spacing: 6) {
                        Text("Block \(viewModel.currentBlockIndex + 1) of \(lesson.totalBlocks)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)
                                
                                Capsule()
                                    .fill(DesignSystem.Colors.fallbackPrimary)
                                    .frame(width: geo.size.width * viewModel.progressPercentage, height: 4)
                                    .animation(.spring(), value: viewModel.progressPercentage)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                }
            }
            
            Spacer()
            
            // Share Button
            Button(action: {
                HapticManager.shared.light()
                // Create a deep link (mock or real)
                shareURL = URL(string: "https://lyo.app/course/\(courseId)")
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            // AI Assistant Button
            Button(action: {
                HapticManager.shared.light()
                // Set context for the AI
                uiState.lioContextHint = "Watching lesson: \(viewModel.lesson?.title ?? lessonTitle)"
                uiState.isLioChatPresented = true
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "8B5CF6").opacity(0.5), radius: 8, x: 0, y: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Stage Area
    
    private var stageArea: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if let block = viewModel.currentBlock {
                // Block-based rendering (the proven workhorse with 27+ block types)
                // Takes priority over errorMessage — if we have local content, show it.
                // Slightly softer scale + slide so transitions feel cinematic, not abrupt.
                blockContentView(block: block)
                    .id(block.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if let errorMsg = viewModel.errorMessage {
                // Error state — only when we have NO content at all
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Something went wrong")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(errorMsg)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") {
                        Task {
                            await viewModel.loadLesson(courseId: courseId, lessonId: lessonId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let lesson = viewModel.lesson, lesson.blocks.isEmpty {
                // Course is generating content
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Generating your course...")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("This usually takes 2–5 minutes. You can stay here and the content will appear automatically.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                // Fallback - no content available
                VStack(spacing: 20) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No lesson content available")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                    Button("Reload") {
                        Task {
                            await viewModel.loadLesson(courseId: courseId, lessonId: lessonId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            
            // Navigation arrows (Floating)
            HStack {
                // Previous button
                if !viewModel.isFirstBlock {
                    Button(action: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            viewModel.goToPreviousBlock()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                }
                
                Spacer()
                
                // Next button
                if viewModel.canAdvance && !viewModel.isLastBlock {
                    Button(action: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            viewModel.advanceToNextBlock()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                }
            }
        }
        // Subtle reveal haptic each time a new block enters the stage.
        // `.soft()` is the gentlest impact — feels like the content "landed"
        // without intruding on whatever the user is reading.
        .onChange(of: viewModel.currentBlockIndex) { _ in
            HapticManager.shared.soft()
        }
    }

    // MARK: - Block Content View
    
    @ViewBuilder
    private func blockContentView(block: LiveLessonBlock) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Lesson banner — only on the first block so it reads as a
                // title page, not chrome that repeats above every step.
                if viewModel.isFirstBlock {
                    let total = max(viewModel.lesson?.blocks.count ?? 1, 1)
                    let progress = Double(viewModel.currentBlockIndex + 1) / Double(total)
                    LessonHero(
                        topic: courseTitle,
                        subtitle: viewModel.lesson?.title,
                        progress: progress,
                        imageURL: nil
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Glass Card Container
                GlassCard {
                    VStack(spacing: 24) {
                        // Dynamic Block Renderer
                        BlockRendererView(block: block, onQuizAnswer: { index in
                            viewModel.submitQuizAnswer(index)
                        }, onAction: { actionId in
                            // Handle custom actions if needed
                        })
                        .padding(.vertical, 8)
                        
                        // Legacy feedback & continue buttons (kept for UI consistency)
                        if viewModel.quizSubmitted && viewModel.isQuizCorrect && !viewModel.isLastBlock {
                            Button(action: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    viewModel.advanceToNextBlock()
                                }
                            }) {
                                HStack {
                                    Text("Continue")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Legacy Block Views (REMOVED - replaced by BlockRendererView)

    
    private func quizOptionButton(
        option: String,
        index: Int,
        isCorrect: Bool,
        isSelected: Bool,
        isSubmitted: Bool
    ) -> some View {
        Button(action: {
            if !isSubmitted {
                viewModel.submitQuizAnswer(index)
            }
        }) {
            HStack {
                // Option letter
                Text(String(Character(UnicodeScalar(65 + index)!)))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(optionBadgeColor(isCorrect: isCorrect, isSelected: isSelected, isSubmitted: isSubmitted))
                    .clipShape(Circle())
                
                Text(option)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Result indicator
                if isSubmitted {
                    if isSelected && isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    } else if isSelected && !isCorrect {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
            }
            .padding()
            .background(optionBackgroundColor(isCorrect: isCorrect, isSelected: isSelected, isSubmitted: isSubmitted))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(optionBorderColor(isSelected: isSelected, isSubmitted: isSubmitted), lineWidth: isSelected ? 2 : 1)
            )
        }
        .disabled(isSubmitted)
    }
    
    private func optionBadgeColor(isCorrect: Bool, isSelected: Bool, isSubmitted: Bool) -> Color {
        if isSubmitted {
            if isSelected && isCorrect { return .green }
            else if isSelected && !isCorrect { return .red }
        }
        return .white.opacity(0.2)
    }
    
    private func optionBackgroundColor(isCorrect: Bool, isSelected: Bool, isSubmitted: Bool) -> Color {
        if isSubmitted {
            if isSelected && isCorrect { return .green.opacity(0.2) }
            else if isSelected && !isCorrect { return .red.opacity(0.2) }
        }
        return isSelected ? DesignSystem.Colors.fallbackPrimary.opacity(0.2) : Color.white.opacity(0.05)
    }
    
    private func optionBorderColor(isSelected: Bool, isSubmitted: Bool) -> Color {
        if isSelected && !isSubmitted { return DesignSystem.Colors.fallbackPrimary }
        return Color.white.opacity(0.1)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Preparing your lesson...")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Lio Live Bar
    
    private var lioLiveBar: some View {
        HStack(spacing: 16) {
            // Lio Avatar
            lioAvatar
            
            // Sentiment chips
            sentimentChips
            
            Spacer()
            
            // Tools
            HStack(spacing: 8) {
                // Transcript button
                Button(action: { viewModel.showTranscriptSheet = true }) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Ask question button
                Button(action: { viewModel.showAskQuestionSheet = true }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(DesignSystem.Colors.fallbackPrimary)
                        .clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(Material.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
    }
    
    private var lioAvatar: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: DesignSystem.Colors.fallbackPrimary.opacity(0.5), radius: viewModel.lioState == .celebrating ? 15 : 0)
                // Breathing Animation when IDLE
                .scaleEffect(viewModel.lioState == .idle ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: viewModel.lioState == .idle)
            
            // State-specific Icon
            Image(systemName: viewModel.lioState.icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .id(viewModel.lioState.rawValue)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: viewModel.lioState)
            
            // Speaking indicator
            if viewModel.isLioSpeaking {
                Circle()
                    .stroke(DesignSystem.Colors.fallbackPrimary, lineWidth: 2)
                    .frame(width: 52, height: 52)
                    .scaleEffect(viewModel.isLioSpeaking ? 1.1 : 1.0)
                    .opacity(viewModel.isLioSpeaking ? 0.5 : 0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isLioSpeaking)
            }
        }
    }
    
    private var sentimentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SentimentSignal.allCases, id: \.rawValue) { signal in
                    Button(action: { viewModel.sendSentimentSignal(signal) }) {
                        HStack(spacing: 4) {
                            Image(systemName: signal.icon)
                                .font(.caption)
                            Text(signal.displayLabel)
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: 200)
    }
}

// MARK: - Preview

#Preview {
    LiveClassroomView(
        courseId: "course-1",
        lessonId: "lesson-1",
        courseTitle: "Swift Basics",
        lessonTitle: "Variables & Constants"
    )
    .environmentObject(UIStackStore.shared)
}

// MARK: - Share Sheet

struct ClassroomShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Lesson Completion View

struct LessonCompletionView: View {
    let courseTitle: String
    let lessonTitle: String
    let xpGained: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Trophy Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 10)
                        .opacity(0.5)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 10)
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0).repeatForever(autoreverses: true), value: true)
                
                VStack(spacing: 8) {
                    Text("Lesson Complete!")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("You've mastered")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(lessonTitle)
                        .font(.title2.weight(.heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Stats Grid
                HStack(spacing: 40) {
                    VStack {
                        Text("100%")
                            .font(.title3.bold())
                            .foregroundColor(.green)
                        Text("Accuracy")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack {
                        Text("+\(xpGained)")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        Text("XP Gained")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                Button(action: onDismiss) {
                    Text("Continue Journey")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.3), radius: 10)
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }
}
