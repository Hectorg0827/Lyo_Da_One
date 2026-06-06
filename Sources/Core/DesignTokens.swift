import SwiftUI
import Foundation
import Combine

// MARK: - Color Extension
// Must be at the top to ensure availability during static property initialization
extension Color {
    public init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        let scanner = Scanner(string: hexString)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Design Tokens
// Centralized design system for consistent, premium UI

public struct DesignTokens {
    
    // MARK: - Typography
    
    public struct Typography {
        // Display - For large headlines
        public static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        public static let displayMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
        public static let displaySmall = Font.system(size: 24, weight: .semibold, design: .rounded)
        
        // Title - For section headers
        public static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
        public static let titleMedium = Font.system(size: 20, weight: .semibold, design: .default)
        public static let titleSmall = Font.system(size: 18, weight: .semibold, design: .default)
        
        // Body - For main content
        public static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
        public static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
        public static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
        
        // Label - For UI elements
        public static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
        public static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
        public static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
        
        // Caption - For metadata
        public static let caption = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    // MARK: - Colors
    
    public struct Colors {
        // Brand Colors
        public static let accent = Color("LyoAccent")
        public static let accentSecondary = Color(hex: "A78BFA")
        
        // Semantic Colors
        public static let success = Color(hex: "10B981")
        public static let warning = Color(hex: "F59E0B")
        public static let danger = Color(hex: "EF4444")
        public static let info = Color(hex: "3B82F6")
        
        // Surface Colors
        public static let background = Color("LyoBackground")
        public static let surface = Color("LyoSurface")
        public static let surfaceElevated = Color(hex: "2A2D3A")
        public static let surfaceHighlight = Color(hex: "343847")
        
        // Text Colors
        public static let textPrimary = Color.white
        public static let textSecondary = Color("LyoTextSecondary")
        public static let textTertiary = Color.white.opacity(0.5)
        
        // Overlay Colors
        public static let overlay = Color.black.opacity(0.5)
        public static let overlayLight = Color.black.opacity(0.3)
        
        // Gradients
        public static let accentGradient = LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "D946EF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let cardGradient = LinearGradient(
            colors: [Color(hex: "4A59A4"), Color(hex: "632E53")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let userMessageGradient = LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        public static let meshGradient = LinearGradient(
            colors: [
                Color(hex: "1A1D2E").opacity(0.95),
                Color(hex: "16213E").opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let shimmerGradient = LinearGradient(
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
    
    public struct Spacing {
        public static let xxxs: CGFloat = 2
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
        public static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    public struct Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let full: CGFloat = 9999
    }
    
    // MARK: - Shadows
    
    public struct Shadow {
        public static let sm = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        
        public static let md = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 4,
            x: 0,
            y: 2
        )
        
        public static let lg = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
        
        public static let xl = ShadowStyle(
            color: Color.black.opacity(0.25),
            radius: 16,
            x: 0,
            y: 8
        )
        
        public static let glow = ShadowStyle(
            color: Color("LyoAccent").opacity(0.4),
            radius: 12,
            x: 0,
            y: 0
        )
        
        public static let accentGlow = ShadowStyle(
            color: Color(hex: "8B5CF6").opacity(0.5),
            radius: 20,
            x: 0,
            y: 0
        )
    }
    
    // MARK: - Animation
    
    public struct Animation {
        public static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        public static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        public static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: - Shadow Style

public struct ShadowStyle {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
}

// MARK: - View Extensions

extension View {
    public func applyShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
    
    public func applyMultiLayerShadow() -> some View {
        self
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Shared AI Chat Components

/// A modifier that adds a pulsing animation to a view, commonly used for thinking/loading dots.
public struct ThinkingDotAnimation: ViewModifier {
    public let index: Int
    @State private var isAnimating = false
    
    public init(index: Int) {
        self.index = index
    }
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.5 : 0.8)
            .opacity(isAnimating ? 1 : 0.4)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15)
                ) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    public func thinkingDotAnimation(index: Int) -> some View {
        self.modifier(ThinkingDotAnimation(index: index))
    }
}

/// A unified thinking indicator used across all AI chat interfaces.
public struct LyoUnifiedThinkingIndicator: View {
    @State private var frameIndex = 0
    @State private var textIndex = 0
    private let frames = ["Mascot_Reading_1", "Mascot_Reading_2", "Mascot_Reading_3", "Mascot_Reading_4"]
    private let thinkingTexts = [
        ("Thinking...", Color(hex: "6366F1")),   // Indigo
        ("Analyzing...", Color(hex: "8B5CF6")),  // Purple
        ("Processing...", Color(hex: "EC4899"))  // Pink
    ]
    
    private let mascotTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    private let textTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 12) {
            // Mascot Animation
            Image(frames[frameIndex])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onReceive(mascotTimer) { _ in
                    frameIndex = (frameIndex + 1) % frames.count
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(thinkingTexts[textIndex].0)
                    .font(.caption.bold())
                    .foregroundColor(thinkingTexts[textIndex].1)
                    .animation(.easeInOut, value: textIndex)
                
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(thinkingTexts[textIndex].1.opacity(0.4))
                            .frame(width: 4, height: 4)
                            .modifier(ThinkingDotAnimation(index: index))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Color.black.opacity(0.4)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        thinkingTexts[textIndex].1.opacity(0.3),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onReceive(textTimer) { _ in
            withAnimation {
                textIndex = (textIndex + 1) % thinkingTexts.count
            }
        }
    }
}

/// A shared pulsing trim component for consistent "alive" feel in AI message bubbles.
public struct PulsingTrimOverlay: View {
    public var cornerRadius: CGFloat
    @State private var pulse = 0.0
    
    public init(cornerRadius: CGFloat = 20) {
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        Color(hex: "6366F1").opacity(0.4 + (pulse * 0.3)), // Indigo
                        Color(hex: "8B5CF6").opacity(0.2 + (pulse * 0.2)), // Purple
                        Color(hex: "EC4899").opacity(0.1 + (pulse * 0.2))  // Pink
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1 + (pulse * 0.5)
            )
            .shadow(
                color: Color(hex: "8B5CF6").opacity(0.2 + (pulse * 0.3)),
                radius: 4 + (pulse * 6)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    pulse = 1.0
                }
            }
    }
}
