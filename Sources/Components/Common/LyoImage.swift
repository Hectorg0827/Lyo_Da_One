import SwiftUI
import NukeUI
import Nuke

/// Project-wide replacement for `AsyncImage`. Backed by Nuke for proper memory +
/// disk caching, image-decoding off the main thread, and prepared resize.
///
/// SwiftUI's `AsyncImage` has no real cache — every appearance triggers a new
/// network fetch and a main-thread decode. In a feed/list this turns into
/// hundreds of redundant downloads per scroll, which is the main reason image
/// scrolling feels sluggish today.
///
/// `LyoImage` is a drop-in replacement for the most common usage pattern:
///
/// ```swift
/// LyoImage(url: avatarURL) { image in
///     image.resizable().aspectRatio(contentMode: .fill)
/// } placeholder: {
///     Color.gray.opacity(0.15)
/// }
/// ```
///
/// On failure it shows the same placeholder by default, or a custom failure view
/// if provided. For the common avatar/thumbnail case, see `LyoImage.thumbnail`.
struct LyoImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    let processors: [ImageProcessing]
    let transaction: ImageTransaction
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    init(
        url: URL?,
        processors: [ImageProcessing] = [],
        transaction: ImageTransaction = .init(animation: .easeOut(duration: 0.2)),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.processors = processors
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                content(image)
                    .transition(.opacity)
            } else if state.error != nil {
                failure()
            } else {
                placeholder()
            }
        }
        .processors(processors)
        .transaction { $0.animation = transaction.animation }
    }

    struct ImageTransaction {
        var animation: Animation?
    }
}

// MARK: - Convenience overloads (placeholder = failure)

extension LyoImage where Failure == Placeholder {
    init(
        url: URL?,
        processors: [ImageProcessing] = [],
        transaction: ImageTransaction = .init(animation: .easeOut(duration: 0.2)),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            processors: processors,
            transaction: transaction,
            content: content,
            placeholder: placeholder,
            failure: placeholder
        )
    }
}

// MARK: - Common shapes

extension LyoImage where Content == AnyView, Placeholder == AnyView, Failure == AnyView {
    /// Square thumbnail with rounded corners. Resized server-side via Nuke for cheap
    /// memory + bandwidth. Use this for avatars, leaderboard rows, and small grid
    /// thumbnails.
    static func thumbnail(url: URL?, size: CGFloat, cornerRadius: CGFloat = 8) -> LyoImage {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: size * scale, height: size * scale)
        return LyoImage(
            url: url,
            processors: [ImageProcessors.Resize(size: pixelSize, contentMode: .aspectFill)],
            content: { image in
                AnyView(
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
            },
            placeholder: {
                AnyView(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: size, height: size)
                )
            },
            failure: {
                AnyView(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        )
                        .frame(width: size, height: size)
                )
            }
        )
    }

    /// Circular avatar. The classic profile-row use case.
    static func avatar(url: URL?, size: CGFloat) -> LyoImage {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: size * scale, height: size * scale)
        return LyoImage(
            url: url,
            processors: [ImageProcessors.Resize(size: pixelSize, contentMode: .aspectFill)],
            content: { image in
                AnyView(
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                )
            },
            placeholder: {
                AnyView(
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: size, height: size)
                )
            },
            failure: {
                AnyView(
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                        )
                        .frame(width: size, height: size)
                )
            }
        )
    }
}

// MARK: - Cache configuration

enum LyoImagePipeline {
    /// Call once at app launch. Bumps memory + disk caches well above iOS defaults
    /// so feed scrolling actually keeps images warm.
    static func configure() {
        let pipeline = ImagePipeline {
            $0.dataCache = try? DataCache(name: "com.lyo.image-cache")
            $0.dataCachePolicy = .automatic
            // 200 MB on disk for thumbnails; OS may evict under pressure.
            ($0.dataCache as? DataCache)?.sizeLimit = 200 * 1024 * 1024
            // 100 MB in-memory image cache. Holds thousands of resized thumbs.
            $0.imageCache = ImageCache(costLimit: 100 * 1024 * 1024, countLimit: 1000)
        }
        ImagePipeline.shared = pipeline
    }
}
