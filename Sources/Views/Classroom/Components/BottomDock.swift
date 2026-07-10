import SwiftUI

/// Frosted-glass bottom dock with the page's primary action at the center
/// and small auxiliary tools (mic, tools) flanking it.
///
/// The dock sits over the lesson content with a tall blur so the gradient
/// background continues underneath without bleeding into the controls.
struct BottomDock: View {
    let primaryLabel: String
    var onPrimary: () -> Void = {}
    var onMic: () -> Void = {}
    var onTools: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            iconButton(systemImage: "mic.fill", action: onMic)

            Button(action: onPrimary) {
                HStack(spacing: 8) {
                    Text(primaryLabel)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(ClassroomTokens.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [ClassroomTokens.accent, ClassroomTokens.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: ClassroomTokens.accentGlow.opacity(0.5), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            iconButton(systemImage: "square.grid.2x2.fill", action: onTools)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(ClassroomTokens.glassBorder, lineWidth: 1)
        )
        .shadow(color: ClassroomTokens.cardShadow, radius: 18, x: 0, y: 8)
    }

    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ClassroomTokens.textPrimary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
