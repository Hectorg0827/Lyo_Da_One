import SwiftUI

/// Single source of truth for "how does a topic look in this app."
///
/// A course / lesson / stack item shows up on many surfaces (chat proposal,
/// stack drawer, course library, classroom hero). Without a shared component
/// each one chose its own gradient + icon, which made the same course look
/// like three different products as the user scrolled. `TopicArt` collapses
/// that into one deterministic mapping from `topic` string → (gradient, icon).
///
/// All APIs are pure functions of the topic string — no network calls, no
/// allocations beyond the `Color`s themselves. The output is stable across
/// runs (uses a custom FNV-1a hash instead of `String.hashValue`, which is
/// randomized per launch).
enum TopicArt {

    // MARK: - Public API

    /// The two-color gradient pair to use as a course/topic background.
    static func gradientPair(for topic: String) -> (Color, Color) {
        palette[bucket(for: topic, count: palette.count)]
    }

    /// A SwiftUI `LinearGradient` ready to drop into a background.
    static func gradient(
        for topic: String,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> LinearGradient {
        let (a, b) = gradientPair(for: topic)
        return LinearGradient(colors: [a, b], startPoint: startPoint, endPoint: endPoint)
    }

    /// SF Symbol that best fits the topic. Falls back to a graduation cap.
    static func iconName(for topic: String) -> String {
        let t = topic.lowercased()
        for (keyword, symbol) in keywordIcons where t.contains(keyword) {
            return symbol
        }
        return "graduationcap.fill"
    }

    // MARK: - Palette

    /// Six gradient pairs. Keep the count a small prime-ish number so two
    /// adjacent course titles in a list don't always collapse onto the same
    /// pair. Hand-tuned for readability on both light and dark surfaces.
    private static let palette: [(Color, Color)] = [
        (Color(hex: "8B5CF6"), Color(hex: "3B82F6")),  // violet → blue
        (Color(hex: "EC4899"), Color(hex: "8B5CF6")),  // pink → violet
        (Color(hex: "F59E0B"), Color(hex: "EF4444")),  // amber → red
        (Color(hex: "10B981"), Color(hex: "06B6D4")),  // emerald → cyan
        (Color(hex: "6366F1"), Color(hex: "0EA5E9")),  // indigo → sky
        (Color(hex: "F97316"), Color(hex: "DB2777")),  // orange → fuchsia
    ]

    /// Topic-keyword → SF Symbol mapping. Order matters — earlier entries
    /// win, so put more specific keywords ("photoshop") above generic ones
    /// ("photo"). The fallback at the call site catches everything else.
    private static let keywordIcons: [(String, String)] = [
        ("calculus", "function"), ("algebra", "function"), ("math", "function"),
        ("geometr", "ruler"), ("statistics", "chart.bar"), ("probabil", "dice"),
        ("physic", "atom"), ("chem", "flask"), ("biolog", "leaf"),
        ("astron", "moon.stars"), ("space", "moon.stars"),
        ("history", "building.columns.fill"), ("geograph", "globe"),
        ("english", "character.book.closed"), ("spanish", "character.book.closed"),
        ("french", "character.book.closed"), ("language", "character.book.closed"),
        ("music", "music.note"), ("paint", "paintpalette"), ("art", "paintpalette"),
        ("photoshop", "camera.macro"), ("photo", "camera"),
        ("swift", "swift"), ("ios", "applelogo"),
        ("python", "terminal"), ("javascript", "curlybraces"),
        ("code", "chevron.left.forwardslash.chevron.right"),
        ("program", "chevron.left.forwardslash.chevron.right"),
        ("web", "globe"),
        ("ai", "sparkles"), ("machine learning", "sparkles"),
        ("data", "cylinder"), ("design", "wand.and.stars"),
        ("business", "briefcase"), ("finance", "dollarsign.circle"),
        ("health", "heart"), ("medic", "cross.case"), ("psycholog", "brain"),
        ("cook", "fork.knife"), ("recipe", "fork.knife"),
        ("guitar", "guitars"), ("piano", "pianokeys"),
    ]

    // MARK: - Hash

    /// FNV-1a 64-bit. Stable across app launches (unlike `String.hashValue`),
    /// fast enough to compute on every render.
    private static func bucket(for topic: String, count: Int) -> Int {
        var h: UInt64 = 1469598103934665603
        for byte in topic.lowercased().utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        return Int(h % UInt64(count))
    }
}

// MARK: - TopicArtSwatch

/// A ready-to-drop-in thumbnail view that shows the topic gradient with the
/// matched glyph overlaid. Useful as a placeholder when a course has no real
/// cover image, or as the entire cover on smaller cards (stack chips, list
/// rows). For richer use, embed it inside a `ZStack` and add title/subtitle.
struct TopicArtSwatch: View {
    let topic: String
    var iconSize: CGFloat = 22
    var showGlyph: Bool = true
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            TopicArt.gradient(for: topic)
            // Soft lens-flare highlight so flat gradients don't feel flat.
            GeometryReader { proxy in
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: proxy.size.width * 0.6)
                    .blur(radius: 24)
                    .offset(x: proxy.size.width * 0.25, y: -proxy.size.height * 0.3)
            }
            if showGlyph {
                Image(systemName: TopicArt.iconName(for: topic))
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
