import SwiftUI

// Type alias for backward compatibility
typealias AnimatedGradient = AnimatedGradientBackground

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    let colors: [Color]
    let speed: Double
    
    init(
        colors: [Color] = [.purple, .blue, .cyan, .purple],
        speed: Double = 5.0
    ) {
        self.colors = colors
        self.speed = speed
    }
    
    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Mesh Gradient Background (iOS 18+)
struct MeshGradientBackground: View {
    @State private var t: Float = 0.0
    @State private var timer: Timer?
    
    let colors: [Color]
    
    init(colors: [Color] = [.purple, .blue, .pink, .cyan, .indigo, .mint]) {
        self.colors = colors
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fallback for older iOS
                meshGradientView
            }
        }
        .ignoresSafeArea()
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                t += 0.01
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    @ViewBuilder
    private var meshGradientView: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [sinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), sinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                    [sinInRange(0.1...0.9, offset: 0.239, timeScale: 0.084, t: t), sinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                    [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), sinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: colors
            )
        } else {
            // Fallback for iOS 17
            AnimatedGradientBackground(colors: colors)
        }
    }
    
    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}

// MARK: - Premium Background
struct PremiumBackground: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated orbs
            GeometryReader { geometry in
                ZStack {
                    // Purple orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(
                            x: geometry.size.width * 0.3 + sin(phase) * 30,
                            y: geometry.size.height * 0.2 + cos(phase * 0.7) * 20
                        )
                    
                    // Blue orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.blue.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                        .frame(width: 500, height: 500)
                        .offset(
                            x: -geometry.size.width * 0.2 + cos(phase * 0.8) * 25,
                            y: geometry.size.height * 0.5 + sin(phase * 0.6) * 35
                        )
                    
                    // Cyan orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cyan.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 350, height: 350)
                        .offset(
                            x: geometry.size.width * 0.4 + sin(phase * 1.2) * 20,
                            y: geometry.size.height * 0.7 + cos(phase * 0.9) * 25
                        )
                }
            }
            
            // Noise texture overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.03)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Aurora Background
struct AuroraBackground: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark base
                Color(red: 0.02, green: 0.02, blue: 0.08)
                
                // Aurora waves
                ForEach(0..<3) { i in
                    AuroraWave(
                        phase: phase + CGFloat(i) * .pi / 3,
                        color: auroraColor(for: i),
                        amplitude: CGFloat(50 + i * 20),
                        frequency: CGFloat(1 + Double(i) * 0.3)
                    )
                    .opacity(0.6 - Double(i) * 0.15)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
    
    private func auroraColor(for index: Int) -> LinearGradient {
        let colorSets: [[Color]] = [
            [.green.opacity(0.8), .cyan.opacity(0.6), .blue.opacity(0.4)],
            [.purple.opacity(0.6), .pink.opacity(0.5), .blue.opacity(0.4)],
            [.cyan.opacity(0.5), .blue.opacity(0.4), .purple.opacity(0.3)]
        ]
        
        return LinearGradient(
            colors: colorSets[index % colorSets.count],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Aurora Wave
struct AuroraWave: View {
    let phase: CGFloat
    let color: LinearGradient
    let amplitude: CGFloat
    let frequency: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height * 0.4
                
                path.move(to: CGPoint(x: 0, y: height))
                
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin(relativeX * .pi * frequency * 2 + phase)
                    let y = midHeight + sine * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(color)
            .blur(radius: 30)
        }
    }
}

// MARK: - Particle Background
struct ParticleBackground: View {
    let particleCount: Int
    
    init(particleCount: Int = 50) {
        self.particleCount = particleCount
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.95)
                
                ForEach(0..<particleCount, id: \.self) { index in
                    ParticleView(
                        size: geometry.size,
                        index: index
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Particle View
struct ParticleView: View {
    let size: CGSize
    let index: Int
    
    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 1
    
    private var particleSize: CGFloat {
        CGFloat.random(in: 2...6)
    }
    
    private var particleColor: Color {
        let colors: [Color] = [.white, .cyan, .purple, .blue]
        return colors[index % colors.count]
    }
    
    var body: some View {
        Circle()
            .fill(particleColor)
            .frame(width: particleSize, height: particleSize)
            .position(position)
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: particleSize > 4 ? 1 : 0)
            .onAppear {
                position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
                
                let duration = Double.random(in: 3...8)
                
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    position = CGPoint(
                        x: CGFloat.random(in: 0...size.width),
                        y: CGFloat.random(in: 0...size.height)
                    )
                    opacity = Double.random(in: 0.3...0.8)
                    scale = CGFloat.random(in: 0.5...1.5)
                }
            }
    }
}

// MARK: - Preview
#Preview("Premium Background") {
    PremiumBackground()
}

#Preview("Aurora Background") {
    AuroraBackground()
}

#Preview("Particle Background") {
    ParticleBackground()
}
