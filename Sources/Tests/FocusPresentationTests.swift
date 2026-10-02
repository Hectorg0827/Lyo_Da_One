import XCTest
@testable import Lyo

// The decisions the Focus tab makes about a learner's saved courses, driven
// directly rather than through a SwiftUI body — for the same reason
// `TestPrepPresentationTests` exists next door. Nobody in this workstream can
// tap through the iOS build, so a test reaching the decision is the only
// verification this logic gets.
//
// The rule being defended throughout: a figure the app does not have is not a
// zero, and an action label is not a measurement.

private func course(
    title: String = "A course",
    subtitle: String? = nil,
    progress: Double? = nil,
    lessonCount: Int? = nil,
    completedLessons: Int? = nil,
    updatedAt: Date = Date()
) -> UIStackItem {
    UIStackItem(
        type: .course,
        title: title,
        subtitle: subtitle,
        updatedAt: updatedAt,
        progress: progress,
        courseId: "course-1",
        lessonCount: lessonCount,
        completedLessons: completedLessons
    )
}

final class FocusProgressTests: XCTestCase {

    func testLessonCountsWinWhenBothAreKnown() {
        let item = course(progress: 0.5, lessonCount: 18, completedLessons: 11)
        XCTAssertEqual(FocusPresentation.progress(for: item), .lessons(total: 18, completed: 11))
    }

    func testCompletedLessonsAreDerivedFromTheFractionWhenAbsent() {
        let item = course(progress: 0.5, lessonCount: 18)
        XCTAssertEqual(FocusPresentation.progress(for: item), .lessons(total: 18, completed: 9))
    }

    /// The whole point of the type. A known total with an unknown position is
    /// not a course the learner has not started — it is a course the app has
    /// not synced, and an empty track would assert the former.
    func testKnownTotalWithNoPositionIsUnknownRatherThanZero() {
        let item = course(lessonCount: 18)
        XCTAssertEqual(FocusPresentation.progress(for: item), .unknown)
        XCTAssertNil(FocusPresentation.percentComplete(for: item))
    }

    func testNoFiguresAtAllIsUnknown() {
        XCTAssertEqual(FocusPresentation.progress(for: course()), .unknown)
        XCTAssertNil(FocusPresentation.percentComplete(for: course()))
    }

    func testFractionIsUsedWhenNoLessonCountExists() {
        XCTAssertEqual(FocusPresentation.progress(for: course(progress: 0.34)), .fraction(0.34))
        XCTAssertEqual(FocusPresentation.percentComplete(for: course(progress: 0.34)), 34)
    }

    func testOutOfRangeFiguresAreClamped() {
        XCTAssertEqual(FocusPresentation.progress(for: course(progress: 1.8)), .fraction(1))
        XCTAssertEqual(FocusPresentation.progress(for: course(progress: -0.4)), .fraction(0))
        XCTAssertEqual(
            FocusPresentation.progress(for: course(lessonCount: 10, completedLessons: 44)),
            .lessons(total: 10, completed: 10)
        )
    }

    func testCompletionRequiresAFigureThatReachesTheEnd() {
        XCTAssertTrue(FocusPresentation.isFinished(course(progress: 1)))
        XCTAssertTrue(FocusPresentation.isFinished(course(lessonCount: 9, completedLessons: 9)))
        XCTAssertFalse(FocusPresentation.isFinished(course(progress: 0.99)))
        // Unknown is not finished, however tempting a default would be.
        XCTAssertFalse(FocusPresentation.isFinished(course()))
    }
}

final class FocusActionTests: XCTestCase {

    func testActionReflectsWhereTheLearnerIs() {
        XCTAssertEqual(FocusPresentation.action(for: course(progress: 0.4)), .resume)
        XCTAssertEqual(FocusPresentation.action(for: course(progress: 0)), .start)
        XCTAssertEqual(FocusPresentation.action(for: course(progress: 1)), .review)
        XCTAssertEqual(
            FocusPresentation.action(for: course(lessonCount: 12, completedLessons: 3)),
            .resume
        )
    }

    /// `.start` on an unmeasured course is a label for a button, not a claim
    /// that the learner has done nothing — which is why the card still draws
    /// no progress figure for it.
    func testUnknownProgressOffersStartWithoutAssertingZero() {
        let item = course()
        XCTAssertEqual(FocusPresentation.action(for: item), .start)
        XCTAssertEqual(FocusPresentation.progress(for: item), .unknown)
    }

    func testTitles() {
        XCTAssertEqual(FocusCourseAction.start.title, "Start")
        XCTAssertEqual(FocusCourseAction.resume.title, "Resume")
        XCTAssertEqual(FocusCourseAction.review.title, "Review")
    }
}

final class FocusFilterTests: XCTestCase {

    func testEachFilterCatchesWhatItSays() {
        let started = course(progress: 0.5)
        let fresh = course(progress: 0)
        let done = course(progress: 1)

        XCTAssertTrue(FocusPresentation.matches(started, filter: .inProgress))
        XCTAssertFalse(FocusPresentation.matches(started, filter: .notStarted))
        XCTAssertFalse(FocusPresentation.matches(started, filter: .finished))

        XCTAssertTrue(FocusPresentation.matches(fresh, filter: .notStarted))
        XCTAssertTrue(FocusPresentation.matches(done, filter: .finished))
        XCTAssertFalse(FocusPresentation.matches(done, filter: .inProgress))

        for item in [started, fresh, done] {
            XCTAssertTrue(FocusPresentation.matches(item, filter: .all))
        }
    }

