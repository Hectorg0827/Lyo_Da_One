import Foundation

// MARK: - Creator stats
//
// What a creator's clips add up to.
//
// People need to see their numbers moving before they will believe there is
// anything to build here, so this is the scoreboard — which makes it exactly
// the place where a number must not be invented. A creator deciding whether
// this is worth their time is the last person who should be shown a figure
// the server never sent.
//
// Every count on a clip is optional: views, likes, comments and shares all
// arrive nil when the backend has nothing to say. Summing them as zero would
// silently understate a creator's reach and look exactly like a real total,
// so each total carries how many clips actually reported it.
//
// `libraryTotal` is the same idea one level up. The clips endpoint is paged,
// so a creator with 120 clips is handed 50 and the sum over them is not their
// total — it is the total of one page, and without this it would be labelled
// complete.
//
// Mirrors web `creator-stats.mjs` and Android `CreatorStats`.

/// The metrics a clip can report, in the order they are shown.
enum CreatorMetric: String, CaseIterable, Identifiable {
    case views, likes, comments, shares

    var id: String { rawValue }

    var title: String {
        switch self {
        case .views: return "Views"
        case .likes: return "Likes"
        case .comments: return "Comments"
        case .shares: return "Shares"
        }
    }
}

/// One total across a creator's clips.
///
/// `reporting` is the honest part: `value` is the sum of what was reported,
/// and `reporting` says how much of the library that covers.
struct CreatorTotal: Equatable {
    let metric: CreatorMetric
    let value: Int
    let reporting: Int
    let clips: Int

    /// Whether this total has anything behind it at all.
    ///
    /// False means no clip reported the figure. The surface shows that as
    /// "Not reported" rather than 0, because a creator whose views are not
    /// being counted needs to know that, not be told nobody watched.
    var isReported: Bool { reporting > 0 }

    /// Whether every clip reported this figure.
    var isComplete: Bool { clips > 0 && reporting == clips }

    /// The qualifier shown under a partial total, or nil when there is none.
    var coverageNote: String? {
        guard isReported, !isComplete else { return nil }
        return "from \(reporting) of \(clips) clips"
    }
}

enum CreatorStats {

    /// Every total across the clips that arrived, measured against the library.
    ///
    /// `libraryTotal` is how many clips the creator has, which is not how many
    /// arrived: the endpoint is paged. When it is larger than the page, the
    /// totals are over the page and say so. When it is missing or smaller,
    /// the page is all there is.
    static func totals(for clips: [Clip], libraryTotal: Int? = nil) -> [CreatorMetric: CreatorTotal] {
        var result: [CreatorMetric: CreatorTotal] = [:]
        for metric in CreatorMetric.allCases {
            result[metric] = total(for: metric, in: clips, libraryTotal: libraryTotal)
        }
        return result
    }

    static func total(
        for metric: CreatorMetric,
        in clips: [Clip],
        libraryTotal: Int? = nil
    ) -> CreatorTotal {
        var value = 0
        var reporting = 0
        for clip in clips {
            guard let count = count(of: metric, on: clip) else { continue }
            value += count
            reporting += 1
        }
        let library = max(libraryTotal ?? clips.count, clips.count)
        return CreatorTotal(metric: metric, value: value, reporting: reporting, clips: library)
    }

    /// A count on one clip, or nil when the clip did not report it.
    private static func count(of metric: CreatorMetric, on clip: Clip) -> Int? {
        switch metric {
        case .views: return clip.viewCount
        case .likes: return clip.likeCount
        case .comments: return clip.commentCount
        case .shares: return clip.shareCount
        }
    }
}
