import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let onStart: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Difficulty badge
                HStack(spacing: 4) {
                    Image(systemName: challenge.difficulty.icon)
                        .font(.system(size: 12))
                    Text(challenge.difficulty.rawValue.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(difficultyColor)
                )
                
                Spacer()
                
                // XP Reward
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color("LyoAccent"))
                    Text("+\(challenge.xpReward) XP")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color("LyoAccent"))
                }
            }
            
            // Title
            Text(challenge.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text(challenge.description)
                .font(.system(size: 14))
                .foregroundColor(Color("LyoTextSecondary"))
                .lineLimit(2)
            
            // Progress bar
            if challenge.progress > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color("LyoSurface"))
                                .frame(height: 6)
                            
                            Rectangle()
                                .fill(Color("BrandPrimary"))
                                .frame(width: geometry.size.width * CGFloat(challenge.progress), height: 6)
                                .animation(.easeOut(duration: 0.3), value: challenge.progress)
                        }
                    }
                    .frame(height: 6)
                    .clipShape(Capsule())
                    
                    Text("\(Int(challenge.progress * 100))% Complete")
                        .font(.system(size: 12))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
            }
            
            // Footer
            HStack {
                // Time limit
                if let timeLimit = challenge.timeLimit {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("\(timeLimit) min")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color("LyoTextSecondary"))
                }
                
                // Expires
                if let expiresAt = challenge.expiresAt {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 12))
                        Text("Expires \(timeUntil(expiresAt))")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.orange)
                }
                
                Spacer()
                
                // Action button
                Button {
                    onStart()
                } label: {
                    Text(challenge.isCompleted ? "Completed" : "Start")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(challenge.isCompleted ? Color.green : Color("BrandPrimary"))
                        )
                }
                .disabled(challenge.isCompleted)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoSurface"))
        )
    }
    
    private var difficultyColor: Color {
        switch challenge.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        case .expert: return .purple
        }
    }
    
    private func timeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        let hours = Int(interval / 3600)
        if hours > 0 {
            return "in \(hours)h"
        }
        let minutes = Int(interval / 60)
        return "in \(minutes)m"
    }
}
