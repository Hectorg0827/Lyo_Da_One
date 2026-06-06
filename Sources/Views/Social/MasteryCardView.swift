
import SwiftUI

struct MasteryCardView: View {
    let post: RepoPost
    let onAction: (PostAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Mastery Badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "FF8C00"))
                    
                    Text("MASTERY HIGHLIGHT")
                        .font(.custom("Futura-Bold", size: 10))
                        .foregroundColor(Color(hex: "FF8C00"))
                        .tracking(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "FF8C00").opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                Menu {
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
            
            // Main Content
            Text(post.content)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            Divider()
                .background(Color(hex: "FF8C00").opacity(0.3))
            
            // Footer with Actions
            HStack(spacing: 20) {
                // Like Button
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
                
                Spacer()
                
                // Author Attribution
                HStack(spacing: 8) {
                    if let avatar = post.author.avatarURL {
                        AsyncImage(url: URL(string: avatar)) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    }
                    
                    Text(post.author.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color("CardBackground").opacity(0.8) // Assumes asset or fallback
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "FF8C00").opacity(0.6), Color(hex: "FFD700").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .cornerRadius(20)
        .shadow(color: Color(hex: "FF8C00").opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}
