import SwiftUI

// MARK: - Design System

struct DesignSystem {
    struct Colors {
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let primary = Color("Primary")
        static let secondary = Color("Secondary")
        static let accent = Color("Accent")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        
        // Fallbacks if assets aren't set up yet
        static let fallbackBackground = Color(hexString: "0F172A") // Deep Navy
        static let fallbackSurface = Color(hexString: "1E293B")    // Slate
        static let fallbackPrimary = Color(hexString: "3B82F6")    // Electric Blue
        static let fallbackSecondary = Color(hexString: "6366F1")  // Indigo
        static let fallbackAccent = Color(hexString: "F59E0B")     // Amber
        static let fallbackTextPrimary = Color.white
        static let fallbackTextSecondary = Color.gray
    }
    
    struct Typography {
        static func largeTitle(_ text: String) -> Text {
            Text(text).font(.system(size: 34, weight: .bold, design: .rounded))
        }
        
        static func title(_ text: String) -> Text {
            Text(text).font(.system(size: 28, weight: .bold, design: .rounded))
        }
        
        static func headline(_ text: String) -> Text {
            Text(text).font(.system(size: 20, weight: .semibold, design: .rounded))
        }
        
        static func body(_ text: String) -> Text {
            Text(text).font(.system(size: 17, weight: .regular, design: .default))
        }
        
        static func caption(_ text: String) -> Text {
            Text(text).font(.system(size: 13, weight: .medium, design: .default))
        }
    }
}

// MARK: - Extensions

extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct GlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [DesignSystem.Colors.fallbackPrimary, DesignSystem.Colors.fallbackSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: DesignSystem.Colors.fallbackPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassEffect() -> some View {
        modifier(GlassModifier())
    }
    
    func primaryButtonStyle() -> some View {
        modifier(PrimaryButtonModifier())
    }
}
