import SwiftUI

struct BattleCardView: View {
    let battle: Battle
    let currentUserId: String
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var timeRemaining: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.2))
                    )
                
                Spacer()
                
                if battle.endsAt != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(timeRemaining)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(timeRemaining.contains("m") ? .orange : Color("LyoTextSecondary"))
                }
            }
            
            // Battle VS Display
            HStack(spacing: 20) {
                // Current User
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color("BrandPrimary").opacity(0.3))
                            .frame(width: 60, height: 60)
                        
                        Text("You")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if battle.status == .active || battle.status == .completed {
                        Text("\(battle.myScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // VS
                VStack(spacing: 4) {
                    Text("VS")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("LyoAccent"))
                    
                    if battle.status == .active {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                }
                
                // Opponent
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color("BrandSecondary").opacity(0.3))
                            .frame(width: 60, height: 60)
                        
                        if let avatarURLString = battle.opponentAvatar, let avatarURL = URL(string: avatarURLString) {
                            LyoImage(url: avatarURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Text(battle.opponentName.prefix(1).uppercased())
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Text(battle.opponentName.prefix(1).uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    if battle.status == .active || battle.status == .completed {
                        Text("\(battle.opponentScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Opponent Name
            Text(battle.opponentName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            // Action buttons
            if battle.status == .pending {
                HStack(spacing: 12) {
                    Button {
                        onDecline()
                    } label: {
                        Text("Decline")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color("LyoTextSecondary"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("LyoSurface"))
                            )
                    }
                    
                    Button {
                        onAccept()
                    } label: {
                        Text("Accept Battle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("BrandPrimary"))
                        )
                    }
                }
            } else if battle.status == .active {
                Button {
                    // Navigate to battle
                } label: {
                    Text("Continue Battle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("BrandPrimary"))
                        )
                }
            } else if battle.status == .completed {
                HStack(spacing: 8) {
                    Image(systemName: battle.myScore > battle.opponentScore ? "trophy.fill" : "flag.fill")
                        .font(.system(size: 16))
                    Text(battle.myScore > battle.opponentScore ? "Victory!" : "Try Again")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(battle.myScore > battle.opponentScore ? Color("LyoAccent") : Color("LyoTextSecondary"))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoSurface"))
        )
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
        .onAppear {
            updateTimeRemaining()
        }
    }
    
    private var statusText: String {
        switch battle.status {
        case .pending: return "Challenge Received"
        case .active: return "Battle In Progress"
        case .completed: return "Battle Complete"
        case .expired: return "Expired"
        }
    }
    
    private var statusColor: Color {
        switch battle.status {
        case .pending: return .orange
        case .active: return .green
        case .completed: return .blue
        case .expired: return .gray
        }
    }
    
    private func updateTimeRemaining() {
        guard let endsAt = battle.endsAt else {
            timeRemaining = ""
            return
        }
        
        let interval = endsAt.timeIntervalSince(Date())
        if interval <= 0 {
            timeRemaining = "Ended"
            return
        }
        
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            timeRemaining = "\(hours)h \(minutes)m"
        } else {
            timeRemaining = "\(minutes)m"
        }
    }
}
