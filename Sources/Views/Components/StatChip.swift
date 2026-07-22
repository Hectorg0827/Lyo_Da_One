import SwiftUI

/// Compact metric component shared by navigation and profile surfaces.
/// Kept separate from the retired legacy Focus implementation.
struct StatChip: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
