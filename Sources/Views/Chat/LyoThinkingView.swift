import SwiftUI

struct LyoThinkingView: View {
    @State private var currentFrame: Int = 1
    @State private var dotOffset1: CGFloat = 0
    @State private var dotOffset2: CGFloat = 0
    @State private var dotOffset3: CGFloat = 0
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            Image("lyo_thinking_\(currentFrame)")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .animation(nil, value: currentFrame) // Don't crossfade the frames to keep it snappy
            
            HStack(spacing: 4) {
                ThinkingDot(offset: dotOffset1)
                ThinkingDot(offset: dotOffset2)
                ThinkingDot(offset: dotOffset3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
        .onAppear {
            animateDots()
        }
        .onReceive(timer) { _ in
            currentFrame = (currentFrame % 4) + 1
        }
    }
    
    private func animateDots() {
        let animation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        
        withAnimation(animation) {
            dotOffset1 = -4
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(animation) {
                dotOffset2 = -4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(animation) {
                dotOffset3 = -4
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
