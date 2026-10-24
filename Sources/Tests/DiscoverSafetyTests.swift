import XCTest
@testable import Lyo

/// Report and Block on Discover.
///
/// Mirrored by web `discover-report.test.mjs` and Android
/// `DiscoverSafetyTest.kt`: a learner has to get the same choices and the
/// same outcome on every platform.
final class DiscoverSafetyTests: XCTestCase {

    func testEveryReasonIsOneTheAPIStoresAndOfferedOnce() {
        // LyoBackendJune lyo_app/community/models.py ReportReason; anything else is a 422.
        let apiReasons: Set<String> = [
            "spam", "harassment", "hate_speech", "violence", "sexual_content",
            "misinformation", "impersonation", "copyright", "inappropriate", "other",
        ]
        let reasons = DiscoverReportReason.allCases
        for reason in reasons {
            XCTAssertTrue(apiReasons.contains(reason.rawValue), "API refuses \(reason.rawValue)")
        }
        XCTAssertEqual(Set(reasons.map(\.label)).count, reasons.count)
        XCTAssertEqual(reasons.last, .other, "a learner can always say \"something else\"")
        XCTAssertEqual(DiscoverSafety.noteLimit, 1000)
    }

    func testOwnVideosCannotBeReportedAndAnUnknownOwnerLeavesItToTheServer() {
        XCTAssertFalse(DiscoverSafety.canReport(ownerId: "42", viewerId: "42"))
        XCTAssertTrue(DiscoverSafety.canReport(ownerId: "42", viewerId: "7"))
        XCTAssertTrue(DiscoverSafety.canReport(ownerId: nil, viewerId: "7"))
        XCTAssertTrue(DiscoverSafety.canReport(ownerId: "42", viewerId: nil))
    }

    func testBlockIsOfferedOnSomeoneElsesVideoNeverYourOwnOrALibraryVideo() {
        XCTAssertTrue(DiscoverSafety.canBlock(ownerId: "42", viewerId: "7", isLibrary: false))
        XCTAssertFalse(DiscoverSafety.canBlock(ownerId: "42", viewerId: "42", isLibrary: false))
        XCTAssertFalse(DiscoverSafety.canBlock(ownerId: "42", viewerId: "7", isLibrary: true),
                       "blocking the library account would empty Discover")
        XCTAssertFalse(DiscoverSafety.canBlock(ownerId: nil, viewerId: "7", isLibrary: false))
        XCTAssertFalse(DiscoverSafety.canBlock(ownerId: "42", viewerId: nil, isLibrary: false),
                       "an unknown viewer might be the owner")
    }

    func testAReportARepeatOrAVanishedVideoLeavesTheFeedAFailureDoesNot() {
        XCTAssertEqual(DiscoverSafety.reportOutcome(status: 201),
                       .init(succeeded: true, message: "Thanks. We'll review this video."))
        XCTAssertTrue(DiscoverSafety.reportOutcome(status: 200).succeeded)
        XCTAssertTrue(DiscoverSafety.reportOutcome(status: 404).succeeded)
        for status in [0, 400, 401, 422, 500, 503] {
            XCTAssertFalse(DiscoverSafety.reportOutcome(status: status).succeeded, "status \(status)")
        }
    }

    func testABlockSucceedsOnceTheServerStoresIt() {
        XCTAssertEqual(DiscoverSafety.blockOutcome(status: 201, name: "Sam"),
                       .init(succeeded: true, message: "Blocked Sam. You won't see each other's videos or comments."))
        XCTAssertTrue(DiscoverSafety.blockOutcome(status: 200, name: "Sam").succeeded)
        XCTAssertEqual(DiscoverSafety.blockOutcome(status: 404, name: "Sam"),
                       .init(succeeded: false, message: "This account no longer exists."))
        for status in [0, 400, 401, 422, 500] {
            XCTAssertFalse(DiscoverSafety.blockOutcome(status: status, name: "Sam").succeeded)
        }
    }

    func testAfterRemovalsTheNextPageAlsoAsksForTheOneBefore() {
        XCTAssertEqual(DiscoverSafety.pagesToFetch(page: 2, removed: 0, perPage: 20), [2])
        XCTAssertEqual(DiscoverSafety.pagesToFetch(page: 2, removed: 1, perPage: 20), [1, 2])
        XCTAssertEqual(DiscoverSafety.pagesToFetch(page: 3, removed: 20, perPage: 20), [2, 3])
        XCTAssertEqual(DiscoverSafety.pagesToFetch(page: 3, removed: 21, perPage: 20), [1, 2, 3])
        XCTAssertEqual(DiscoverSafety.pagesToFetch(page: 2, removed: 45, perPage: 20), [1, 2])
    }

    func testBlockedAccountsDecodeFromTheServerShape() throws {
        let json = Data(#"[{"id": 9, "user_id": 3, "user_name": "Sam Rivera", "user_avatar": null, "blocked_at": "2026-10-24T17:00:00.123456"}]"#.utf8)
        let accounts = try JSONDecoder.lyoDecoder.decode([BlockedAccount].self, from: json)
        XCTAssertEqual(accounts, [BlockedAccount(userId: 3, userName: "Sam Rivera")])
    }
}
