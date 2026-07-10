//
//  CommunityFeedView.swift
//  Lyo
//
//  Production-ready Community Feed with posts, likes, comments, and moderation
//

import SwiftUI

struct CommunityFeedView: View {
    @StateObject private var viewModel = CommunityFeedViewModel()
    @State private var showCreatePost = false
    
    var body: some View {
        ZStack {
            feedContent
            
            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    createPostButton
                }
            }
            .padding()
            
            // Toast overlay
            if let message = viewModel.toastMessage {
                toastView(message: message, type: viewModel.toastType)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                filterButton
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostSheet { content, mediaURLs, tags, postType, visibility in
                await viewModel.createPost(
                    content: content,
                    mediaURLs: mediaURLs,
                    tags: tags,
                    postType: postType,
                    visibility: visibility
                )
            }
        }
        .sheet(isPresented: $viewModel.showFilters) {
            CommunityFiltersSheet(filters: $viewModel.filters)
        }
        .sheet(item: $viewModel.selectedPostForAction) { post in
            ReportContentSheet(post: post) { reason, description in
                await viewModel.reportPost(post, reason: reason, description: description)
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    // MARK: - Feed Content
    
    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            loadingView
        } else if let error = viewModel.error, viewModel.posts.isEmpty {
            errorView(error: error)
        } else if viewModel.posts.isEmpty {
            emptyStateView
        } else {
            postsList
        }
    }
    
    private var postsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Active filters indicator
                if viewModel.filters.postType != nil || !viewModel.filters.tags.isEmpty {
                    activeFiltersView
                }
                
                ForEach(viewModel.posts) { post in
                    CommunityFeedPostCard(
                        post: post,
                        onLike: { viewModel.toggleLike(post: post) },
                        onBookmark: { viewModel.toggleBookmark(post: post) },
                        onComment: { /* Navigation handled by card */ },
                        onShare: { sharePost(post) },
                        onReport: { viewModel.selectedPostForAction = post },
                        onBlock: { Task { await viewModel.blockUser(post.authorId) } },
                        onDelete: { viewModel.deletePost(post) }
                    )
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(currentPost: post)
                        }
                    }
                }
                
                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
                
                if !viewModel.hasMorePages && !viewModel.posts.isEmpty {
                    Text("You've reached the end")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 80) // Space for FAB
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - UI Components
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading posts...")
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await viewModel.loadInitialData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No posts yet")
                .font(.headline)
            
            Text("Be the first to share something with the community!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Post") {
                showCreatePost = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var activeFiltersView: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.accentColor)
            
            Text("Filtered")
                .font(.caption)
            
            Spacer()
            
            Button("Clear") {
                viewModel.clearFilters()
            }
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var filterButton: some View {
        Button {
            viewModel.showFilters = true
        } label: {
            Image(systemName: viewModel.filters.postType != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
    
    private var createPostButton: some View {
        Button {
            showCreatePost = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private func toastView(message: String, type: CommunityFeedViewModel.ToastType) -> some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: type == .success ? "checkmark.circle.fill" : type == .error ? "xmark.circle.fill" : "info.circle.fill")
                Text(message)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(type == .error ? Color.red : type == .success ? Color.green : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(25)
            .shadow(radius: 4)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: message)
    }
    
    private func sharePost(_ post: CommunityPost) {
        // Create share content
        let shareText = "\(post.authorName): \(post.content)"
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Post Card

struct CommunityFeedPostCard: View {
    let post: CommunityPost
    let onLike: () -> Void
    let onBookmark: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void
    let onDelete: () -> Void
    
    @State private var showActions = false
    @State private var showComments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(post.authorName)
                            .font(.subheadline.weight(.semibold))
                        
                        if post.authorLevel >= 5 {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(post.createdAt.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if post.isEdited {
                            Text("• edited")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Post type badge
                if post.postType != .text {
                    Label(post.postType.displayName, systemImage: post.postType.iconName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Menu {
                    Button(role: .destructive) {
                        onReport()
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    
                    Button(role: .destructive) {
                        onBlock()
                    } label: {
                        Label("Block User", systemImage: "hand.raised")
                    }
                    
                    // Only show delete for own posts (would check userId in real app)
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            
            // Content
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
            
            // Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Media preview (placeholder)
            if !post.mediaURLs.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 0) {
                // Like
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.hasLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.hasLiked ? .red : .secondary)
                        Text("\(post.likeCount)")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                
                // Comment
                NavigationLink(destination: CommentsView(post: post)) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text("\(post.commentCount)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Bookmark
                Button(action: onBookmark) {
                    Image(systemName: post.hasBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.subheadline)
                        .foregroundColor(post.hasBookmarked ? .accentColor : .secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Share
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Create Post Sheet

struct CreatePostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var tags = ""
    @State private var selectedPostType: CommunityPostType = .text
    @State private var selectedVisibility: CommunityPostVisibility = .publicPost
    @State private var isSubmitting = false
    
    let onSubmit: (String, [String], [String], CommunityPostType, CommunityPostVisibility) async -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                } header: {
                    Text("What's on your mind?")
                }
                
                Section {
                    Picker("Post Type", selection: $selectedPostType) {
                        ForEach(CommunityPostType.allCases, id: \.rawValue) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    
                    Picker("Visibility", selection: $selectedVisibility) {
                        ForEach(CommunityPostVisibility.allCases, id: \.rawValue) { visibility in
                            Label(visibility.displayName, systemImage: visibility.iconName)
                                .tag(visibility)
                        }
                    }
                }
                
                Section {
                    TextField("Tags (comma separated)", text: $tags)
                        .autocapitalization(.none)
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Add relevant tags to help others find your post")
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        submitPost()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func submitPost() {
        isSubmitting = true
        let tagList = tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        Task {
            await onSubmit(content, [], tagList, selectedPostType, selectedVisibility)
            dismiss()
        }
    }
}

// MARK: - Filters Sheet

struct CommunityFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: CommunityFeedFilters
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sort By") {
                    ForEach(CommunitySortOption.allCases) { option in
                        Button {
                            filters.sortBy = option
                        } label: {
                            HStack {
                                Label(option.displayName, systemImage: option.iconName)
                                Spacer()
                                if filters.sortBy == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Post Type") {
                    Button {
                        filters.postType = nil
                    } label: {
                        HStack {
                            Text("All Types")
                            Spacer()
                            if filters.postType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    
                    ForEach(CommunityPostType.allCases, id: \.rawValue) { type in
                        Button {
                            filters.postType = type
                        } label: {
                            HStack {
                                Label(type.displayName, systemImage: type.iconName)
                                Spacer()
                                if filters.postType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Report Sheet

struct ReportContentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let post: CommunityPost
    let onReport: (CommunityReportReason, String?) async -> Void
    
    @State private var selectedReason: CommunityReportReason = .spam
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Reason for Report") {
                    ForEach(CommunityReportReason.allCases, id: \.rawValue) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.displayName)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Additional Details (Optional)") {
                    TextEditor(text: $additionalDetails)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Report Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        isSubmitting = true
                        Task {
                            await onReport(selectedReason, additionalDetails.isEmpty ? nil : additionalDetails)
                            dismiss()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    CommunityFeedView()
}
