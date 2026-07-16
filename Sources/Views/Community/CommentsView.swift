//
//  CommentsView.swift
//  Lyo
//
//  Shared Community comments list and composer
//

import SwiftUI
import os

struct CommentsView: View {
    let post: CommunityPost
    @StateObject private var viewModel: CommentsViewModel
    
    init(post: CommunityPost) {
        self.post = post
        self._viewModel = StateObject(wrappedValue: CommentsViewModel(post: post))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Comments list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Original post summary
                    postSummary
                    
                    Divider()
                        .padding(.vertical, 12)
                    
                    // Comments header
                    HStack {
                        Text("Comments")
                            .font(.headline)
                        
                        Text("(\(viewModel.comments.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    if viewModel.isLoading && viewModel.comments.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.comments.isEmpty {
                        emptyCommentsView
                    } else {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(comment: comment)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentComment: comment)
                            }
                        }
                        
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }
            
            Divider()
            
            // Comment input
            commentInput
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .background(DesignTokens.Colors.background)
        .task {
            await viewModel.loadComments()
        }
        .alert("Community error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "Please try again.")
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Post Summary
    
    private var postSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.subheadline.weight(.semibold))
                    Text(post.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(post.content)
                .font(.subheadline)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            if post.postType != .text {
                Label(post.postType.displayName, systemImage: post.postType.iconName)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.accent)
            }

            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.accent)
                        }
                    }
                }
            }

            if !post.mediaURLs.isEmpty {
                TabView {
                    ForEach(post.mediaURLs, id: \.self) { mediaURL in
                        AsyncImage(url: URL(string: mediaURL)) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            case .failure: Image(systemName: "photo.badge.exclamationmark")
                            default: ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                }
                .frame(height: 200)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: post.mediaURLs.count > 1 ? .automatic : .never))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            }

            HStack {
                Button(action: viewModel.togglePostLike) {
                    Label("\(viewModel.postLikeCount)", systemImage: viewModel.isPostLiked ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isPostLiked ? .red : DesignTokens.Colors.textSecondary)
                }
                Spacer()
                Label("\(viewModel.postCommentCount)", systemImage: "bubble.left")
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Button(action: viewModel.togglePostBookmark) {
                    Image(systemName: viewModel.isPostBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(viewModel.isPostBookmarked ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
                }
                Spacer()
                Button(action: sharePost) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(DesignTokens.Colors.surface)
    }

    private func sharePost() {
        let activity = UIActivityViewController(
            activityItems: ["\(post.authorName): \(post.content)"],
            applicationActivities: nil
        )
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(activity, animated: true)
    }
    
    // MARK: - Empty State
    
    private var emptyCommentsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No comments yet")
                .font(.headline)
            
            Text("Be the first to share your thoughts!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Comment Input
    
    private var commentInput: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                TextField("Add a comment...", text: $viewModel.newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                
                Button {
                    Task {
                        await viewModel.submitComment()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                }
                .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(DesignTokens.Colors.background)
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: PostComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(comment.authorName.prefix(1)).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Author and time
                    HStack {
                        Text(comment.authorName)
                            .font(.subheadline.weight(.semibold))
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(comment.createdAt.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // Content
                    Text(comment.content)
                        .font(.subheadline)
                    
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Comments ViewModel

@MainActor
final class CommentsViewModel: ObservableObject {
    let post: CommunityPost
    
    @Published var comments: [PostComment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSubmitting = false
    @Published var newCommentText = ""
    @Published var error: String?
    @Published var isPostLiked: Bool
    @Published var postLikeCount: Int
    @Published var isPostBookmarked: Bool
    @Published var postCommentCount: Int
    @Published var isPostActionBusy = false
    
    private var currentPage = 1
    private var hasMorePages = true
    private let pageSize = 20
    private let service = CommunityService.shared
    
    init(post: CommunityPost) {
        self.post = post
        self.isPostLiked = post.hasLiked
        self.postLikeCount = post.likeCount
        self.isPostBookmarked = post.hasBookmarked
        self.postCommentCount = post.commentCount
    }
    
    func loadComments() async {
        guard !isLoading else { return }
        
        isLoading = true
        currentPage = 1
        
        do {
            let response = try await service.fetchComments(
                postId: post.id,
                page: currentPage,
                limit: pageSize
            )
            
            comments = response.items
            hasMorePages = response.hasNextPage
            Log.social.info("Loaded \(self.comments.count) comments")
        } catch {
            self.error = error.localizedDescription
            Log.social.error("Failed to load comments: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMoreIfNeeded(currentComment: PostComment) {
        guard let index = comments.firstIndex(where: { $0.id == currentComment.id }),
              index >= comments.count - 3,
              hasMorePages,
              !isLoadingMore else {
            return
        }
        
        Task {
            await loadMore()
        }
    }
    
    private func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let response = try await service.fetchComments(
                postId: post.id,
                page: currentPage,
                limit: pageSize
            )
            
            let existingIds = Set(comments.map { $0.id })
            let newComments = response.items.filter { !existingIds.contains($0.id) }
            
            comments.append(contentsOf: newComments)
            hasMorePages = response.hasNextPage
        } catch {
            currentPage -= 1
            Log.social.error("Failed to load more comments: \(error)")
        }
        
        isLoadingMore = false
    }
    
    func submitComment() async {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        isSubmitting = true
        
        let request = CommunityCreateCommentRequest(
            content: trimmedText,
            parentId: nil
        )
        
        do {
            let newComment = try await service.createComment(postId: post.id, request: request)
            
            comments.insert(newComment, at: 0)
            postCommentCount += 1
            newCommentText = ""
            Log.social.info("Comment posted")
        } catch {
            self.error = error.localizedDescription
            Log.social.error("Failed to post comment: \(error)")
        }
        
        isSubmitting = false
    }

    func togglePostLike() {
        guard !isPostActionBusy else { return }
        let wasLiked = isPostLiked
        isPostLiked.toggle()
        postLikeCount += wasLiked ? -1 : 1
        isPostActionBusy = true
        Task {
            do {
                let response = try await service.toggleLike(postId: post.id)
                isPostLiked = response.liked
                postLikeCount = response.likeCount
            } catch {
                isPostLiked = wasLiked
                postLikeCount += wasLiked ? 1 : -1
                self.error = error.localizedDescription
            }
            isPostActionBusy = false
        }
    }

    func togglePostBookmark() {
        guard !isPostActionBusy else { return }
        let wasBookmarked = isPostBookmarked
        isPostBookmarked.toggle()
        isPostActionBusy = true
        Task {
            do {
                let response = try await service.toggleBookmark(postId: post.id)
                isPostBookmarked = response.bookmarked
            } catch {
                isPostBookmarked = wasBookmarked
                self.error = error.localizedDescription
            }
            isPostActionBusy = false
        }
    }
    
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CommentsView(post: CommunityPost(
            id: "preview-1",
            authorId: "user1",
            authorName: "Jane Doe",
            authorAvatar: nil,
            authorLevel: 5,
            content: "This is a sample post for the comments preview. What do you think about this topic?",
            mediaURLs: [],
            tags: ["preview", "test"],
            likeCount: 42,
            commentCount: 15,
            hasLiked: true,
            hasBookmarked: false,
            postType: .questionDiscussion,
            linkedCourseId: nil,
            linkedGroupId: nil,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3600),
            isEdited: false,
            isPinned: false,
            visibility: .publicPost
        ))
    }
}
