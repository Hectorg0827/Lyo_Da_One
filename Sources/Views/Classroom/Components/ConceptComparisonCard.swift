import SwiftUI

/// Side-by-side comparison: two columns, a "VS" circle in the middle,
/// and a takeaway strip at the bottom.
///
/// Used for `LessonBlock(block_type: "comparison")` from the backend, where
/// the AI emits `headers: [<left>, <right>]` and `rows: [[lhs, rhs], ...]`.
/// The takeaway is read from `block.content`.
struct ConceptComparisonCard: View {
    let title: String
    let leftHeading: String
    let leftBullets: [String]
    let rightHeading: String
    let rightBullets: [String]
    let takeaway: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ClassroomTokens.textPrimary)

            // Two columns + VS
            ZStack {
                HStack(alignment: .top, spacing: 0) {
                    column(heading: leftHeading, bullets: leftBullets, alignment: .leading)
                    Spacer(minLength: 12)
                    column(heading: rightHeading, bullets: rightBullets, alignment: .leading)
                }

                versusCircle
            }

            // Takeaway strip (if provided)
            if let takeaway, !takeaway.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ClassroomTokens.accent)
                    Text(takeaway)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(ClassroomTokens.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ClassroomTokens.accent.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ClassroomTokens.accent.opacity(0.18), lineWidth: 0.5)
                )
            }
        }
        .padding(ClassroomTokens.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .classroomGlassCard()
    }

    @ViewBuilder
    private func column(heading: String, bullets: [String], alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(heading)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ClassroomTokens.accent)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: alignment, spacing: 6) {
                ForEach(bullets, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(ClassroomTokens.accent.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(item)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(ClassroomTokens.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var versusCircle: some View {
        Text("VS")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(ClassroomTokens.textPrimary)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(ClassroomTokens.accent.opacity(0.18))
                    .background(
                        Circle().fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                Circle().stroke(ClassroomTokens.accent.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: ClassroomTokens.accentGlow.opacity(0.4), radius: 8)
    }
}
