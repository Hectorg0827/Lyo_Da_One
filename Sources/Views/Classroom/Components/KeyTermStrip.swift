import SwiftUI

/// Compact, collapsible strip for a single definition or callout.
///
/// Rendered very small — should never compete with the teaching card.
/// Tapping the chevron expands `expandedDetail` (for follow-up). When no
/// expanded content is provided the chevron is hidden.
///
/// Maps to `LessonBlock(block_type: "callout")` from the backend.
struct KeyTermStrip: View {
    let label: String
    let term: String
    let definition: String
    var expandedDetail: String? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if expandedDetail != nil {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    aaIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(ClassroomTokens.accent)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        (
                            Text(term)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ClassroomTokens.textPrimary)
                            +
                            Text(" — \(definition)")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(ClassroomTokens.textSecondary)
                        )
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    if expandedDetail != nil {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ClassroomTokens.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if isExpanded, let detail = expandedDetail {
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ClassroomTokens.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: ClassroomTokens.stripRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: ClassroomTokens.stripRadius, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClassroomTokens.stripRadius, style: .continuous)
                .stroke(ClassroomTokens.glassBorder, lineWidth: 1)
        )
    }

    /// "Aa" icon prefix.
    private var aaIcon: some View {
        Text("Aa")
            .font(.system(size: 13, weight: .bold, design: .serif))
            .foregroundStyle(ClassroomTokens.accent)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ClassroomTokens.accent.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ClassroomTokens.accent.opacity(0.30), lineWidth: 0.5)
            )
    }
}
