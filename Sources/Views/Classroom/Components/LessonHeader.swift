import SwiftUI

/// Top header for the active lesson screen.
///
/// Layout:  `<` [avatar] Title                              [...]
///                       Subtitle (Lesson 1 of 6 · Step 2 of 5 · 4 min left)
///          ─────────── progress bar ───────────              40%
struct LessonHeader: View {
    let title: String
    let subtitle: String
    let progress: Double                  // 0.0 … 1.0
    var onBack: () -> Void = {}
    var onMenu: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ClassroomTokens.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                LyoAvatar(size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ClassroomTokens.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ClassroomTokens.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onMenu) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ClassroomTokens.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                LessonProgressBar(progress: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ClassroomTokens.textSecondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Slim animated progress bar

struct LessonProgressBar: View {
    let progress: Double  // 0.0 … 1.0

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ClassroomTokens.accentDeep, ClassroomTokens.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * clamped)
                    .shadow(color: ClassroomTokens.accentGlow.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.5), value: progress)
    }
}

// MARK: - Lyo avatar (small purple orb with "L")

struct LyoAvatar: View {
    var size: CGFloat = 32
    var glow: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "C4B5FD"),
                            Color(hex: "8B5CF6"),
                            Color(hex: "6D5BF5"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("L")
                .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(
            color: glow ? ClassroomTokens.accentGlow.opacity(0.5) : .clear,
            radius: glow ? size * 0.25 : 0
        )
    }
}
