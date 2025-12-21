import SwiftUI

// MARK: - Glassmorphic Card
// Reusable card component with frosted glass effect

struct GlassmorphicCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let borderGradient: LinearGradient?
    let shadowStyle: ShadowStyle?
    let backgroundColor: Color
    let blurIntensity: CGFloat
    
    init(
        cornerRadius: CGFloat = DesignTokens.Radius.lg,
        borderGradient: LinearGradient? = nil,
        shadowStyle: ShadowStyle? = DesignTokens.Shadow.md,
        backgroundColor: Color = DesignTokens.Colors.surface.opacity(0.7),
        blurIntensity: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.borderGradient = borderGradient
        self.shadowStyle = shadowStyle
        self.backgroundColor = backgroundColor
        self.blurIntensity = blurIntensity
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    // Blur background
                    if #available(iOS 15.0, *) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(backgroundColor)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor)
                    }
                    
                    // Border gradient overlay
                    if let gradient = borderGradient {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(gradient, lineWidth: 1)
                    }
                }
            )
            .overlay(
                // Glossy highlight
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .modifier(ConditionalShadow(shadow: shadowStyle))
    }
}

// MARK: - Conditional Shadow Modifier

struct ConditionalShadow: ViewModifier {
    let shadow: ShadowStyle?
    
    func body(content: Content) -> some View {
        if let shadow = shadow {
            content.applyShadow(shadow)
        } else {
            content
        }
    }
}

// MARK: - Glassmorphic Background Modifier

struct GlassmorphicBackground: ViewModifier {
    let cornerRadius: CGFloat
    let borderColor: Color
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if #available(iOS 15.0, *) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(DesignTokens.Colors.surface.opacity(0.8))
                    }
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(borderColor.opacity(0.3), lineWidth: 1)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            )
    }
}

extension View {
    func glassmorphic(
        cornerRadius: CGFloat = DesignTokens.Radius.lg,
        borderColor: Color = .white
    ) -> some View {
        self.modifier(GlassmorphicBackground(cornerRadius: cornerRadius, borderColor: borderColor))
    }
}
