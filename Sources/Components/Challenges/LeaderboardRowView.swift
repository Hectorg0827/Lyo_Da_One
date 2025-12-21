import SwiftUI

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Image(systemName: rankMedalIcon)
                        .font(.system(size: 24))
                        .foregroundColor(rankMedalColor)
                } else {
                    Text("#\(entry.rank)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
            }
            .frame(width: 40)
            
            // Avatar
            ZStack {
                Circle()
                    .fill(Color("Primary").opacity(0.3))
                    .frame(width: 44, height: 44)
                
                if let avatarURLString = entry.avatarURL, let avatarURL = URL(string: avatarURLString) {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color("Primary"))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Text(entry.userName.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.userName)
                        .font(.system(size: 16, weight: isCurrentUser ? .bold : .semibold))
                        .foregroundColor(.white)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.system(size: 13))
                            .foregroundColor(Color("LyoAccent"))
                    }
                    
                    if let badge = entry.badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color("LyoAccent").opacity(0.3))
                            )
                    }
                }
                
                HStack(spacing: 8) {
                    Text("Level \(entry.level)")
                        .font(.system(size: 13))
                        .foregroundColor(Color("LyoTextSecondary"))
                    
                    Circle()
                        .fill(Color("LyoTextSecondary"))
                        .frame(width: 3, height: 3)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("\(formatNumber(entry.xp)) XP")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Color("LyoTextSecondary"))
                }
            }
            
            Spacer()
            
            // Rank change indicator (optional)
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
                .opacity(0) // Can be toggled based on rank changes
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color("Primary").opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isCurrentUser ? Color("LyoAccent") : Color.clear, lineWidth: 2)
        )
    }
    
    private var rankMedalIcon: String {
        switch entry.rank {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
    
    private var rankMedalColor: Color {
        switch entry.rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        default: return .clear
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}
