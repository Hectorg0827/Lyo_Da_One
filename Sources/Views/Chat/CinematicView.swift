
import SwiftUI
import AVKit

struct CinematicView: View {
    let data: A2UICinematic
    let onPlay: () -> Void
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            // Background Layer (Simulation of video thumbnail or ambient mood)
            Color.black.ignoresSafeArea()
            
            // Dynamic Gradient Background based on Mood
            LinearGradient(
                colors: getMoodColors(data.mood),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.4)
            .ignoresSafeArea()
            
            // Ambient Overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Title Section
                VStack(spacing: 12) {
                    Text(data.title.uppercased())
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .kerning(1.2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 20)
                    
                    if let subtitle = data.subtitle {
                        Text(subtitle)
                            .font(.system(size: 18, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(isAnimating ? 1 : 0)
                            .offset(y: isAnimating ? 0 : 20)
                    }
                }
                .padding(.horizontal)
                
                // Play Button
                Button(action: {
                    HapticManager.shared.playSuccess()
                    onPlay()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .scaleEffect(pulse ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 80, height: 80)
                            .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 0)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.black)
                            .offset(x: 3)
                    }
                }
                .padding(.top, 20)
                .opacity(isAnimating ? 1 : 0)
                .scaleEffect(isAnimating ? 1 : 0.8)
                
                Spacer()
                
                // Footer
                Text("Tap to begin immersion")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 40)
                    .opacity(isAnimating ? 1 : 0)
            }
            
            // Close Button
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                isAnimating = true
            }
            pulse = true
        }
    }
    
    private func getMoodColors(_ mood: String) -> [Color] {
        switch mood.lowercased() {
        case "mysterious":
            return [Color(hex: "434343"), Color(hex: "000000")]
        case "playful":
            return [Color(hex: "FF9966"), Color(hex: "FF5E62")]
        case "dramatic":
            return [Color(hex: "8E2DE2"), Color(hex: "4A00E0")]
        default:
            // "Normal" or generic
            return [Color(hex: "1F1C2C"), Color(hex: "928DAB")]
        }
    }
}

// Helper extension removed as it exists in project

