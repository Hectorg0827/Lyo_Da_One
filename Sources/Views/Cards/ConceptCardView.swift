import SwiftUI

public struct ConceptCardView: View {
    let card: ConceptCard
    let palette: LyoLessonPalette
    
    @State private var revealedCharacterCount = 0
    @State private var showBodyText = false
    @State private var phase: Float = 0.0
    
    public init(card: ConceptCard, palette: LyoLessonPalette) {
        self.card = card
        self.palette = palette
    }
    
    public var body: some View {
        ZStack {
            // Background Layer (Deepest parallax)
            AnimatedMeshBackground(palette: palette, phase: phase)
                .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))
            
            // Kinetic Typography (Foreground parallax)
            VStack(alignment: .leading, spacing: 24) {
                // The Voice Orb goes at the top, but the LessonContainerView usually handles it.
                // However, we position content assuming VoiceOrb is at top.
                Spacer().frame(height: 120)
                
                // Key Term with Kinetic Reveal
                KineticText(
                    text: card.keyTerm,
                    revealedCount: revealedCharacterCount,
                    font: .system(size: 60, weight: .bold, design: .rounded)
                )
                
                // Body text fading in after key term
                if showBodyText {
                    Text(card.bodyText)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        // Subtle mesh animation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: true)) {
            phase = .pi * 2
        }
        
        // Character by character reveal with haptics
        let totalChars = card.keyTerm.count
        for i in 1...totalChars {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    revealedCharacterCount = i
                }
                LyoHapticManager.shared.playTypingCharacter()
                
                // When done, show body text
                if i == totalChars {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeIn(duration: 0.8)) {
                            showBodyText = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AnimatedMeshBackground: View {
    let palette: LyoLessonPalette
    let phase: Float
    
    var color1: Color { Color(hex: palette.color1Hex) ?? .indigo }
    var color2: Color { Color(hex: palette.color2Hex) ?? .blue }
    var color3: Color { Color(hex: palette.color3Hex) ?? .black }
    
    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5 + Float(sin(phase)) * 0.1, 0.5 + Float(cos(phase)) * 0.1], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    color1, color2, color3,
                    color2, color1, color2,
                    color3, color2, color1
                ]
            )
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [color1, color2, color3],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct KineticText: View {
    let text: String
    let revealedCount: Int
    let font: Font
    
    private var characters: [String] {
        text.map { String($0) }
    }
    
    var body: some View {
        // Flow layout for characters (basic H/V stack combo or custom layout)
        // For simplicity in Sprint 1, we use an HStack if short, or wrap using a custom Layout.
        // Assuming SwiftUI wrapping component here.
        FlowLayout(alignment: .leading, spacing: 2) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, char in
                Text(char)
                    .font(font)
                    .foregroundColor(.white)
                    .opacity(index < revealedCount ? 1.0 : 0.0)
                    .blur(radius: index < revealedCount ? 0 : 8)
                    .offset(y: index < revealedCount ? 0 : 20)
                    .scaleEffect(index < revealedCount ? 1.0 : 0.5)
            }
        }
    }
}

/// Simple flow layout to wrap text
struct FlowLayout: Layout {
    var alignment: Alignment = .leading
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var points: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Layout.Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var rowStartIdx = 0
            
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && index > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                    rowStartIdx = index
                }
                
                points.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// Helper Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