    /// An unmeasured course must still be reachable from a filter, or it is
    /// invisible everywhere except "All".
    func testUnmeasuredCoursesAreReachable() {
        XCTAssertTrue(FocusPresentation.matches(course(), filter: .notStarted))
        XCTAssertTrue(FocusPresentation.matches(course(), filter: .all))
    }

    func testCoursesAreNewestFirstAndMustBeAbleToOpen() {
        let now = Date()
        let old = UIStackItem(
            type: .course, title: "Old", updatedAt: now.addingTimeInterval(-9000), courseId: "a"
        )
        let recent = UIStackItem(
            type: .course, title: "Recent", updatedAt: now, courseId: "b"
        )
        // No course id: tapping it has nowhere to go, so it is not a card.
        let unopenable = UIStackItem(type: .course, title: "Broken", updatedAt: now, courseId: "   ")
        let chat = UIStackItem(type: .chat, title: "A chat", updatedAt: now, courseId: "c")

        let result = FocusPresentation.courses(in: [old, unopenable, chat, recent])
        XCTAssertEqual(result.map(\.title), ["Recent", "Old"])
    }
}

final class FocusBlurbTests: XCTestCase {

    func testADescriptionIsUsedWhenThereIsOne() {
        let item = course(subtitle: "Lesson 11")
        XCTAssertEqual(
            FocusPresentation.blurb(description: "Electron pushing, then synthesis.", for: item),
            .description("Electron pushing, then synthesis.")
        )
    }

    /// `UIStackItem` has no description field, so this is the ordinary case.
    /// The fallback is something the stack really carries.
    func testTheSubtitleStandsInWhenNoDescriptionExists() {
        let item = course(subtitle: "Lesson 11 · E1 vs E2")
        XCTAssertEqual(
            FocusPresentation.blurb(description: nil, for: item),
            .subtitle("Lesson 11 · E1 vs E2")
        )
    }

    func testWhitespaceCountsAsAbsent() {
        let item = course(subtitle: "   ")
        XCTAssertEqual(FocusPresentation.blurb(description: "\n ", for: item), .none)
    }

    func testNeitherSaysSoRatherThanFillingTheSpace() {
        XCTAssertEqual(FocusPresentation.blurb(description: nil, for: course()), .none)
    }
}

final class FocusWeakConceptTests: XCTestCase {

    private func struggle(
        _ topic: String,
        frequency: Int = 1,
        resolved: Bool = false,
        daysAgo: Int = 0
    ) -> StruggleItem {
        StruggleItem(
            id: topic,
            topic: topic,
            firstOccurred: Date().addingTimeInterval(TimeInterval(-86_400 * daysAgo)),
            frequency: frequency,
            resolved: resolved
        )
    }

    func testMostFrequentFirstAndResolvedDropped() {
        let concepts = FocusPresentation.weakConcepts([
            struggle("Titration curves", frequency: 2),
            struggle("Long division", frequency: 9, resolved: true),
            struggle("E2 elimination", frequency: 5),
            struggle("Subjunctive mood", frequency: 3)
        ])
        XCTAssertEqual(concepts, ["E2 elimination", "Subjunctive mood", "Titration curves"])
    }

    func testDuplicatesCollapseIgnoringCase() {
        let concepts = FocusPresentation.weakConcepts([
            struggle("E2 elimination", frequency: 4),
            struggle("e2 ELIMINATION", frequency: 3),
            struggle("Titration", frequency: 2)
        ])
        XCTAssertEqual(concepts, ["E2 elimination", "Titration"])
    }

    func testBlankTopicsAreDroppedAndTheLimitHolds() {
        let concepts = FocusPresentation.weakConcepts([
            struggle("  ", frequency: 9),
            struggle("One", frequency: 5),
            struggle("Two", frequency: 4),
            struggle("Three", frequency: 3),
            struggle("Four", frequency: 2)
        ])
        XCTAssertEqual(concepts, ["One", "Two", "Three"])
    }

    /// Nothing recorded means the row is hidden, not filled with guesses.
    func testNoStrugglesMeansNoChips() {
        XCTAssertTrue(FocusPresentation.weakConcepts([]).isEmpty)
        XCTAssertTrue(FocusPresentation.weakConcepts([struggle("Done", resolved: true)]).isEmpty)
    }
}

final class FocusArtworkTests: XCTestCase {

    func testSubjectKeywordsPickTheMatchingMotif() {
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Organic Chemistry: Reaction Mechanisms"), .lattice)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Spanish B1 Conversation"), .speech)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Introduction to Statistics"), .curve)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Music Theory Basics"), .staff)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Linear Algebra Done Right"), .grid)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(FocusPresentation.motif(forTitle: "ORGANIC CHEMISTRY"), .lattice)
    }

    /// The reason this uses FNV-1a rather than `hashValue`: Swift seeds its own
    /// hashing per process, so a course would repaint itself on every launch.
    func testTheFallbackIsStableAcrossCalls() {
        let title = "Beekeeping for beginners"
        let first = FocusPresentation.motif(forTitle: title)
        XCTAssertEqual(first, FocusPresentation.motif(forTitle: title))
        XCTAssertEqual(
            FocusPresentation.stableHash("Beekeeping for beginners"),
            FocusPresentation.stableHash("Beekeeping for beginners")
        )
    }

    func testDifferentTitlesHashDifferently() {
        XCTAssertNotEqual(FocusPresentation.stableHash("one"), FocusPresentation.stableHash("two"))
    }

    func testAnEmptyTitleStillGetsArt() {
        XCTAssertTrue(FocusArtMotif.allCases.contains(FocusPresentation.motif(forTitle: "")))
    }
}
