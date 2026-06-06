import SwiftUI

// MARK: - Mascot Particles
/// A shared particle effect used for Lyo interactions, supporting accessibility settings.
struct MascotParticles: View {
    let color: Color
    var reduced: Bool = false
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var speed: CGFloat
    }

    private var timerInterval: TimeInterval {
        reduced ? 0.5 : 0.1
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x * size.width,
                        y: particle.y * size.height,
                        width: 4 * particle.scale,
                        height: 4 * particle.scale
                    )
                    context.opacity = particle.opacity
                    context.fill(Circle().path(in: rect), with: .color(color))
                }
            }
        }
        .onReceive(Timer.publish(every: timerInterval, on: .main, in: .common).autoconnect()) { _ in
            updateParticles()
        }
    }

    private func updateParticles() {
        // Reduce particle generation for accessibility
        let generationThreshold = reduced ? 0.9 : 0.7

        // Add new particle
        if Double.random(in: 0...1) > generationThreshold {
            particles.append(Particle(
                x: CGFloat.random(in: 0.2...0.8),
                y: 0.8,
                scale: CGFloat.random(in: reduced ? 1.0...1.2 : 0.5...1.5),
                opacity: 1.0,
                speed: CGFloat.random(in: reduced ? 0.02...0.03 : 0.01...0.03)
            ))
        }

        // Update existing
        for i in particles.indices {
            particles[i].y -= particles[i].speed
            particles[i].opacity -= reduced ? 0.04 : 0.02
        }

        // Remove dead particles
        particles.removeAll { $0.opacity <= 0 }
    }
}
