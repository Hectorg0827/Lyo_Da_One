import SwiftUI

// MARK: - Glass Card Intensity
enum GlassIntensity {
    case ultraLight
    case light
    case medium
    case heavy
    
    var blur: CGFloat {
        switch self {
        case .ultraLight: return 10
        case .light: return 20
        case .medium: return 30
        case .heavy: return 40
        }
    }
    
    var opacity: CGFloat {
        switch self {
        case .ultraLight: return 0.05
        case .light: return 0.08
        case .medium: return 0.12
        case .heavy: return 0.18
        }
    }
    
    var borderOpacity: CGFloat {
        switch self {
        case .ultraLight: return 0.1
        case .light: return 0.15
        case .medium: return 0.2
        case .heavy: return 0.25
        }
    }
}

// MARK: - Glass Card
struct GlassCard<Content: View>: View {
    let intensity: GlassIntensity
    let cornerRadius: CGFloat
    let content: () -> Content
    
    init(
        intensity: GlassIntensity = .medium,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.intensity = intensity
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(16)
            .background(
                ZStack {
                    // Frosted glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                    
                    // Color overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(intensity.opacity))
                    
                    // Border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(intensity.borderOpacity),
                                    Color.white.opacity(intensity.borderOpacity * 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Glass Card Modifier
struct GlassCardModifier: ViewModifier {
    let intensity: GlassIntensity
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(intensity.opacity))
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(intensity.borderOpacity),
                                    Color.white.opacity(intensity.borderOpacity * 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func glassCard(intensity: GlassIntensity = .medium, cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(intensity: intensity, cornerRadius: cornerRadius))
    }
}

// MARK: - Gradient Glass Card
struct GradientGlassCard<Content: View>: View {
    let colors: [Color]
    let cornerRadius: CGFloat
    let content: () -> Content
    
    init(
        colors: [Color] = [.purple.opacity(0.3), .blue.opacity(0.3)],
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: colors.first?.opacity(0.3) ?? .clear, radius: 20, x: 0, y: 10)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassCard(intensity: .light) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Light Glass Card")
                        .foregroundColor(.white)
                }
            }
            
            GlassCard(intensity: .medium) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Medium Glass Card")
                        .foregroundColor(.white)
                }
            }
            
            GradientGlassCard(colors: [.orange.opacity(0.4), .pink.opacity(0.4)]) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Gradient Glass Card")
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
    }
}
