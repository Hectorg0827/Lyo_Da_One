import SwiftUI

struct LyoThinkingView: View {
    @State private var dotOffset1: CGFloat = 0
    @State private var dotOffset2: CGFloat = 0
    @State private var dotOffset3: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
            Image("lyo_avatar_small") // Assuming this exists based on previous codebase traces
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            HStack(spacing: 4) {
                ThinkingDot(offset: dotOffset1)
                ThinkingDot(offset: dotOffset2)
                ThinkingDot(offset: dotOffset3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        let animation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        
        withAnimation(animation) {
            dotOffset1 = -5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(animation) {
                dotOffset2 = -5
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(animation) {
                dotOffset3 = -5
            }
        }
    }
}

struct ThinkingDot: View {
    var offset: CGFloat
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.7))
            .frame(width: 6, height: 6)
            .offset(y: offset)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LyoThinkingView()
    }
}
