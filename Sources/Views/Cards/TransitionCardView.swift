import SwiftUI

public struct TransitionCardView: View {
    let card: TransitionCard
    let palette: LyoLessonPalette
    
    @State private var appear = false
    
    public init(card: TransitionCard, palette: LyoLessonPalette) {
        self.card = card
        self.palette = palette
    }
    
    public var body: some View {
        ZStack {
            // Full-bleed color wash transitioning between two colors
            LinearGradient(
                colors: appear ? 
                    [Color(hex: palette.color2Hex) ?? .blue, Color(hex: palette.color3Hex) ?? .indigo] :
                    [Color(hex: palette.color1Hex) ?? .indigo, Color(hex: palette.color2Hex) ?? .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: appear)
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))
            
            // Foreground Content
            VStack(spacing: 60) {
                Spacer()
                
                // Note: The actual VoiceOrb is usually rendered by the container,
                // but if we need a specific prominent placement, we might render a placeholder here 
                // or just let the container handle it. We'll leave space for the container's VoiceOrb
                // to move here if needed using matchedGeometryEffect in the container.
                Circle()
                    .fill(Color.clear)
                    .frame(width: 150, height: 150)
                
                Text(card.title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appear ? 1.0 : 0.0)
                    .offset(y: appear ? 0 : 20)
                
                Spacer()
            }
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.foregroundDepth))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                appear = true
            }
        }
    }
}
