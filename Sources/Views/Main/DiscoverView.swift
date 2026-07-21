import SwiftUI

// MARK: - Discover View

struct DiscoverView: View {
    @EnvironmentObject var uiState: AppUIState
    @EnvironmentObject var uiStackStore: UIStackStore
    
    @StateObject private var viewModel = DiscoverViewModel()
    // Unified AI ViewModel from MainTabView environment
    @EnvironmentObject var lyoAIViewModel: LyoAIViewModel
    
    // Navigation state
    @State private var selectedCourse: (id: String, lessonId: String?, title: String)?
    @State private var showClassroom = false
    @State private var showLioChat = false
    @State private var itemToShare: DiscoverItem?
    @State private var animateHeader = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Content Layer (Full Screen)
                if viewModel.isLoading {
                    PremiumBackground()
                    LoadingDots(count: 3, color: .white, size: 10)
                } else if viewModel.filteredItems.isEmpty {
                    PremiumBackground()
                    emptyState
                } else {
                    feedContent
                }
                
                // Header Overlay
                VStack(spacing: 0) {
                    // Keep search field below header
                    premiumSearchField
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .padding(.top, 60) // Add top padding for App Drawer button
                }
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateHeader = true
                }
            }
        }
        .fullScreenCover(isPresented: $showClassroom) {
            if let course = selectedCourse {
                LivingClassroomView(
                    courseId: course.id,
                    courseTitle: course.title
                )
                .environmentObject(uiStackStore)
                .environmentObject(uiState)
            }
        }
        .sheet(isPresented: $showLioChat) {
            LioChatSheet(isPresented: $showLioChat)
                .environmentObject(uiState)
                .environmentObject(lyoAIViewModel) // FIX: provide required EnvironmentObject
        }
        .sheet(item: $itemToShare) { item in
            ActivityViewController(activityItems: viewModel.prepareShareItems(for: item))
                .onAppear {
                    // Count the share on the backend (same contract web/Android use)
                    Task { await DiscoveryService.shared.recordShare(discoveryId: item.id) }
                }
        }
        // Present the context sheet using the selected item so the closure always returns a View
        .sheet(item: $viewModel.selectedContextItem) { item in
            SimpleVideoContextSheet(item: item, onPromptSelected: { prompt in
                // Dismiss by clearing the item
                viewModel.selectedContextItem = nil
                
                // Small delay to allow dismissal animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    uiState.lioContextHint = prompt
                    showLioChat = true
                }
            })
            .presentationDetents([.medium, .fraction(0.4)])
            .presentationDragIndicator(.visible)
            .applyPresentationBackgroundIfAvailable()
        }
        .sheet(item: $viewModel.selectedItemForComments) { item in
            CommentsSheet(item: item, isPresented: Binding(
                get: { viewModel.selectedItemForComments != nil },
                set: { if !$0 { viewModel.selectedItemForComments = nil } }
            ))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Retry")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Header Section
    
    // MARK: - Header Section
    // Replaced by TopHeaderView
    private var headerSection: some View {
        EmptyView()
    }
    
    // MARK: - Premium Search Field
    
    private var premiumSearchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.8))
            
            TextField("Search topics, courses, skills...", text: $viewModel.searchQuery)
                .foregroundColor(.white)
                .placeholder(when: viewModel.searchQuery.isEmpty) {
                    Text("Search topics, courses, skills...")
                        .foregroundColor(.white.opacity(0.7))
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Feed Content
    
    private var feedContent: some View {
        GeometryReader { geometry in
            TabView {
                ForEach(viewModel.filteredItems) { item in
                    DiscoverReelView(
                        item: item,
                        onLike: { 
                            viewModel.toggleLike(for: item)
                        },
                        onComment: { 
                            viewModel.commentsAction(item: item)
                        },
                        onShare: { 
                            itemToShare = item
                        },
                        onSave: { 
                            viewModel.toggleSave(for: item) 
                        },
                        onAskLio: { askLioAbout(item) },
                        onStart: { startAction(for: item) },
                        onConvertToCourse: { viewModel.convertToCourse(item: item) }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        EmptyStateView(
            iconName: "magnifyingglass",
            title: "No results found",
            message: "Try a different search term or check back later for new discoveries."
        )
    }
    
    // MARK: - Actions
    
    private func startAction(for item: DiscoverItem) {
        HapticManager.shared.medium()
        
        guard let courseId = item.courseId else {
            // If no courseId, just save to Stack
            viewModel.saveToStack(item: item)
            return
        }
        
        selectedCourse = (id: courseId, lessonId: item.lessonId, title: item.title)
        showClassroom = true
    }
    
    private func saveAction(for item: DiscoverItem) {
        viewModel.saveToStack(item: item)
    }
    
    private func askLioAbout(_ item: DiscoverItem) {
        HapticManager.shared.light()
        // Present the context sheet by setting the item
        viewModel.selectedContextItem = item
    }
}

// Helper for placeholder color
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
    
    // Apply presentation background when available (iOS 16.4+)
    @ViewBuilder
    func applyPresentationBackgroundIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.ultraThinMaterial)
        } else {
            self
        }
    }
}

// MARK: - Activity View Controller (Share Sheet)

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

// MARK: - Preview

#Preview {
    DiscoverView()
        .environmentObject(AppUIState())
        .environmentObject(UIStackStore.shared)
}
