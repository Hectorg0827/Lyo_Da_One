import SwiftUI

/// The Voice Orb: The teacher's presence.
/// A living, audio-reactive gradient sphere built with iOS 18 MeshGradient.
public struct VoiceOrbView: View {
    // Current state (Sprint 1 only supports idle, but built to expand)
    public enum OrbState {
        case idle
        case speaking
        case thinking
        case celebrate
        case encourage
    }
    
    @State private var state: OrbState = .idle
    @State private var phase: Float = 0.0
    
    // Size defined in Master Context: approximately 90pt diameter
    public let diameter: CGFloat = 90.0
    
    // Adaptive colors from lesson palette (default to a nice warmup if none provided)
    public var accentColor: Color = .blue
    public var amplitude: Float = 0.0
    
    public init(state: OrbState = .idle, accent: Color = .blue, amplitude: Float = 0.0) {
        self.state = state
        self.accentColor = accent
        self.amplitude = amplitude
    }
    
    public var body: some View {
        ZStack {
            // Shadow / Glow behind the avatar based on accent color and amplitude
            Circle()
                .fill(accentColor.opacity(state == .speaking ? 0.6 : 0.2))
                .blur(radius: state == .speaking ? 20 + CGFloat(amplitude) * 20 : 15)
                .frame(width: diameter * 0.9, height: diameter * 0.9)
            
            // Avatar Image swapping based on state
            Group {
                if state == .speaking {
                    Image("avatar_speaking")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // Slight vertical bounce based on amplitude
                        .offset(y: -CGFloat(amplitude) * 8)
                } else {
                    Image("avatar_idle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // Subtle floating animation for idle
                        .offset(y: CGFloat(sin(phase)) * 2)
                }
            }
            .frame(width: diameter, height: diameter)
            // Prevent clipping
            .clipShape(Circle())
        }
        .frame(width: diameter, height: diameter)
        // General scale pulsing based on state/amplitude
        .scaleEffect(
            state == .speaking ? (1.0 + CGFloat(amplitude) * 0.15) :
            (state == .idle ? (1.0 + CGFloat(sin(phase)) * 0.02) : 1.0)
        )
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: amplitude)
        .animation(.easeInOut(duration: 0.2), value: state)
        .onAppear {
            startBreathing()
        }
    }
    
    private func startBreathing() {
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: true)) {
            phase = .pi
        }
    }

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VoiceOrbView(state: .idle, accent: .orange)
    }
}
