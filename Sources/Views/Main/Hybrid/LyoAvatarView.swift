import SwiftUI

struct LyoAvatarView: View {
    var size: CGFloat = 256
    var isListening: Bool = false
    var isThinking: Bool = false
    var isLiveMode: Bool = false
    var isSpeaking: Bool = false
    var userLevel: Float = 0
    var aiLevel: Float = 0
    var onTap: (() -> Void)? = nil
    
    @State private var isBreathing = false
    @State private var isSquished = false
    @State private var thinkingRotation = 0.0
    
    var body: some View {
        ZStack {
            // Radar/Ripple Effect (when listening or live)
            if isListening || isLiveMode {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color(hex: "FF8C00").opacity(0.5), lineWidth: 2)
                        .scaleEffect(isLiveMode ? (1.0 + CGFloat(userLevel) * 0.5) : (isBreathing ? 1.5 : 1.0))
                        .opacity(isLiveMode ? 0.8 : (isBreathing ? 0.0 : 0.5))
                        .animation(
                            isLiveMode ? .interactiveSpring() :
                            Animation.easeOut(duration: 2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.5),
                            value: isLiveMode ? userLevel : Float(isBreathing ? 1 : 0)
                        )
                }
                .frame(width: size, height: size)
            }
            
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            isSpeaking ? Color(hex: "10B981").opacity(0.6) : Color(hex: "FF8C00").opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: isSpeaking ? 30 : 20)
                .scaleEffect(isSpeaking ? (1.0 + CGFloat(aiLevel) * 0.5) : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSpeaking)
            
            // Avatar
            avatarImage
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(isLiveMode ? (1.0 + CGFloat(aiLevel) * 0.25) : (isThinking ? 1.05 : (isSquished ? 0.9 : 1.0)))
                .scaleEffect(isBreathing ? 1.03 : 1.0)
                .shadow(color: isSpeaking ? Color(hex: "10B981").opacity(0.5) : .clear, radius: 10)
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
        if isThinking {
            // Using reading_0 as the thinking/reading state asset
            // Note: If more frames (reading_1, etc.) are added, the startReadingAnimation
            // will cycle through them automatically.
            return Image("reading_0")
        } else {
            return Image("LyoAvatar")
        }
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
