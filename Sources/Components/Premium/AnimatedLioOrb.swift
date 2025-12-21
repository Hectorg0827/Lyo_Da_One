import SwiftUI

// MARK: - Animated Lio Orb
struct AnimatedLioOrb: View {
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    
    let size: CGFloat
    let isSpeaking: Bool
    let primaryColor: Color
    let secondaryColor: Color
    
    init(
        size: CGFloat = 80,
        isSpeaking: Bool = false,
        primaryColor: Color = .purple,
        secondaryColor: Color = .cyan
    ) {
        self.size = size
        self.isSpeaking = isSpeaking
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }
    
    var body: some View {
        ZStack {
            // Outer glow rings
            GlowRing(ring: 0, size: size, primaryColor: primaryColor, secondaryColor: secondaryColor, isAnimating: isAnimating, glowOpacity: glowOpacity, rotationAngle: rotationAngle)
            GlowRing(ring: 1, size: size, primaryColor: primaryColor, secondaryColor: secondaryColor, isAnimating: isAnimating, glowOpacity: glowOpacity, rotationAngle: rotationAngle)
            GlowRing(ring: 2, size: size, primaryColor: primaryColor, secondaryColor: secondaryColor, isAnimating: isAnimating, glowOpacity: glowOpacity, rotationAngle: rotationAngle)
            
            // Main orb background
            mainOrb
            
            // Inner shimmer
            innerShimmer
            
            // Lio face/icon
            lioFace
        }
        .scaleEffect(pulseScale)
        .onAppear {
            startAnimations()
        }
    }
    
    private var mainOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        primaryColor.opacity(0.8),
                        secondaryColor.opacity(0.6),
                        primaryColor.opacity(0.4)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .shadow(color: primaryColor.opacity(0.5), radius: 20)
            .shadow(color: secondaryColor.opacity(0.3), radius: 30)
    }
    
    private var innerShimmer: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [
                        .white.opacity(0.4),
                        .clear,
                        .white.opacity(0.2),
                        .clear
                    ],
                    center: .center
                )
            )
            .frame(width: size * 0.9, height: size * 0.9)
            .rotationEffect(.degrees(rotationAngle))
    }
    
    private var lioFace: some View {
        ZStack {
            // Eyes
            HStack(spacing: size * 0.15) {
                OrbEye(size: size * 0.12, isAnimating: isAnimating)
                OrbEye(size: size * 0.12, isAnimating: isAnimating)
            }
            .offset(y: -size * 0.05)
            
            // Mouth (when speaking)
            if isSpeaking {
                RoundedRectangle(cornerRadius: size * 0.05)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: size * 0.2, height: size * 0.08)
                    .offset(y: size * 0.12)
                    .scaleEffect(y: isAnimating ? 1.5 : 0.5)
            } else {
                // Smile
                Arc()
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .frame(width: size * 0.2, height: size * 0.1)
                    .offset(y: size * 0.12)
            }
        }
    }
    
    private func startAnimations() {
        // Rotation animation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = isSpeaking ? 1.08 : 1.02
            isAnimating = true
        }
        
        // Glow animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowOpacity = 0.8
        }
    }
}

// MARK: - Glow Ring Component
struct GlowRing: View {
    let ring: Int
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    let isAnimating: Bool
    let glowOpacity: Double
    let rotationAngle: Double
    
    var body: some View {
        let ringSize = size + CGFloat(ring * 25)
        let primaryOpacity = max(0, 0.3 - Double(ring) * 0.1)
        let secondaryOpacity = max(0, 0.2 - Double(ring) * 0.05)
        let finalOpacity = max(0, glowOpacity - Double(ring) * 0.15)
        let rotation = rotationAngle * (ring % 2 == 0 ? 1 : -1)
        
        return Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        primaryColor.opacity(primaryOpacity),
                        secondaryColor.opacity(secondaryOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: ringSize, height: ringSize)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .opacity(finalOpacity)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Orb Eye Component
struct OrbEye: View {
    let size: CGFloat
    let isAnimating: Bool
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .scaleEffect(y: isAnimating ? 0.3 : 1.0)
    }
}

// MARK: - Arc Shape
struct Arc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        return path
    }
}

// MARK: - Mini Lio Orb (Simplified version)
struct MiniLioOrb: View {
    let size: CGFloat
    @State private var isGlowing = false
    
    init(size: CGFloat = 40) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.purple.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(isGlowing ? 1.2 : 1.0)
            
            // Orb
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .cyan, .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .purple.opacity(0.5), radius: 10)
            
            // Eyes
            HStack(spacing: size * 0.15) {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.12, height: size * 0.12)
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.12, height: size * 0.12)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

// MARK: - Preview
#Preview("Animated Lio Orb") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 40) {
            AnimatedLioOrb(size: 100, isSpeaking: false)
            AnimatedLioOrb(size: 60, isSpeaking: true)
            MiniLioOrb(size: 40)
        }
    }
}
