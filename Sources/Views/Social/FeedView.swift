import SwiftUI

// MARK: - Feed View
struct FeedView: View {

    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedPost: RepoPost?
    @State private var showComments = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Algorithm Selector
                AlgorithmSelector(
                    selectedAlgorithm: $viewModel.selectedAlgorithm,
                    algorithms: viewModel.availableAlgorithms
                ) { algorithm in
                    viewModel.selectAlgorithm(algorithm)
                }

                Divider()

                // Feed Content
                if viewModel.isEmpty {
                    EmptyFeedView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.posts) { post in
                                postRow(for: post)
                                    .onAppear {
                                        // Load more when reaching last post
                                        if post.id == viewModel.posts.last?.id {
                                            Task {
                                                await viewModel.loadMore()
                                            }
                                        }
                                    }

                                Divider()
                            }

                            // Loading indicator for pagination
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Social Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingNewPostSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingNewPostSheet) {
                NewPostView(viewModel: viewModel)
            }
            .sheet(isPresented: $showComments) {
                if let post = selectedPost {
                    CommentsView(post: post, viewModel: viewModel)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
            .task {
                await viewModel.loadFeed(refresh: true)
            }
        }
    }

    private func handlePostAction(post: RepoPost, action: PostAction) {
        switch action {
        case .like:
            Task {
                await viewModel.likePost(post)
            }

        case .comment:
            selectedPost = post
            showComments = true

        case .share:
            // TODO: Implement share sheet
            print("Share post: \(post.id)")

        case .delete:
            Task {
                await viewModel.deletePost(post)
            }
        }
    }

    @ViewBuilder
    private func postRow(for post: RepoPost) -> some View {
        if post.postType == "course_progress" {
            MasteryCardView(post: post) { action in
                handlePostAction(post: post, action: action)
            }
        } else {
            PostCardView(post: post) { action in
                handlePostAction(post: post, action: action)
            }
        }
    }
}

// MARK: - Algorithm Selector
struct AlgorithmSelector: View {
    @Binding var selectedAlgorithm: FeedAlgorithm
    let algorithms: [FeedAlgorithm]
    let onSelect: (FeedAlgorithm) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(algorithms) { algorithm in
                    Button {
                        onSelect(algorithm)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: algorithm.icon)
                                .font(.system(size: 20))

                            Text(algorithm.title)
                                .font(.caption)
                                .fontWeight(selectedAlgorithm == algorithm ? .semibold : .regular)
                        }
                        .foregroundColor(selectedAlgorithm == algorithm ? .blue : .secondary)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Post Card View
struct PostCardView: View {
    let post: RepoPost
    let onAction: (PostAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author Header
            HStack(spacing: 12) {
                // Avatar
                if let avatarURL = post.author.avatarURL {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(post.author.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(.blue)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(post.author.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let level = post.author.level {
                            Text("Lv. \(level)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    Text(timeAgo(from: post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        // TODO: Report post
                    } label: {
                        Label("Report", systemImage: "flag")
                    }

                    Button(role: .destructive) {
                        onAction(.delete)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }

            // Content
            Text(post.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // Attachments
            if let attachments = post.attachments, !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments, id: \.self) { attachment in
                            AsyncImage(url: URL(string: attachment)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                            .clipped()
                        }
                    }
                }
            }

            // Action Bar
            HStack(spacing: 24) {
                // Like
                Button {
                    onAction(.like)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .secondary)
                        Text("\(post.likes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Comment
                Button {
                    onAction(.comment)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.secondary)
                        Text("\(post.comments)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Share
                Button {
                    onAction(.share)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .font(.system(size: 20))
        }
        .padding()
    }

    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else if seconds < 604800 {
            let days = seconds / 86400
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Post Action
enum PostAction {
    case like
    case comment
    case share
    case delete
}

// MARK: - Empty Feed View
struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No posts yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Be the first to share something!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - New Post View
struct NewPostView: View {
    @ObservedObject var viewModel: FeedViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $viewModel.newPostContent)
                    .frame(minHeight: 200)
                    .overlay(
                        Group {
                            if viewModel.newPostContent.isEmpty {
                                Text("What's on your mind?")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                        },
                        alignment: .topLeading
                    )

                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        Task {
                            await viewModel.createPost()
                        }
                    }
                    .disabled(viewModel.newPostContent.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Comments View
struct CommentsView: View {
    let post: RepoPost
    @ObservedObject var viewModel: FeedViewModel
    @Environment(\.dismiss) var dismiss

    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Post Preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(post.author.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(timeAgo(from: post.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(post.content)
                        .font(.body)
                        .lineLimit(3)
                }
                .padding()
                .background(Color(.systemGray6))

                Divider()

                // Comments List
                if isLoading {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if comments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No comments yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Be the first to comment!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(comments) { comment in
                                CommentRowView(comment: comment)
                                Divider()
                            }
                        }
                        .padding()
                    }
                }

                Divider()

                // New Comment Input
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newCommentText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await postComment()
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(newCommentText.isEmpty ? .gray : .blue)
                    }
                    .disabled(newCommentText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                comments = await viewModel.loadComments(for: post)
                isLoading = false
            }
        }
    }

    private func postComment() async {
        let commentText = newCommentText
        newCommentText = ""

        await viewModel.commentOnPost(post, content: commentText)

        // Reload comments
        comments = await viewModel.loadComments(for: post)
    }

    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            if let avatarURL = comment.author.avatarURL {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(comment.author.name.prefix(1)))
                            .font(.caption)
                            .foregroundColor(.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let level = comment.author.level {
                        Text("Lv. \(level)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(timeAgo(from: comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(comment.content)
                    .font(.body)

                HStack(spacing: 16) {
                    Button {
                        // TODO: Like comment
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .font(.caption)
                            Text("\(comment.likes)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h"
        } else {
            let days = seconds / 86400
            return "\(days)d"
        }
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
    }
}
