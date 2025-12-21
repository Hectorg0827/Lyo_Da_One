import SwiftUI

struct AchievementBadgeView: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? categoryColor.opacity(0.2) : Color("LyoSurface"))
                    .frame(width: 70, height: 70)
                
                if achievement.isUnlocked {
                    Text(achievement.icon)
                        .font(.system(size: 32))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color("LyoTextSecondary").opacity(0.3))
                }
            }
            
            // Title
            Text(achievement.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(achievement.isUnlocked ? .white : Color("LyoTextSecondary"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 36)
            
            // Progress or unlock date
            if achievement.isUnlocked {
                if let unlockedAt = achievement.unlockedAt {
                    Text(formatDate(unlockedAt))
                        .font(.system(size: 11))
                        .foregroundColor(categoryColor)
                }
            } else {
                // Progress bar
                if achievement.progress > 0 {
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color("LyoSurface"))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(categoryColor)
                                    .frame(width: geometry.size.width * CGFloat(achievement.progress), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .clipShape(Capsule())
                        
                        Text("\(Int(achievement.progress * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                } else {
                    Text("Locked")
                        .font(.system(size: 11))
                        .foregroundColor(Color("LyoTextSecondary").opacity(0.5))
                }
            }
        }
        .padding()
        .frame(width: 140, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoSurface"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(achievement.isUnlocked ? categoryColor.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
    
    private var categoryColor: Color {
        switch achievement.category {
        case .learning: return Color("Primary")
        case .streak: return .orange
        case .battle: return .red
        case .social: return .green
        case .special: return Color("LyoAccent")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
