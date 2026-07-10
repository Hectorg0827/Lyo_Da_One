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
    
    @State private var isDrawerOpen = false
    @State private var chatInput = ""
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background to match landing page
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea()
            
            // Celebration Layer
            if viewModel.lioState == .celebrating {
                Group {
                    MagicEffectView(type: .confetti)
                }
                .transition(.opacity)
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Top header
                topOverlay
                
                // Main Area
                ZStack(alignment: .trailing) {
                    
                    // Whiteboard Area
                    stageArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 4) // 99.5% width effect
                    
                    // Hidden Drawer
                    if isDrawerOpen {
                        drawerArea
                            .frame(width: 280)
                            .background(Color(.systemBackground))
                            .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: -5, y: 0)
                            .transition(.move(edge: .trailing))
                            .zIndex(20)
                    }
                    
                    // Drawer toggle tab
                    Button(action: {
                        withAnimation(.spring()) {
                            isDrawerOpen.toggle()
                        }
                    }) {
                        Image(systemName: isDrawerOpen ? "chevron.right" : "chevron.left")
                            .foregroundColor(.gray)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: -2, y: 0)
                    }
                    .offset(x: isDrawerOpen ? -280 : 0)
                    .zIndex(21)
                }
                
                // Bottom Input
                bottomInputBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
            
            // Floating Lyo Mascot
            VStack {
                Spacer()
                HStack {
                    floatingMascot
                        .padding(.leading, 16)
                        .padding(.bottom, 80)
                    Spacer()
                }
            }
            .zIndex(15)
            
            // Completion View Overlay
            if viewModel.isLessonComplete {
                LessonCompletionView(
                    courseTitle: courseTitle,
                    lessonTitle: viewModel.lesson?.title ?? lessonTitle,
                    xpGained: viewModel.xpGained,
                    onDismiss: { dismiss() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(20)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .task {
            // Setup
            await viewModel.loadLesson(courseId: courseId, lessonId: lessonId)
            uiStackStore.upsertCourse(courseId: courseId, title: courseTitle, subtitle: lessonTitle)
        }
    }
    
    // MARK: - Top Overlay
    
    private var topOverlay: some View {
        HStack(alignment: .center) {
            Button(action: {
                HapticManager.shared.light()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(courseTitle)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Phantom view to center title perfectly
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Floating Mascot
    
    private var floatingMascot: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
            
            Image(systemName: viewModel.lioState.icon)
                .font(.title2)
                .foregroundColor(.white)
        }
        .offset(y: viewModel.lioState == .idle ? -5 : 0)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: viewModel.lioState == .idle)
    }
    
    // MARK: - Drawer Area
    
    private var drawerArea: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Classroom Tools")
                .font(.headline)
                .padding(.top, 24)
            
            VStack(alignment: .leading, spacing: 16) {
                Label("Course Syllabus", systemImage: "list.bullet.rectangle")
                    .font(.subheadline)
                
                Label("My Notes", systemImage: "note.text")
                    .font(.subheadline)
            }
            .foregroundColor(.primary)
            
            Divider()
            
            Text("Quick Actions")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                quickChip("I don't understand")
                quickChip("Explain again")
                quickChip("Give me an example")
                quickChip("Skip this part")
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
    }
    
    private func quickChip(_ text: String) -> some View {
        Button(action: {
            Task { await viewModel.askQuestion(text) }
            withAnimation { isDrawerOpen = false }
        }) {
            Text(text)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Bottom Input Bar
    
    private var bottomInputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask Lyo a question...", text: $chatInput, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            if !chatInput.isEmpty {
                Button(action: {
                    let msg = chatInput
                    chatInput = ""
                    Task { await viewModel.askQuestion(msg) }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
            } else {
                Button(action: {
                    // Activate Mic recording logic
                }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                }
            }
        }
    }
    
    // MARK: - Stage Area
    
    private var stageArea: some View {
        ZStack {
            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Preparing your lesson...")
                        .foregroundColor(.secondary)
                }
            } else if let block = viewModel.currentBlock {
                blockContentView(block: block)
                    .id(block.id)
            } else if let lesson = viewModel.lesson, lesson.blocks.isEmpty {
                 VStack(spacing: 16) {
                    ProgressView()
                    Text("Generating your course...")
                        .foregroundColor(.secondary)
                }
            }
            
            // Navigation arrows (Floating) - Optional, keep subtle
            HStack {
                if !viewModel.isFirstBlock {
                    Button(action: { withAnimation { viewModel.goToPreviousBlock() } }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                Spacer()
                if viewModel.canAdvance && !viewModel.isLastBlock {
                    Button(action: { withAnimation { viewModel.advanceToNextBlock() } }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }
        }
    }
    
    // MARK: - Block Content View
    
    @ViewBuilder
    private func blockContentView(block: LiveLessonBlock) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                BlockRendererView(block: block, onQuizAnswer: { index in
                    viewModel.submitQuizAnswer(index)
                }, onAction: { actionId in
                })
                .padding(.vertical, 8)
                
                if viewModel.quizSubmitted && viewModel.isQuizCorrect && !viewModel.isLastBlock {
                    Button(action: { withAnimation { viewModel.advanceToNextBlock() } }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(24)
        }
    }
}

// Corner radius modifier helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Lesson Completion View (unchanged from original but styled lightly if needed)
struct LessonCompletionView: View {
    let courseTitle: String
    let lessonTitle: String
    let xpGained: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 32) {
                Image(systemName: "trophy.fill").font(.system(size: 60)).foregroundColor(.yellow)
                VStack(spacing: 8) {
                    Text("Lesson Complete!").font(.largeTitle.bold()).foregroundColor(.white)
                    Text(lessonTitle).font(.title2.weight(.heavy)).foregroundColor(.white)
                }
                Button(action: onDismiss) {
                    Text("Continue Journey")
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(Capsule())
                }.padding(.horizontal, 40)
            }.padding()
        }
    }
}
