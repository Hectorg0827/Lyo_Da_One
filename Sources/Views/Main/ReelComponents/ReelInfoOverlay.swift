import SwiftUI

struct ReelInfoOverlay: View {
    let item: DiscoverItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Creator Profile & Badge
            if let author = item.authorName {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        // Level-based Ring
                        Circle()
                            .stroke(colorForLevel(item.level), lineWidth: 2)
                            .frame(width: 34, height: 34)
                        
                        if let avatarURL = item.authorAvatarURL {
                            AsyncImage(url: avatarURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Text(author.prefix(1)).font(.caption.bold()).foregroundColor(.white)
                            }
                            .clipShape(Circle())
                            .frame(width: 32, height: 32)
                        } else {
                            Text(author.prefix(1)).font(.caption.bold()).foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(author)
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)
                        
                        Text("Verified Mentor") // Placeholder logic
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // Key Points (The "Learning Wrapper")
                if !item.keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.keyPoints.prefix(3), id: \.self) { point in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .padding(.top, 2)
                                
                                Text(point)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.95))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else if let subtitle = item.subtitle {
                     Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
            }
            
            // Community Link
            if let groupId = item.relatedGroupId {
                Button(action: { /* Open Group */ }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.caption2)
                        Text("Join \(groupId) Study Group")
                            .font(.caption2.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func colorForLevel(_ level: LearningLevel) -> Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .yellow
        case .advanced: return .red
        }
    }
}
