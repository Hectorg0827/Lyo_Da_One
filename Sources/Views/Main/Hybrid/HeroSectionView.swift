import SwiftUI

struct HeroSectionView: View {
    @ObservedObject var viewModel: LyoAIViewModel
    let userName: String
    var onChatTap: () -> Void
    var onVoiceTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Centered Avatar & Greeting
            VStack(spacing: 24) {
                EnhancedAnimatedLyoAvatar(state: .idle, size: 140)
                    .shadow(color: Color("LyoAccent").opacity(0.3), radius: 20)
                
                VStack(spacing: 8) {
                    Text("Hello, \(userName).")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Ready to learn something new?")
                        .font(.system(size: 18))
                        .foregroundColor(Color("LyoTextSecondary"))
                }
            }
            .padding(.bottom, 48)
            
            // Minimalist Horizontal Rail
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Started Courses
                    ForEach(viewModel.startedCards) { card in
                        MiniCourseCard(title: card.title, subtitle: "Continue", icon: "play.circle.fill", color: Color("LyoAccent"))
                    }
                    
                    // Suggested
                    ForEach(viewModel.suggestedCards.prefix(3)) { card in
                        MiniCourseCard(title: card.title, subtitle: "Suggested", icon: "sparkles", color: Color.blue)
                    }
                    
                    // Placeholder if empty
                    if viewModel.startedCards.isEmpty && viewModel.suggestedCards.isEmpty {
                        MiniCourseCard(title: "Python Basics", subtitle: "Start Learning", icon: "play.circle.fill", color: Color("LyoAccent"))
                        MiniCourseCard(title: "Photography", subtitle: "Suggested", icon: "camera.fill", color: Color.purple)
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
            
            // Input Controls
            HStack(spacing: 40) {
                // Chat Button
                Button(action: onChatTap) {
                    Circle()
                        .fill(Color("LyoSurface"))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                }
                
                // Voice Button
                Button(action: onVoiceTap) {
                    Circle()
                        .fill(Color("LyoSurface"))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                }
            }
            .padding(.bottom, 60)
            
            // Scroll Indicator
            VStack(spacing: 8) {
                Text("Explore Feed")
                    .font(.caption)
                    .foregroundColor(Color("LyoTextSecondary").opacity(0.7))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("LyoTextSecondary").opacity(0.7))
                    .offset(y: 0) // Animation would go here
            }
            .padding(.bottom, 40)
        }
        .frame(minHeight: UIScreen.main.bounds.height)
    }
}

struct MiniCourseCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color("LyoTextSecondary"))
                    .textCase(.uppercase)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(width: 160, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("LyoSurface"))
        )
    }
}
