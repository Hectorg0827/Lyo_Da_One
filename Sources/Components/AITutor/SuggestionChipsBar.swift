import SwiftUI

struct SuggestionChipsBar: View {
    let suggestions: [SuggestionChip]
    let onTap: (SuggestionChip) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(suggestions) { chip in
                    PremiumChipButton(chip: chip, onTap: onTap)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

struct PremiumChipButton: View {
    let chip: SuggestionChip
    let onTap: (SuggestionChip) -> Void
    @State private var isPressed = false
    @State private var showShimmer = true
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Button {
            HapticManager.shared.light()
            
            withAnimation(DesignTokens.Animation.quick) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignTokens.Animation.springBouncy) {
                    isPressed = false
                }
                onTap(chip)
            }
        } label: {
            HStack(spacing: 6) {
                if let icon = chip.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(chip.text)
                    .font(DesignTokens.Typography.labelMedium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(chipBackground)
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .opacity(isPressed ? 0.8 : 1.0)
        .animation(DesignTokens.Animation.springBouncy, value: isPressed)
    }
    
    @ViewBuilder
    private var chipBackground: some View {
        ZStack {
            // Gradient background
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface,
                            DesignTokens.Colors.surfaceElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Border gradient
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.accent.opacity(0.6),
                            DesignTokens.Colors.accentSecondary.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            
            // Glossy overlay
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
        .applyShadow(DesignTokens.Shadow.sm)
        .modifier(ConditionalShimmer(enabled: showShimmer && !reduceMotion))
    }
}

// MARK: - Conditional Shimmer Modifier

struct ConditionalShimmer: ViewModifier {
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content.shimmer(duration: 3.0, opacity: 0.15)
        } else {
            content
        }
    }
}
