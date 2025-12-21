import SwiftUI

struct SocialFeedSection: View {
    @ObservedObject var viewModel: LyoAIViewModel
    
    var body: some View {
        LazyVStack(spacing: 24) {
            // Header
            HStack {
                Text("Community Updates")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Suggested Users Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.suggestedUsers) { user in
                        SuggestedUserCard(user: user)
                    }
                }
                .padding(.horizontal)
            }
            
            // Posts
            ForEach(viewModel.socialPosts) { post in
                HybridPostCard(post: post)
            }
            
            // Bottom Spacer
            Spacer().frame(height: 100)
        }
        .background(Color("LyoBackground"))
    }
}

struct HybridPostCard: View {
    let post: RepoPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.author.name.prefix(1)))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("2h ago") // Mock time
                        .font(.caption)
                        .foregroundColor(Color("LyoTextSecondary"))
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color("LyoTextSecondary"))
                }
            }
            .padding(.horizontal)
            
            // Content
            Text(post.content)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal)
                .lineLimit(4)
            
            // Image Attachment (if any)
            if let attachments = post.attachments, let _ = attachments.first {
                // Placeholder for async image
                Rectangle()
                    .fill(Color("LyoSurface"))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(Color("LyoTextSecondary"))
                    )
            }
            
            // Actions
            HStack(spacing: 24) {
                PostActionButton(icon: post.isLiked ? "heart.fill" : "heart", count: post.likes, color: post.isLiked ? .red : .white)
                PostActionButton(icon: "bubble.right", count: post.comments, color: .white)
                PostActionButton(icon: "paperplane", count: 0, color: .white)
                Spacer()
                PostActionButton(icon: "bookmark", count: 0, color: .white)
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            Divider()
                .background(Color("LyoSurface"))
                .padding(.top, 12)
        }
    }
}

struct PostActionButton: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct SuggestedUserCard: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color("LyoSurface"))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(user.name.prefix(1)))
                        .font(.title3)
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 4) {
                Text(user.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("Lv. \(user.level)")
                    .font(.caption)
                    .foregroundColor(Color("LyoAccent"))
            }
            
            Button(action: {}) {
                Text("Follow")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoSurface").opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .frame(width: 120)
    }
}
