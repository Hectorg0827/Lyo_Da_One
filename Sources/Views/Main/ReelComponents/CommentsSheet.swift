import SwiftUI

struct CommentsSheet: View {
    let item: DiscoverItem
    @Binding var isPresented: Bool
    
    @StateObject private var discoveryService = DiscoveryService.shared
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading && comments.isEmpty {
                    ProgressView()
                        .padding()
                } else if comments.isEmpty {
                    emptyState
                } else {
                    commentsList
                }
                
                // Input Area
                inputArea
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
            .task {
                await loadComments()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            Text("No comments yet")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Be the first to share your thoughts!")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
            Spacer()
        }
    }
    
    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(comments) { comment in
                    DiscoverCommentRow(comment: comment)
                }
            }
            .padding()
        }
    }
    
    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .lineLimit(1...5)
            
            Button {
                Task {
                    await postComment()
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
                .padding(.top, -0.5),
            alignment: .top
        )
    }
    
    private func loadComments() async {
        isLoading = true
        do {
            comments = try await discoveryService.fetchComments(discoveryId: item.id)
        } catch {
            print("Failed to load comments: \(error)")
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    private func postComment() async {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let pendingComment = text
        newCommentText = "" // Clear input immediately
        
        do {
            let newComment = try await discoveryService.postComment(discoveryId: item.id, content: pendingComment)
            withAnimation {
                comments.append(newComment)
            }
        } catch {
            print("Failed to post comment: \(error)")
            self.error = error.localizedDescription
            newCommentText = pendingComment // Restore text on failure
        }
    }
}

struct DiscoverCommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: comment.author.avatarURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author.name)
                        .font(.subheadline.bold())
                    
                    Spacer()
                    
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(comment.content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
    }
}
