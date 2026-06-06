import SwiftUI

public struct AnalogyCardView: View {
    let card: AnalogyCard
    let palette: LyoLessonPalette
    
    @State private var appearTop = false
    @State private var appearBottom = false
    
    public init(card: AnalogyCard, palette: LyoLessonPalette) {
        self.card = card
        self.palette = palette
    }
    
    public var body: some View {
        ZStack {
            // Background Layer
            AnimatedMeshBackground(palette: palette, phase: 0)
                .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))
            
            // Split Content
            VStack(spacing: 0) {
                // Top Half: Abstract Concept
                VStack(alignment: .leading, spacing: 16) {
                    Text("THE CONCEPT")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                        .tracking(2.0)
                    
                    Text(card.conceptSide)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                    
                    Spacer()
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    LinearGradient(
                        colors: [Color(hex: palette.color1Hex), Color(hex: palette.color1Hex).opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .opacity(appearTop ? 1.0 : 0.0)
                .offset(y: appearTop ? 0 : -50)
                
                // Bottom Half: Concrete Analogy
                VStack(alignment: .leading, spacing: 16) {
                    Text("IS LIKE")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.8))
                        .tracking(2.0)
                    
                    Text(card.analogySide)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                    
                    Spacer()
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    LinearGradient(
                        colors: [Color(hex: palette.color2Hex), Color(hex: palette.color3Hex)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .opacity(appearBottom ? 1.0 : 0.0)
                .offset(y: appearBottom ? 0 : 50)
            }
            .cornerRadius(32)
            .padding(.horizontal, 16)
            .padding(.vertical, 80)
            // Mid-level depth for the whole card frame to contrast with the mesh behind it
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.midLayerDepth))
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appearTop = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    appearBottom = true
                }
            }
        }
    }
}
