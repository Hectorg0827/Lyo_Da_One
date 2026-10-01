import SwiftUI

// MARK: - From people you follow
//
// Five recent posts from the learner's own follow graph, then a hand-off to
// Community.
//
// Capped on purpose. Focus is where saved courses live, and an endless feed
// above them would bury the thing the screen is for — once a feed starts
// nobody scrolls back up. Five is enough to show the app has other people in
// it; the full feed already exists one tab away.
//
// It must be the follow graph. `scripts/verify-android-focus-honesty.mjs` bans
// a public feed on this screen in CI, because an earlier build labelled public
// posts as community activity, which told the learner these were people they
// had chosen to follow when they were not. So this requests `sortBy: .following`
// and, when that comes back empty, says so rather than falling back to public
// posts to fill the rail.

@MainActor
final class FocusFollowFeedModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded([CommunityPost])
        /// The request failed. Not the same as "nobody you follow has posted".
        case failed
    }

    @Published private(set) var state: State = .idle

    private let limit = 5

    func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let response = try await CommunityService.shared.fetchPosts(
                page: 1,
                limit: limit,
                filters: CommunityFeedFilters(sortBy: .following)
            )
            state = .loaded(Array(response.items.prefix(limit)))
        } catch {
            state = .failed
        }
    }
}

struct FocusFollowRail: View {
    let state: FocusFollowFeedModel.State
    let onSeeAll: () -> Void
    let onOpen: (CommunityPost) -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            placeholderRail
        case let .loaded(posts) where posts.isEmpty:
            notice("No posts yet from people you follow.")
        case let .loaded(posts):
            VStack(spacing: 10) {
                rail(posts)
                seeAll
            }
        case .failed:
            notice("Could not load posts from people you follow.")
        }
    }

    // MARK: - Pieces

    private func rail(_ posts: [CommunityPost]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(posts) { post in
                    Button { onOpen(post) } label: { FocusPostCard(post: post) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 15)
        }
        .scrollClipDisabled()
        // The rail bleeds to both edges so items scroll off the screen rather
        // than stopping short of it; the inner padding keeps the first card
        // aligned with the headings above.
        .padding(.horizontal, -15)
    }

    private var seeAll: some View {
        Button(action: onSeeAll) {
            HStack(spacing: 6) {
                Text("See all in Community")
                    .font(.system(size: 11.5, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(DesignTokens.Colors.accentSecondaryLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                DesignTokens.Colors.accentSecondary.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(DesignTokens.Colors.accentSecondary.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var placeholderRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 128, height: 170)
                }
            }
            .padding(.horizontal, 15)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -15)
        .accessibilityLabel("Loading posts")
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.white.opacity(0.46))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

// MARK: - One post

private struct FocusPostCard: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            media
            Text(post.content)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineSpacing(1.5)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 9)
                .padding(.bottom, 11)
        }
        .frame(width: 128)
        .background(Color(hex: "0E1320"), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.authorName), \(kindLabel). \(post.content)")
    }

    /// The post's own image when it has one, otherwise artwork generated from
    /// its text — the same treatment the course cards get, so a text post does
    /// not read as a broken image.
    private var media: some View {
        ZStack(alignment: .topLeading) {
            if let first = post.mediaURLs.first, let url = URL(string: first) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        FocusCourseArtwork(title: post.content)
                    }
                }
            } else {
                FocusCourseArtwork(title: post.content)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.42), .clear, Color.black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )

            kindBadge.padding(7)
        }
        .frame(width: 128, height: 128)
        .clipped()
        .overlay(alignment: .bottomLeading) { author.padding(7) }
    }

    private var kindBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: post.postType.iconName)
                .font(.system(size: 9, weight: .semibold))
            Text(kindLabel)
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.7)
                .textCase(.uppercase)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var author: some View {
        HStack(spacing: 5) {
            Text(initial)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(DesignTokens.Colors.accentSecondary, in: Circle())
            Text(post.authorName)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var kindLabel: String { post.postType.displayName }

    private var initial: String {
        let trimmed = post.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
    }
}
