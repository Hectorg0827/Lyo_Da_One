import SwiftUI

/// Banner card at the top of a lesson screen.
///
/// Picks a deterministic gradient + SF Symbol from the topic string so every
/// course gets a distinct, recognizable header without any network request or
/// generated image. If the backend later supplies a real cover image URL, pass
/// it via `imageURL` and the hero will load it through `LyoImage` (Nuke-backed,
/// cached). When the URL is nil or fails, the gradient stays as the surface.
struct LessonHero: View {
    let topic: String
    let subtitle: String?
    let progress: Double?       // 0.0 … 1.0, optional
    let imageURL: URL?

    init(topic: String, subtitle: String? = nil, progress: Double? = nil, imageURL: URL? = nil) {
        self.topic = topic
        self.subtitle = subtitle
        self.progress = progress
        self.imageURL = imageURL
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background

            // Soft dark scrim so light text always reads, even over bright photos.
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    Text("Course")
                        .font(ClassroomTokens.captionMeta)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    Spacer(minLength: 0)
                }

                Text(topic)
                    .font(ClassroomTokens.titleHero)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(ClassroomTokens.bodyLesson)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                }

                if let progress {
                    progressBar(value: progress)
                        .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: ClassroomTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ClassroomTokens.cardRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: ClassroomTokens.cardShadow, radius: 18, y: 10)
    }

    // MARK: - Background layers

    @ViewBuilder
    private var background: some View {
        gradient
            .overlay(decorations)
        if let imageURL {
            LyoImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.clear
            }
            .transition(.opacity)
        }
    }

    private var gradient: some View {
        // Single source of truth — same gradient used in stack chips, course
        // catalog, chat proposal card, etc.
        TopicArt.gradient(for: topic)
    }

    /// Faint geometric flourishes so the banner doesn't look flat. Two soft
    /// off-screen circles tinted with the gradient's complement.
    private var decorations: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: proxy.size.width * 0.7)
                    .blur(radius: 30)
                    .offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.35)
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: proxy.size.width * 0.5)
                    .blur(radius: 20)
                    .offset(x: -proxy.size.width * 0.35, y: proxy.size.height * 0.35)
            }
        }
    }

    // MARK: - Progress bar

    private func progressBar(value: Double) -> some View {
        let clamped = min(max(value, 0), 1)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(Color.white)
                    .frame(width: proxy.size.width * CGFloat(clamped))
            }
        }
        .frame(height: 6)
    }

    /// Icon glyph for the lesson topic. Delegates to the shared `TopicArt`
    /// keyword map so the same course shows the same icon in stack chips,
    /// catalog cards, chat proposals — wherever it appears.
    private var iconName: String { TopicArt.iconName(for: topic) }
}
