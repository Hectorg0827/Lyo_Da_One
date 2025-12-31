import SwiftUI

struct LyoAvatarView: View {
    var size: CGFloat = 256
    var isListening: Bool = false
    var isThinking: Bool = false
    var onTap: (() -> Void)? = nil
    
    @State private var isBreathing = false
    @State private var isSquished = false
    @State private var thinkingRotation = 0.0
    
    var body: some View {
        ZStack {
            // Radar/Ripple Effect (when listening)
            if isListening {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color(hex: "FF8C00").opacity(0.5), lineWidth: 2)
                        .scaleEffect(isBreathing ? 1.5 : 1.0)
                        .opacity(isBreathing ? 0.0 : 0.5)
                        .animation(
                            Animation.easeOut(duration: 2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.5),
                            value: isBreathing
                        )
                }
                .frame(width: size, height: size)
            }
            
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FF8C00").opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .blur(radius: 20)
            
            // Avatar
            avatarImage
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(isThinking ? 1.05 : (isSquished ? 0.9 : 1.0)) // Subtle scale for thinking
                .scaleEffect(isBreathing ? 1.05 : 1.0)
                .onTapGesture {
                    triggerSquish()
                    onTap?()
                }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onChange(of: isThinking) { _, thinking in
            if thinking {
                startReadingAnimation()
            } else {
                stopReadingAnimation()
            }
        }
    }
    
    // Reading Animation State
    @State private var readingFrame = 0
    @State private var timer: Timer?
    
    // Avatar Image Logic
    private var avatarImage: Image {
        // Fallback to static avatar until reading_0...4 assets are added
        return Image("LyoAvatar")
        /*
        if isThinking {
            return Image("reading_\(readingFrame)")
        } else {
            return Image("LyoAvatar")
        }
        */
    }
    
    private func startReadingAnimation() {
        timer?.invalidate()
        readingFrame = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            withAnimation(.linear(duration: 0.15)) {
                readingFrame = (readingFrame + 1) % 5
            }
        }
    }
    
    private func stopReadingAnimation() {
        timer?.invalidate()
        timer = nil
        readingFrame = 0
    }
    
    private func triggerSquish() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            isSquished = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isSquished = false
            }
        }
    }
}
