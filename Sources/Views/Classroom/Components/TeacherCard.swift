import SwiftUI

/// The hero of the lesson screen: the AI teacher's current message,
/// a single primary "Continue" action, and two muted secondary actions.
///
/// Designed for *progressive disclosure* — only the current teaching message
/// is shown. Tapping Continue advances the parent state to the next message.
struct TeacherCard: View {
    let teacherName: String
    let teacherBadge: String
    let bodyText: String
    var teacherImageName: String? = nil

    let primaryActionLabel: String
    var onPrimary: () -> Void = {}

    var secondaryActions: [SecondaryAction] = []

    struct SecondaryAction: Identifiable {
        let id = UUID()
        let label: String
        let systemImage: String?
        let onTap: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header row: avatar, name, AI Teacher badge
            HStack(spacing: 10) {
                if let imageName = teacherImageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .shadow(color: ClassroomTokens.accentGlow.opacity(0.5), radius: 8)
                } else {
                    LyoAvatar(size: 32)
                }

                Text(teacherName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(ClassroomTokens.textPrimary)

                Text(teacherBadge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ClassroomTokens.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(ClassroomTokens.accent.opacity(0.14))
                    )
                    .overlay(
                        Capsule().stroke(ClassroomTokens.accent.opacity(0.30), lineWidth: 0.5)
                    )

                Spacer()
            }

            // Main teaching paragraph
            Text(bodyText)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(ClassroomTokens.textPrimary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // Primary action
            PrimaryActionButton(label: primaryActionLabel, action: onPrimary)

            // Secondary actions row
            if !secondaryActions.isEmpty {
                HStack(spacing: 18) {
                    ForEach(secondaryActions) { action in
                        Button(action: action.onTap) {
                            HStack(spacing: 6) {
                                if let icon = action.systemImage {
                                    Image(systemName: icon)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                Text(action.label)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(ClassroomTokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(ClassroomTokens.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .classroomGlassCard(elevated: true)
    }
}

// MARK: - Primary action button

struct PrimaryActionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(ClassroomTokens.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ClassroomTokens.accent, ClassroomTokens.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: ClassroomTokens.accentGlow.opacity(0.45), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}
