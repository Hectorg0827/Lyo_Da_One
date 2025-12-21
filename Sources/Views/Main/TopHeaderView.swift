import SwiftUI

struct TopHeaderView: View {
    let title: String
    let onProfileTap: () -> Void

    var body: some View {
        ZStack {
            // Subtle glass background for readability over gradients
            VisualEffectBlur(material: .ultraThin, blendingMode: .normal)
                .opacity(0.8)
                .ignoresSafeArea(edges: .top)
            
            HStack {
                // Left spacer to keep title centered
                Spacer().frame(width: 44)

                // Title
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                // Profile button
                Button(action: onProfileTap) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .frame(height: 80) // Matches the top padding used in FocusView
    }
}

// A small helper to get a blur similar to .ultraThinMaterial with broader OS support
private struct VisualEffectBlur: View {
    let material: Material
    let blendingMode: BlendMode

    init(material: Material = .ultraThin, blendingMode: BlendMode = .normal) {
        self.material = material
        self.blendingMode = blendingMode
    }

    var body: some View {
        Rectangle().fill(material)
            .blendMode(blendingMode)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 0) {
            TopHeaderView(title: "Focus", onProfileTap: {})
            Spacer()
        }
    }
}
