import SwiftUI

/// Triggerable celebratory effects (Confetti, Sparkles)
struct MagicEffectView: View {
    let type: EffectType
    @State private var particles: [EffectParticle] = []
    
    enum EffectType {
        case confetti
        case sparkles
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                for p in particles {
                    let age = now - p.startTime
                    if age > p.life || age < 0 { continue }
                    
                    // Deterministic Physics: y = y0 + v0y*t + 0.5*g*t^2
                    let t = age
                    let currentX = p.startX + (p.vx * t * 100)
                    let currentY = p.startY + (p.vy * t * 100) + (0.5 * 10.0 * t * t * 100) // g=10 scaled
                    
                    var innerContext = context
                    let opacity = max(0, 1.0 - (age / p.life))
                    innerContext.opacity = opacity
                    
                    let rect = CGRect(x: currentX, y: currentY, width: p.size, height: p.size)
                    
                    if type == .confetti {
                        innerContext.fill(
                            Path(rect),
                            with: .color(p.color)
                        )
                    } else {
                        innerContext.addFilter(.blur(radius: 1))
                        innerContext.fill(
                            Circle().path(in: rect),
                            with: .color(p.color)
                        )
                    }
                }
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        let count = type == .confetti ? 50 : 30
        let now = Date().timeIntervalSinceReferenceDate
        
        // Use a small delay to ensure size is available if needed, 
        // but here we just use center screen as a heuristic or wait for geometry
        particles = (0..<count).map { _ in
            EffectParticle(
                startX: UIScreen.main.bounds.width / 2,
                startY: UIScreen.main.bounds.height / 2,
                vx: Double.random(in: -3...3),
                vy: Double.random(in: -6...(-2)),
                size: Double.random(in: 4...10),
                color: [.orange, .blue, .purple, .pink, .yellow, .green].randomElement() ?? .white,
                life: Double.random(in: 1.5...3.0),
                startTime: now
            )
        }
    }
}

struct EffectParticle: Identifiable {
    let id = UUID()
    let startX: Double
    let startY: Double
    let vx: Double
    let vy: Double
    let size: Double
    let color: Color
    let life: Double
    let startTime: Double
}
