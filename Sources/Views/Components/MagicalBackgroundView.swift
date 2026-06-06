import SwiftUI

/// A magical, performant background for the AI Classroom
/// Features a celestial starfield/particle system that reacts to the learning experience
struct MagicalBackgroundView: View {
    @State private var particles: [Particle] = []
    let baseColor: Color
    
    init(baseColor: Color = DesignSystem.Colors.fallbackBackground) {
        self.baseColor = baseColor
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                // Draw gradient background using linearGradient
                let gradient = Gradient(colors: [baseColor, baseColor.opacity(0.8), baseColor.opacity(0.5)])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    )
                )
                
                // Draw particles based on current time
                for p in particles {
                    // Calculate deterministic position
                    let timeOffset = now - p.startTime
                    var currentY = p.startY - (p.speed * timeOffset * 50)
                    let currentX = p.startX + sin(now * p.speed) * 10
                    
                    // Wrap around logic (simulated by modulo)
                    let totalHeight = size.height + 40
                    currentY = ((currentY + 20).truncatingRemainder(dividingBy: totalHeight))
                    if currentY < -20 { currentY += totalHeight }
                    
                    let rect = CGRect(
                        x: currentX.truncatingRemainder(dividingBy: size.width),
                        y: currentY,
                        width: p.size,
                        height: p.size
                    )
                    
                    var innerContext = context
                    innerContext.opacity = p.opacity
                    
                    innerContext.fill(
                        Circle().path(in: rect),
                        with: .color(p.color.opacity(p.opacity))
                    )
                    
                    // Add subtle glow to larger particles
                    if p.size > 2 {
                        innerContext.addFilter(.blur(radius: 2))
                        innerContext.fill(
                            Circle().path(in: rect.insetBy(dx: -2, dy: -2)),
                            with: .color(p.color.opacity(p.opacity * 0.5))
                        )
                    }
                }
            }
        }
        .onAppear {
            setupParticles()
        }
        .ignoresSafeArea()
    }
    
    private func setupParticles() {
        let now = Date().timeIntervalSinceReferenceDate
        particles = (0..<60).map { _ in
            Particle(
                startX: Double.random(in: 0...2000), // Large range for horizontal variety
                startY: Double.random(in: 0...2000),
                size: Double.random(in: 1...4),
                speed: Double.random(in: 0.1...0.5),
                opacity: Double.random(in: 0.2...0.8),
                color: [Color.white, Color.blue, Color.purple, Color.orange].randomElement() ?? .white,
                startTime: now
            )
        }
    }
}

// MARK: - Particle Logic

struct Particle: Identifiable {
    let id = UUID()
    let startX: Double
    let startY: Double
    let size: Double
    let speed: Double
    let opacity: Double
    let color: Color
    let startTime: Double
}

// MARK: - Helper Extensions

extension Color {
    var shadowColor: Color {
        // Return a darker version for the gradient bottom
        return self.opacity(0.5)
    }
}

#Preview {
    MagicalBackgroundView()
}
