import SwiftUI

/// End-of-lesson celebration + shareable recap.
///
/// Shown as an overlay when `LivingClassroomService.lessonComplete` flips.
/// The recap card renders to an image (ImageRenderer) so it can be shared to
/// any app — every finished lesson becomes lightweight, branded, learner-made
/// marketing.
struct LessonCompletionOverlay: View {
    let topic: String
    let points: [String]
    /// The session's checkpoint questions — powers "Challenge a friend".
    var quizQuestions: [ChallengeQuestion] = []
    let onKeepGoing: () -> Void
    let onDone: () -> Void

    @State private var appeared = false
    @State private var challenge: FriendChallenge?
    @State private var creatingChallenge = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                LessonRecapCard(topic: topic, points: points)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)

                HStack(spacing: 12) {
                    ShareLink(
                        item: renderedCardImage(),
                        preview: SharePreview(
                            "What I learned: \(topic)",
                            image: renderedCardImage()
                        )
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .foregroundColor(.white)
                    }

                    Button(action: onKeepGoing) {
                        Label("Keep learning", systemImage: "arrow.right")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                            )
                            .foregroundColor(.white)
                    }
                }

                // Duel a friend on this lesson's checkpoints.
                if !quizQuestions.isEmpty {
                    if let challenge {
                        ShareLink(item: ChallengeService.shareMessage(for: challenge)) {
                            Label("Send challenge · code \(challenge.code)", systemImage: "person.2.fill")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color(hexString: "D9B24C").opacity(0.25)))
                                .overlay(Capsule().stroke(Color(hexString: "D9B24C").opacity(0.5), lineWidth: 1))
                                .foregroundColor(.white)
                        }
                    } else {
                        Button {
                            guard !creatingChallenge else { return }
                            creatingChallenge = true
                            Task {
                                challenge = try? await ChallengeService.shared.create(
                                    topic: topic, questions: quizQuestions)
                                creatingChallenge = false
                            }
                        } label: {
                            Label(
                                creatingChallenge ? "Creating…" : "Challenge a friend",
                                systemImage: "person.2"
                            )
                            .font(.subheadline.bold())
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .foregroundColor(.white)
                        }
                        .disabled(creatingChallenge)
                    }
                }

                Button("Done", action: onDone)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
            HapticManager.shared.playSuccess()
        }
    }

    @MainActor
    private func renderedCardImage() -> Image {
        let renderer = ImageRenderer(
            content: LessonRecapCard(topic: topic, points: points)
                .frame(width: 380)
        )
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "graduationcap.fill")
    }
}

/// The shareable card itself — branded, compact, learner-made.
struct LessonRecapCard: View {
    let topic: String
    let points: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image("Mascot_Standing")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lesson complete! 🎉")
                        .font(.caption.bold())
                        .foregroundColor(Color(hexString: "A78BFA"))
                    Text(topic.isEmpty ? "Today's lesson" : topic)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT I LEARNED")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.5))
                        .kerning(1.2)
                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hexString: "10B981"))
                                .padding(.top, 2)
                            Text(point)
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack {
                Text("Learned with Lyo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hexString: "D9B24C"))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(hexString: "0E173D"), Color(hexString: "1A1D2E")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hexString: "8B5CF6").opacity(0.6), Color(hexString: "D946EF").opacity(0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
}

#Preview {
    LessonCompletionOverlay(
        topic: "Photosynthesis",
        points: [
            "Light energy is converted to chemical energy in chloroplasts",
            "The equation: 6CO2 + 6H2O + light → C6H12O6 + 6O2",
            "Chlorophyll absorbs red and blue light, reflecting green",
        ],
        onKeepGoing: {},
        onDone: {}
    )
    .background(Color(hexString: "0B1230"))
}
