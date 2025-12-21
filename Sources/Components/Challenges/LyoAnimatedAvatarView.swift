// LyoAnimatedAvatarView.swift
import SwiftUI

struct LyoAnimatedAvatarView: View {
    let size: CGFloat
    @Binding var state: LyoAvatarState
    
    var body: some View {
        ZStack {
            // Placeholder visual for the animated avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color("LyoAccent"), Color("Primary")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Text(avatarEmoji(for: state))
                        .font(.system(size: size * 0.35))
                        .minimumScaleFactor(0.5)
                )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.white.opacity(0.2), lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.25), value: state)
    }
    
    private func avatarEmoji(for state: LyoAvatarState) -> String {
        switch state {
        case .idle: return "🦁"
        case .talking: return "💬"
        case .thinking: return "🤔"
        case .happy: return "😄"
        case .sad: return "😕"
        case .reading: return "📖"
        }
    }
}
