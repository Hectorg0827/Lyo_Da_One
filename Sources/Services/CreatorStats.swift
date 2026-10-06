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

    /// Every total, plus the clip count — which is always known.
    static func totals(for clips: [Clip]) -> [CreatorMetric: CreatorTotal] {
        var result: [CreatorMetric: CreatorTotal] = [:]
        for metric in CreatorMetric.allCases {
            result[metric] = total(for: metric, in: clips)
        }
        return result
    }

    static func total(for metric: CreatorMetric, in clips: [Clip]) -> CreatorTotal {
        var value = 0
        var reporting = 0
        for clip in clips {
            guard let count = count(of: metric, on: clip) else { continue }
            value += count
            reporting += 1
        }
        return CreatorTotal(metric: metric, value: value, reporting: reporting, clips: clips.count)
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
