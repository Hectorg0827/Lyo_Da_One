//
//  CommentsView.swift
//  Lyo
//
//  Full comments system with replies, likes, and moderation
//

import SwiftUI
import os

struct CommentsView: View {
    let post: CommunityPost
    @StateObject private var viewModel: CommentsViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                            CommentRow(
                                comment: comment,
                                onLike: { viewModel.likeComment(comment) },
                                onReply: { viewModel.startReply(to: comment) },
                                onDelete: { viewModel.deleteComment(comment) },
                                onReport: { viewModel.reportComment(comment) },
                                canDelete: viewModel.canDelete(comment)
                            )
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
        .task {
            await viewModel.loadComments()
        }
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
                .lineLimit(3)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
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
            // Reply indicator
            if let replyingTo = viewModel.replyingTo {
                HStack {
                    Text("Replying to \(replyingTo.authorName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        viewModel.cancelReply()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
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
        .background(Color(.systemBackground))
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: PostComment
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let canDelete: Bool
    
    @State private var showReplies = false
    
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
                        
                        if comment.isEdited {
                            Text("(edited)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button {
                                onReport()
                            } label: {
                                Label("Report", systemImage: "flag")
                            }
                            
                            if canDelete {
                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(4)
                        }
                    }
                    
                    // Content
                    Text(comment.content)
                        .font(.subheadline)
                    
                    // Actions
                    HStack(spacing: 16) {
                        Button(action: onLike) {
                            HStack(spacing: 4) {
                                Image(systemName: comment.hasLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                    .foregroundColor(comment.hasLiked ? .red : .secondary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button(action: onReply) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.caption)
                                Text("Reply")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if comment.replyCount > 0 {
                            Button {
                                showReplies.toggle()
                            } label: {
                                Text(showReplies ? "Hide replies" : "View \(comment.replyCount) replies")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            // Replies (would be loaded separately in full implementation)
            if showReplies {
                Text("Replies would load here...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 42)
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
    @Published var replyingTo: PostComment?
    @Published var error: String?
    
    private var currentPage = 1
    private var hasMorePages = true
    private let pageSize = 20
    private let service = CommunityService.shared
    
    init(post: CommunityPost) {
        self.post = post
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
            parentId: replyingTo?.id
        )
        
        do {
            let newComment = try await service.createComment(postId: post.id, request: request)
            
            if replyingTo != nil {
                // For replies, we'd insert under parent - simplified here
                comments.append(newComment)
            } else {
                comments.insert(newComment, at: 0)
            }
            
            newCommentText = ""
            replyingTo = nil
            Log.social.info("Comment posted")
        } catch {
            Log.social.error("Failed to post comment: \(error)")
        }
        
        isSubmitting = false
    }
    
    func startReply(to comment: PostComment) {
        replyingTo = comment
    }
    
    func cancelReply() {
        replyingTo = nil
    }
    
    func likeComment(_ comment: PostComment) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        
        // Optimistic update
        comments[index].hasLiked.toggle()
        comments[index].likeCount += comments[index].hasLiked ? 1 : -1
        
        Task {
            do {
                let response = try await service.likeComment(postId: post.id, commentId: comment.id)
                comments[index].hasLiked = response.liked
                comments[index].likeCount = response.likeCount
            } catch {
                // Revert
                comments[index].hasLiked.toggle()
                comments[index].likeCount += comments[index].hasLiked ? 1 : -1
            }
        }
    }
    
    func deleteComment(_ comment: PostComment) {
        Task {
            do {
                try await service.deleteComment(postId: post.id, commentId: comment.id)
                comments.removeAll { $0.id == comment.id }
            } catch {
                Log.social.error("Failed to delete comment: \(error)")
            }
        }
    }
    
    func reportComment(_ comment: PostComment) {
        Task {
            let request = CommunityReportRequest(
                targetType: .comment,
                targetId: comment.id,
                reason: .harassment,
                description: nil
            )
            do {
                _ = try await service.reportContent(request)
                Log.social.info("Comment reported")
            } catch {
                Log.social.error("Failed to report comment: \(error)")
            }
        }
    }
    
    func canDelete(_ comment: PostComment) -> Bool {
        // In real app, check against current user ID
        // For now, allow delete on all (demo purposes)
        return true
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
