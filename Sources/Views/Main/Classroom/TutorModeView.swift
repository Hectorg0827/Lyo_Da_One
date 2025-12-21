import SwiftUI

struct TutorModeView: View {
    let courseId: String
    let lessonId: String
    let onClose: () -> Void
    
    // Optional titles for stack registration
    var courseTitle: String = "Course"
    var lessonTitle: String = "Lesson"
    
    @EnvironmentObject var uiState: AppUIState
    
    @StateObject private var viewModel: TutorViewModel
    @State private var scrollProxy: ScrollViewProxy?
    
    init(courseId: String, lessonId: String, onClose: @escaping () -> Void, courseTitle: String = "Course", lessonTitle: String = "Lesson") {
        self.courseId = courseId
        self.lessonId = lessonId
        self.onClose = onClose
        self.courseTitle = courseTitle
        self.lessonTitle = lessonTitle
        _viewModel = StateObject(wrappedValue: TutorViewModel(courseId: courseId, lessonId: lessonId))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if viewModel.messages.isEmpty && !viewModel.isLoading {
                                emptyStateView
                            } else {
                                ForEach(viewModel.messages) { msg in
                                    messageRow(msg)
                                        .id(msg.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        scrollToBottom()
                    }
                }
                
                Divider()
                
                // Input bar
                inputBar
                    .padding()
                    .background(DesignSystem.Colors.fallbackSurface)
            }
            .background(DesignSystem.Colors.fallbackBackground)
            .navigationTitle("Tutor Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onClose()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Close")
                        }
                        .foregroundColor(DesignSystem.Colors.fallbackPrimary)
                    }
                }
            }
            .task {
                await viewModel.setupSession()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                uiState.isTutorActive = true
                // Register tutor session in UI Stack
                UIStackStore.shared.upsertTutor(
                    courseId: courseId,
                    lessonId: lessonId,
                    courseTitle: courseTitle,
                    lessonTitle: lessonTitle
                )
            }
            .onDisappear {
                uiState.isTutorActive = false
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.fallbackPrimary.opacity(0.6))
            
            Text("Ask Lio Anything")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Get help understanding this lesson, ask questions, or explore concepts in depth.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask Lio about this lesson…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .lineLimit(1...4)
                .foregroundColor(.white)
            
            if viewModel.isLoading {
                ProgressView()
                    .tint(DesignSystem.Colors.fallbackPrimary)
                    .padding(.trailing, 4)
            } else {
                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                       .gray : DesignSystem.Colors.fallbackPrimary)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func messageRow(_ msg: TutorMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if msg.sender == "ai" {
                // AI Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: msg.sender == "user" ? .trailing : .leading, spacing: 6) {
                Text(msg.sender == "user" ? "You" : "Lio")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)
                
                Text(msg.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(14)
                    .background(
                        msg.sender == "user" ? 
                        DesignSystem.Colors.fallbackPrimary.opacity(0.2) : 
                        Color.white.opacity(0.08)
                    )
                    .cornerRadius(16)
            }
            .frame(maxWidth: .infinity, alignment: msg.sender == "user" ? .trailing : .leading)
            
            if msg.sender == "user" {
                Spacer()
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Actions
    
    private func scrollToBottom() {
        guard let lastMessage = viewModel.messages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TutorModeView(
        courseId: "test-course",
        lessonId: "test-lesson",
        onClose: {}
    )
}
