import SwiftUI

// MARK: - Lio Orb View
/// A floating orb button that represents Lio AI assistant
/// Changes appearance based on current app state (tab, tutor mode, etc.)
struct LioOrbView: View {
    @EnvironmentObject var uiState: AppUIState
    let onTap: () -> Void
    
    // Animation state
    @State private var breathingScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.4
    @State private var isPressed: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            onTap()
        }) {
            ZStack {
                // Outer glow ring (animated)
                Circle()
                    .fill(glowGradient)
                    .frame(width: 72, height: 72)
                    .blur(radius: 8)
                    .opacity(glowOpacity)
                    .scaleEffect(breathingScale * 1.1)
                
                // Main orb
                Circle()
                    .fill(orbGradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: orbShadowColor, radius: 12, x: 0, y: 6)
                    .scaleEffect(breathingScale)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                
                // Icon/Label
                VStack(spacing: 2) {
                    Image(systemName: orbIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if uiState.isTutorActive {
                        Text("Tutor")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .buttonStyle(.plain)
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
        .onAppear {
            startBreathingAnimation()
        }
    }
    
    // MARK: - Animations
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            breathingScale = 1.06
        }
        
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 0.6
        }
    }
    
    // MARK: - Appearance
    
    private var orbGradient: LinearGradient {
        let colors: [Color]
        
        // Special state for Tutor Mode
        if uiState.isTutorActive {
            colors = [Color.purple, Color.indigo]
        } else {
            switch uiState.currentTab {
            case .focus:
                colors = [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary]
            case .discover:
                colors = [Color(hex: "F472B6"), Color(hex: "FB923C")] // Pink to Orange
            case .campus:
                colors = [Color(hex: "34D399"), Color(hex: "14B8A6")] // Green to Teal
            case .collab, .profile:
                colors = [Color(hex: "818CF8"), Color(hex: "22D3EE")] // Indigo to Cyan
            }
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var glowGradient: RadialGradient {
        let color: Color
        
        if uiState.isTutorActive {
            color = .purple
        } else {
            switch uiState.currentTab {
            case .focus:
                color = DesignSystem.Colors.fallbackPrimary
            case .discover:
                color = Color(hex: "F472B6")
            case .campus:
                color = Color(hex: "34D399")
            case .collab, .profile:
                color = Color(hex: "818CF8")
            }
        }
        
        return RadialGradient(
            colors: [color.opacity(0.6), color.opacity(0)],
            center: .center,
            startRadius: 20,
            endRadius: 50
        )
    }
    
    private var orbShadowColor: Color {
        if uiState.isTutorActive {
            return .purple.opacity(0.5)
        }
        
        switch uiState.currentTab {
        case .focus:
            return DesignSystem.Colors.fallbackPrimary.opacity(0.4)
        case .discover:
            return Color(hex: "F472B6").opacity(0.4)
        case .campus:
            return Color(hex: "34D399").opacity(0.4)
        case .collab, .profile:
            return Color(hex: "818CF8").opacity(0.4)
        }
    }
    
    private var orbIcon: String {
        if uiState.isTutorActive {
            return "book.fill"
        }
        
        switch uiState.currentTab {
        case .focus:
            return "sparkles"
        case .discover:
            return "magnifyingglass"
        case .campus:
            return "mappin.and.ellipse"
        case .collab, .profile:
            return "person.2.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        LioOrbView(onTap: {})
            .environmentObject(AppUIState())
    }
}
