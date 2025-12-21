import SwiftUI

struct StoryCircleView: View {
    let story: Story
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Ring
                Circle()
                    .strokeBorder(
                        story.isSeen ? Color.gray.opacity(0.3) : DesignSystem.Colors.primary,
                        lineWidth: 2.5
                    )
                    .frame(width: 68, height: 68)
                
                // Avatar
                if let avatar = story.userAvatar {
                    if avatar == "sparkles" || avatar == "atom" { // System images for mock data
                        Image(systemName: avatar)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .frame(width: 60, height: 60)
                            .background(Color.black.opacity(0.1))
                            .clipShape(Circle())
                    } else {
                        // Real image URL (would use AsyncImage here)
                        // Using placeholder for now
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                }
                
                // Live Badge
                if story.isLive {
                    VStack {
                        Spacer()
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                            .offset(y: 8)
                    }
                }
            }
            .frame(width: 70, height: 75) // Provide space for badge
            
            // Name
            Text(story.userName)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 70)
        }
        .opacity(story.isSeen ? 0.6 : 1.0)
    }
}

// Add Story Button Variant
struct AddStoryCircleView: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundColor(Color(.systemGray6))
                
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                // Positioned on the ring line
                Circle()
                    .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1, antialiased: true)
                    .frame(width: 68, height: 68)
                    .opacity(0) // Hidden ring, just for layout consistency if needed
            }
            .frame(width: 70, height: 75)
            
            Text("Your Story")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
