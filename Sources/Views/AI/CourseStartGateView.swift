import SwiftUI

/// A short, truthful transition between selecting a course and presenting the
/// classroom. This view does not simulate advertising, subscription benefits,
/// curriculum generation, or progress that is not backed by a real service.
struct CourseStartGateView: View {
    let courseId: String
    let courseTitle: String
    let onProceed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didProceed = false
    @State private var orbPulse = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 28) {
                Spacer()

                classroomOrb

                VStack(spacing: 10) {
                    Text("Opening your classroom")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(Color(hex: "A78BFA"))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text("Connecting your saved course context and learning tools.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
                    .accessibilityLabel("Opening classroom")

                Button(action: proceed) {
                    Label("Open now", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "7C3AED"), Color(hex: "2563EB")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(didProceed)

                Spacer()

                Button("Cancel") {
                    guard !didProceed else { return }
                    dismiss()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .task {
            guard !didProceed else { return }
            // Give the full-screen cover one render pass before MainTabView
            // dismisses it and presents the classroom destination.
            try? await Task.sleep(nanoseconds: 250_000_000)
            proceed()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                orbPulse = true
            }
            Log.ui.info("Course transition opened for courseId=\(courseId)")
        }
    }

    private var displayTitle: String {
        let trimmed = courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your class" : trimmed
    }

    private var background: some View {
        ZStack {
            Color(hex: "060811")
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "7C3AED").opacity(0.32), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 460
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "2563EB").opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
    }

    private var classroomOrb: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color(hex: "A78BFA").opacity(0.26 - Double(index) * 0.055), lineWidth: 1.5)
                    .frame(
                        width: CGFloat(118 + index * 34),
                        height: CGFloat(118 + index * 34)
                    )
                    .scaleEffect(orbPulse ? 1.05 + Double(index) * 0.015 : 0.96)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "8B5CF6"), Color(hex: "2563EB")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 92, height: 92)
                .shadow(color: Color(hex: "7C3AED").opacity(0.55), radius: 30)

            Image(systemName: "graduationcap.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: 205)
        .accessibilityHidden(true)
    }

    @MainActor
    private func proceed() {
        guard !didProceed else { return }
        didProceed = true
        Log.ui.info("Course transition proceeding to classroom for courseId=\(courseId)")
        onProceed()
    }
}

#Preview {
    CourseStartGateView(
        courseId: "course-123",
        courseTitle: "Introduction to Physics",
        onProceed: {}
    )
}
