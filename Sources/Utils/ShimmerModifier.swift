import SwiftUI

// MARK: - Shimmer Effect
// Adds animated shimmer effect for loading states and subtle accents

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let opacity: Double
    
    init(duration: Double = 2.0, opacity: Double = 0.3) {
        self.duration = duration
        self.opacity = opacity
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(opacity),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: phase * geometry.size.width - geometry.size.width * 0.3)
                        .animation(
                            Animation.linear(duration: duration)
                                .repeatForever(autoreverses: false),
                            value: phase
                        )
                }
            )
            .onAppear {
                phase = 1.0
            }
    }
}

extension View {
    func shimmer(duration: Double = 2.0, opacity: Double = 0.3) -> some View {
        self.modifier(ShimmerModifier(duration: duration, opacity: opacity))
    }
}

// MARK: - Skeleton Loading View
// Reusable skeleton loading component

struct SkeletonLoadingView: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat = 100, height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignTokens.Colors.surfaceElevated)
            .frame(width: width, height: height)
            .shimmer(duration: 1.5, opacity: 0.2)
    }
}
