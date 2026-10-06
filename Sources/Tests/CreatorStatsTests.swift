import XCTest
@testable import Lyo

/// The scoreboard a creator reads to decide whether this is worth their time.
///
/// Mirrored by `creator-stats.test.mjs` and `CreatorStatsTest.kt`: the rule
/// that a count the server did not send is not a zero has to hold on all
/// three, or one platform quietly understates someone's reach.
final class CreatorStatsTests: XCTestCase {

    private func clip(
        views: Int? = nil,
        likes: Int? = nil,
        comments: Int? = nil,
        shares: Int? = nil
    ) -> Clip {
        Clip(
            userId: 1,
            title: "A clip",
            videoURL: URL(string: "https://example.com/c.mp4")!,
            viewCount: views,
            likeCount: likes,
            commentCount: comments,
            shareCount: shares
        )
    }

    func testTotalsAddUpWhatEveryClipReported() {
        let totals = CreatorStats.totals(for: [
            clip(views: 100, likes: 5, comments: 2, shares: 1),
            clip(views: 40, likes: 3, comments: 0, shares: 4)
        ])
        XCTAssertEqual(totals[.views]?.value, 140)
        XCTAssertEqual(totals[.likes]?.value, 8)
        XCTAssertEqual(totals[.comments]?.value, 2)
        XCTAssertEqual(totals[.shares]?.value, 5)
        for metric in CreatorMetric.allCases {
            XCTAssertTrue(totals[metric]?.isComplete == true, "\(metric) should be complete")
        }
    }

    /// Summing a missing count as zero would understate the creator's reach
    /// and look exactly like a real total.
    func testACountTheServerDidNotSendIsNotAZero() {
        let total = CreatorStats.total(for: .views, in: [
            clip(views: 100),
            clip(views: nil),
            clip()
        ])
        XCTAssertEqual(total.value, 100)
        XCTAssertEqual(total.reporting, 1)
        XCTAssertEqual(total.clips, 3)
        XCTAssertFalse(total.isComplete)
        XCTAssertEqual(total.coverageNote, "from 1 of 3 clips")
    }

    /// A clip genuinely watched zero times reported its figure. That is not
    /// the same as a clip whose views are not being counted.
    func testARealZeroStillCountsAsReported() {
        let total = CreatorStats.total(for: .views, in: [clip(views: 0)])
        XCTAssertEqual(total.value, 0)
        XCTAssertTrue(total.isReported)
        XCTAssertTrue(total.isComplete)
        XCTAssertNil(total.coverageNote)
    }

    func testNothingReportedIsNotAZeroEither() {
        let total = CreatorStats.total(for: .views, in: [clip(), clip()])
        XCTAssertFalse(total.isReported)
        XCTAssertFalse(total.isComplete)
        // No note: the surface says "Not reported" instead of a qualified number.
        XCTAssertNil(total.coverageNote)
    }

    func testACompleteTotalCarriesNoQualifier() {
        let total = CreatorStats.total(for: .views, in: [clip(views: 7), clip(views: 3)])
        XCTAssertEqual(total.value, 10)
        XCTAssertNil(total.coverageNote)
    }

    func testNoClipsIsNoStatsNotZeroes() {
        let total = CreatorStats.total(for: .views, in: [])
        XCTAssertEqual(total.clips, 0)
        XCTAssertFalse(total.isReported)
        XCTAssertFalse(total.isComplete)
    }
}
