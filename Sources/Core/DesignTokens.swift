import SwiftUI

// MARK: - Design Tokens
// Centralized design system for consistent, premium UI

struct DesignTokens {
    
    // MARK: - Typography
    
    struct Typography {
        // Display - For large headlines
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let displaySmall = Font.system(size: 24, weight: .semibold, design: .rounded)
        
        // Title - For section headers
        static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 20, weight: .semibold, design: .default)
        static let titleSmall = Font.system(size: 18, weight: .semibold, design: .default)
        
        // Body - For main content
        static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
        
        // Label - For UI elements
        static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
        
        // Caption - For metadata
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    // MARK: - Colors
    
    struct Colors {
        // Brand Colors
        static let accent = Color("LyoAccent")
        static let accentSecondary = Color(hex: "A78BFA")
        
        // Semantic Colors
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let danger = Color(hex: "EF4444")
        static let info = Color(hex: "3B82F6")
        
        // Surface Colors
        static let background = Color("LyoBackground")
        static let surface = Color("LyoSurface")
        static let surfaceElevated = Color(hex: "2A2D3A")
        static let surfaceHighlight = Color(hex: "343847")
        
        // Text Colors
        static let textPrimary = Color.white
        static let textSecondary = Color("LyoTextSecondary")
        static let textTertiary = Color.white.opacity(0.5)
        
        // Overlay Colors
        static let overlay = Color.black.opacity(0.5)
        static let overlayLight = Color.black.opacity(0.3)
        
        // Gradients
        static let accentGradient = LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "D946EF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let cardGradient = LinearGradient(
            colors: [Color(hex: "4A59A4"), Color(hex: "632E53")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let userMessageGradient = LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let meshGradient = LinearGradient(
            colors: [
                Color(hex: "1A1D2E").opacity(0.95),
                Color(hex: "16213E").opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let shimmerGradient = LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.3),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    struct Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9999
    }
    
    // MARK: - Shadows
    
    struct Shadow {
        static let sm = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let md = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let lg = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let xl = ShadowStyle(
            color: Color.black.opacity(0.25),
            radius: 16,
            x: 0,
            y: 8
        )
        
        static let glow = ShadowStyle(
            color: Color("LyoAccent").opacity(0.4),
            radius: 12,
            x: 0,
            y: 0
        )
        
        static let accentGlow = ShadowStyle(
            color: Color(hex: "8B5CF6").opacity(0.5),
            radius: 20,
            x: 0,
            y: 0
        )
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    func applyShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
    
    func applyMultiLayerShadow() -> some View {
        self
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
