import SwiftUI

// MARK: - Premium Shimmer Modifier (renamed to avoid conflict)
struct PremiumShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    init(duration: Double = 1.5) {
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width * 0.3 + (geometry.size.width * 1.6 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func premiumShimmer(duration: Double = 1.5) -> some View {
        modifier(PremiumShimmerModifier(duration: duration))
    }
}

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.1))
            .frame(width: width, height: height)
            .premiumShimmer()
    }
}

// MARK: - Skeleton Card
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(height: 120, cornerRadius: 16)
            SkeletonView(width: 200, height: 16)
            SkeletonView(width: 150, height: 12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Shimmer Text
struct ShimmerText: View {
    let text: String
    let font: Font
    
    init(_ text: String, font: Font = .body) {
        self.text = text
        self.font = font
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(.white.opacity(0.6))
            .premiumShimmer()
    }
}

// MARK: - Glow Effect
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
            .shadow(color: color.opacity(0.1), radius: radius * 1.5)
    }
}

extension View {
    func glow(color: Color = .blue, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Pulse Animation
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double
    
    init(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 1.0) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulsing(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 1.0) -> some View {
        modifier(PulseModifier(minScale: minScale, maxScale: maxScale, duration: duration))
    }
}

// MARK: - Loading Dots
struct LoadingDots: View {
    let count: Int
    let color: Color
    let size: CGFloat
    @State private var activeIndex = 0
    
    init(count: Int = 3, color: Color = .white, size: CGFloat = 8) {
        self.count = count
        self.color = color
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: size * 0.75) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(activeIndex == index ? 1.3 : 1.0)
                    .opacity(activeIndex == index ? 1.0 : 0.5)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeIndex = (activeIndex + 1) % count
                }
            }
        }
    }
}

// MARK: - Premium Typing Indicator (renamed to avoid conflict)
struct PremiumTypingIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            LoadingDots(count: 3, color: .white.opacity(0.7), size: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Preview
#Preview("Shimmer Effects") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 30) {
            ShimmerText("Premium Loading...", font: .title.bold())
            
            SkeletonCard()
            
            HStack {
                SkeletonView(width: 60, height: 60, cornerRadius: 30)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(width: 150, height: 14)
                    SkeletonView(width: 100, height: 12)
                }
            }
            
            LoadingDots()
            
            PremiumTypingIndicator()
            
            Circle()
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
                .glow(color: .purple)
                .pulsing()
        }
        .padding()
    }
}
