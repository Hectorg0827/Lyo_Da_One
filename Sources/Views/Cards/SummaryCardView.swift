import SwiftUI

public struct SummaryCardView: View {
    let card: SummaryCard
    let palette: LyoLessonPalette
    
    @State private var visiblePointCount = 0
    
    public init(card: SummaryCard, palette: LyoLessonPalette) {
        self.card = card
        self.palette = palette
    }
    
    public var body: some View {
        ZStack {
            // Background Layer
            AnimatedMeshBackground(palette: palette, phase: 0)
                .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))
            
            // Foreground Content
            VStack(alignment: .leading, spacing: 32) {
                Spacer().frame(height: 100)
                
                Text(card.title.uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: palette.color2Hex))
                    .tracking(2.0)
                
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(card.keyPoints.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: palette.color2Hex))
                                .font(.system(size: 24))
                                .padding(.top, 2)
                            
                            Text(point)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .lineSpacing(4)
                        }
                        .opacity(index < visiblePointCount ? 1.0 : 0.0)
                        .offset(x: index < visiblePointCount ? 0 : -50)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.foregroundDepth))
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        for i in 0..<card.keyPoints.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4 + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    visiblePointCount = i + 1
                }
                LyoHapticManager.shared.playCardArrival()
            }
        }
    }
}
