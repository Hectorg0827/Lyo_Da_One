import SwiftUI

/// Renders a `SuggestedActionCard` under Lyo's chat reply.
///
/// Visual style intentionally mirrors the classroom's calm glass aesthetic
/// (deep navy, lavender accent) so the transition between chat → classroom
/// feels continuous when the primary action is tapped.
///
/// Two callbacks: `onPrimary` (tap the big button) and `onChip` (tap a
/// secondary chip with its label). The chat view-model interprets both
/// based on the card's kind + payload.
struct SuggestedActionCardView: View {
    let card: SuggestedActionCard
    var onPrimary: (SuggestedActionCard) -> Void = { _ in }
    var onChip: (String, SuggestedActionCard) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row: kind badge + title
            HStack(spacing: 8) {
                Image(systemName: kindIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ClassroomTokens.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(ClassroomTokens.accent.opacity(0.14))
                    )

                Text(kindLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ClassroomTokens.accent)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Spacer()
            }

            // Title + optional subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ClassroomTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = card.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(ClassroomTokens.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Primary CTA
            Button {
                onPrimary(card)
            } label: {
                HStack(spacing: 6) {
                    Text(card.primaryLabel)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(ClassroomTokens.textOnAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [ClassroomTokens.accent, ClassroomTokens.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: ClassroomTokens.accentGlow.opacity(0.45), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            // Secondary chips (optional)
            if !card.chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(card.chips, id: \.self) { label in
                            Button {
                                onChip(label, card)
                            } label: {
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ClassroomTokens.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(Color.white.opacity(0.07))
                                    )
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)  // breathing room for ring
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ClassroomTokens.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Kind metadata

    private var kindIcon: String {
        switch card.kind {
        case .guidedLesson: return "graduationcap.fill"
        case .studyPlan:    return "calendar.badge.clock"
        }
    }

    private var kindLabel: String {
        switch card.kind {
        case .guidedLesson: return "Suggested · Guided lesson"
        case .studyPlan:    return "Suggested · Study plan"
        }
    }
}
