import SwiftUI

struct ReelActionStrip: View {
    let item: DiscoverItem
    @Binding var isLiked: Bool
    @Binding var isSaved: Bool
    
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onAskLio: () -> Void
    let onSave: () -> Void
    let onConvertToCourse: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            
            // --- Primary Lyo Actions ---
            
            // Ask Lio
            Button(action: onAskLio) {
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    Text("Ask Lio")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Convert to Mini-Course
            Button(action: onConvertToCourse) {
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    Text("Course")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Save / Path
            Button(action: onSave) {
                VStack(spacing: 2) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 26))
                        .foregroundColor(isSaved ? .yellow : .white)
                    
                    Text(isSaved ? "Saved" : "Save")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // --- Social Actions (De-emphasized) ---
            
            // Like
            Button {
                withAnimation(.spring()) {
                    isLiked.toggle()
                }
                onLike()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 26))
                        .foregroundColor(isLiked ? .red : .white)
                    
                    Text(formatCount(item.likeCount + (isLiked ? 1 : 0) - (item.isLiked ? 1 : 0)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Share
            Button(action: onShare) {
                VStack(spacing: 2) {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text("Share")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // Helper used previously in DiscoverReelView
    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return "\(count)"
        }
    }
}
