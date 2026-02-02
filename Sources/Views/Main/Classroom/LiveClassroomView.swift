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
    @EnvironmentObject var aiViewModel: LyoAIViewModel
    
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
            // Attempt to upgrade to A2UI experience
            await viewModel.loadLessonUI(lessonId)
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
            } else if let a2ui = viewModel.a2uiComponent {
                // A2UI Rendering
                ScrollView {
                    A2UIRecursiveRenderer(component: a2ui, onAction: { actionId in
                        Task { await viewModel.handleA2UIAction(actionId) }
                    })
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 120) // Space for bottom bar
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else if let block = viewModel.currentBlock {
                blockContentView(block: block)
                    .id(block.id) // Ensure unique ID for transitions
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
            }
            
            // Navigation arrows (Floating)
            HStack {
                // Previous button
                if !viewModel.isFirstBlock {
                    Button(action: { 
                        withAnimation { viewModel.goToPreviousBlock() }
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
                        withAnimation { viewModel.advanceToNextBlock() }
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
    }
    
    // MARK: - Block Content View
    
    @ViewBuilder
    private func blockContentView(block: LessonBlock) -> some View {
        ScrollView {
            VStack(spacing: 24) {
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
                            Button(action: { withAnimation { viewModel.advanceToNextBlock() } }) {
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
