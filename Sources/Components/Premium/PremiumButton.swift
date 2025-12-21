import SwiftUI

// MARK: - Premium Button Style
enum PremiumButtonStyle {
    case primary
    case secondary
    case gradient([Color])
    case glass
    case outline
    
    var background: AnyShapeStyle {
        switch self {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .secondary:
            return AnyShapeStyle(Color.white.opacity(0.1))
        case .gradient(let colors):
            return AnyShapeStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .glass:
            return AnyShapeStyle(Color.white.opacity(0.08))
        case .outline:
            return AnyShapeStyle(Color.clear)
        }
    }
}

// MARK: - Premium Button
struct PremiumButton: View {
    let title: String
    let icon: String?
    let style: PremiumButtonStyle
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        style: PremiumButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.body.weight(.semibold))
                    }
                    
                    Text(title)
                        .font(.body.weight(.semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                Group {
                    switch style {
                    case .outline:
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    default:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(style.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            )
            .shadow(color: shadowColor, radius: isPressed ? 5 : 15, y: isPressed ? 2 : 8)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary:
            return .purple.opacity(0.4)
        case .gradient(let colors):
            return colors.first?.opacity(0.4) ?? .clear
        default:
            return .black.opacity(0.2)
        }
    }
}

// MARK: - Icon Button
struct PremiumIconButton: View {
    let icon: String
    let size: CGFloat
    let colors: [Color]
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String,
        size: CGFloat = 50,
        colors: [Color] = [.blue, .purple],
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.colors = colors
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: isPressed ? 5 : 15)
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let colors: [Color]
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isAnimating = false
    
    init(
        icon: String = "plus",
        colors: [Color] = [.purple, .pink],
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.colors = colors
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [colors.first?.opacity(0.6) ?? .clear, .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.2 : 1)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 15, y: 5)
                
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isPressed ? 45 : 0))
            }
            .scaleEffect(isPressed ? 0.9 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.opacity(0.9).ignoresSafeArea()
        
        VStack(spacing: 20) {
            PremiumButton("Get Started", icon: "arrow.right") {
                print("Tapped")
            }
            
            PremiumButton("Secondary", style: .secondary) {
                print("Tapped")
            }
            
            PremiumButton("Custom Gradient", style: .gradient([.orange, .pink])) {
                print("Tapped")
            }
            
            PremiumButton("Outline", style: .outline) {
                print("Tapped")
            }
            
            PremiumButton("Loading...", isLoading: true) {
                print("Tapped")
            }
            
            HStack(spacing: 20) {
                PremiumIconButton(icon: "heart.fill", colors: [.pink, .red]) {}
                PremiumIconButton(icon: "star.fill", colors: [.yellow, .orange]) {}
                PremiumIconButton(icon: "bolt.fill", colors: [.blue, .cyan]) {}
            }
            
            FloatingActionButton {}
        }
        .padding()
    }
}
